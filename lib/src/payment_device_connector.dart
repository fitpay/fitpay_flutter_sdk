import 'dart:collection';

import 'package:fitpay_flutter_sdk/src/api.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'models.dart';
import 'package:semaphore/semaphore.dart';

enum PaymentDeviceSyncState {
  starting,
  running,
  completed,
  error,
}

enum PaymentDeviceState {
  scanning,
  connecting,
  connected,
  disconnecting,
  disconnected,
  sending,
  waitingOnDevice,
  receiving,
  idle
}

abstract class PaymentDeviceConnector {
  API api;
  Device platformDevice;

  @protected
  String _deviceId;
  String get deviceId => _deviceId;
  PaymentDeviceState _state;
  var _syncLock = GlobalSemaphore();
  List<String> _syncHistory = [];
  PaymentDeviceState get state => _state;

  @protected
  final StreamController<PaymentDeviceState> _stateStream = StreamController<PaymentDeviceState>();
  Stream<PaymentDeviceState> _broadcastStream;
  Stream<PaymentDeviceState> get stateStream {
    if (_broadcastStream == null) _broadcastStream = _stateStream.stream.asBroadcastStream();
    return _broadcastStream;
  }

  PaymentDeviceConnector({this.api, this.platformDevice});

  Future<PaymentDeviceInformation> get deviceInformation;

  @mustCallSuper
  Future<void> connect(String deviceId) async {
    _deviceId = deviceId;
  }

  Future<void> disconnect() async {
    _deviceId = null;
  }

  Future<void> factoryReset() async {}

  void dispatch(PaymentDeviceState state) {
    // avoid dupes
    if (state != _state) {
      print('broadcasting device state change from ${_state.toString()} to ${state.toString()}');
      _state = state;
      _stateStream.add(_state);
    }
  }

  Future<bool> get isConnected async {
    return _state != null &&
        _state != PaymentDeviceState.disconnected &&
        _state != PaymentDeviceState.disconnecting &&
        _state != PaymentDeviceState.connecting &&
        _state != PaymentDeviceState.scanning;
  }

  bool _duplicateSync(SyncRequest syncRequest) {
    if (syncRequest == null || syncRequest.syncId == null) return false; // unable to dedupe these!

    for (int i = 0; i < _syncHistory.length; i++) {
      if (syncRequest.syncId == _syncHistory[i]) {
        return true;
      }
    }

    _syncHistory.add(syncRequest.syncId);
    while (_syncHistory.length > 100) {
      _syncHistory.remove(0);
    }

    return false;
  }

  Stream<PaymentDeviceSyncState> sync({SyncRequest syncRequest}) async* {
    if (_duplicateSync(syncRequest)) return;

    Device device = platformDevice;
    if (device == null) {
      print('sync called ahead of platform device being available, waiting ...');
      device = await Observable.periodic(Duration(seconds: 1))
          .timeout(Duration(seconds: 30))
          .doOnEach((_) => 'still waiting to perform sync on platformDevice being available ... ')
          .where((_) => platformDevice != null)
          .map((_) => platformDevice)
          .first;
    }

    try {
      await _syncLock.acquire();
      print('starting sync on device ${device.deviceIdentifier}');

      var taskLock = new LocalSemaphore(1);

      yield PaymentDeviceSyncState.starting;

      if (syncRequest != null) {
        api.ackSync(syncRequest);
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      Uri commitsUrl = platformDevice?.links['commits'].toUri();
      Map<String, dynamic> commitsUrlParameters = Map.from(commitsUrl.queryParameters);
      var lastCommitId = prefs.getString('last_commit_id');

      if (prefs.containsKey('last_commit_id')) {
        commitsUrlParameters['commitsAfter'] = prefs.getString('last_commit_id');
      }

      commitsUrlParameters['includeAcknowledged'] =
          api?.config?.syncIncludeAcknowledgedCommits ?? true ? 'true' : 'false';

      commitsUrl = Uri(
        scheme: commitsUrl.scheme,
        host: commitsUrl.host,
        port: commitsUrl.port,
        path: commitsUrl.path,
        queryParameters: commitsUrlParameters,
      );

      yield PaymentDeviceSyncState.running;

      while (commitsUrl != null) {
        Page<Commit> commits = await api.getDeviceCommits(commitsUrl);
        if (commits == null || commits.results == null) return;

        Queue<Function> tasks = Queue();

        commits.results.forEach((commit) => tasks.add(() async {
              try {
                await taskLock.acquire();

                if (commit.commitType == 'APDU_PACKAGE') {
                  APDUPackage apduPackage = APDUPackage.fromJson(await api.encryptor.decrypt(commit.encryptedData));
                  ApduExecutionResult result = await executeApduPackage(apduPackage)
                      .where((apduStatus) => apduStatus.state == APDUExecutionState.success)
                      .map((apduStatus) => apduStatus.result)
                      .first;

                  if (result != null) {
                    await api.confirmApduPackage(commit, result);
                  }

                  await prefs.setString('last_commit_id', commit.commitId);
                  return true;
                } else {
                  CommitResponse response;

                  switch (commit.commitType) {
                    case 'CREDITCARD_CREATED':
                      response = await syncOnCreditCardCreated(commit);
                      break;
                    case 'CREDITCARD_DELETED':
                      response = await syncOnCreditCardDeleted(commit);
                      break;
                    case 'CREDITCARD_ACTIVATED':
                      response = await syncOnCreditCardActivated(commit);
                      break;
                    case 'CREDITCARD_DEACTIVATED':
                      response = await syncOnCreditCardDeactivated(commit);
                      break;
                    case 'CREDITCARD_REACTIVATED':
                      response = await syncOnCreditCardReactivated(commit);
                      break;
                    case 'CREDITCARD_METADATA_UPDATED':
                      response = await syncOnCreditCardMetadataUpdated(commit);
                      break;
                    case 'CREDITCARD_PROVISION_FAILED':
                      response = await syncOnCreditCardProvisionFailed(commit);
                      break;
                    default:
                      print('(default) skipping commit: ${commit.commitType}');
                      response = CommitResponse(
                        result: CommitResult.SKIPPED,
                      );
                  }

                  await api.confirmDeviceCommit(commit, response);

                  if (response.result == CommitResult.FAILED) {
                    return false;
                  }
                }

                await prefs.setString('last_commit_id', commit.commitId);
                return true;
              } catch (err) {
                print('error during sync: $err');
                return false;
              } finally {
                taskLock.release();
              }
            }));

        // execute all the commits
        print('${tasks.length} commits to sync in this chunk');
        bool successful = true;
        for (var i = 0; i < tasks.length; i++) {
          print('sync commit ${commits.results[i].commitType} ${i + 1}/${tasks.length} starting');
          bool result = await Future(tasks.elementAt(i));
          print('sync commit ${commits.results[i].commitType} ${i + 1}/${tasks.length} completed: $result');

          if (!result) {
            print('sync commit ${commits.results[i].commitType} failed, breaking out of sync workflow');
            successful = false;
            break;
          }
        }

        if (successful && commits.links.containsKey('next')) {
          commitsUrl = commits.links['next'].toUri();
        } else {
          commitsUrl = null;
        }
      }

      if (syncRequest != null) {
        api.completeSync(syncRequest);
      }

      yield PaymentDeviceSyncState.completed;
    } finally {
      _syncLock.release();
    }
  }

  Future<CommitResponse> syncOnCreditCardCreated(Commit commit) async {
    return CommitResponse(
      result: CommitResult.SKIPPED,
    );
  }

  Future<CommitResponse> syncOnCreditCardDeleted(Commit commit) async {
    return CommitResponse(
      result: CommitResult.SKIPPED,
    );
  }

  Future<CommitResponse> syncOnCreditCardActivated(Commit commit) async {
    return CommitResponse(
      result: CommitResult.SKIPPED,
    );
  }

  Future<CommitResponse> syncOnCreditCardDeactivated(Commit commit) async {
    return CommitResponse(
      result: CommitResult.SKIPPED,
    );
  }

  Future<CommitResponse> syncOnCreditCardReactivated(Commit commit) async {
    return CommitResponse(
      result: CommitResult.SKIPPED,
    );
  }

  Future<CommitResponse> syncOnCreditCardMetadataUpdated(Commit commit) async {
    return CommitResponse(
      result: CommitResult.SKIPPED,
    );
  }

  Future<CommitResponse> syncOnCreditCardProvisionFailed(Commit commit) async {
    return CommitResponse(
      result: CommitResult.SKIPPED,
    );
  }

  Stream<APDUExecutionStatus> executeApduPackage(APDUPackage apduPackage);

  void dispose() {}
}

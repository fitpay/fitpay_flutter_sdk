import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:fitpay_flutter_sdk/src/models.dart';
import 'package:fitpay_flutter_sdk/src/payment_device_connector.dart';
import 'package:rxdart/rxdart.dart';
import 'hndx_models.dart';
import 'package:rx_ble/rx_ble.dart';
import 'package:semaphore/semaphore.dart';
import '../utils.dart';

class HndxConnectionState {
  final BleConnectionState state;
  final HendricksPaymentDeviceConnector connector;

  HndxConnectionState(this.state, {this.connector});
}

enum HndxWorkflowState {
  idle,
  waiting_status_start_ack,
  status_start_ack,
  waiting_command_ack,
  command_ack,
  waiting_status_end_ack,
  status_end_ack,
  waiting_data,
}

class HendricksPaymentDeviceConnector extends PaymentDeviceConnector {
  static final HendricksPaymentDeviceConnector _singleton = HendricksPaymentDeviceConnector._internal();
  factory HendricksPaymentDeviceConnector() => _singleton;

  HendricksPaymentDeviceConnector._internal();

  StreamSubscription<Uint8List> _statusObserver;
  StreamSubscription<Uint8List> _dataObserver;

  ScanResult scanResult;

  // hndx command state information during command execution
  HndxWorkflowState _workflowState;
  HndxStatusAck _statusEndAck;
  HndxStatusAck _cmdAck;
  StreamController<HndxWorkflowState> _workflow;
  StreamSubscription<dynamic> _connectStream;
  int _cmdStartTime;
  int _currentCmd;
  int _expectedDataLength;
  Uint8List _dataBuffer;
  StreamController<HndxResultState> _commandResult;
  int _mtu = 20;
  APDUPackage _apduPackage;
  var _hndxLock = new LocalSemaphore(1);
  var _hndxConnectingLock = new LocalSemaphore(1);
  Timer _heartbeatTimer;

  @override
  Future<void> connect(String deviceId) async {
    await _hndxConnectingLock.acquire();

    try {
      if (await isConnected) return;
      if (!(await RxBle.hasAccess())) {
        await RxBle.requestAccess(showRationale: () async {
          return true;
        });
      }
      await super.connect(deviceId);

      // rx_ble requires a scan to be performed before a connection
      await _connectStream?.cancel();

      if (scanResult == null) {
        print('hndx looking for and connecting to $deviceId');

        await _connectStream?.cancel();
        await RxBle.stopScan();

        print('hndx scanning for $deviceId');
        dispatch(PaymentDeviceState.scanning);
        scanResult = await RxBle.startScan(deviceId: deviceId).first;
        print('hndx $deviceId found in scan, stopping scan');
        await RxBle.stopScan();

        if (Platform.isAndroid) {
          print('hndx $deviceId scan stopped, forcing pause before attempting connect');
          await Future.delayed(Duration(seconds: 3));
        }
      } else {
        print('hndx scanResult ${scanResult.toString()} already exists, skipping scan');
      }

      try {
        _connectStream?.cancel();
        _connectStream = RxBle.connect(deviceId, waitForDevice: true, autoConnect: false).listen((state) async {
          print('hndx connection state change ${state.toString()}');

          switch (state) {
            case BleConnectionState.connecting:
              dispatch(PaymentDeviceState.connecting);
              break;

            case BleConnectionState.connected:
              print('forcing 2s delay after connected event, why?!???');
              await Future.delayed(Duration(seconds: 1));

              if (Platform.isAndroid) {
                print('android only: requesting mtu change');
                try {
                  _mtu = await RxBle.requestMtu(deviceId, 257);
                } on BleDisconnectedException {
                  print('unexpected ble disconnect');
                  disconnect();
                  return;
                }

                print('android only: mtu=$_mtu');
                _mtu = _mtu - 3;
              } else if (Platform.isIOS) {
                // hard coded for iOS
                _mtu = 182;
              }

              _createSubscriptions();

              // this is here so this app can deal with devices that haven't been upgraded yet to emit the 0x03 (ready)
              // byte when the above subscriptions have been completed.  This effectively replicates what was going on
              // before the 0x03 was introduced with a delay between "connected" and actually being ready to send
              // data to hndx
              stateStream.where((state) => state == PaymentDeviceState.connected).first.timeout(Duration(seconds: 2),
                  onTimeout: () {
                print(
                    'dispatching connected after not receiving the 0x03 byte back from the device, older firmware maybe?');
                dispatch(PaymentDeviceState.connected);
                return null;
              });

              _heartbeatTimer ??= Timer.periodic(Duration(seconds: 20), (_) {
                _sendCommand(Uint8List.fromList([HndxStatus.HEARTBEAT]))
                    .listen((cmdState) => print('hndx heartbeat state change: ${cmdState.toString()}'));
              });

              break;

            case BleConnectionState.disconnecting:
              print('hndx ble connector disconnecting');
              dispatch(PaymentDeviceState.disconnecting);
              break;

            case BleConnectionState.disconnected:
              print('hndx ble connector disconnected');
              disconnect();
              break;

            default:
              print('unhandled ble state change: ${state.toString()}');
          }
        });
      } on BleDisconnectedException {
        print('unexpected ble disconnect while trying to connect, calling connect again');
        Future.delayed(Duration(milliseconds: 100), () => connect(deviceId));
      }
    } finally {
      _hndxConnectingLock.release();
    }
  }

  @override
  Future<CommitResponse> syncOnCreditCardDeleted(Commit commit) async {
    Map<String, dynamic> ed = await api.encryptor.decrypt(commit.encryptedData);
    if (ed.containsKey('creditCardId')) {
      return Observable(_deleteCreditCard(ed['creditCardId']))
          .where((state) => state.state == HndxCmdState.complete)
          .map((state) => CommitResponse(result: CommitResult.SUCCESS))
          .first
          .timeout(Duration(seconds: 30), onTimeout: () => CommitResponse(result: CommitResult.FAILED));
    }

    return CommitResponse(result: CommitResult.SKIPPED);
  }

  @override
  Future<void> factoryReset() async {
    await Observable(_sendCommand(Uint8List.fromList([HndxCmd.FACTORY_RESET, 0x01])))
        .where((result) => result.state == HndxCmdState.complete)
        .first
        .timeout(Duration(seconds: 30));
  }

  @override
  Future<CommitResponse> syncOnCreditCardActivated(Commit commit) async {
    Map<String, dynamic> ed = await api.encryptor.decrypt(commit.encryptedData);

    if (ed.containsKey('creditCardId')) {
      return Observable(_activateCreditCard(ed['creditCardId']))
          .where((state) => state.state == HndxCmdState.complete || state.state == HndxCmdState.skipped)
          .map((state) => CommitResponse(
              result: state.state == HndxCmdState.complete ? CommitResult.SUCCESS : CommitResult.SKIPPED))
          .onErrorReturn(CommitResponse(result: CommitResult.FAILED))
          .first
          .timeout(Duration(seconds: 30), onTimeout: () => CommitResponse(result: CommitResult.FAILED));
    }

    return CommitResponse(result: CommitResult.SKIPPED);
  }

  @override
  Future<CommitResponse> syncOnCreditCardMetadataUpdated(Commit commit) async {
    Map<String, dynamic> ed = await api.encryptor.decrypt(commit.encryptedData);

    if (ed.containsKey('creditCardId')) {
      String creditCardId = ed['creditCardId'];

      return Observable.fromFuture(api.getCreditCards())
          .expand((page) => page.results)
          .where((card) => card.creditCardId == creditCardId)
          .defaultIfEmpty(null)
          .asyncExpand((card) => _sendCard(card))
          .where((state) => state.state == HndxCmdState.complete || state.state == HndxCmdState.skipped)
          .map((state) => CommitResponse(
              result: state.state == HndxCmdState.complete ? CommitResult.SUCCESS : CommitResult.SKIPPED))
          .onErrorReturn(CommitResponse(result: CommitResult.FAILED))
          .first
          .timeout(Duration(seconds: 30), onTimeout: () => CommitResponse(result: CommitResult.FAILED));
    }

    return CommitResponse(result: CommitResult.SKIPPED);
  }

  @override
  Future<CommitResponse> syncOnCreditCardDeactivated(Commit commit) async {
    Map<String, dynamic> ed = await api.encryptor.decrypt(commit.encryptedData);
    if (ed.containsKey('creditCardId')) {
      return Observable(_dectivateCreditCard(ed['creditCardId']))
          .where((state) => state.state == HndxCmdState.complete || state.state == HndxCmdState.skipped)
          .map((state) => CommitResponse(
              result: state.state == HndxCmdState.complete ? CommitResult.SUCCESS : CommitResult.SKIPPED))
          .onErrorReturn(CommitResponse(result: CommitResult.FAILED))
          .first
          .timeout(Duration(seconds: 30), onTimeout: () => CommitResponse(result: CommitResult.FAILED));
    }

    return CommitResponse(result: CommitResult.SKIPPED);
  }

  @override
  Future<CommitResponse> syncOnCreditCardReactivated(Commit commit) async {
    Map<String, dynamic> ed = await api.encryptor.decrypt(commit.encryptedData);
    if (ed.containsKey('creditCardId')) {
      return Observable(_activateCreditCard(ed['creditCardId']))
          .where((state) => state.state == HndxCmdState.complete || state.state == HndxCmdState.skipped)
          .map((state) => CommitResponse(
              result: state.state == HndxCmdState.complete ? CommitResult.SUCCESS : CommitResult.SKIPPED))
          .onErrorReturn(CommitResponse(result: CommitResult.FAILED))
          .first
          .timeout(Duration(seconds: 30), onTimeout: () => CommitResponse(result: CommitResult.FAILED));
    }

    return CommitResponse(result: CommitResult.SKIPPED);
  }

  @override
  Future<void> disconnect() async {
    print('disconnect called, current workflow state: ${_workflowState.toString()}');
    await Observable.periodic(Duration(milliseconds: 250))
        .where((_) => _workflowState != HndxWorkflowState.idle)
        .first
        .timeout(Duration(seconds: 30), onTimeout: () {});

    dispatch(PaymentDeviceState.disconnecting);
    await RxBle.stopScan();
    await RxBle.disconnect(deviceId: deviceId);

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectStream?.cancel();
    _connectStream = null;
    await _commandResult?.close();
    _commandResult = null;
    await _dataObserver?.cancel();
    _dataObserver = null;
    await _statusObserver?.cancel();
    _statusObserver = null;

    super.disconnect();
    dispatch(PaymentDeviceState.disconnected);
  }

  void _createSubscriptions() {
    _statusObserver = _generateStatusSubscription(deviceId);
    _dataObserver = _generateDataSubscription(deviceId);
  }

  Stream<HndxResultState> _deleteCreditCard(String creditCardId) async* {
    var oid = await _findHndxOidForCreditCard(creditCardId);
    if (oid != null) {
      yield* deleteObject(oid);
    } else {
      yield (HndxResultState(state: HndxCmdState.complete));
    }
  }

  Stream<HndxResultState> clearFirmwareResetFlag() async* {
    yield* _sendCommand(Uint8List.fromList([HndxCmd.CLEAR_FACTORY_RESET]));
  }

  Stream<HndxResultState> deleteObject(Uint8List oid) async* {
    yield* _sendCommand(HndxCategoryUtils.getDeleteCommand(oid));
  }

  Stream<HndxResultState> _activateCreditCard(String creditCardId) async* {
    var foundCard = false;
    var oid = await _findHndxOidForCreditCard(creditCardId);
    if (oid != null) {
      foundCard = true;
      yield* _sendCommand(HndxCategoryUtils.getActivateCommand(oid));
    } else {
      Page<CreditCard> cards = await api.getCreditCards();
      for (CreditCard card in cards.results) {
        if (card.creditCardId == creditCardId) {
          foundCard = true;
          yield* _sendCard(card);
        }
      }
    }

    // card was deleted
    if (!foundCard) {
      yield HndxResultState(state: HndxCmdState.skipped);
    }
  }

  Stream<HndxResultState> _sendCard(CreditCard card) async* {
    if (card == null) {
      yield HndxResultState(state: HndxCmdState.skipped);
      return;
    }

    var oid = await _findHndxOidForCreditCard(card.creditCardId);
    HndxAddCardData c = await HndxCardUtils.addCardCmd(
      api,
      card,
      oid,
      cardStatus:
          card.state == 'ACTIVE' ? HndxCardUtils.HNDX_CARD_STATUS_ACTIVATED : HndxCardUtils.HNDX_CARD_STATUS_CREATED,
    );

    yield* _sendCommand(c.command, data: c.data);
  }

  Stream<HndxResultState> _dectivateCreditCard(String creditCardId) async* {
    var oid = await _findHndxOidForCreditCard(creditCardId);
    if (oid != null) {
      yield* _sendCommand(HndxCategoryUtils.getDeactivateCommand(oid));
    } else {
      yield (HndxResultState(state: HndxCmdState.skipped));
    }
  }

  Stream<HndxResultState> _devicePing() async* {
    yield* _sendCommand(Uint8List.fromList([HndxCmd.PING]));
  }

  Stream<HndxResultState> _getCategoryObjects() async* {
    yield* _sendCommand(Uint8List.fromList([HndxCmd.GET_CATEGORIES]));
  }

  Stream<HndxResultState> getObject(Uint8List categoryId, Uint8List oid) async* {
    yield* _sendCommand(HndxCategoryUtils.getObjectCommand(categoryId, oid));
  }

  Future<Uint8List> _safeBleWrite(String char, Uint8List data) async {
    try {
      return await RxBle.writeChar(deviceId, char, data);
    } on BleDisconnectedException {
      print('unexpected ble disconnect');
      await disconnect();
    } catch (err) {
      print('unexpected ble exception: ${err.toString()}');
      _commandResult.add(HndxResultState(state: HndxCmdState.failed));
      _resetHndxCommandState();
      throw err;
    }

    return Uint8List(0);
  }

  Stream<HndxResultState> _sendCommand(Uint8List command, {Uint8List data, APDUPackage apduPackage}) async* {
    if (!(await isConnected)) {
      print('device not yet connected, waiting to send command ${Utils.hexEncode(command)}: ${state.toString()}');
      bool connected = await Observable.periodic(Duration(seconds: 5))
          .asyncMap((_) => isConnected)
          .where((connected) => connected)
          .timeout(Duration(seconds: 5), onTimeout: (_) => false)
          .first;

      if (!connected) {
        print('timeout waiting on connected device for command ${Utils.hexEncode(command)}');
        yield HndxResultState(state: HndxCmdState.failed);
        return;
      }
    }

    try {
      print('cmd [${Utils.hexEncode(command)}] waiting for lock');
      await _hndxLock.acquire();
      print('cmd [${Utils.hexEncode(command)}] aquired lock');

      this._cmdStartTime = DateTime.now().millisecondsSinceEpoch;
      this._currentCmd = command[0];
      this._apduPackage = apduPackage;
      this._commandResult = StreamController<HndxResultState>();
      this._workflow = StreamController<HndxWorkflowState>();
      this._workflowState = HndxWorkflowState.idle;
      this._dataBuffer = Uint8List(0);

      dispatch(PaymentDeviceState.sending);

      if (_currentCmd == HndxStatus.HEARTBEAT) {
        print('TX: status heartbeat [${HndxStatus.HEARTBEAT.toRadixString(16).padLeft(2, "0")}]');
        var startRes = await _safeBleWrite(HndxBle.STATUS_CHAR, Uint8List.fromList([HndxStatus.HEARTBEAT]));
        print('TX: status heartbeat response [${Utils.hexEncode(startRes)}]');

        yield HndxResultState(state: HndxCmdState.complete);
        _resetHndxCommandState();
        return;
      } else {
        // send status start and then enter a listener waiting for workflow state changes to ensure the state eng for communication
        // matches hndx embedded workflow exactly

        print('TX: status start [${HndxStatus.STATUS_START.toRadixString(16).padLeft(2, "0")}]');
        var startRes = await _safeBleWrite(HndxBle.STATUS_CHAR, Uint8List.fromList([HndxStatus.STATUS_START]));
        print('TX: status start response [${Utils.hexEncode(startRes)}]');
      }

      _workflowState = HndxWorkflowState.waiting_status_start_ack;

      this._workflow.stream.listen((newWorkflowState) async {
        switch (newWorkflowState) {
          case HndxWorkflowState.status_start_ack:
            print('status start ack completed, waiting on command ack');
            _workflowState = HndxWorkflowState.waiting_command_ack;
            print('TX: command [${Utils.hexEncode(command)}]');
            var cmdRes = await _safeBleWrite(HndxBle.COMMAND_CHAR, command);
            print('TX: command response [${Utils.hexEncode(cmdRes)}]');
            break;

          case HndxWorkflowState.command_ack:
            _workflowState = HndxWorkflowState.waiting_status_end_ack;

            if (data != null) {
              print('command ack received, sending data to hndx ...');
              dispatch(PaymentDeviceState.sending);
              print('TX: send data, length ${data.length}');
              for (var i = 0; i < data.length; i += _mtu) {
                int offset = i + _mtu > data.length ? data.length : i + _mtu;

                print('TX: send data [${data.sublist(i, offset)}]');
                var dataRes = await _safeBleWrite(HndxBle.DATA_CHAR, data.sublist(i, offset));
                print(
                    'TX: data response [${Utils.hexEncode(dataRes)}], offset: $i/${data.length} ${(i / data.length) * 100}%');
              }
            }

            dispatch(PaymentDeviceState.waitingOnDevice);
            print('command ack completed, waiting on status end ack');
            print('TX: status end [${HndxStatus.STATUS_END.toRadixString(16).padLeft(2, "0")}]');
            var endRes = await _safeBleWrite(HndxBle.STATUS_CHAR, Uint8List.fromList([HndxStatus.STATUS_END]));
            print('TX: status end response [${Utils.hexEncode(endRes)}]');
            break;

          case HndxWorkflowState.status_end_ack:
            print('status end ack received');
            if (_statusEndAck.length > 0) {
              _workflowState = HndxWorkflowState.waiting_data;
            } else {
              _commandResult.add(HndxResultState(state: HndxCmdState.complete));
              _resetHndxCommandState();
            }
            break;

          default:
            print(
                'unexpected workflow state change from ${_workflowState.toString()} to ${newWorkflowState.toString()}');
        }
      });

      yield* this._commandResult.stream;
    } finally {
      _hndxLock.release();
      print('command [${Utils.hexEncode(command)}] released lock');
    }
  }

  Future<HendricksDeviceInfo> get hendricksDeviceInformation async {
    return _devicePing()
        .where((result) => result.state == HndxCmdState.complete)
        .where((result) => result.result is HendricksDeviceInfo)
        .map((result) => result.result as HendricksDeviceInfo)
        .first
        .timeout(Duration(seconds: 10), onTimeout: () => throw 'Timeout waiting for device ping information');
  }

  @override
  Future<PaymentDeviceInformation> get deviceInformation async {
    return _devicePing()
        .where((result) => result.state == HndxCmdState.complete)
        .where((result) => result.result is HendricksDeviceInfo)
        .map((result) {
          print('result: ${result.result.toString()}');

          if (result.result is HendricksDeviceInfo) {
            HendricksDeviceInfo info = result.result;
            return PaymentDeviceInformation(
                deviceType: DeviceType.WATCH,
                deviceName: 'Hendricks #${info.serialNumber}',
                firmwareRevision: '${info.firmwareVersion}-${info.buildHash}',
                softwareRevision: '1.0.0',
                hardwareRevision: info.hardwareVersion,
                countryCode: 'us',
                serialNumber: info.serialNumber,
                manufacturerName: 'FitPay',
                modelNumber: info.hardwareVersion,
                osName: 'HNDX',
                systemId: info.serialNumber);
          }
        })
        .first
        .timeout(Duration(seconds: 10), onTimeout: () => throw 'Timeout waiting for device ping information');
  }

  Future<void> enterBootloader() async {
    await for (final HndxResultState state in _sendCommand(Uint8List.fromList([HndxCmd.BOOTLOADER]))) {
      if (state.state == HndxCmdState.complete) {
        break;
      } else if (state.state == HndxCmdState.failed) {
        throw 'error entering bootloader';
      }
    }
  }

  Stream<HndxResultState> getCategories() async* {
    yield* _getCategoryObjects();
  }

  Future<Uint8List> _findHndxOidForCreditCard(String creditCardId) async {
    List<HndxObject> candidates = await Observable(_getCategoryObjects())
        .where((state) => state.state == HndxCmdState.complete)
        .map((state) => state.result as HndxGetCategoriesResult)
        .expand((result) => result.categories)
        .where((category) => category.categoryId[0] == 2)
        .expand((category) => category.objects)
        .toList();

    return Observable.fromIterable(candidates)
        .asyncExpand((candidate) => getObject(candidate.categoryId, candidate.oid))
        .where((state) => state.state == HndxCmdState.complete)
        .map((state) => state.result as HndxObjectCard)
        .where((card) => card.creditCardId == creditCardId)
        .map((card) => card.oid)
        .defaultIfEmpty(null)
        .first;
  }

  @override
  Stream<APDUExecutionStatus> executeApduPackage(APDUPackage apduPackage) async* {
    assert(apduPackage != null);

    yield APDUExecutionStatus(state: APDUExecutionState.starting);

    Uint8List data = HndxApduUtils.apduPackageData(apduPackage);
    Uint8List cmd = HndxApduUtils.apduPackageCommand(apduPackage, data);

    await for (final cmdState in _sendCommand(cmd, data: data, apduPackage: apduPackage)) {
      switch (cmdState.state) {
        case HndxCmdState.waiting:
          yield APDUExecutionStatus(state: APDUExecutionState.executing);
          break;

        case HndxCmdState.receiving:
          yield APDUExecutionStatus(state: APDUExecutionState.receiving);
          break;
        case HndxCmdState.sending:
          yield APDUExecutionStatus(state: APDUExecutionState.sending);
          break;
        case HndxCmdState.complete:
          HendricksApduResponse cmdResult = cmdState.result;
          List<ApduCommandResult> apduCmdResults =
              await HndxApduUtils.parseApduCommandResults(_apduPackage, cmdResult.data);

          // determine if the apdu package was successful or not
          ApduExecutionResultState execState = ApduExecutionResultState.processed;
          for (var i = 0; i < apduCmdResults.length; i++) {
            bool continueOnFailure = await Observable.fromIterable(_apduPackage.commandApdus)
                .where((cmd) => cmd.commandId == apduCmdResults[i].commandId)
                .map((cmd) => cmd.continueOnFailure)
                .first;

            if (apduCmdResults[i].responseCode != "9000" && !continueOnFailure) {
              execState = ApduExecutionResultState.failed;
              break;
            }
          }

          print('## APDU Package ${apduPackage.packageId} ##');
          apduPackage.commandApdus.forEach((apduCmd) async {
            print('cmd ${apduCmd.commandId} [${apduCmd.command}]');
            ApduCommandResult cmdResult =
                await Observable.fromIterable(apduCmdResults).where((res) => res.commandId == apduCmd.commandId).first;
            print('res ${cmdResult.commandId} [${cmdResult.responseData}]');
          });

          yield APDUExecutionStatus(
            state: APDUExecutionState.success,
            result: ApduExecutionResult(
              packageId: _apduPackage.packageId,
              executedDuration: DateTime.now().millisecondsSinceEpoch - _cmdStartTime,
              executedTsEpoch: _cmdStartTime,
              state: execState,
              apduResponses: apduCmdResults,
            ),
          );
          return;

        default:
      }
    }
  }

  Stream<Uint8List> _safeBleObserve(final String char) {
    try {
      return RxBle.observeChar(deviceId, char);
    } on BleDisconnectedException {
      print('unexpected ble disconnect');
      disconnect();
    }

    return Stream.empty();
  }

  StreamSubscription<Uint8List> _generateStatusSubscription(String deviceId) {
    return _safeBleObserve(HndxBle.STATUS_CHAR).listen((data) {
      if (data == null || data.length == 0) {
        print('empty status received from hndx device, ignoring');
        return;
      }

      print('status received [${Utils.hexEncode(data)}]');

      HndxStatusAck ack = HndxStatusAck.fromData(data);

      if (ack.successful) {
        switch (_workflowState) {
          case HndxWorkflowState.waiting_status_start_ack:
            _workflow.add(HndxWorkflowState.status_start_ack);
            break;

          case HndxWorkflowState.waiting_command_ack:
            if (_currentCmd != ack.command) {
              print(
                  'command ${_currentCmd.toRadixString(16).padLeft(2, "0")} sent, command ack however reported ${ack.command.toRadixString(16)} bailing out and resetting state');
              _resetHndxCommandState();
            } else {
              _cmdAck = ack;
              _workflow.add(HndxWorkflowState.command_ack);
            }

            break;

          case HndxWorkflowState.waiting_status_end_ack:
            _statusEndAck = ack;
            _expectedDataLength = ack.length;
            _workflow.add(HndxWorkflowState.status_end_ack);
            break;

          default:
            print(
                'unexpected ack received [${Utils.hexEncode(data)}], currentState: ${_workflow.toString()}, resetting state');
            if (!_commandResult?.isClosed || !_commandResult?.isPaused) {
              _commandResult.add(HndxResultState(state: HndxCmdState.failed));
            }

            _resetHndxCommandState();
        }
      } else if (ack.nack) {
        print('nack, resetting state');
        // nack, stop reset the current state and fail
        if (!_commandResult?.isClosed || !_commandResult?.isPaused) {
          _commandResult?.add(HndxResultState(state: HndxCmdState.failed));
        }

        _resetHndxCommandState();
      } else if (ack.ready) {
        print('hndx ble connector setup completed');
        dispatch(PaymentDeviceState.connected);
      } else {
        print('unrecognized status, ignoring....');
      }
    });
  }

  StreamSubscription<Uint8List> _generateDataSubscription(String deviceId) {
    return _safeBleObserve(HndxBle.DATA_CHAR).listen((data) {
      if (_cmdAck == null) {
        print('hndx is sending something back for data that was not expected [${Utils.hexEncode(data)}]');
        return;
      }

      dispatch(PaymentDeviceState.receiving);

      if (_dataBuffer != null) {
        _dataBuffer = Uint8List.fromList(_dataBuffer.toList() + data.toList());
      }

      if (_dataBuffer.length == _expectedDataLength) {
        print(
            'hndx command ${_currentCmd.toRadixString(16).padLeft(2, "0")} ack\'ed: ${_cmdAck.successful}, finished in ${DateTime.now().millisecondsSinceEpoch - _cmdStartTime}ms with data [${Utils.hexEncode(_dataBuffer)}]');

        if (!_cmdAck.successful) {
          _commandResult.add(HndxResultState(state: HndxCmdState.failed));
        } else {
          switch (_currentCmd) {
            case HndxCmd.PING:
              HendricksDeviceInfo info = HendricksDeviceInfo.fromData(_dataBuffer);
              print('ping results received: $info');
              _commandResult.add(HndxResultState(
                state: HndxCmdState.complete,
                result: HendricksDeviceInfo.fromData(_dataBuffer),
              ));
              break;

            case HndxCmd.APDU_PACKAGE:
              _commandResult.add(HndxResultState(
                state: HndxCmdState.complete,
                result: HendricksApduResponse(_dataBuffer),
              ));
              break;

            case HndxCmd.ADD_CARD:
              _commandResult.add(HndxResultState(
                state: HndxCmdState.complete,
                result: HndxAddCardDataResult(_dataBuffer),
              ));
              break;

            case HndxCmd.GET_CATEGORIES:
              _commandResult.add(HndxResultState(
                state: HndxCmdState.complete,
                result: HndxGetCategoriesResult.fromData(_dataBuffer),
              ));
              break;

            case HndxCmd.GET_OBJECT:
              _commandResult.add(HndxResultState(
                state: HndxCmdState.complete,
                result: HndxObject.fromData(_dataBuffer),
              ));
              break;

            case HndxCmd.ACTIVATE_CARD:
            case HndxCmd.DEACTIVATE_CARD:
            case HndxCmd.DELETE_OBJECT:
              _commandResult.add(HndxResultState(state: HndxCmdState.complete));
              break;

            default:
              print('unmapped hndx command ${_currentCmd.toRadixString(16).padLeft(2, "0")}, defaulting as completed');
              _commandResult.add(HndxResultState(state: HndxCmdState.complete));
          }
        }

        _resetHndxCommandState();

        dispatch(PaymentDeviceState.idle);
      } else if (_dataBuffer.length > _expectedDataLength) {
        _commandResult.addError('unexpected data length received, more than $_expectedDataLength bytes received');
        _resetHndxCommandState();

        dispatch(PaymentDeviceState.idle);
      }
    });
  }

  void _resetHndxCommandState() {
    print('resetting hndx cmd state');
    dispatch(PaymentDeviceState.idle);
    _workflow?.close();
    _commandResult.close().then((_) {
      _workflow = null;
      _workflowState = HndxWorkflowState.idle;
      _statusEndAck = null;
      _cmdAck = null;
      _commandResult = null;
      _currentCmd = null;
      _expectedDataLength = 0;
      _dataBuffer = null;
      _apduPackage = null;
    });
  }
}

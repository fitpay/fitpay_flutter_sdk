import 'package:fitpay_flutter_sdk/fitpay_flutter_sdk.dart';
import 'package:fitpay_flutter_sdk/src/encryptor.dart';
import 'package:fitpay_flutter_sdk/src/models.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:uri/uri.dart';
import 'package:eventsource/eventsource.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fitpay_flutter_sdk/src/mock_gpr_account.dart';
import 'package:fitpay_flutter_sdk/src/mock_gpr_transaction.dart';
import 'package:fitpay_flutter_sdk/src/mock_funding_source.dart';
import 'package:http_retry/http_retry.dart';

class API {
  AccessToken _accessToken;
  ApiConfiguration _config;
  DataEncryptor _encryptor;
  @protected
  EventSource encryptedSse;
  final StreamController<FitPayEvent> _outsideSseController;
  Stream<FitPayEvent> _outsideSseStream;
  Stream<FitPayEvent> _sse;
  List<StreamSubscription<dynamic>> _sseSubscriptions = [];
  int _lastSseStreamHeartbeatTs = 0;
  Timer _sseStreamHeartbeatWatchdog;

  http.Client _httpRetryClient = new RetryClient(new http.Client(),
      onRetry: (baseRequest, baseResponse, retryCount) => print(
          'retry ${baseRequest.method} ${baseRequest.url.toString()} with original response ${baseResponse.statusCode}, retry count: $retryCount'),
      when: (baseResponse) => baseResponse.statusCode >= 500 && baseResponse.statusCode <= 599);
  http.Client _httpClient = new http.Client();

  User _user;

  API() : this._outsideSseController = new StreamController();

  Stream<FitPayEvent> get sse {
    if (_outsideSseStream == null) {
      _outsideSseStream = _outsideSseController.stream.asBroadcastStream();
    }

    return _outsideSseStream;
  }

  @protected
  final Map<String, PaymentDeviceConnector> paymentDeviceConnectors = {};
  void registerPaymentConnector(PaymentDeviceConnector connector) {
    if (connector == null || connector.platformDevice == null) {
      throw 'connector not registered, missing connector or platformDevice';
    }

    paymentDeviceConnectors[connector.platformDevice.deviceIdentifier] = connector;
  }

  void removePaymentConnector(PaymentDeviceConnector connector) {
    paymentDeviceConnectors.removeWhere((candidateDeviceId, candidateConnector) {
      return candidateConnector == connector;
    });
    print('connector ${connector.toString()} removed, ${paymentDeviceConnectors.length} left');
  }

  List<String> _previousSyncRequests = [];

  static const INVALID_CARD_STATES = ['ERROR', 'DECLINED'];

  DataEncryptor get encryptor => _encryptor;
  AccessToken get accessToken => _accessToken;
  ApiConfiguration get config => _config;
  User get user => _user;

  Future<void> initialize({AccessToken accessToken, ApiConfiguration config}) async {
    _config = config;
    _accessToken = accessToken;
    _encryptor = new DataEncryptor(config: config);
    _previousSyncRequests = [];

    if (_accessToken != null) {
      _user = await getUser();
      print('user during initialization: ${_user.userId}');
      if (_user.links.containsKey('eventStream')) {
        // eventsStream.dynamic is an issue because it needs an Authorization header, and EventSource.connect doesn't allow headers to be specified
        // UriTemplate template = UriTemplate(user.links['eventStream.dynamic'].href);
        // String eventsUrl = template.expand({
        //   'events': ['SYNC']
        // });
        await _connectSseStream();

        _sseStreamHeartbeatWatchdog?.cancel();
        _sseStreamHeartbeatWatchdog = Timer.periodic(Duration(seconds: 5), (_) async {
          if (_user != null && (DateTime.now().millisecondsSinceEpoch - _lastSseStreamHeartbeatTs) > 60000) {
            print(
                'time since last stream heartbeat: ${DateTime.now().millisecondsSinceEpoch - _lastSseStreamHeartbeatTs}ms exceeds the limit, refreshing the SSE subscription');

            if (_accessToken == null) {
              print('unable to refresh SSE stream, _accessToken has been removed');
              return;
            }

            _user = await getUser(forceRefresh: true);
            await _disconnectSseStream();
            await _connectSseStream();
          }
        });
      }
    }
  }

  Future<void> _disconnectSseStream() async {
    _sseSubscriptions.forEach((subscription) async => await subscription.cancel());
    _sseSubscriptions.clear();

    try {
      encryptedSse?.client?.close();
    } catch (err) {
      print('error closing sse stream, ignoring: ${err.toString()}');
      // ignored
    }

    encryptedSse = null;
  }

  Future<void> _connectSseStream() async {
    encryptedSse = await EventSource.connect(_user.links['eventStream'].href);

    _sse = encryptedSse
        .asBroadcastStream()
        .asyncMap((event) => _encryptor.decrypt(event.data))
        .map<FitPayEvent>((event) => FitPayEvent.fromJson(event))
        .asBroadcastStream();

    // create a SYNC listening to fire sync's at payment device connectors
    _sseSubscriptions.add(_sse
        .where((event) => event.type == 'SYNC')
        .map((event) => SyncRequest.fromJson(event.payload))
        .listen((syncRequest) => deliverSyncToPaymentDeviceConnector(syncRequest: syncRequest)));

    // create a listeners that publishes to outside listeners
    _sseSubscriptions.add(_sse.listen((event) {
      print('sse event received ${event.type}, deliverying to subscribers');
      _outsideSseController.add(event);
    }));

    // heartbeats
    _sseSubscriptions.add(_sse
        .where((event) => event.type == 'STREAM_HEARTBEAT' || event.type == 'STREAM_CONNECTED')
        .listen((syncRequest) => _lastSseStreamHeartbeatTs = DateTime.now().millisecondsSinceEpoch));
  }

  void deliverSyncToPaymentDeviceConnector({SyncRequest syncRequest}) {
    print('sync request received: ${syncRequest.toString()}');

    // dedupe syncs
    if (syncRequest != null && _previousSyncRequests.contains(syncRequest.syncId)) {
      print('sync ${syncRequest.syncId} skipped, already seen');
      return;
    }

    // hacky hack, if no syncRequest then sync all connectors
    if (syncRequest == null) {
      Observable.fromIterable(paymentDeviceConnectors.values)
          .asyncExpand((c) => c.sync())
          .listen((state) => print('manual sync state ${state.toString()}'));
    } else {
      if (paymentDeviceConnectors.containsKey(syncRequest.deviceId)) {
        print('sending ${syncRequest.syncId} to connector ${paymentDeviceConnectors[syncRequest.deviceId]}');
        paymentDeviceConnectors[syncRequest.deviceId]
            .sync(syncRequest: syncRequest)
            .listen((PaymentDeviceSyncState state) {
          print('sync ${syncRequest.syncId} : ${state.toString()}');
          switch (state) {
            case PaymentDeviceSyncState.completed:
              _previousSyncRequests.add(syncRequest.syncId);
              while (_previousSyncRequests.length > 50) {
                _previousSyncRequests.removeAt(0);
              }
              break;
            default:
          }
        });
      } else {
        print('skipped sync ${syncRequest.syncId} for device ${syncRequest.deviceId}, no connector found');
      }
    }
  }

  Future<void> dispose() async {
    _user = null;
    await _disconnectSseStream();
    paymentDeviceConnectors.values.forEach((c) async => c.dispose());
    paymentDeviceConnectors.clear();
    _previousSyncRequests = null;
    _accessToken = null;
    await _encryptor?.dispose();
    _encryptor = null;
  }

  Future<void> registerPaymentDeviceConnector(
    PaymentDeviceConnector connector, {
    Uri existingPaymentDeviceUrl,
    bool enforcePlatformDeviceCreation = true,
    bool enforceDeviceInitialization = false,
    String notificationToken,
  }) async {
    assert(await connector.isConnected);
    connector.api = this;

    if (enforcePlatformDeviceCreation) {
      Device platformDevice;
      if (existingPaymentDeviceUrl != null) {
        platformDevice = await getDevice(existingPaymentDeviceUrl);
      }

      // no existing platform device, creating one!
      if (platformDevice == null) {
        PaymentDeviceInformation deviceInformation = await connector.deviceInformation;

        if (deviceInformation == null) {
          throw 'connector returned an empty device';
        }

        // need to create/register the device on the platform
        platformDevice = await createDevice(Device(
            deviceType: DeviceType.WATCH,
            manufacturerName: deviceInformation.manufacturerName,
            countryCode: deviceInformation.countryCode,
            deviceName: deviceInformation.deviceName,
            firmwareRevision: deviceInformation.firmwareRevision,
            hardwareRevision: deviceInformation.hardwareRevision,
            modelNumber: deviceInformation.modelNumber,
            osName: deviceInformation.osName,
            secureElement: deviceInformation.secureElement,
            serialNumber: deviceInformation.serialNumber,
            softwareRevision: deviceInformation.softwareRevision,
            systemId: deviceInformation.systemId,
            notificationToken: notificationToken));
      }
      paymentDeviceConnectors[platformDevice.deviceIdentifier] = connector;
      connector.platformDevice = platformDevice;

      // wait for the device to be initialized
      if (enforceDeviceInitialization && platformDevice.state == DeviceState.INITIALIZING) {
        platformDevice = await Observable<Device>.race([
          // TODO: listen for DEVICE_STATE_UPDATED on the SSE stream, poll or race... one will win
          Observable.periodic(Duration(seconds: 5))
              .asyncMap((_) => getDevice(platformDevice.links['self'].toUri()))
              .where((device) => device.state != DeviceState.INITIALIZING)
        ]).first;
      }

      // update the connector
      connector.platformDevice = platformDevice;
    }
  }

  Future<User> getUser({bool forceRefresh = false}) async {
    if (_user == null || forceRefresh) {
      var response = await _httpRetryClient.get(
        '${_config.apiUrl}/users/${_accessToken.getUserId()}',
        headers: await _headers(),
      );

      print("response from fitpay: ${response.body}");
      if (response.statusCode == 200) {
        _user = User.fromJson(jsonDecode(response.body));
      }
    }

    return _user;
  }

  Future<void> deleteUser() async {
    if (_user != null) {
      await _httpRetryClient.delete(_user.self, headers: await _headers());
      _user = null;
    }
  }

  Stream<CreditCardCreationStatus> createCreditCard(CreateCreditCardRequest request) async* {
    yield CreditCardCreationStatus(state: CreditCardCreationState.creating);

    var headers = await _headers();
    User user = await getUser();

    if (user.links.containsKey('creditCards')) {
      Map<String, dynamic> encryptedRequest = {
        'encryptedData': await _encryptor.encrypt({
          'pan': request.cardNumber,
          'cvv': request.securityCode,
          'expMonth': request.expMonth,
          'expYear': request.expYear,
          'name': request.name,
          'deviceId': request.deviceId,
          'riskData': request.riskData,
          'address': {
            'street1': request.street,
            'city': request.city,
            'state': request.state,
            'countryCode': request.country,
            'postalCode': request.postalCode
          }
        })
      };

      print('sending card creation request ${jsonEncode(encryptedRequest)}');

      var response =
          await _httpClient.post(user.links['creditCards'].href, body: jsonEncode(encryptedRequest), headers: headers);

      if (response.statusCode >= 400) {
        print('card add failed: ${response.body}');

        yield CreditCardCreationStatus(
          state: CreditCardCreationState.error,
          statusCode: response.statusCode,
          error: ApiError.fromJson(jsonDecode(response.body)),
        );
        return;
      }
      // if we get a 202, we need to wait until the card has been created
      if (response.statusCode == 202) {
        print("headers ${response.headers}");
        String location = response.headers['location'];

        print("api returned 202 for card creation at location $location, starting polling for card");

        int count = 0;
        response = await Observable.periodic(Duration(seconds: 5))
            .asyncMap((_) => _httpRetryClient.get(location, headers: headers))
            .where((response) => response.statusCode != 404)
            .doOnEach((_) => print('card polling attempt ${++count}, waiting for 202 accepted resource to be created'))
            .first
            .timeout(Duration(minutes: 2), onTimeout: () => throw 'card did not create within the allowable time');

        print('polling completed, current card: ${response.body}');
      }

      CreditCard card = CreditCard.fromJson(jsonDecode(response.body));

      // if the card is in a new state, then eligibility check is still pending
      // and we need to wait for the card to change from NEW
      while (card.state == 'NEW') {
        print('card state is NEW, starting to poll to wait for eligibility check to complete');

        yield CreditCardCreationStatus(state: CreditCardCreationState.pending_eligibility_check, creditCard: card);

        int count = 0;
        card = await Observable<CreditCard>.race([
          Observable<CreditCard>.periodic(Duration(seconds: 3))
              .asyncMap((tick) async {
                paymentDeviceConnectors.values
                    .forEach((c) => c.sync().listen((state) => print('add card sync state ${state.toString()}')));
                return tick;
              })
              .asyncMap((_) => _httpRetryClient.get(card.links['self'].href, headers: headers))
              .where((response) => response.statusCode == 200)
              .map((response) => CreditCard.fromJson(jsonDecode(response.body)))
              .doOnEach((_) => print('card polling attempt ${++count}, waiting for change from new state'))
              .where((card) => card.state != 'NEW'),
          _sse
              .where((event) => event.type == 'CREDITCARD_CREATED')
              .map((event) => event.payload)
              .where((payload) => payload['creditCardId'] == card.creditCardId && payload['state'] != 'NEW')
              .asyncMap(
                  (_) => _httpRetryClient.get(card.links['self'].href, headers: headers)) // refresh view from the API
              .where((response) => response.statusCode == 200)
              .map((response) => CreditCard.fromJson(jsonDecode(response.body)))
        ])
            .doOnError((err) {
              print('error polling for card state change: $err');
              throw err;
            })
            .first
            .timeout(Duration(minutes: 1),
                onTimeout: () => throw 'timeout waiting on card to transition from NEW state');

        print('polling completed, current card: ${response.body}');
      }

      yield CreditCardCreationStatus(state: CreditCardCreationState.created, creditCard: card);
    } else {
      yield CreditCardCreationStatus(
          state: CreditCardCreationState.error,
          error: ApiError(message: 'no creditCards link available on user record'));
    }
  }

  Future<CreditCard> deactivateCreditCard(Uri uri) async {
    print('deactivating credit card: ${uri.toString()}');

    var response = await _httpRetryClient.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'causedBy': 'CARDHOLDER'}),
    );

    if (response.statusCode == 200) {
      return CreditCard.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<CreditCard> reactivateCreditCard(Uri uri) async {
    print('reactivating credit card: ${uri.toString()}');

    var response = await _httpRetryClient.post(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return CreditCard.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<CreditCard> declineCreditCardTerms(Uri uri) async {
    print('declining terms and conditions: ${uri.toString()}');

    var response = await _httpRetryClient.post(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      CreditCard card = CreditCard.fromJson(jsonDecode(response.body));

      CreditCard.removeAcceptTermsState(card.creditCardId);
      return card;
    }

    return null;
  }

  Stream<CreditCardAcceptTermsStatus> acceptCreditCardTerms(CreditCard card) async* {
    var headers = await _headers();

    String uri;
    if (card.links['acceptTerms'].templated) {
      UriTemplate uriTemplate = UriTemplate(card.links['acceptTerms'].href);
      print('templated link: ${uriTemplate.toString()}');

      Map<String, dynamic> acceptTermsState = await card.acceptTermsState;

      print('saved state: ${acceptTermsState.toString()}');

      uri = uriTemplate.expand(acceptTermsState);
    } else {
      uri = card.links['acceptTerms'].href;
    }

    print('accepting terms: ${uri.toString()}');

    yield CreditCardAcceptTermsStatus(
      state: CreditCardAcceptTermsState.accepting,
    );

    var response = await _httpClient.post(uri, headers: headers);

    if (response.statusCode >= 400) {
      print('card add failed: ${response.body}');

      yield CreditCardAcceptTermsStatus(
        state: CreditCardAcceptTermsState.error,
        statusCode: response.statusCode,
        error: ApiError.fromJson(jsonDecode(response.body)),
      );
      return;
    }

    if (response.statusCode == 202) {
      print("headers ${response.headers}");
      String location = response.headers['location'];

      print("api returned 202 for card creation at location $location, starting polling for card");
      do {
        await Future.delayed(Duration(seconds: 5));
        response = await _httpRetryClient.get(location, headers: headers);
      } while (response.statusCode == 404);

      print('polling completed, current card: ${response.body}');
    }

    CreditCard updatedCard = CreditCard.fromJson(jsonDecode(response.body));
    var creditCardId = updatedCard.creditCardId;
    var cardUrl = updatedCard.links['self'].href;

    // states we're waiting for the card to transition into after accept terms
    var transitionStates = [
      'PENDING_ACTIVE',
      'PENDING_VERIFICATION',
      'ACTIVE',
      'ERROR',
      'DECLINED',
      'NOT_ELIGIBLE',
      'DELETED'
    ];

    if (!transitionStates.contains(updatedCard.state)) {
      updatedCard = await Observable.race([
        _sse
            .where((event) => event.type == 'CREDITCARD_PROVISION_FAILED')
            .where((event) => event.payload['creditCardId'] == creditCardId)
            .asyncMap((_) => _httpRetryClient.get(cardUrl, headers: headers))
            .map((response) => CreditCard.fromJson(jsonDecode(response.body))),
        // refresh the card
        Observable.periodic(Duration(seconds: 5))
            .asyncMap((_) => _httpRetryClient.get(cardUrl, headers: headers))
            .map((response) => CreditCard.fromJson(jsonDecode(response.body)))
            .where((card) => transitionStates.contains(card.state)),
      ]).first;

      print('polling completed, current card state: ${updatedCard.state}');
    }

    print('accept terms completed on ${updatedCard.creditCardId} in state ${updatedCard.state}');

    CreditCard.removeAcceptTermsState(updatedCard.creditCardId);

    switch (updatedCard.state) {
      case 'PENDING_ACTIVE':
      case 'PENDING_VERIFICATION':
      case 'ACTIVE':
        yield CreditCardAcceptTermsStatus(
          state: CreditCardAcceptTermsState.accepted,
          creditCard: updatedCard,
        );
        break;

      default:
        yield CreditCardAcceptTermsStatus(
          state: CreditCardAcceptTermsState.error,
          creditCard: updatedCard,
        );
    }
  }

  Future<Page<Transaction>> getTransactions(Uri uri) async {
    var response = await _httpRetryClient.get(
      uri,
      headers: await _headers(accept: 'application/vnd.fitpay-v2+json'),
    );

    if (response.statusCode == 200) {
      return Page<Transaction>.fromJson(jsonDecode(response.body));
    } else {
      print('transaction retreival failed: ${response.statusCode}: ${response.body}');
      return Page<Transaction>(results: []);
    }
  }

  Future<CreditCard> getCreditCard(Uri uri) async {
    var response = await _httpRetryClient.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      return CreditCard.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    }

    throw response;
  }

  Future<VerificationMethods> getVerificationMethods(Uri uri) async {
    var response = await _httpRetryClient.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      return VerificationMethods.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    }

    throw response;
  }

  /// Returns a [Page] of [CreditCard] instances for the current authenticated
  /// user.
  ///
  /// [excludeStates] - Filter out the list of provided states, default: DELETED
  /// [limit] - Limit the number of credit cards returned, default: 20
  /// [offset] - Starting offset to the page of credit cards, default: 0
  /// [cleanupInvalidStates] - If invalid states are found (i.e. ERROR) then automatically
  /// delete those cards, default: true
  ///
  Future<Page<CreditCard>> getCreditCards(
      {List<String> excludeStates = const ['DELETED'],
      int limit = 20,
      int offset = 0,
      bool cleanupInvalidStates = true}) async {
    User user = await getUser();
    if (user.links.containsKey('creditCards')) {
      var uri = Uri.parse(user.links['creditCards'].href);
      var urlBuilder = UriBuilder.fromUri(uri);

      urlBuilder.queryParameters['excludeState'] = excludeStates.join(',');
      urlBuilder.queryParameters['limit'] = '$limit';
      urlBuilder.queryParameters['offset'] = '$offset';

      var response = await _httpRetryClient.get(urlBuilder.build().toString(), headers: await _headers());

      if (response.statusCode == 200) {
        Page<CreditCard> page = Page<CreditCard>.fromJson(jsonDecode(response.body));

        if (cleanupInvalidStates) {
          page.results.forEach((card) {
            if (INVALID_CARD_STATES.contains(card.state)) {
              deleteCreditCard(card.links['self'].toUri());
            }
          });
        }

        return Page<CreditCard>.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      }

      throw response;
    }

    return null;
  }

  /// Deletes the credit card at [uri]
  Future<void> deleteCreditCard(Uri uri) async {
    var response = await _httpRetryClient.get(uri, headers: await _headers(includeFpKeyId: false));
    if (response.statusCode == 200) {
      CreditCard card = CreditCard.fromJson(jsonDecode(response.body));
      CreditCard.removeAcceptTermsState(card.creditCardId);
    }

    response = await _httpRetryClient.delete(uri.toString(), headers: await _headers(includeFpKeyId: false));

    if (response.statusCode == 204) {
      print('successfully deleted credit card: ${uri.toString()}');
    }
  }

  Future<Device> createDevice(Device device) async {
    User user = await getUser();
    if (user.links.containsKey('devices')) {
      var response = await _httpClient.post("${user.links['devices'].href}",
          body: jsonEncode(device.toJson()), headers: await _headers());

      print('devices: ${response.body}');

      if (response.statusCode == 201) {
        return Device.fromJson(jsonDecode(response.body));
      } else {
        throw response;
      }
    } else {
      throw 'no devices link available on user ${user?.userId}';
    }
  }

  Future<void> makeActive(Uri uri) async {
    var response = await _httpRetryClient.post(uri, headers: await _headers());

    print('make active: ${response.body}');
  }

  Future<Device> getDevice(Uri uri) async {
    var response = await _httpRetryClient.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      return Device.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    }

    throw response;
  }

  Future<Device> patchDevice(Uri uri, List<JsonPatch> patch) async {
    List<Map<String, dynamic>> encoded = await Observable.fromIterable(patch).map((p) => p.toJson()).toList();

    print('device patch: ${jsonEncode(encoded)}');
    var response = await _httpRetryClient.patch(uri, headers: await _headers(), body: jsonEncode(encoded));

    if (response.statusCode == 200) {
      print('device patch result: ${response.body}');
      return Device.fromJson(jsonDecode(response.body));
    }

    throw response;
  }

  Future<void> deleteDevice(Uri uri) async {
    await _httpRetryClient.delete(uri, headers: await _headers(includeFpKeyId: false));
  }

  Future<Commit> getDeviceCommit(Uri uri) async {
    var response = await _httpRetryClient.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      return Commit.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<Page<Commit>> getDeviceCommits(Uri uri) async {
    var response = await _httpRetryClient.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      return Page<Commit>.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<void> confirmDeviceCommit(Commit commit, CommitResponse response) async {
    assert(commit != null);
    assert(response != null);

    if (commit.links.containsKey('confirm')) {
      await _httpClient.post(
        commit.links['confirm'].toUri(),
        body: jsonEncode(response.toJson()),
        headers: await _headers(includeFpKeyId: false),
      );
    }
  }

  Future<void> confirmApduPackage(Commit commit, ApduExecutionResult result) async {
    assert(commit != null);
    assert(result != null);

    if (commit.links.containsKey('apduResponse')) {
      print('body: ${jsonEncode(result.toJson())}');

      var response = await _httpRetryClient.post(
        commit.links['apduResponse'].toUri(),
        body: jsonEncode(result.toJson()),
        headers: await _headers(includeFpKeyId: false),
      );

      print('apdu response ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> ackSync(SyncRequest request) async {
    Uri ackLink = request?.links['ackSync']?.toUri();

    if (ackLink != null) {
      await _httpRetryClient.post(ackLink, headers: await _headers(includeFpKeyId: false));
    }
  }

  Future<void> completeSync(SyncRequest request) async {
    Uri completeLink = request?.links['completeSync']?.toUri();

    if (completeLink != null) {
      await _httpRetryClient.post(completeLink, headers: await _headers(includeFpKeyId: false));
    }
  }

  Future<VerificationMethod> selectVerificationMethod(VerificationMethod method) async {
    if (method.links.containsKey('select')) {
      var response =
          await _httpClient.post(method.links['select'].toUri(), headers: await _headers(includeFpKeyId: false));

      print('select verification response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        return VerificationMethod.fromJson(jsonDecode(response.body));
      }
    }

    return null;
  }

  Future<VerificationMethod> verifyVerificationMethod(VerificationMethod method, String verificationCode) async {
    if (method.links.containsKey('verify')) {
      String body = jsonEncode({'verificationCode': verificationCode});

      print('verification request: $body');

      var response = await _httpClient.post(
        method.links['verify'].toUri(),
        body: jsonEncode({'verificationCode': verificationCode}),
        headers: await _headers(includeFpKeyId: false),
      );

      if (response.statusCode == 200) {
        return VerificationMethod.fromJson(jsonDecode(response.body));
      } else if (response.statusCode >= 400 && response.statusCode <= 499) {
        throw VerificationMethodSubmitError.fromJson(jsonDecode(response.body));
      } else {
        throw response;
      }
    } else {
      print('no verify link available! ${method.links.toString()}');
    }

    return null;
  }

  Future<Page<Device>> getDevices() async {
    User user = await getUser();
    if (user.links.containsKey('devices')) {
      var response = await _httpRetryClient.get("${user.links['devices'].href}", headers: await _headers());

      print('devices: ${response.body}');

      if (response.statusCode == 200) {
        return Page<Device>.fromJson(jsonDecode(response.body));
      }
    }

    return null;
  }

  Future<Page<GPRAccount>> getGPRAccounts(String serialCode) async {
    var response = await _httpRetryClient.get('${_config.apiUrl}/galileoAccounts?deviceSerialNumber=$serialCode',
        headers: await _headers());

    print("response from fitpay: ${response.body}");

    if (response.statusCode == 200) {
      return Page<GPRAccount>.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<GPRAccount> getGPRAccount(String accountId) async {
    var response =
        await _httpRetryClient.get('${_config.apiUrl}/galileoAccounts/$accountId', headers: await _headers());

    print("GPR Account: ${response.body}");

    if (response.statusCode == 200) {
      return GPRAccount.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<GPRAccount> activateAccount(Uri uri) async {
    var response = await _httpClient.post("https://${uri.toString()}", headers: await _headers());

    print('Account activation response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      return GPRAccount.fromJson(jsonDecode(response.body));
    }

    throw response.statusCode;
  }

  Future<FundingSource> createFundingSource(FundingSource fundingSource) async {
    User user = await getUser();
    if (user.links.containsKey('fundingSources')) {
      var response = await _httpClient.post(user.links['fundingSources'].toUri(),
          body: jsonEncode(fundingSource.toJson()), headers: await _headers());

      print('New funding source: ${response.body}');

      if (response.statusCode == 201) {
        return FundingSource.fromJson(jsonDecode(response.body));
      }
    }
    return null;
  }

  Future<Page<FundingSource>> getFundingSources(Uri uri, {bool useMockFundingSources = false}) async {
    if (useMockFundingSources) {
      return mockFundingSources;
    }
    var response = await _httpRetryClient.get(uri, headers: await _headers());

    print('Funding sources: ${response.body}');

    if (response.statusCode == 200) {
      return Page<FundingSource>.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<Page<GPRTransaction>> getGPRTransactions(String transxnUrl, {bool useMockTransactions = false}) async {
    if (useMockTransactions) {
      return mockTransactions;
    }
    var response = await http.get(transxnUrl, headers: await _headers());

    print("GPR Transaction stream ${response.body}");

    if (response.statusCode == 200) {
      return Page<GPRTransaction>.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<GPRAccount> convertHybridToGpr(Uri uri) async {
    var response = await _httpClient.post(uri, headers: await _headers());

    print('Account conversion response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      return GPRAccount.fromJson(jsonDecode(response.body));
    }

    throw response.statusCode;
  }

  Future<Application> getApplication(Uri uri) async {
    var response = await _httpClient.get(uri, headers: await _headers());

    print("Application ${response.body}");

    if (response.statusCode ==  200) {
        return Application.fromJson(jsonDecode(response.body));
    }

    return null;
  }

  Future<Map<String, String>> _headers({bool includeFpKeyId = true, accept = 'application/json'}) async {
    Map<String, String> headers = Map<String, String>();

    headers['Accept'] = accept;
    headers['Content-Type'] = 'application/json';
    headers['X-FitPay-SDK'] = 'dart-1.0.0'; // TODO: Figure out how to read the version from pubspec.yaml

    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer ${_accessToken.token}';
    }

    if (includeFpKeyId && _encryptor != null) {
      headers['fp-key-id'] = await _encryptor.currentKeyId();
    }

    return headers;
  }
}

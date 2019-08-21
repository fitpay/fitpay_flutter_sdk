import 'package:fitpay_flutter_sdk/fitpay_flutter_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<AccessToken> exchangeFirebaseTokenForFitPayApiToken(
  String clientId,
  String firebaseToken, {
  ApiConfiguration config = const ApiConfiguration(),
}) async {
  assert(clientId != null);
  assert(firebaseToken != null);

  var response = await http.post(
    '${config.authUrl}/oauth/token',
    body: {
      "firebase_token": firebaseToken,
      "client_id": clientId,
    },
  );

  if (response.statusCode == 200) {
    debugPrint('access token created: ${response.body}');
    return AccessToken.fromJson(jsonDecode(response.body));
  }

  throw ('error getting FitPay API Token with Firebase Token, statusCode: ${response.statusCode}, body: ${response.body}');
}

Future<API> initializeApiWithFirebaseToken(
  String clientId,
  String firebaseToken, {
  ApiConfiguration config = const ApiConfiguration(),
}) async {
  assert(clientId != null);
  assert(firebaseToken != null);

  API api = new API();
  await api.initialize(
    config: config,
    accessToken: await exchangeFirebaseTokenForFitPayApiToken(
      clientId,
      firebaseToken,
      config: config,
    ),
    tokenRefresher: () => exchangeFirebaseTokenForFitPayApiToken(
      clientId,
      firebaseToken,
      config: config,
    ),
  );

  return api;
}

Future<API> initializeApiWithFirebaseTokenGetter(
  String clientId,
  Future<String> Function() fbTokenGetter, {
  ApiConfiguration config = const ApiConfiguration(),
}) async {
  assert(clientId != null);
  assert(fbTokenGetter != null);

  API api = new API();
  await api.initialize(
    config: config,
    accessToken: await exchangeFirebaseTokenForFitPayApiToken(
      clientId,
      await fbTokenGetter(),
      config: config,
    ),
    tokenRefresher: () async {
        return exchangeFirebaseTokenForFitPayApiToken(
        clientId,
        await fbTokenGetter(),
        config: config,
      );
    },
  );

  return api;
}

Future<API> initializeApiUnauthenticated({ApiConfiguration config = const ApiConfiguration()}) async {
  API api = new API();
  await api.initialize(config: config);
  return api;
}

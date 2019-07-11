import 'package:fitpay_flutter_sdk/fitpay_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const MethodChannel _channel = const MethodChannel('fitpay_flutter_sdk');

class DataEncryptor {
  final ApiConfiguration config;
  EncryptionKey _key;

  DataEncryptor({this.config});

  Future<void> register() async {
    String keyPairJson = await _channel.invokeMethod('create_session_keypair');
    Map<String, dynamic> keyPair = jsonDecode(keyPairJson);

    var response = await http.post(
      "${config.apiUrl}/config/encryptionKeys",
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "clientPublicKey": keyPair["pub"],
      }),
    );

    print("key registration response: ${response.body}");

    this._key = EncryptionKey.fromJson(jsonDecode(response.body));
    this._key.clientPrivateKey = keyPair['pvt'];
    print("registered keyId ${this._key.keyId} with FitPay API");
  }

  Future<void> dispose() async {
    if (_key != null) {
      await http.delete('${config.apiUrl}/config/encryptionKeys/${_key.keyId}');
    }
  }

  Future<String> encrypt(Map<String, dynamic> data) async {
    EncryptionKey key = await this.currentKey;

    return await _channel.invokeMethod('encrypt', {
      'keyId': key.keyId,
      'publicKey': key.serverPublicKey,
      'privateKey': key.clientPrivateKey,
      'data': jsonEncode(data)
    });
  }

  Future<Map<String, dynamic>> decrypt(String data) async {
    EncryptionKey key = await this.currentKey;

    String decryptedString = await _channel.invokeMethod('decrypt', {
      'keyId': key.keyId,
      'publicKey': key.serverPublicKey,
      'privateKey': key.clientPrivateKey,
      'serverPublicKey': key.serverPublicKey,
      'data': data,
    });

    return jsonDecode(decryptedString);
  }

  Future<EncryptionKey> get currentKey async {
    if (_key == null) {
      await register();
    }

    // TODO: Verify the key isn't expired
    return _key;
  }

  Future<String> currentKeyId() async {
    EncryptionKey key = await this.currentKey;
    return key.keyId;
  }
}

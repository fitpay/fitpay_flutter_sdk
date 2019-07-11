package com.fitpay.flutter;

import com.fitpay.flutter.utils.Hex;
import com.google.common.collect.ImmutableMap;
import com.google.gson.Gson;
import com.nimbusds.jose.EncryptionMethod;
import com.nimbusds.jose.JWEAlgorithm;
import com.nimbusds.jose.JWEEncrypter;
import com.nimbusds.jose.JWEHeader;
import com.nimbusds.jose.JWEObject;
import com.nimbusds.jose.JWSVerifier;
import com.nimbusds.jose.Payload;
import com.nimbusds.jose.crypto.AESDecrypter;
import com.nimbusds.jose.crypto.AESEncrypter;
import com.nimbusds.jose.crypto.ECDSAVerifier;
import com.nimbusds.jwt.SignedJWT;

import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.interfaces.ECPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.Map;

import javax.crypto.KeyAgreement;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * This class is intended to be completely stateless, only enabling the Flutter application/sdk to
 * perform data encryption necessary to use the FitPay API.  Current support for ECDH in Dart is
 * very limited, while it's an easy task on the native mobile platform.
 */
public class FitpayFlutterSdkPlugin implements MethodCallHandler {
  private static final String ALGORITHM = "EC";
  private static final String KEY_AGREEMENT = "ECDH";

  private Gson gson = new Gson();
  private final Registrar registrar;

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "fitpay_flutter_sdk");
    channel.setMethodCallHandler(new FitpayFlutterSdkPlugin(registrar));
  }

  private FitpayFlutterSdkPlugin(Registrar registrar) {
    this.registrar = registrar;
  }

  enum Operation {
    CREATE_SESSION_KEYPAIR("create_session_keypair"),
    ENCRYPT("encrypt"),
    DECRYPT("decrypt"),
    UNKNOWN("unknown");

    private final String value;
    Operation(String value) {
      this.value = value;
    }

    public static Operation fromString(String value) {
      for (Operation o : values()) {
        if (o.toString().equals(value)) {
          return o;
        }
      }

      return UNKNOWN;
    }

    public String toString() {
      return this.value;
    }
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    Operation op = Operation.fromString(call.method);

    String keyId, privateKey, publicKey, serverPublicKey, data;

    try {
      switch (op) {
        case CREATE_SESSION_KEYPAIR:
          result.success(gson.toJson(generateKeyPair()));
          break;

        case ENCRYPT:
          keyId = call.argument("keyId");
          privateKey = call.argument("privateKey");
          publicKey = call.argument("publicKey");
          data = call.argument("data");

          result.success(encrypt(keyId, privateKey, publicKey, data));
          break;

        case DECRYPT:
          keyId = call.argument("keyId");
          privateKey = call.argument("privateKey");
          publicKey = call.argument("publicKey");
          serverPublicKey = call.argument("serverPublicKey");
          data = call.argument("data");

          result.success(decrypt(keyId, publicKey, privateKey, serverPublicKey, data));
          break;
          
        default:
          result.notImplemented();
      }
    } catch (Exception e) {
      e.printStackTrace();
      result.error("fitpay_flutter_sdk", e.getMessage(), e);
    }
  }

  private Map<String, String> generateKeyPair() throws Exception {
    KeyPairGenerator kpg = KeyPairGenerator.getInstance(ALGORITHM);
    kpg.initialize(256);

    KeyPair kp = kpg.generateKeyPair();

    return ImmutableMap.<String, String>builder()
            .put("pub", Hex.bytesToHexString(kp.getPublic().getEncoded()))
            .put("pvt", Hex.bytesToHexString(kp.getPrivate().getEncoded()))
            .build();
  }

  private String encrypt(String keyId,
                         String privateKeyString,
                         String publicKeyString,
                         String data) throws Exception {
    JWEAlgorithm alg = JWEAlgorithm.A256GCMKW;
    EncryptionMethod enc = EncryptionMethod.A256GCM;

    JWEHeader.Builder jweHeaderBuilder = new JWEHeader.Builder(alg, enc)
            .contentType("application/json")
            .keyID(keyId);

    JWEHeader header = jweHeaderBuilder.build();
    Payload payload = new Payload(data);
    JWEObject jweObject = new JWEObject(header, payload);
    byte[] derivedSecretKey = createSecretKey(privateKeyString, publicKeyString);

    JWEEncrypter encrypter = new AESEncrypter(derivedSecretKey);
    jweObject.encrypt(encrypter);

    return jweObject.serialize();
  }

  private String decrypt(
          String keyId,
          String publicKeyString,
          String privateKeyString,
          String publicServerKeyString,
          String encryptedString) throws Exception {
    assert(keyId != null);
    assert(publicKeyString != null);
    assert(privateKeyString != null);
    assert(publicServerKeyString != null);
    assert(encryptedString != null);

    JWEObject jweObject = JWEObject.parse(encryptedString);
    JWEHeader jweHeader = jweObject.getHeader();

    if (jweHeader.getKeyID() == null || jweHeader.getKeyID().equals(keyId)) {
      jweObject.decrypt(new AESDecrypter(createSecretKey(privateKeyString, publicKeyString)));

      if ("JWT".equals(jweObject.getHeader().getContentType())) {
        SignedJWT signedJwt = jweObject.getPayload().toSignedJWT();

        ECPublicKey key;
        if ("https://fit-pay.com".equals(signedJwt.getJWTClaimsSet().getIssuer())) {
          key = (ECPublicKey) getPublicKey(Hex.hexStringToBytes(publicServerKeyString));
        } else {
          key = (ECPublicKey) getPublicKey(Hex.hexStringToBytes(publicKeyString));
        }

        JWSVerifier verifier = new ECDSAVerifier(key);
        if (!signedJwt.verify(verifier)) {
          throw new IllegalArgumentException("jwt did not pass signature validation");
        }

        return signedJwt.getJWTClaimsSet().getStringClaim("data");
      } else {
        return jweObject.getPayload().toString();
      }
    }

    return null;
  }

  private byte[] createSecretKey(String privateKeyStr, String publicKeyStr) throws Exception {
    PrivateKey privateKey = getPrivateKey(Hex.hexStringToBytes(privateKeyStr));
    PublicKey publicKey = getPublicKey(Hex.hexStringToBytes(publicKeyStr));

    KeyAgreement keyAgreement = KeyAgreement.getInstance(KEY_AGREEMENT);

    keyAgreement.init(privateKey);
    keyAgreement.doPhase(publicKey, true);

    return keyAgreement.generateSecret();

  }

  public PrivateKey getPrivateKey(byte[] privateKey) throws Exception {
    KeyFactory kf = KeyFactory.getInstance(ALGORITHM);

    PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(privateKey);
    return kf.generatePrivate(keySpec);
  }

  public PublicKey getPublicKey(byte[] publicKey) throws Exception {
    return getPublicKey(ALGORITHM, publicKey);
  }

  public PublicKey getPublicKey(String algorithm, byte[] publicKey) throws Exception {
    KeyFactory kf = KeyFactory.getInstance(algorithm);

    X509EncodedKeySpec keySpec = new X509EncodedKeySpec(publicKey);
    return kf.generatePublic(keySpec);
  }
}



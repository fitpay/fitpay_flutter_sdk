import Flutter
import UIKit
import SwCrypt

public class SwiftFitpayFlutterSdkPlugin: NSObject, FlutterPlugin {
  let asnEncodingHeader = "3059301306072a8648ce3d020106082a8648ce3d030107034200"
  let encoder = JSONEncoder()
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fitpay_flutter_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftFitpayFlutterSdkPlugin()
    
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
        case "create_session_keypair":
            let keyPair = try! CC.EC.generateKeyPair(256)
            let keyObject = [
                "pub": asnEncodingHeader + keyPair.1.hex,
                "pvt": keyPair.0.hex
            ]
            
            let json = String(data: try! encoder.encode(keyObject), encoding: .utf8)
            result(json)
            
            break
        
        case "encrypt":
            guard let args = call.arguments as? [String: Any] else {
                result("iOS could not recognize flutter arguments in method: (sendParams)")
                break
            }
            
            let keyId : String = args["keyId"] as! String
            let publicKey : String = args["publicKey"] as! String
            let privateKey : String = args["privateKey"] as! String
            let data : String = args["data"] as! String
            
            let start = publicKey.index(publicKey.startIndex, offsetBy: 0)
            let end   = publicKey.index(publicKey.startIndex, offsetBy: asnEncodingHeader.count)
            
            let publicKeyWithoutPrefix = publicKey.replacingCharacters(in: start..<end, with: "")
            
            let secret = try! CC.EC.computeSharedSecret(privateKey.hexToData()!, publicKey: publicKeyWithoutPrefix.hexToData()!)
            
            let jweObject = JWE(.A256GCMKW, enc: .A256GCM, payload: data, keyId: keyId)
            if let encrypted = try? jweObject.encrypt(secret) {
                result(encrypted)
            }
            
            break
        
        case "decrypt":
            guard let args = call.arguments as? [String: Any] else {
                result("iOS could not recognize flutter arguments in method: (sendParams)")
                break
            }
            
            let keyId : String = args["keyId"] as! String
            let publicKey : String = args["publicKey"] as! String
            let privateKey : String = args["privateKey"] as! String
            let data : String = args["data"] as! String
            
            let start = publicKey.index(publicKey.startIndex, offsetBy: 0)
            let end   = publicKey.index(publicKey.startIndex, offsetBy: asnEncodingHeader.count)
            
            let publicKeyWithoutPrefix = publicKey.replacingCharacters(in: start..<end, with: "")
            
            let secret = try! CC.EC.computeSharedSecret(privateKey.hexToData()!, publicKey: publicKeyWithoutPrefix.hexToData()!)
            
            let jwe = JWE(payload: data)
            guard jwe.header?.kid == keyId else {
                result("keyId does not match")
                break
                
            }
            guard let decryptResult = try? jwe.decrypt(secret) else {
                result("error decrypting payload")
                break
            }
            
            if (jwe.header?.cty == "JWT") {
                // TODO: Validate signature from serverPublicKey in args
                let jws = try! JWS(token: decryptResult!)
                let payload = jws.body["data"] as! String
                result(payload)
            } else {
                result(decryptResult)
            }
            
            break
        
    default:
                result(FlutterMethodNotImplemented);
    }
    }
}

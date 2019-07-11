import Security
import SwCrypt

class SECP256R1KeyPair {
    var keys: (privateKey: Data, publicKey: Data)
    init() {
        keys = try! CC.EC.generateKeyPair(256)
    }
    
    init(publicKey: Data, privateKey: Data) {
        keys = (privateKey, publicKey)
    }
    
    private let asnEncodingHeader = "3059301306072a8648ce3d020106082a8648ce3d030107034200"
    
    // we should provide public key 
    // with unknown prefix
    var publicKey: String? {
        return asnEncodingHeader + keys.publicKey.hex
    }
    
    var privateKey: String? {
        return keys.privateKey.hex
    }
    
    func generateSecretForPublicKey(_ publicKey: String) -> Data? {
        // removing prefix from public key
        let start = publicKey.index(publicKey.startIndex, offsetBy: 0)
        let end   = publicKey.index(publicKey.startIndex, offsetBy: asnEncodingHeader.count)
        
        let publicKeyWithoutPrefix = publicKey.replacingCharacters(in: start..<end, with: "")
        
        // compute secret for public key without prefix
        return try? CC.EC.computeSharedSecret(keys.privateKey, publicKey: publicKeyWithoutPrefix.hexToData()!)
    }
}

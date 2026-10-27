import Foundation
import LocalAuthentication
import Security

struct KeychainGoogleCredentialStore: GoogleCredentialStoring {
    let namespace: String
    // No sharing group, synchronizable item, exported file, or legacy-Keychain fallback.
    var query: [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: namespace,
            kSecAttrAccount as String: "google-desktop-oauth-v1",
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationContext as String: context,
        ]
    }
    func load() throws -> GoogleCredential? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw GoogleAuthFailure.keychainUnavailable }
        guard let data = item as? Data, data.count <= 65_536,
            let credential = try? JSONDecoder().decode(GoogleCredential.self, from: data)
        else { throw GoogleAuthFailure.corruptCredential }
        return credential
    }
    func save(_ credential: GoogleCredential) throws {
        let data = try JSONEncoder().encode(credential)
        guard data.count <= 65_536 else { throw GoogleAuthFailure.corruptCredential }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw GoogleAuthFailure.keychainUnavailable }
        var addition = query
        for (key, value) in attributes { addition[key] = value }
        guard SecItemAdd(addition as CFDictionary, nil) == errSecSuccess else {
            throw GoogleAuthFailure.keychainUnavailable
        }
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GoogleAuthFailure.keychainUnavailable
        }
    }
}

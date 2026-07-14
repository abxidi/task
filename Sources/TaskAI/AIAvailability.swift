import Foundation

public enum AIAvailability {
    public static func isConfigured(configurationData: Data?, keyStore: APIKeyStore) -> Bool {
        guard let configurationData,
              let configuration = try? JSONDecoder().decode(AIServiceConfiguration.self, from: configurationData),
              let key = try? keyStore.read(),
              !key.isEmpty else {
            return false
        }
        _ = configuration
        return true
    }
}

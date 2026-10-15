import Foundation

public struct SettingsStore: Sendable {
    public var suiteName: String

    public init(suiteName: String = AppGroup.identifier) {
        self.suiteName = suiteName
    }

    public func load() -> EngineSettings {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: AppGroup.settingsKey),
            let settings = try? JSONDecoder().decode(EngineSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    public func save(_ settings: EngineSettings) {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = try? JSONEncoder().encode(settings)
        else {
            return
        }
        defaults.set(data, forKey: AppGroup.settingsKey)
    }
}

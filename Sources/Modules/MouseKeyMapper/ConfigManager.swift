import Foundation
import Combine

@MainActor
class ConfigManager: ObservableObject {
    @Published var appConfigs: [AppConfig] = []
    
    private let fileName = "mouse_mappings.json"
    
    init() {
        loadConfig()
        if appConfigs.isEmpty {
            appConfigs.append(AppConfig.globalDefault)
        }
    }
    
    func getMappings(for bundleId: String?) -> [KeyMapping] {
        var activeMappings: [KeyMapping] = []
        
        // 1. Global
        if let globalConfig = appConfigs.first(where: { $0.bundleId == nil }) {
            // print("   [Config] Found Global Config: \(globalConfig.mappings.count) rules")
            activeMappings.append(contentsOf: globalConfig.mappings)
        }
        
        // 2. App Specific
        if let bundleId = bundleId {
            if let appConfig = appConfigs.first(where: { $0.bundleId == bundleId }) {
                print("   [Config] Found App Config for '\(bundleId)': \(appConfig.mappings.count) rules")
                // 覆盖/叠加逻辑
                for mapping in appConfig.mappings {
                    if let index = activeMappings.firstIndex(where: { $0.inputType == mapping.inputType }) {
                        activeMappings[index] = mapping
                    } else {
                        activeMappings.append(mapping)
                    }
                }
            } else {
                // print("   [Config] No specific config for '\(bundleId)'")
            }
        }
        
        return activeMappings
    }
    
    func saveConfig() {
        do {
            let data = try JSONEncoder().encode(appConfigs)
            let url = getConfigFileURL()
            try data.write(to: url)
            print("💾 [Storage] Saved \(appConfigs.count) Apps. Global rules: \(appConfigs.first(where: {$0.bundleId == nil})?.mappings.count ?? 0)")
        } catch {
            print("❌ Failed to save config: \(error)")
        }
    }
    
    func loadConfig() {
        let url = getConfigFileURL()
        print("📂 [Storage] Loading from: \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            appConfigs = try JSONDecoder().decode([AppConfig].self, from: data)
            print("✅ [Storage] Loaded. Apps registered: \(appConfigs.map { $0.appName })")
        } catch {
            print("❌ Failed to load config: \(error)")
        }
    }
    
    private func getConfigFileURL() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("MacToolkit")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }
}

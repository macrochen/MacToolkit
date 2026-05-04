import Foundation
import Combine

/// 触摸板手势配置管理器
@MainActor
class GestureConfigManager: ObservableObject {
    @Published var appConfigs: [GestureAppConfig] = []
    
    private let fileName = "touchpad_gestures.json"
    
    init() {
        loadConfig()
        if appConfigs.isEmpty {
            appConfigs.append(GestureAppConfig.globalDefault)
            // 添加 Chrome 默认配置
            addChromeDefaults()
        }
    }
    
    func getMappings(for bundleId: String?) -> [GestureMapping] {
        var activeMappings: [GestureMapping] = []
        
        // 1. Global
        if let globalConfig = appConfigs.first(where: { $0.bundleId == nil }) {
            activeMappings.append(contentsOf: globalConfig.mappings.filter { $0.isEnabled })
        }
        
        // 2. App Specific
        if let bundleId = bundleId {
            if let appConfig = appConfigs.first(where: { $0.bundleId == bundleId }) {
                // 覆盖/叠加逻辑
                for mapping in appConfig.mappings.filter({ $0.isEnabled }) {
                    if let index = activeMappings.firstIndex(where: { $0.gestureType == mapping.gestureType }) {
                        activeMappings[index] = mapping
                    } else {
                        activeMappings.append(mapping)
                    }
                }
            }
        }
        
        return activeMappings
    }
    
    func saveConfig() {
        do {
            let data = try JSONEncoder().encode(appConfigs)
            let url = getConfigFileURL()
            try data.write(to: url)
            print("💾 [GestureConfig] Saved \(appConfigs.count) Apps.")
        } catch {
            print("❌ Failed to save gesture config: \(error)")
        }
    }
    
    func loadConfig() {
        let url = getConfigFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            appConfigs = try JSONDecoder().decode([GestureAppConfig].self, from: data)
            print("✅ [GestureConfig] Loaded. Apps: \(appConfigs.map { $0.appName })")
        } catch {
            print("❌ Failed to load gesture config: \(error)")
        }
    }
    
    private func addChromeDefaults() {
        var chromeConfig = GestureAppConfig(bundleId: "com.google.Chrome", appName: "Google Chrome")
        chromeConfig.mappings = [
            GestureMapping(gestureType: .fourFingerTap, actionType: .cmdClick),  // 四指点击 = Cmd+Click
        ]
        appConfigs.append(chromeConfig)
        saveConfig()
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

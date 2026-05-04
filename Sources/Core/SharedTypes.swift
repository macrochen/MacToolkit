import Foundation

/// 跨模块共享类型

/// 模块 Tab 定义（用于外部引用）
struct ModuleTab: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
}

import SwiftUI

struct AlertView: View {
    let phase: TimerPhase
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text(phase.icon)
                .font(.system(size: 48))
            
            Text(phase.alertMessage)
                .font(.title2)
            
            Button("确认，开始\(phase.label)") {
                onConfirm()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
    }
}

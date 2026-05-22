import AppKit
import SwiftUI

struct TextAnnotationPanel: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let initialPosition: CGPoint
    let screenSize: CGSize

    @State private var position: CGPoint?
    @State private var dragStart: CGPoint?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("文字")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button(action: { viewModel.cancelTextAnnotation() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let start = dragStart ?? currentPosition
                        dragStart = start
                        position = clamped(CGPoint(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        ))
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )

            FocusedMultilineTextView(text: $viewModel.textDraft)
                .frame(width: 320, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("取消") {
                    viewModel.cancelTextAnnotation()
                }
                Button("添加") {
                    viewModel.commitTextAnnotation()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 350)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
        .position(currentPosition)
        .onAppear {
            position = clamped(initialPosition)
        }
    }

    private var currentPosition: CGPoint {
        clamped(position ?? initialPosition)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 185), max(185, screenSize.width - 185)),
            y: min(max(point.y, 110), max(110, screenSize.height - 110))
        )
    }
}

struct FocusedMultilineTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .textBackgroundColor

        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .systemFont(ofSize: 14)
        textView.string = text
        textView.delegate = context.coordinator
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            textView.window?.makeKey()
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if textView.window?.firstResponder !== textView {
                textView.window?.makeKey()
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

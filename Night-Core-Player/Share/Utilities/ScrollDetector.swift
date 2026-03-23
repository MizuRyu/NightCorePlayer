import SwiftUI

/// List / ScrollView のスクロールを検知し、コールバックで通知する ViewModifier
struct ScrollDetectorModifier: ViewModifier {
    let onScrolling: (Bool) -> Void

    @State private var scrollTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { _ in
                        onScrolling(true)
                        resetDelay()
                    }
                    .onEnded { _ in
                        resetDelay()
                    }
            )
            .onDisappear {
                scrollTask?.cancel()
            }
    }

    private func resetDelay() {
        scrollTask?.cancel()
        scrollTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            onScrolling(false)
        }
    }
}

extension View {
    func onScrollDetected(_ handler: @escaping (Bool) -> Void) -> some View {
        modifier(ScrollDetectorModifier(onScrolling: handler))
    }
}

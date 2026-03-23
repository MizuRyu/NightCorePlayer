import SwiftUI

/// List / ScrollView のスクロールを検知し、コールバックで通知する ViewModifier
struct ScrollDetectorModifier: ViewModifier {
    let onScrolling: (Bool) -> Void

    @State private var scrollTimer: Timer?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { _ in
                        onScrolling(true)
                        resetTimer()
                    }
                    .onEnded { _ in
                        resetTimer()
                    }
            )
    }

    private func resetTimer() {
        scrollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            DispatchQueue.main.async {
                onScrolling(false)
            }
        }
        // @State にセットするのではなく直接保持
        DispatchQueue.main.async {
            scrollTimer?.invalidate()
            scrollTimer = timer
        }
    }
}

extension View {
    func onScrollDetected(_ handler: @escaping (Bool) -> Void) -> some View {
        modifier(ScrollDetectorModifier(onScrolling: handler))
    }
}

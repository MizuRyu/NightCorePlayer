import SwiftUI
import Combine

/// キーボード表示状態を監視
final class KeyboardResponder: ObservableObject {
    @Published var isVisible: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }
        
        // show／hide イベントどちらも受けて isVisible を更新
        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .assign(to: \.isVisible, on: self)
            .store(in: &cancellables)
    }
}

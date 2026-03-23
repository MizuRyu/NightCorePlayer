import SwiftUI
import Combine
import Observation

@Observable
final class KeyboardResponder {
    var isVisible: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }
        
        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isVisible = $0 }
            .store(in: &cancellables)
    }
}

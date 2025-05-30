import SwiftData

struct PersistenceController {
    static let shared = PersistenceController()
    let container: ModelContainer
    
    private init() {
        container = try! ModelContainer(
            for: PlayerState.self,
            History.self
        )
    }
}


# Style and conventions
- Keep existing Swift style: `@MainActor` on UI/service types that touch player state, protocol-based DI for services, concise comments, Japanese user-facing comments/messages.
- Tests use Swift Testing (`@Suite`, `@Test`, `#expect`, `#require`) and must follow Given/When/Then comments and `action_condition_expected` naming per `docs/specs/TESTING-STRATEGY.md`.
- View logic should stay thin; behavior belongs in view models/services. Existing project docs explicitly avoid SwiftUI view tests and focus on service/viewmodel logic.
- Maintain current code organization by feature/service rather than creating ad hoc files.
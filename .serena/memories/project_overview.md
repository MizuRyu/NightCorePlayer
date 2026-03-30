# NightCorePlayer overview
- Purpose: iOS app to play Apple Music tracks in a Nightcore style (higher rate/pitch), with search, playlists, queue management, play history, and artwork cache.
- Tech stack: Swift, SwiftUI, MusicKit + MediaPlayer, SwiftData, Combine, AVFoundation. Architecture is MVVM plus service layer with protocol-based DI.
- Repo structure: `Night-Core-Player/` app sources (`Core`, `Models`, `Services`, `Data`, `Features`, `Extensions`, `Share`), `Night-Core-PlayerTests/` tests, `docs/specs/` design docs, `docs/memo/` investigations, `scripts/` utility scripts, `privacy-policy/` MkDocs site.
- Entry point: `Night-Core-Player/App.swift` creates concrete services and injects view models into SwiftUI environment.
- Current notable area: playback is centered in `Services/MusicPlayerServiceImpl.swift` with `MPMusicPlayerAdapter` over `MPMusicPlayerController.applicationQueuePlayer` and `MusicKitServiceImpl` for catalog/library access.
# Suggested commands
- List files: `fd <pattern> <path>`
- Search text: `rg -n "<pattern>" Night-Core-Player Night-Core-PlayerTests docs`
- Inspect history: `git log --oneline -- <path>` and `git blame -L start,end <path>`
- Run targeted tests: `xcodebuild test -project Night-Core-Player.xcodeproj -scheme Night-Core-Player -destination 'id=<SIMULATOR_ID>' -only-testing:Night-Core-PlayerTests/MusicPlayerServiceTests -only-testing:Night-Core-PlayerTests/MusicKitServiceTests`
- Show destinations: `xcodebuild -showdestinations -project Night-Core-Player.xcodeproj -scheme Night-Core-Player`
- Real-device build: `xcodebuild -project Night-Core-Player.xcodeproj -scheme Night-Core-Player -configuration Debug -destination 'id=<DEVICE_ID>' -derivedDataPath ./.derivedData -allowProvisioningUpdates build`
- Install to device: `xcrun devicectl device install app --device <DEVICE_ID> ./.derivedData/Build/Products/Debug-iphoneos/Night-Core-Player.app`
- Launch on device: `xcrun devicectl device process launch --device <DEVICE_ID> --console MizuRyu.Night-Core-Player`
- Search debug prints to remove later: `rg '🎵|⚠️.*print' Night-Core-Player/`
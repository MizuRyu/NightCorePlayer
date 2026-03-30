# Task completion checklist
- Prefer lightweight verification first: targeted `xcodebuild test` for impacted suites.
- For playback/library changes, verify on real device when possible because MusicKit/MediaPlayer behavior differs from simulator and mocks.
- Summarize any environment-dependent risks separately from code changes, especially Apple Music authorization, subscription, and App Services configuration.
- If debug logging was added during investigation, remove it before finalizing unless the user explicitly wants it kept.
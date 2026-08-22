PROJECT := Night-Core-Player.xcodeproj
SCHEME := Night-Core-Player

# ローカル環境に合わせて上書き可: make test DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro'
DESTINATION ?= platform=iOS Simulator,name=iPhone SE (3rd generation)

.PHONY: check build lint swiftformat-lint test format

check: build lint swiftformat-lint ## ビルド + Lint 一式

build: ## デバッグビルドが通ることを確認
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-quiet

lint: ## SwiftLint で全体を検査（警告は失敗にしない。--strict は pre-commit で実施）
	swiftlint lint

swiftformat-lint: ## SwiftFormat の整形漏れを検査（修正はしない）
	swiftformat --lint .

test: ## ユニットテスト実行
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-parallel-testing-enabled NO \
		-quiet

format: ## SwiftFormat で自動整形
	swiftformat .

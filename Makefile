PROJECT := Night-Core-Player.xcodeproj
SCHEME := Night-Core-Player

# ローカル環境に合わせて上書き可: make test DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro'
# OS=latest は必須: 同名デバイスが複数ランタイムに存在するため、省略すると宛先が一意に定まらず Error 70 になる
# 端末名は最新ランタイムに存在するものを指定する（iPhone SE は iOS 18 系までのため latest では見つからない）
DESTINATION ?= platform=iOS Simulator,name=iPhone 17,OS=latest

.PHONY: check build lint swiftformat-lint test format check-swiftformat-version

check: build lint swiftformat-lint ## ビルド + Lint 一式

build: ## デバッグビルドが通ることを確認
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-quiet

lint: ## SwiftLint で全体を検査（警告は失敗にしない。--strict は pre-commit で実施）
	swiftlint lint

check-swiftformat-version: ## インストール済み swiftformat が .swiftformat-version と一致するか検査
	@expected="$$(cat .swiftformat-version)"; \
	installed="$$(swiftformat --version 2>/dev/null)"; \
	if [ "$$installed" != "$$expected" ]; then \
		echo "swiftformat のバージョンが不一致です（期待: $$expected / 検出: $${installed:-未インストール}）"; \
		echo "インストール: brew install swiftformat（バージョンは .swiftformat-version を参照）"; \
		exit 1; \
	fi

swiftformat-lint: check-swiftformat-version ## SwiftFormat の整形漏れを検査（修正はしない）
	swiftformat --lint .

test: ## ユニットテスト実行（デモ用UIテストは除外。実行は scripts/record-demo.sh）
	swift test --package-path Packages/NightCoreDomain
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-skip-testing:Night-Core-PlayerUITests \
		-parallel-testing-enabled NO \
		-quiet

format: check-swiftformat-version ## SwiftFormat で自動整形
	swiftformat .

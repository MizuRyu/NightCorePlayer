# Swift ソフトウェアアーキテクチャ・設計パターン 総合調査レポート

> 調査日: 2026-03-23
> 対象: Swift / iOS 開発における ベストプラクティス、プロジェクト構造、ソフトウェアアーキテクチャ（SWA）、契約（Ports / Protocols / Interfaces / Contracts）、デザインパターン

---

## 目次

1. [Executive Summary](#1-executive-summary)
2. [Swift における「契約」の用語整理](#2-swift-における契約の用語整理)
3. [Protocol-Oriented Programming (POP)](#3-protocol-oriented-programming-pop)
4. [Existential Type (`any`) vs Opaque Type (`some`) vs Generics](#4-existential-type-any-vs-opaque-type-some-vs-generics)
5. [ソフトウェアアーキテクチャ比較](#5-ソフトウェアアーキテクチャ比較)
6. [Clean Architecture in Swift](#6-clean-architecture-in-swift)
7. [Hexagonal Architecture (Ports & Adapters)](#7-hexagonal-architecture-ports--adapters)
8. [プロジェクト構造のベストプラクティス](#8-プロジェクト構造のベストプラクティス)
9. [SPM マルチモジュール化](#9-spm-マルチモジュール化)
10. [Swift Concurrency & Actor Model](#10-swift-concurrency--actor-model)
11. [Observation フレームワーク (`@Observable`)](#11-observation-フレームワーク-observable)
12. [依存性注入 (Dependency Injection)](#12-依存性注入-dependency-injection)
13. [よく使われるデザインパターン一覧](#13-よく使われるデザインパターン一覧)
14. [NightCorePlayer への適用分析](#14-nightcoreplayer-への適用分析)
15. [参考文献](#15-参考文献)

---

## 1. Executive Summary

Swift / iOS 開発における現代のソフトウェア設計は、以下の 3 つの柱を中心に構成される:

1. **Protocol-Oriented Programming (POP)** — Swift 固有のパラダイムであり、他言語の Interface / Contract / Port に相当する `protocol` を中心に設計する
2. **レイヤードアーキテクチャ** — Clean Architecture / Hexagonal Architecture の思想に基づき、Domain ↔ Data ↔ Presentation を分離する
3. **Swift Concurrency** — `async/await`、`Actor`、`@Observable` など Swift ネイティブの並行処理・状態管理メカニズム

本レポートでは、これらの概念を体系的に整理し、具体的なコード例と共に NightCorePlayer プロジェクトとの対応関係も分析する。

---

## 2. Swift における「契約」の用語整理

ソフトウェア設計では、コンポーネント間の「契約」を表す用語が多数存在する。Swift では以下のように対応する:

| 一般用語 | Swift での対応 | 説明 |
|---------|-------------|------|
| **Interface** (Java/C#) | `protocol` | 型が準拠すべきメソッド・プロパティのシグネチャを定義 |
| **Contract** | `protocol` + ドキュメント | 振る舞いの保証。事前条件・事後条件を含む |
| **Port** (Hexagonal) | `protocol` (Domain 層で定義) | ドメインが外部と通信するための抽象境界 |
| **Adapter** (Hexagonal) | `protocol` の具象実装 (`class`/`struct`) | Port を満たす具体的な外部連携の実装 |
| **Abstract Base Class** | `protocol` + extension (default impl) | Swift では継承よりも protocol + extension を推奨 |
| **Trait** (Rust) | `protocol` | 機能の単位。Swift の protocol は Rust の trait に最も近い |
| **Type Class** (Haskell) | `protocol` with associated types | ジェネリックな抽象。`Equatable`, `Codable` など |

### Swift `protocol` が他言語の Interface より強力な理由

```swift
// 1. Default Implementation（デフォルト実装）
protocol Drawable {
    func draw()
}
extension Drawable {
    func draw() { print("Default drawing") }  // Java の default method に相当
}

// 2. Associated Types（関連型）
protocol Repository {
    associatedtype Entity
    func findAll() -> [Entity]
    func save(_ entity: Entity)
}

// 3. Protocol Composition（合成）
typealias Persistable = Codable & Identifiable

// 4. Conditional Conformance（条件付き準拠）
extension Array: Equatable where Element: Equatable { }

// 5. Value Types も準拠可能（Java Interface は class のみ）
struct Circle: Drawable {
    func draw() { print("Circle") }
}
```

> **重要**: Swift の `protocol` は Java の `interface`、C# の `interface`、Rust の `trait`、Go の `interface` すべてに対応するが、default implementation と associated types によりこれらより柔軟である[^1][^2]。

---

## 3. Protocol-Oriented Programming (POP)

WWDC 2015 で Apple が提唱した Swift のコアパラダイム。「クラス継承よりプロトコル合成を優先する」という設計哲学。

### 基本原則

```
┌─────────────────────────────────────────────────────┐
│                   POP の 4 原則                       │
├─────────────────────────────────────────────────────┤
│ 1. 継承より合成 (Composition over Inheritance)        │
│ 2. 値型の優先 (Prefer Value Types)                    │
│ 3. プロトコルでの抽象化 (Abstract with Protocols)       │
│ 4. プロトコル拡張でコード共有 (Share via Extensions)     │
└─────────────────────────────────────────────────────┘
```

### ベストプラクティス

#### 3.1 小さく焦点を絞ったプロトコル (ISP: Interface Segregation Principle)

```swift
// ❌ 悪い例: 太い interface
protocol MusicPlayer {
    func play()
    func pause()
    func setRate(_ rate: Float)
    func fetchArtwork() async -> Data?
    func saveHistory(_ song: Song)
    func searchSongs(_ query: String) async -> [Song]
}

// ✅ 良い例: 責務ごとに分離
protocol Playable {
    func play()
    func pause()
}

protocol RateAdjustable {
    func setRate(_ rate: Float)
}

protocol ArtworkProvider {
    func fetchArtwork() async -> Data?
}

// 必要に応じて合成
typealias NightCorePlayer = Playable & RateAdjustable
```

#### 3.2 プロトコル拡張でデフォルト実装を提供

```swift
protocol Loggable {
    var logPrefix: String { get }
}

extension Loggable {
    var logPrefix: String { String(describing: type(of: self)) }
    
    func log(_ message: String) {
        print("[\(logPrefix)] \(message)")
    }
}

// struct でも class でも利用可能
struct PlayerService: Loggable {
    func doSomething() {
        log("Processing...")  // "[PlayerService] Processing..."
    }
}
```

#### 3.3 Protocol Witness（プロトコル証人パターン）

関数型プログラミング的アプローチ。protocol の代わりに struct に関数を持たせる:

```swift
// Protocol-based
protocol Validator {
    func validate(_ input: String) -> Bool
}

// Protocol Witness (関数型スタイル)
struct StringValidator {
    let validate: (String) -> Bool
}

// 使用例: テスト時の差し替えが容易
let alwaysValid = StringValidator { _ in true }
let emailValidator = StringValidator { $0.contains("@") }
```

> **使い分け**: Protocol は型レベルの抽象化に、Protocol Witness は関数レベルの差し替えに向く。pointfree.co の TCA は Protocol Witness を多用している[^3]。

---

## 4. Existential Type (`any`) vs Opaque Type (`some`) vs Generics

Swift 5.6+ で導入された `any` / `some` キーワードは、プロトコルベースの抽象化におけるパフォーマンスと柔軟性のトレードオフを明示する。

### 比較表

| 特性 | `any Protocol` (Existential) | `some Protocol` (Opaque) | `<T: Protocol>` (Generic) |
|------|---------------------------|------------------------|--------------------------|
| コンパイル時に型が確定 | ❌ No | ✅ Yes | ✅ Yes |
| ディスパッチ方式 | 動的 (Witness Table) | 静的 | 静的 (単相化) |
| メモリ配置 | Existential Container (最大24bytes inline, 超過時ヒープ) | インライン | インライン |
| ヒープ確保の可能性 | あり | なし | なし |
| インライン最適化 | 不可 | 可能 | 可能 |
| 異種コレクション | ✅ 可能 (`[any Drawable]`) | ❌ 不可 | ❌ 不可 |
| 推奨用途 | ランタイムポリモーフィズム | API の戻り値型隠蔽 | パフォーマンス重視 |

### Existential Container の内部構造

```
┌──────────────────────────────────────┐
│        Existential Container         │
├──────────────────────────────────────┤
│  Value Buffer (24 bytes)             │  ← 値が 24bytes 以内なら inline 格納
│  ──────────────────────────────────  │    超える場合はヒープへのポインタ
│  Value Witness Table pointer         │  ← copy/destroy 等の基本操作
│  Protocol Witness Table pointer(s)   │  ← protocol メソッドへの関数ポインタ
└──────────────────────────────────────┘
```

### 実践的な使い分けガイド

```swift
// 1. any — 異なる具象型をまとめて扱う場合
let shapes: [any Shape] = [Circle(), Square(), Triangle()]

// 2. some — 戻り値の型を隠蔽しつつパフォーマンスを維持
func makeView() -> some View {
    Text("Hello")  // 具象型は呼び出し側に非公開だが、コンパイラは知っている
}

// 3. Generic — 最高パフォーマンス。コンパイラが型ごとに特殊化
func process<T: Encodable>(_ value: T) {
    // T の具体型ごとにコードが生成される（単相化）
}

// 4. any → some/Generic への変換（パフォーマンス改善テクニック）
func render(_ shape: any Shape) {       // ❌ 動的ディスパッチ
    shape.draw()
}
func render(_ shape: some Shape) {      // ✅ 静的ディスパッチ
    shape.draw()
}
```

> **経験則**: `any` は「異種混合コレクション」「DI コンテナ」に限定し、それ以外は `some` またはジェネリクスを使う。パフォーマンスクリティカルなパスでは `any` を避ける[^4][^5]。

---

## 5. ソフトウェアアーキテクチャ比較

### アーキテクチャ比較表

| アーキテクチャ | 複雑度 | ボイラープレート | モジュール性 | テスト容易性 | SwiftUI 適合性 | 推奨規模 |
|-------------|-------|-------------|-----------|-----------|-------------|---------|
| **MVC** | 低 | 最少 | 低 | 低 | △ (UIKit向き) | 小規模 |
| **MVVM** | 低〜中 | 少 | 中 | 中〜高 | ◎ | 小〜中規模 |
| **MVVM + Clean** | 中 | 中 | 高 | 高 | ◎ | 中〜大規模 |
| **TCA** | 中〜高 | 多 | 高 | 非常に高 | ◎ | 中〜大規模 |
| **VIPER** | 高 | 非常に多 | 非常に高 | 高 | △ (UIKit向き) | 大規模エンタープライズ |
| **Clean Architecture** | 高 | 多 | 非常に高 | 高 | ○ | 大規模・長寿命 |

### 各アーキテクチャの概要

#### MVVM (Model-View-ViewModel)
```
┌──────────┐    ┌─────────────┐    ┌──────────┐
│   View   │◀──▶│  ViewModel  │───▶│  Model   │
│ (SwiftUI)│    │ (@Observable)│    │ (struct) │
└──────────┘    └─────────────┘    └──────────┘
```
- SwiftUI と最も自然に統合される
- `@Observable` + `@State` / `@Environment` でリアクティブバインディング
- 小〜中規模アプリに最適

#### TCA (The Composable Architecture)
```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  View    │──▶│  Action  │──▶│ Reducer  │──▶│  State   │
│          │◀──│          │    │ (pure fn)│    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                                     │
                                     ▼
                               ┌──────────┐
                               │  Effect  │
                               │(副作用)   │
                               └──────────┘
```
- Redux/Elm にインスパイアされた単方向データフロー
- Reducer は純粋関数 → テストが非常に容易
- 学習コスト高、ボイラープレート多

#### VIPER
```
┌──────┐  ┌───────────┐  ┌────────────┐  ┌────────┐  ┌────────┐
│ View │◀▶│ Presenter │◀▶│ Interactor │──│ Entity │  │ Router │
└──────┘  └───────────┘  └────────────┘  └────────┘  └────────┘
```
- 5 層の厳密な責務分離
- UIKit 時代の大規模アプリに最適
- SwiftUI では過剰設計になりがち

### 選定ガイドライン

```
アプリ規模は？
├── 小規模（個人/プロトタイプ）→ MVVM
├── 中規模（チーム開発）
│   ├── 状態管理が複雑 → TCA
│   └── 標準的な CRUD → MVVM + Clean
└── 大規模（エンタープライズ）
    ├── UIKit ベース → VIPER or Clean
    └── SwiftUI ベース → MVVM + Clean or TCA
```

> **NightCorePlayer の選択**: MVVM + Service Layer（Clean Architecture の簡易版）は、個人〜小規模チーム開発の SwiftUI アプリとして最適な選択である[^6][^7]。

---

## 6. Clean Architecture in Swift

Robert C. Martin (Uncle Bob) の Clean Architecture を Swift に適用する。

### レイヤー構造

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│   ┌───────────────┐    ┌──────────────────┐              │
│   │  SwiftUI View │◀──▶│   ViewModel      │              │
│   └───────────────┘    │  (@Observable)    │              │
│                         └────────┬─────────┘              │
├──────────────────────────────────┼──────────────────────-─┤
│                    Domain Layer   │                        │
│   ┌─────────────┐    ┌──────────▼──────────┐             │
│   │   Entity     │    │    Use Case         │             │
│   │  (Model)     │    │  (Business Logic)   │             │
│   └─────────────┘    └──────────┬──────────┘             │
│                         ┌───────▼────────┐                │
│                         │   Repository   │                │
│                         │   (protocol)   │  ← Port        │
│                         └───────┬────────┘                │
├─────────────────────────────────┼─────────────────────────┤
│                    Data Layer    │                         │
│   ┌─────────────────────────────▼──────────────────────┐  │
│   │         Repository Implementation                   │  │ ← Adapter
│   │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │  │
│   │  │ SwiftData│  │ Network  │  │ UserDefaults     │ │  │
│   │  └──────────┘  └──────────┘  └──────────────────┘ │  │
│   └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 依存関係ルール (Dependency Rule)

**内側の層は外側の層を知らない。依存は常に内向き。**

```swift
// ✅ Domain 層: フレームワーク非依存
protocol SongRepository {                   // ← Port
    func findAll() async throws -> [Song]
    func save(_ song: Song) async throws
}

struct FetchSongsUseCase {                  // ← Use Case
    let repository: SongRepository          // protocol に依存
    
    func execute() async throws -> [Song] {
        try await repository.findAll()
    }
}

// ✅ Data 層: Domain の protocol を実装
final class SwiftDataSongRepository: SongRepository {  // ← Adapter
    let container: ModelContainer
    
    func findAll() async throws -> [Song] {
        // SwiftData 固有の実装
    }
    func save(_ song: Song) async throws {
        // SwiftData 固有の実装
    }
}

// ✅ Presentation 層: Domain の Use Case を使用
@Observable
class SongListViewModel {
    private let fetchSongs: FetchSongsUseCase
    var songs: [Song] = []
    
    func load() async {
        do {
            songs = try await fetchSongs.execute()
        } catch {
            // エラーハンドリング
        }
    }
}
```

> **ポイント**: Domain 層は UIKit / SwiftUI / SwiftData など一切のフレームワークに依存しない。純粋な Swift コードのみ[^8][^9]。

---

## 7. Hexagonal Architecture (Ports & Adapters)

Alistair Cockburn が提唱したアーキテクチャパターン。Clean Architecture と思想が近いが、Port / Adapter の概念がより明確。

### 構造図

```
                     ┌─────────────────────────┐
                     │     Driving Adapter      │
                     │   (UI / CLI / Test)      │
                     └────────────┬────────────┘
                                  │
                     ┌────────────▼────────────┐
                     │     Driving Port         │
                     │   (Inbound Protocol)     │
                     └────────────┬────────────┘
                                  │
            ┌─────────────────────▼─────────────────────┐
            │              Domain Core                   │
            │                                            │
            │   ┌──────────┐    ┌──────────────────┐    │
            │   │ Entities │    │  Business Logic   │    │
            │   └──────────┘    └──────────────────┘    │
            │                                            │
            └─────────────────────┬─────────────────────┘
                                  │
                     ┌────────────▼────────────┐
                     │     Driven Port          │
                     │   (Outbound Protocol)    │
                     └────────────┬────────────┘
                                  │
                     ┌────────────▼────────────┐
                     │     Driven Adapter       │
                     │  (DB / API / FileSystem) │
                     └─────────────────────────┘
```

### Swift での実装

```swift
// === Driven Port (Outbound) ===
// Domain 層で定義。外部永続化の抽象
protocol PlayHistoryPort {
    func record(_ song: Song, at date: Date) async throws
    func recentHistory(limit: Int) async throws -> [PlayRecord]
}

// === Driven Adapter ===
// Data 層で実装。SwiftData を使った具象
final class SwiftDataPlayHistoryAdapter: PlayHistoryPort {
    private let container: ModelContainer
    
    func record(_ song: Song, at date: Date) async throws {
        // SwiftData 固有の保存処理
    }
    
    func recentHistory(limit: Int) async throws -> [PlayRecord] {
        // SwiftData 固有のクエリ
    }
}

// === テスト用 Adapter ===
final class InMemoryPlayHistoryAdapter: PlayHistoryPort {
    var records: [PlayRecord] = []
    
    func record(_ song: Song, at date: Date) async throws {
        records.append(PlayRecord(song: song, date: date))
    }
    
    func recentHistory(limit: Int) async throws -> [PlayRecord] {
        Array(records.suffix(limit))
    }
}

// === Driving Port (Inbound) ===
protocol MusicPlayerPort {
    func play(_ song: Song) async throws
    func adjustRate(_ rate: Float) async throws
}

// === Domain Service (Driving Port の実装) ===
final class NightCorePlayerService: MusicPlayerPort {
    private let historyPort: PlayHistoryPort  // Driven Port に依存
    
    func play(_ song: Song) async throws {
        // 再生ロジック
        try await historyPort.record(song, at: .now)
    }
    
    func adjustRate(_ rate: Float) async throws {
        // レート調整ロジック
    }
}
```

### Port の命名規則

| Port 種別 | 方向 | 命名パターン | 例 |
|-----------|------|-----------|-----|
| Driving Port | 外→内 (Inbound) | `~Service`, `~UseCase`, `~Port` | `MusicPlayerService` |
| Driven Port | 内→外 (Outbound) | `~Repository`, `~Gateway`, `~Port` | `SongRepository`, `APIGateway` |

> **Swift の慣例**: Java のように `I~` プレフィックスは使わない。`protocol MusicPlayerService` が interface、`class MusicPlayerServiceImpl` が実装。もしくは `Default~`, `Live~` プレフィックス[^10][^11]。

---

## 8. プロジェクト構造のベストプラクティス

### 推奨ディレクトリ構成 (MVVM + Clean)

```
MyApp/
├── App/
│   ├── App.swift                    # @main, DI Composition Root
│   └── AppDelegate.swift            # (UIKit 統合時のみ)
│
├── Core/
│   ├── Constants/
│   │   ├── BusinessConstants.swift
│   │   └── UIConstants.swift
│   ├── Extensions/
│   │   └── Date+Format.swift
│   ├── Errors/
│   │   └── AppError.swift
│   └── Utilities/
│       └── Logger.swift
│
├── Domain/
│   ├── Models/                      # Entity (純粋な Swift struct)
│   │   ├── Song.swift
│   │   └── Playlist.swift
│   ├── Services/                    # Protocol (Port) + Implementation
│   │   ├── MusicPlayerService.swift
│   │   └── PlaybackRateManager.swift
│   └── UseCases/                    # (規模が大きい場合)
│       └── FetchSongsUseCase.swift
│
├── Data/
│   ├── Repositories/
│   │   ├── SongRepository.swift
│   │   └── HistoryRepository.swift
│   ├── Persistence/
│   │   ├── Persistence.swift        # SwiftData ModelContainer
│   │   └── PlayerState.swift        # @Model
│   └── Network/
│       └── APIClient.swift
│
├── Features/                        # Feature-based grouping
│   ├── MusicPlayer/
│   │   ├── MusicPlayerView.swift
│   │   ├── MusicPlayerViewModel.swift
│   │   └── Components/
│   │       └── PlaybackControls.swift
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchViewModel.swift
│   ├── Playlist/
│   │   ├── PlaylistView.swift
│   │   └── PlaylistDetailView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
├── Share/                           # 共有 UI コンポーネント
│   ├── Components/
│   │   ├── MarqueeText.swift
│   │   └── SongContextMenu.swift
│   └── Modifiers/
│       └── ShakeEffect.swift
│
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.xcstrings
│
└── Tests/
    ├── UnitTests/
    │   ├── Services/
    │   ├── ViewModels/
    │   └── Repositories/
    ├── Mock/
    │   ├── MusicPlayerServiceMock.swift
    │   └── MusicKitServiceMock.swift
    └── UITests/
```

### 構成の原則

| 原則 | 説明 |
|------|------|
| **Feature-first** | View + ViewModel を機能単位でグルーピング。ファイルを探す際の認知負荷を下げる |
| **Layer-second** | Domain/Data/Core は横断的な層としてトップレベルに配置 |
| **Flat over Deep** | 3 階層以上のネストを避ける。IDE でのナビゲーションを容易にする |
| **Co-location** | 関連ファイルを近くに配置（Test は Tests/ に、Mock は Mock/ に集約） |
| **1 ファイル 1 型** | 原則として 1 つの Swift ファイルに 1 つの主要な型を定義 |

---

## 9. SPM マルチモジュール化

大規模プロジェクトでは Swift Package Manager (SPM) を使ったマルチモジュール化が推奨される。

### モジュール分割例

```
MyApp/
├── App/                     # メインアプリターゲット
├── Packages/
│   ├── Core/                # Swift Package
│   │   ├── Sources/Core/
│   │   └── Tests/CoreTests/
│   ├── Domain/              # Swift Package
│   │   ├── Sources/Domain/
│   │   └── Tests/DomainTests/
│   ├── Networking/          # Swift Package
│   │   ├── Sources/Networking/
│   │   └── Tests/NetworkingTests/
│   ├── DesignSystem/        # Swift Package
│   │   └── Sources/DesignSystem/
│   └── Feature-Player/      # Swift Package
│       ├── Sources/FeaturePlayer/
│       └── Tests/FeaturePlayerTests/
└── Package.swift
```

### モジュール依存関係

```
┌──────────────┐
│     App      │ ← 全モジュールを統合
├──────┬───────┤
│      │       │
▼      ▼       ▼
┌──────┐┌──────┐┌──────────────┐
│Player││Search││DesignSystem  │  ← Feature modules
└──┬───┘└──┬───┘└──────────────┘
   │       │
   ▼       ▼
┌──────────────┐
│   Domain     │  ← ビジネスロジック (フレームワーク非依存)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│    Core      │  ← ユーティリティ、定数
└──────────────┘
```

### メリット

- **ビルド時間の短縮**: 変更されたモジュールのみ再ビルド
- **アクセス制御の強制**: `public` / `internal` がモジュール境界で意味を持つ
- **チームの自律性**: 各チームが担当モジュールを独立して開発
- **テストの分離**: モジュール単位でのテスト実行が可能

> **NightCorePlayer の規模では**: 現時点では単一ターゲットで十分。ただし将来的に Widget Extension や Watch App を追加する際にはモジュール分割が有効[^12][^13]。

---

## 10. Swift Concurrency & Actor Model

### async/await

```swift
// ❌ コールバック地獄
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, error in
        if let error { completion(.failure(error)); return }
        guard let data else { completion(.failure(AppError.noData)); return }
        // さらにネスト...
        completion(.success(data))
    }.resume()
}

// ✅ async/await でフラットに
func fetchData() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

### Structured Concurrency

```swift
// async let — 並列実行（タスク数が固定の場合）
async let artwork = fetchArtwork(for: song)
async let lyrics = fetchLyrics(for: song)
let (artworkData, lyricsText) = try await (artwork, lyrics)

// TaskGroup — 並列実行（タスク数が動的の場合）
func fetchAllArtworks(songs: [Song]) async throws -> [Data] {
    try await withThrowingTaskGroup(of: Data.self) { group in
        for song in songs {
            group.addTask { try await fetchArtwork(for: song) }
        }
        return try await group.reduce(into: []) { $0.append($1) }
    }
}
```

### Actor

```swift
// Mutable state の安全な隔離
actor ImageCache {
    private var cache: [URL: Data] = [:]
    
    func image(for url: URL) -> Data? {
        cache[url]
    }
    
    func store(_ data: Data, for url: URL) {
        cache[url] = data
    }
}

// 使用側: await が必要
let cache = ImageCache()
await cache.store(imageData, for: imageURL)
if let cached = await cache.image(for: imageURL) { ... }
```

### @MainActor

```swift
// UI 更新は必ず Main Actor で
@Observable
@MainActor
class MusicPlayerViewModel {
    var currentSong: Song?
    var isPlaying: Bool = false
    
    func play(_ song: Song) async throws {
        // この中の処理はすべて MainActor で実行される
        currentSong = song
        isPlaying = true
        try await musicService.play(song)
    }
}
```

### Sendable

```swift
// Concurrency 境界を越える型は Sendable に準拠させる
struct Song: Sendable {  // Value type → 自動的に Sendable
    let id: String
    let title: String
}

// class は明示的な準拠が必要
final class AppConfiguration: Sendable {
    let apiKey: String  // let のみ（var は不可）
    init(apiKey: String) { self.apiKey = apiKey }
}
```

> **ベストプラクティス**: ViewModel は `@MainActor`、Service 層は `actor` または通常の `class` + `async`、Model は `struct` + `Sendable`[^14][^15]。

---

## 11. Observation フレームワーク (`@Observable`)

iOS 17 / Swift 5.9 で導入された新しい状態管理メカニズム。

### ObservableObject → @Observable 移行マップ

| 旧 (Combine ベース) | 新 (Observation) |
|--------------------|------------------|
| `class VM: ObservableObject` | `@Observable class VM` |
| `@Published var x` | `var x` (自動追跡) |
| `@StateObject var vm` | `@State var vm` |
| `@ObservedObject var vm` | `var vm` or `@Bindable var vm` |
| `@EnvironmentObject var x` | `@Environment(Type.self) var x` |
| `.environmentObject(x)` | `.environment(x)` |
| `objectWillChange.send()` | 不要 (自動) |

### 主要な利点

1. **プロパティレベル追跡**: View が実際に使用しているプロパティが変更された時のみ再描画
2. **Combine 不要**: `@Published` や `ObservableObject` の Combine 依存を排除
3. **シンプルな API**: マクロ一つで完結

### パターン例

```swift
// --- ViewModel ---
@Observable
class PlayerViewModel {
    var currentSong: Song?
    var isPlaying = false
    var playbackRate: Float = 1.0
    
    @ObservationIgnored  // UI 更新をトリガーしない
    private var musicService: MusicPlayerService
    
    init(service: MusicPlayerService) {
        self.musicService = service
    }
}

// --- App.swift (Composition Root) ---
@main
struct MyApp: App {
    @State private var playerVM = PlayerViewModel(
        service: MusicPlayerServiceImpl()
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerVM)
        }
    }
}

// --- View ---
struct PlayerView: View {
    @Environment(PlayerViewModel.self) var vm
    
    var body: some View {
        @Bindable var vm = vm  // 双方向バインディング用
        
        VStack {
            Text(vm.currentSong?.title ?? "No Song")
            Slider(value: $vm.playbackRate, in: 0.5...2.0)
            Button(vm.isPlaying ? "Pause" : "Play") {
                // ...
            }
        }
    }
}
```

### protocol ベース DI と @Environment の制約

```swift
// ❌ @Environment は protocol 型を直接サポートしない
// @Environment(MusicPlayerService.self) var service  // コンパイルエラー

// ✅ EnvironmentKey を定義する
private struct MusicServiceKey: EnvironmentKey {
    static let defaultValue: any MusicPlayerService = MusicPlayerServiceImpl()
}

extension EnvironmentValues {
    var musicService: any MusicPlayerService {
        get { self[MusicServiceKey.self] }
        set { self[MusicServiceKey.self] = newValue }
    }
}

// 使用側
struct SomeView: View {
    @Environment(\.musicService) var service
}
```

> **注意**: `@Environment(Type.self)` は具象クラスのみ。protocol 型には `EnvironmentKey` パターンが必要[^16][^17]。

---

## 12. 依存性注入 (Dependency Injection)

### DI パターンの比較

| パターン | 説明 | メリット | デメリット |
|---------|------|---------|----------|
| **Constructor Injection** | init で依存を注入 | 最も安全。不変性を保証 | パラメータが多くなりがち |
| **Property Injection** | プロパティに後から設定 | 柔軟 | nil の可能性、unsafe |
| **Method Injection** | メソッド引数で渡す | 呼び出しごとに変更可能 | 毎回渡す手間 |
| **Environment Injection** | SwiftUI の `.environment()` | 宣言的、SwiftUI ネイティブ | SwiftUI 外では使えない |
| **DI Container** | Swinject 等のフレームワーク | 大規模向け、自動解決 | 過剰設計になりがち |

### 推奨: Constructor Injection + Composition Root

```swift
// === Protocol 定義 ===
protocol MusicPlayerService { ... }
protocol HistoryRepository { ... }
protocol ArtworkCacheService { ... }

// === Composition Root (App.swift) ===
@main
struct NightCorePlayerApp: App {
    // 依存グラフをここで構築
    let container: ModelContainer
    let historyRepo: HistoryRepository
    let musicService: MusicPlayerService
    let artworkCache: ArtworkCacheService
    
    @State private var playerVM: MusicPlayerViewModel
    @State private var settingsVM: SettingsViewModel
    
    init() {
        let container = PersistenceController.shared.container
        let historyRepo = HistoryRepositoryImpl(container: container)
        let musicService = MusicPlayerServiceImpl(
            historyRepository: historyRepo
        )
        let artworkCache = ArtworkCacheServiceImpl()
        
        self.container = container
        self.historyRepo = historyRepo
        self.musicService = musicService
        self.artworkCache = artworkCache
        
        self._playerVM = State(initialValue: MusicPlayerViewModel(
            musicPlayerService: musicService
        ))
        self._settingsVM = State(initialValue: SettingsViewModel(
            rateManager: PlaybackRateManagerImpl()
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(playerVM)
                .environment(settingsVM)
        }
    }
}
```

### テスト時の差し替え

```swift
@Suite("MusicPlayerViewModel Tests")
struct MusicPlayerViewModelTests {
    @Test func play_shouldUpdateState() async {
        // Mock を Constructor Injection
        let mockService = MusicPlayerServiceMock()
        let vm = MusicPlayerViewModel(musicPlayerService: mockService)
        
        await vm.play(song)
        
        #expect(mockService.playCallCount == 1)
        #expect(vm.isPlaying == true)
    }
}
```

> **DI コンテナは不要**: 小〜中規模の Swift アプリでは、Swinject 等の DI コンテナは過剰。Composition Root + Constructor Injection で十分[^18]。

---

## 13. よく使われるデザインパターン一覧

### 生成パターン (Creational)

| パターン | Swift での実装 | 代表的な使用場面 |
|---------|-------------|------------|
| **Singleton** | `static let shared` + `private init()` | `URLSession.shared`, `FileManager.default` |
| **Factory Method** | static メソッド or protocol | UI コンポーネント生成、ViewModel 生成 |
| **Builder** | メソッドチェーン or Result Builder | URLRequest 構築、SwiftUI DSL |
| **Abstract Factory** | protocol + 具象 Factory | テーマ切替、プラットフォーム分岐 |

```swift
// Singleton
final class AudioEngine {
    static let shared = AudioEngine()
    private init() { }
}

// Factory Method
protocol ViewModelFactory {
    func makePlayerViewModel() -> MusicPlayerViewModel
    func makeSearchViewModel() -> SearchViewModel
}

// Builder (Result Builder)
@resultBuilder
struct PlaylistBuilder {
    static func buildBlock(_ songs: Song...) -> [Song] { songs }
}
func playlist(@PlaylistBuilder content: () -> [Song]) -> Playlist {
    Playlist(songs: content())
}
```

### 構造パターン (Structural)

| パターン | Swift での実装 | 代表的な使用場面 |
|---------|-------------|------------|
| **Adapter** | protocol 準拠 wrapper | レガシー API のラップ |
| **Facade** | 複数サービスを統合するクラス | `MusicPlayerServiceImpl`（複数機能の統合） |
| **Decorator** | protocol extension or wrapper | ログ追加、キャッシュ追加 |
| **Composite** | 再帰的な protocol | SwiftUI `View` protocol 自体 |
| **Bridge** | protocol + 具象分離 | Persistence 層の抽象化 |
| **Proxy** | 同一 protocol の wrapper | 遅延読み込み、アクセス制御 |

```swift
// Decorator: ログ付き Repository
final class LoggingHistoryRepository: HistoryRepository {
    private let wrapped: HistoryRepository
    
    init(wrapping repository: HistoryRepository) {
        self.wrapped = repository
    }
    
    func save(_ record: PlayRecord) async throws {
        print("[History] Saving: \(record.song.title)")
        try await wrapped.save(record)
    }
}
```

### 振る舞いパターン (Behavioral)

| パターン | Swift での実装 | 代表的な使用場面 |
|---------|-------------|------------|
| **Observer** | Combine, NotificationCenter, `@Observable` | 状態変更の通知 |
| **Strategy** | protocol + DI | ソートアルゴリズム、バリデーション |
| **Command** | closure or enum + associated values | Undo/Redo、TCA の Action |
| **State** | enum + switch | 画面状態（loading/loaded/error） |
| **Coordinator** | class + NavigationPath | 画面遷移管理 |
| **Iterator** | `Sequence` / `IteratorProtocol` | カスタムコレクション |
| **Template Method** | protocol + default extension | 共通処理フローの定義 |

```swift
// State パターン (enum ベース)
enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case error(AppError)
}

@Observable
class SearchViewModel {
    var state: ViewState<[Song]> = .idle
    
    func search(_ query: String) async {
        state = .loading
        do {
            let results = try await searchService.search(query)
            state = .loaded(results)
        } catch let error as AppError {
            state = .error(error)
        } catch {
            state = .error(.unknown(error))
        }
    }
}

// Strategy パターン
protocol SortStrategy {
    func sort(_ songs: [Song]) -> [Song]
}
struct TitleSort: SortStrategy {
    func sort(_ songs: [Song]) -> [Song] { songs.sorted(by: { $0.title < $1.title }) }
}
struct DateSort: SortStrategy {
    func sort(_ songs: [Song]) -> [Song] { songs.sorted(by: { $0.addedDate > $1.addedDate }) }
}

// Coordinator パターン
@Observable
class AppCoordinator {
    var path = NavigationPath()
    
    func showPlayer(song: Song) {
        path.append(Route.player(song))
    }
    
    func showSettings() {
        path.append(Route.settings)
    }
    
    enum Route: Hashable {
        case player(Song)
        case settings
        case playlist(Playlist)
    }
}
```

---

## 14. NightCorePlayer への適用分析

現在の NightCorePlayer プロジェクトが採用しているパターンと、本レポートの推奨事項との対応:

### 現状の評価

| カテゴリ | 現在の実装 | 評価 | 備考 |
|---------|----------|------|------|
| アーキテクチャ | MVVM + Service Layer | ✅ 適切 | 規模に合った選択 |
| 状態管理 | `@Observable` + Combine (Service 層) | ✅ 適切 | Service → VM は Combine、VM → View は Observation |
| DI | Constructor Injection + Composition Root | ✅ 適切 | DI コンテナ不使用は正しい |
| Protocol 設計 | Protocol + Impl パターン | ✅ 適切 | テスタブルな設計 |
| ディレクトリ構造 | Feature-based + Layer | ✅ 適切 | Domain/Data/Core/Features の分離 |
| エラー処理 | AppError enum + throws chain | ✅ 適切 | Repository → Service → VM → View |
| テスト | Mock + Swift Testing | ✅ 適切 | 119 テストケース |

### 改善の余地（将来的な検討事項）

| 項目 | 現状 | 改善案 | 優先度 |
|------|------|-------|-------|
| `any` / `some` の明示 | protocol を暗黙的に existential として使用 | `any MusicPlayerService` を明示（Swift 6 対応） | 中 |
| ViewState enum | VM ごとに個別管理 | 共通 `ViewState<T>` enum の導入 | 低 |
| Coordinator | NavigationPath をView 内で管理 | AppCoordinator パターンの導入（規模増大時） | 低 |
| Sendable 準拠 | 未対応 | Model struct への Sendable 準拠（Swift 6 対応） | 中 |
| Use Case 層 | VM が直接 Service を呼ぶ | Use Case の導入（ビジネスロジック複雑化時） | 低 |

---

## 15. 参考文献

### 公式ドキュメント
- [^1]: [Apple: Protocols - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [^4]: [Apple: Using existentials and generics](https://developer.apple.com/tutorials/app-dev-training/using-existentials-and-generics)
- [^12]: [Apple: Organizing your code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [^14]: [Apple: Concurrency - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [^16]: [Apple: Observation Framework](https://developer.apple.com/documentation/Observation)

### アーキテクチャ・設計
- [^6]: [7span: MVVM vs Clean Architecture vs TCA](https://7span.com/blog/mvvm-vs-clean-architecture-vs-tca)
- [^7]: [ICertGlobal: Choosing the Best Architecture for SwiftUI Apps](https://www.icertglobal.com/community/choosing-the-best-architecture-for-swiftui-apps)
- [^8]: [Netguru: SwiftUI Clean Architecture](https://www.netguru.com/blog/clean-swift-with-swiftui-ios)
- [^9]: [CMARIX: Clean Architecture iOS](https://www.cmarix.com/blog/clean-architecture-ios/)
- [^10]: [Software Patterns Lexicon: Hexagonal Architecture in Swift](https://softwarepatternslexicon.com/swift/architectural-patterns-in-swift/hexagonal-architecture-in-swift/)
- [^11]: [GeeksforGeeks: Hexagonal Architecture System Design](https://www.geeksforgeeks.org/system-design/hexagonal-architecture-system-design/)
- [^18]: [Software Patterns Lexicon: Swift Design Patterns](https://softwarepatternslexicon.com/swift/)

### Protocol & 型システム
- [^2]: [Toptal: Protocol-oriented Programming in Swift](https://www.toptal.com/developers/swift/introduction-protocol-oriented-programming-swift)
- [^3]: [Swift Anytime: Protocol Oriented Programming in Swift](https://www.swiftanytime.com/blog/protocol-oriented-programming-in-swift)
- [^5]: [Swift Forums: Relative Performance of Existential Any](https://forums.swift.org/t/relative-performance-of-existential-any/77299)

### Observation & Concurrency
- [^15]: [HowToInSwift: SwiftUI Concurrency Deep Dive 2025](https://howtoinswift.tech/blog/2025/SwiftUI-Concurrency-Deep-Dive-Mastering-Structured-Concurrency-with-Swift-6-2025-Edition)
- [^17]: [Donny Wals: @Observable in SwiftUI explained](https://www.donnywals.com/observable-in-swiftui-explained/)

### モジュール化
- [^13]: [NimbleHQ: Modularizing iOS Applications with SwiftUI and SPM](https://nimblehq.co/blog/modern-approach-modularize-ios-swiftui-spm)

---

## Confidence Assessment

| カテゴリ | 信頼度 | 根拠 |
|---------|-------|------|
| Protocol / POP | 🟢 高 | Apple 公式ドキュメント + Swift Book に基づく |
| any / some / Generics | 🟢 高 | Swift Evolution proposals + 公式チュートリアル |
| アーキテクチャ比較 | 🟡 中〜高 | 複数の独立した情報源で一致。ただし「最適解」は文脈依存 |
| Hexagonal Architecture in Swift | 🟡 中 | 概念は確立。Swift 固有の大規模実例は限定的 |
| @Observable | 🟢 高 | Apple WWDC + 公式ドキュメント。本プロジェクトで実証済み |
| Swift Concurrency | 🟢 高 | Swift Book + Apple チュートリアル |
| NightCorePlayer 分析 | 🟢 高 | 実コードを直接検証済み |

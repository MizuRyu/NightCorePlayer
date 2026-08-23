# ADR 002: 速度とピッチの独立制御は公開 API では実現しない

> Status: Accepted
> Date: 2026-08-23

## Context

Nightcore 再生は「速度を上げてピッチも一緒に上がる」体験が前提だが、将来的な拡張として「速度だけ上げてピッチは変えない（pitch-independent / time-stretch）」再生の要望が想定される。

これを実装するには、アプリ側で PCM サンプルを取得し、time-stretch アルゴリズム（`AVAudioUnitTimePitch` 等）を通して自前で再生する必要がある。今回の調査で次が分かった。

- MusicKit は Apple Music カタログの `Song` に対して raw audio データを公開しない
- Apple Music の `Song.assetURL` は常に `nil`（ローカルファイルとして曲を持たない仕組みのため、`AVAudioPlayer` / `AVAudioEngine` に直接読み込めない）
- 再生は `MPMusicPlayerController`（`MPMusicPlayerApplicationController` / `MPMusicPlayerControllerSystemMusicPlayer`）経由に限定され、内部の PCM バッファに tap する手段が公開されていない
- `MPMusicPlayerController.currentPlaybackRate` は速度を変えるとピッチも連動して変わる。これはこの API の仕様であり、アプリ側で切り離せない

## Decision

速度とピッチの独立制御は、Apple Music 再生を前提とする限り**公開 API では実現不可能**と判断し、実装しない。

再生速度の制御は `MPMusicPlayerController.currentPlaybackRate` を上限とする。ピッチが速度に連動して変わることを Nightcore 再生の仕様として受け入れる。

## Scope

対象:

- Apple Music カタログの `Song` 再生（このアプリの唯一の再生経路）

対象外:

- ローカルファイル / ユーザーが保有する音源の再生（このアプリではそもそも扱わない）
- Apple Music 以外のソースからの音声取得

## Consequences

### Pros

- 実装がシンプルなまま維持できる（`MPMusicPlayerController` 単体で完結）
- FairPlay DRM を回避する独自の音声取得経路を持たない。規約違反・審査リスクを避けられる

### Cons

- 「速度だけ変えてピッチはそのまま」という一部ユーザーの要望には応えられない
- 差別化の軸を pitch-independent 再生に置けない。Pro 版の価値提案は、速度制御そのもの（UI・プリセット・上限緩和等）や残高無制限化に寄せる必要がある

## Rejected Alternative

### 1. `AVAudioEngine` + 自前 time-stretch

`AVAudioUnitTimePitch` で速度とピッチを分離制御する案。

却下理由:

- Apple Music の `Song` から PCM を取得する公開手段がない（`assetURL` が `nil`）
- FairPlay で保護された音声を非公式に取り出す実装は利用規約違反になる

### 2. サードパーティ音声処理ライブラリの併用

却下理由:

- 前提となる PCM 取得自体ができないため、ライブラリを足しても解決しない

## Implementation Notes

- `currentPlaybackRate` の範囲は `Constants.MusicPlayer.minPlaybackRate`（0.5）〜`maxPlaybackRate`（3.0）に制限している（`MPMusicPlayerAdapter`）
- 将来 Apple が MusicKit で raw audio access や pitch 制御 API を公開した場合は、この ADR を Superseded にして再検討する

## Acceptance Criteria

- 速度変更時にピッチが連動して変化することを仕様として README / UI 文言に矛盾なく反映している
- 「ピッチ固定」を謳う UI・マーケティング文言が存在しない

# ADR 001: 再生中のキュー更新は staged にし、曲切替境界で反映する

> Status: Proposed
> Date: 2026-03-29

## Context

NightCorePlayer では、再生中に次のようなキュー更新が発生する。

- `shuffle` の ON / OFF
- 再生キュー内の手動並び替え
- 将来的な「次曲以降のみ変更」系の操作

現在の `MPMusicPlayerController` ベース実装では、これらを即時に実プレイヤーへ反映するには `setQueue` が必要になる。
しかし `setQueue -> prepareToPlay -> play/seek` は、実機上で一瞬の無音や停止を起こしやすい。

今回の調査で次が分かった。

- 即時反映を優先すると、再生中の音切れが起きやすい
- 無音化のために再同期を遅延すると、自然な曲送りや `currentIndex` 同期を壊しやすい
- 一方で、音楽アプリとして最優先すべきなのは「現在再生中の曲を切らない」ことである

## Decision

再生中のキュー更新は、即時に実プレイヤーへ反映しない。
代わりに app 側で **staged queue** として保持し、次の境界で確定反映する。

境界は次に固定する。

- ユーザーが `next` / `previous` を押したとき
- 自然な曲切替が起きた直後
- `playNow` / `playNextAndPlay` / `setQueue` など、もともと明示的に queue 再構築が必要な操作時

再生中の現在曲は維持し、staged queue は「次曲以降」にだけ効かせる。

## Scope

この ADR の対象は、再生中に upcoming queue を変更する操作のみ。

対象:

- `shuffle`
- 手動 reorder
- 将来の upcoming-only queue mutations

対象外:

- `repeat one` の現在曲ループ
- `playNow` のように現在曲自体を切り替える操作
- Apple Music backend 変更

## Intended Behavior

再生中に queue 更新が発生したときの仕様は次にする。

1. UI 上のキュー順は即時に更新する
2. 実プレイヤーの内部 queue はその場では更新しない
3. 現在再生中の曲は切らない
4. 次の境界で staged queue を実プレイヤーへ反映する

このため、短時間だけ次のズレを許容する。

- View 上の `次に再生`
- 実際の player が保持する internal queue

ただし、現在曲は常に一致していなければならない。

## Consequences

### Pros

- `shuffle` や reorder 操作時の音切れを避けやすい
- 現在再生中の曲を守れる
- `shuffle` と手動 reorder を同じモデルで扱える

### Cons

- UI queue と実プレイヤー queue が一時的にズレる
- `trackChanged` と `currentIndex` 同期の設計が重要になる
- 「押した瞬間から厳密に upcoming が変わる」わけではない

## Rejected Alternative

### 1. 即時反映

再生中の queue 更新ごとに `setQueue` する案。

却下理由:

- 実機で一瞬停止しやすい
- ユーザー体験が悪い

### 2. 完全な native queue 編集

再生中の Apple Music queue を無停止で任意位置 move する案。

却下理由:

- 現在の `MPMusicPlayerController` 公開 API では現実的ではない
- `setQueue` を避けて同等制御する手段がない

## Implementation Notes

実装時は次を守る。

- `trackChanged()` は観測と同期に徹し、自然な曲進行を止めない
- staged queue の適用は境界時だけに限定する
- `repeat` は staged queue に混ぜず、ネイティブ repeat を優先する
- reorder 中でも現在曲の index は壊さない

## Acceptance Criteria

- 再生中に `shuffle` を押しても、その瞬間に音が切れない
- 再生中に upcoming queue を並び替えても、その瞬間に音が切れない
- 自然な曲送りが止まらない
- 境界到達後は UI queue と実プレイヤー queue が再び一致する


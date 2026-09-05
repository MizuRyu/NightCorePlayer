import Foundation
import NightCoreDomain

// MARK: - Auto-Play Recommendations

extension MusicPlayerServiceImpl {
    func fetchAndPlayRecommendations() async {
        guard let musicKitService, !isFetchingRecommendations else { return }
        isFetchingRecommendations = true
        defer { isFetchingRecommendations = false }

        do {
            // 履歴曲は除外しない: レコメンドの C 枠 (よく聴く曲) は履歴由来が本体のため。
            // キューに既にある曲だけ重複を避ける
            let existingIDs = Set(queue.items.map { $0.id })

            let recommendations = try await musicKitService.fetchPersonalRecommendations(
                history: historyManager.history,
                limit: Constants.Recommendation.defaultLimit
            )
            let filtered = recommendations.filter { !existingIDs.contains($0.id) }
            guard !filtered.isEmpty else { return }

            // 現在のキューに推薦楽曲を追加して再生
            var newQueue = queue.items
            newQueue.append(contentsOf: filtered)
            let nextIndex = queue.currentIndex + 1
            let action = await queue.setQueue(newQueue, startAt: nextIndex)
            await handleQueueAction(action)
        } catch {
            logger.error("Auto-play recommendation fetch error: \(error.localizedDescription)")
        }
    }

    func checkAutoPlayOnQueueEnd() {
        guard isAutoPlayEnabled,
              repeatMode == .none,
              !queue.isEmpty,
              queue.currentIndex >= queue.items.count - 1,
              player.playbackState != .playing
        else { return }

        Task { [weak self] in
            await self?.fetchAndPlayRecommendations()
        }
    }
}

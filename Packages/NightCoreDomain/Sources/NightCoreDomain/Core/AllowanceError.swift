import Foundation

/// 残高ドメインのエラー。ユーザー向けの文言はアプリ層で AppError へ写す
public enum AllowanceError: Error, Equatable, Sendable {
    case dailyRewardLimitReached
}

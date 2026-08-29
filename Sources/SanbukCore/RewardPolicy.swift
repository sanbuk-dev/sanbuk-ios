import Foundation

/// Whether a reward has been earned.
///
/// The one format where the person chose to see the ad, in exchange for
/// something. That changes two things:
///
/// - none of `FullscreenPolicy`'s gates apply. Refusing an ad somebody asked
///   for, because they have already seen two, is refusing them their coins;
/// - the bar is duration, not viewability. A rewarded ad is full screen by
///   definition, so "was it visible" is not the question; "did they stay" is.
///
/// Earning is decided here rather than in the publisher's app so that "did
/// this person earn it" has one answer on every platform. Leaving early earns
/// nothing, which has to be said before they start — the integrator's job.
///
/// Elapsed milliseconds from a monotonic source: a reward measured on the wall
/// clock is a reward anyone can collect by winding the device forward.
public final class RewardPolicy {

    /// Long enough to be worth an advertiser's money, short enough that a
    /// player does not abandon it — where the format settled years ago.
    public static let requiredMilliseconds: Int64 = 15_000

    private let required: Int64
    private var earned = false

    public init(requiredMilliseconds: Int64 = RewardPolicy.requiredMilliseconds) {
        self.required = requiredMilliseconds
    }

    /// - Returns: true the first time the requirement is met, false ever after.
    @discardableResult
    public func onProgress(shownAt: Int64, now: Int64) -> Bool {
        if earned { return false }
        guard now - shownAt >= required else { return false }
        earned = true
        return true
    }

    public var hasEarned: Bool { earned }

    public func millisecondsRemaining(shownAt: Int64, now: Int64) -> Int64 {
        max(0, required - (now - shownAt))
    }
}

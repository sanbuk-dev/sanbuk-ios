import Foundation

/// When a full-screen ad may interrupt someone.
///
/// An interstitial is the most profitable format and the fastest way to lose a
/// publisher. It is natural in a game — between two levels, nobody minds — and
/// an ambush in a utility app. The difference is almost never the creative; it
/// is when it appeared. So the rules live here, in shared code with tests,
/// rather than being left to whoever integrates.
///
/// Rewarded is deliberately gated by none of this: the person asked for it.
/// See `RewardPolicy`.
///
/// Every time argument is elapsed milliseconds from a monotonic source, not a
/// date. A timer someone can wind forward is a close gate they can skip.
public final class FullscreenPolicy {

    public static let minimumGapMilliseconds: Int64 = 60_000
    public static let maximumPerSession = 3
    /// A cold start belongs to the app, not to us.
    public static let quietAfterLaunchMilliseconds: Int64 = 30_000
    public static let closeAfterMilliseconds: Int64 = 5_000

    /// Why a full-screen ad was not shown — the answer an integrator needs.
    public enum Refusal: String, Sendable {
        case tooSoonAfterLaunch = "too_soon_after_launch"
        case tooSoonAfterLast = "too_soon_after_last"
        case sessionLimit = "session_limit"
    }

    private let minimumGap: Int64
    private let maximumPerSession: Int
    private let quietAfterLaunch: Int64
    private let closeAfter: Int64

    private var shownThisSession = 0
    private var lastShownAt: Int64?

    public init(
        minimumGapMilliseconds: Int64 = FullscreenPolicy.minimumGapMilliseconds,
        maximumPerSession: Int = FullscreenPolicy.maximumPerSession,
        quietAfterLaunchMilliseconds: Int64 = FullscreenPolicy.quietAfterLaunchMilliseconds,
        closeAfterMilliseconds: Int64 = FullscreenPolicy.closeAfterMilliseconds
    ) {
        self.minimumGap = minimumGapMilliseconds
        self.maximumPerSession = maximumPerSession
        self.quietAfterLaunch = quietAfterLaunchMilliseconds
        self.closeAfter = closeAfterMilliseconds
    }

    /// - Parameter sessionStartedAt: when the app process began, not when the
    ///   SDK was initialised — a publisher who initialises us late would
    ///   otherwise get a quiet window that has already elapsed.
    public func refusal(now: Int64, sessionStartedAt: Int64) -> Refusal? {
        if now - sessionStartedAt < quietAfterLaunch { return .tooSoonAfterLaunch }
        if shownThisSession >= maximumPerSession { return .sessionLimit }
        if let last = lastShownAt, now - last < minimumGap { return .tooSoonAfterLast }
        return nil
    }

    public func mayShow(now: Int64, sessionStartedAt: Int64) -> Bool {
        refusal(now: now, sessionStartedAt: sessionStartedAt) == nil
    }

    /// Call when one is actually put on screen, not when it is loaded.
    public func recordShown(now: Int64) {
        shownThisSession += 1
        lastShownAt = now
    }

    /// Whether the close control has earned its place on screen yet.
    public func closeAllowed(shownAt: Int64, now: Int64) -> Bool {
        now - shownAt >= closeAfter
    }

    public func millisecondsUntilClose(shownAt: Int64, now: Int64) -> Int64 {
        max(0, closeAfter - (now - shownAt))
    }
}

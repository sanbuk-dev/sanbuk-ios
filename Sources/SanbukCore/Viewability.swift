import Foundation

/// When a view has actually been seen.
///
/// An impression reported the moment a banner is attached is not an
/// impression: it may be off screen, behind a keyboard, in a list row nobody
/// scrolled to. The MRC bar is the industry's answer — at least half the
/// pixels, for at least one continuous second — and meeting it is what makes
/// the number an advertiser will pay against and a publisher's quality score
/// honest.
///
/// A pure state machine on purpose: the iOS layer feeds it samples from a
/// display link, the Android layer from a draw listener, and both get
/// identical behaviour. It never reports twice — one drawn ad is one view.
public final class Viewability {

    public static let mrcFraction = 0.5
    public static let mrcMilliseconds: Int64 = 1_000

    private let minimumVisibleFraction: Double
    private let requiredMilliseconds: Int64
    private var continuousSince: Int64?
    private var counted = false

    public init(
        minimumVisibleFraction: Double = Viewability.mrcFraction,
        requiredMilliseconds: Int64 = Viewability.mrcMilliseconds
    ) {
        self.minimumVisibleFraction = minimumVisibleFraction
        self.requiredMilliseconds = requiredMilliseconds
    }

    /// Feed one observation.
    ///
    /// - Parameters:
    ///   - visibleFraction: 0…1 of the ad's own area currently on screen.
    ///   - nowMilliseconds: elapsed milliseconds from a monotonic source. Not a
    ///     date: a clock that can jump backwards is a duration that never
    ///     finishes, and one that can jump forwards is a view nobody had.
    /// - Returns: true exactly once, on the sample that completes the bar.
    @discardableResult
    public func sample(visibleFraction: Double, nowMilliseconds: Int64) -> Bool {
        if counted { return false }

        guard visibleFraction >= minimumVisibleFraction else {
            // Interrupted. The clock restarts rather than accumulating: half a
            // second twice is not a second of attention.
            continuousSince = nil
            return false
        }

        let since = continuousSince ?? {
            continuousSince = nowMilliseconds
            return nowMilliseconds
        }()

        guard nowMilliseconds - since >= requiredMilliseconds else { return false }

        counted = true
        return true
    }

    public var hasCounted: Bool { counted }
}

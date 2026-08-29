import Foundation

/// One ad, described rather than drawn.
///
/// The server never sends markup — no HTML, no ready-made banner, no hidden
/// web view. That is the product decision behind this SDK: the publisher's app
/// draws these fields with its own fonts, colours and animation, and the ad
/// looks like part of the app. A network that ships a rendered banner cannot
/// offer that. Our own renderer is a convenience over the same data.
public struct Ad: Sendable, Equatable {
    /// The tracking link behind this decision; every URL below hangs off it.
    public let linkCode: String
    /// banner | native | interstitial | rewarded — chosen by the publisher when
    /// the slot was registered, never by the app.
    public let format: String
    public let campaignID: String
    public let creativeID: String
    public let headline: String?
    public let body: String?
    public let cta: String
    /// The words on the button, already resolved — a custom call to action is
    /// the advertiser's own wording.
    public let ctaLabel: String
    public let brandColor: String?
    public let imageURL: String?
    public let logoURL: String?
    /// Open this. Never a destination resolved by following it: the redirect
    /// IS the click.
    public let clickURL: String
    public let impressionURL: String
    /// How long the visitor's per-campaign view counters stay relevant.
    public let frequencyWindowHours: Int
}

/// What came back.
///
/// An empty answer is a normal outcome, not a failure — the publisher's screen
/// simply shows nothing — so it is a value rather than a thrown error.
public enum AdResponse: Sendable, Equatable {
    case filled(Ad)
    /// - Parameters:
    ///   - reason: the server's own word for why, when an operator has
    ///     diagnostics on. Nil in production, always.
    ///   - kill: stop asking until this build is updated. Unlike `reason` this
    ///     is not a diagnostic: it is the only way to retire code already on
    ///     people's phones, so it arrives in production too.
    ///   - minimumSDK: the version this framework must reach, when that is why.
    case empty(reason: String? = nil, kill: Bool = false, minimumSDK: String? = nil)
}

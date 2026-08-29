import Foundation

/// One ask for an ad, as the edge expects it.
///
/// Everything a native SDK knows and a browser does not. Two fields carry more
/// weight than their size suggests:
///
/// - `platform` is what keeps app campaigns in app inventory. The server reads
///   the browser user agent to decide whether a visitor could install an app;
///   a native SDK has no user agent, so without this the campaigns meant for
///   app inventory are filtered out of it.
/// - `installID` is the rate-limit key. Iranian carriers put tens of thousands
///   of subscribers behind one address, so an IP means very little; a caller
///   that names its install is limited by that name instead.
public struct AdRequest: Sendable, Equatable {
    public let placementCode: String
    public let mediaCode: String
    public let installID: String
    /// Framework-tagged, e.g. `ios-0.1.0` — so one bad shell can be retired alone.
    public let sdkVersion: String
    public let platform: Platform
    public let bundleIdentifier: String?
    public let appVersion: String?
    public let osVersion: String?
    public let connection: Connection
    public let render: RenderMode
    /// The visitor's own per-campaign view counts, `id:count` pairs.
    public let frequency: String?

    public init(
        placementCode: String,
        mediaCode: String,
        installID: String,
        sdkVersion: String,
        platform: Platform = .ios,
        bundleIdentifier: String? = nil,
        appVersion: String? = nil,
        osVersion: String? = nil,
        connection: Connection = .unknown,
        render: RenderMode = .standard,
        frequency: String? = nil
    ) {
        self.placementCode = placementCode
        self.mediaCode = mediaCode
        self.installID = installID
        self.sdkVersion = sdkVersion
        self.platform = platform
        self.bundleIdentifier = bundleIdentifier
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.connection = connection
        self.render = render
        self.frequency = frequency
    }
}

import Foundation

/// Builds the edge URL for one ad request. Pure string work, no I/O.
public enum ServeURL {

    /// - Parameter base: the tracker origin, e.g. `https://t.sanbuk.com`. A
    ///   trailing slash is tolerated because publishers paste these by hand.
    public static func build(base: String, request: AdRequest) -> String {
        var origin = base
        while origin.hasSuffix("/") { origin.removeLast() }

        var pairs: [(String, String)] = [
            ("placement", request.placementCode),
            ("media", request.mediaCode),
            ("platform", request.platform.rawValue),
            ("install_id", request.installID),
            ("sdk", request.sdkVersion),
            ("render", request.render.rawValue),
        ]

        // The app's own identifier, matched against the media the publisher
        // registered — the app world's answer to the website crawler.
        if let bundle = request.bundleIdentifier { pairs.append(("package", bundle)) }
        if let version = request.appVersion { pairs.append(("app_version", version)) }
        if let os = request.osVersion { pairs.append(("os", os)) }
        if request.connection != .unknown { pairs.append(("conn", request.connection.rawValue)) }
        // An empty counter string is noise on the wire, not information.
        if let frequency = request.frequency, !frequency.isEmpty { pairs.append(("fc", frequency)) }

        let query = pairs
            .map { "\($0.0)=\(encode($0.1))" }
            .joined(separator: "&")

        return "\(origin)/ad?\(query)"
    }

    /// Percent-encoding for a query VALUE: `&`, `=`, `+` and the rest have to
    /// survive as data, or a media code with an ampersand in it splits the
    /// query and the request means something else entirely.
    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

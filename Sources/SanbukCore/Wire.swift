import Foundation

/// The vocabulary the server and every shell agree on.
///
/// These strings are a published contract (`/ad` in the tracking spec): once a
/// build carrying them is on phones it can never be renamed, because a version
/// from two years ago still has to be understood. Hence the explicit raw
/// values rather than relying on case names.
public enum Platform: String, Sendable {
    case android
    case ios
    case web
}

/// Who draws the ad, and therefore who counts the view.
///
/// `standard` means our own renderer drew it and its gate decided the view was
/// real. `custom` means the publisher's app drew it and calls
/// `recordImpression()` itself — which the server cannot verify, and that is
/// exactly why it is declared rather than assumed.
public enum RenderMode: String, Sendable {
    case standard = "default"
    case custom
}

/// Connection class — a matching and anti-fraud signal, never a gate.
public enum Connection: String, Sendable {
    case wifi
    case cellular
    case unknown
}

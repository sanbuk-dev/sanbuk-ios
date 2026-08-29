import Foundation

/// Turns the impression URL the server handed us into one this install can
/// safely retry.
///
/// The `eid` is the whole point. The platform counts impressions into a daily
/// counter with no event identity of its own, which is safe on the web — a
/// browser either sends the pixel or it does not, and nothing retries — and
/// unsafe here, because an offline queue exists precisely to send again. Money
/// hangs off that number: a per-impression publisher commission is paid on it,
/// and a new media spends its trial allowance from it.
///
/// The id is minted when the view HAPPENS, not when it is sent. Two attempts
/// at the same view must carry the same id, or the server's guard has nothing
/// to recognise.
public enum ImpressionURL {

    public static func build(impressionURL: String, eventID: String, installID: String) -> String {
        let separator = impressionURL.contains("?") ? "&" : "?"
        return "\(impressionURL)\(separator)eid=\(encode(eventID))&install_id=\(encode(installID))"
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

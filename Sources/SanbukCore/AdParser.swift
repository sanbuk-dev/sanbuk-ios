import Foundation

/// Reads the edge's answer.
///
/// Never throws. A malformed body, a field that changed type, a truncated
/// response — all of them become an empty answer, because the alternative is
/// an error crossing into a publisher's app for the sake of an advertisement.
/// The reason names the parse failure so a debug build can still see it.
public enum AdParser {

    public static let defaultFrequencyWindowHours = 24

    public static func parse(_ body: String) -> AdResponse {
        guard
            let data = body.data(using: .utf8),
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return .empty(reason: "unreadable_response")
        }

        let reason = optionalString(root["reason"])
        let kill = root["kill"] as? Bool ?? false
        let minimum = optionalString(root["min_sdk"])

        // `ad: null` is the documented empty shape, and a missing key is the
        // same outcome to a caller.
        guard let ad = root["ad"] as? [String: Any] else {
            return .empty(reason: reason, kill: kill, minimumSDK: minimum)
        }

        // A field the server nulled must read as absence, never as the text
        // "null": a link code of "null" is a 404 nobody can explain.
        guard
            let code = optionalString(ad["code"]),
            let clickURL = optionalString(ad["click_url"]),
            let impressionURL = optionalString(ad["impression_url"])
        else {
            return .empty(reason: "malformed_ad", kill: kill, minimumSDK: minimum)
        }

        return .filled(
            Ad(
                linkCode: code,
                format: optionalString(ad["format"]) ?? "banner",
                campaignID: optionalString(ad["campaign_id"]) ?? "",
                creativeID: optionalString(ad["creative_id"]) ?? "",
                headline: optionalString(ad["headline"]),
                body: optionalString(ad["description"]),
                cta: optionalString(ad["cta"]) ?? "view",
                ctaLabel: optionalString(ad["cta_label"]) ?? "",
                brandColor: optionalString(ad["brand_color"]),
                imageURL: optionalString(ad["image_url"]),
                logoURL: optionalString(ad["logo_url"]),
                clickURL: clickURL,
                impressionURL: impressionURL,
                // A missing window is not a reason to stop capping; it is a
                // reason to fall back to the shipped default.
                frequencyWindowHours: (ad["fc_hours"] as? Int) ?? defaultFrequencyWindowHours
            )
        )
    }

    /// JSON null, a wrong type and an empty string are all absence here.
    private static func optionalString(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
}

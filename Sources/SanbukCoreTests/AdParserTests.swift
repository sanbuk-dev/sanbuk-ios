import Foundation
import SanbukCore

func runAdParserTests() {
    Check.test("parser reads a served ad") {
        let body = """
        {"ad":{"code":"abc123","format":"native","campaign_id":"cmp-1","creative_id":"crv-1",
        "headline":"تخفیف پاییزه","description":"تا ۵۰ درصد","cta":"buy","cta_label":"خرید کنید",
        "brand_color":"#060ADB","image_url":"https://cdn/i.png","logo_url":null,
        "click_url":"https://t.sanbuk.com/c/abc123","impression_url":"https://t.sanbuk.com/i/abc123",
        "fc_hours":12}}
        """
        guard case let .filled(ad) = AdParser.parse(body) else {
            return Check.expect(false, "expected an ad")
        }
        Check.equal(ad.linkCode, "abc123")
        Check.equal(ad.format, "native")
        Check.equal(ad.headline, "تخفیف پاییزه")
        Check.equal(ad.ctaLabel, "خرید کنید")
        Check.equal(ad.frequencyWindowHours, 12)
        Check.nilValue(ad.logoURL, "an explicit JSON null is absence, not the string \"null\"")
    }

    Check.test("an empty slot is a normal answer") {
        guard case let .empty(reason, kill, _) = AdParser.parse(#"{"ad":null}"#) else {
            return Check.expect(false, "expected an empty answer")
        }
        Check.nilValue(reason, "production sends no reason and none is invented")
        Check.expect(!kill)
    }

    Check.test("an empty slot can name the rule that emptied it") {
        guard case let .empty(reason, _, _) = AdParser.parse(#"{"ad":null,"reason":"advertiser_cannot_pay"}"#) else {
            return Check.expect(false, "expected an empty answer")
        }
        Check.equal(reason, "advertiser_cannot_pay")
    }

    // The only way to retire a build already on people's phones — so unlike
    // the reason, it has to survive production, where diagnostics are off.
    Check.test("a stopped build is told so, without diagnostics") {
        guard case let .empty(reason, kill, minimum) =
            AdParser.parse(#"{"ad":null,"kill":true,"min_sdk":"1.2.0"}"#)
        else { return Check.expect(false, "expected an empty answer") }
        Check.expect(kill)
        Check.equal(minimum, "1.2.0")
        Check.nilValue(reason, "the instruction arrives without diagnostics")
    }

    Check.test("parser falls back to the shipped window when the server names none") {
        guard case let .filled(ad) =
            AdParser.parse(#"{"ad":{"code":"a","click_url":"https://c","impression_url":"https://i"}}"#)
        else { return Check.expect(false, "expected an ad") }
        Check.equal(ad.frequencyWindowHours, AdParser.defaultFrequencyWindowHours)
        Check.equal(ad.format, "banner", "an unnamed format is the common one, not a failure")
    }

    // The rule the whole SDK stands on: nothing that arrives over the network
    // may fail into a publisher's app for the sake of an advertisement.
    Check.test("no shape of garbage ever fails") {
        for body in [
            "", "not json at all", "{", "[]",
            #"{"ad":"a string where an object belongs"}"#,
            #"{"ad":{}}"#,
            #"{"ad":{"code":"a"}}"#,
            #"{"ad":{"code":"a","click_url":"https://c"}}"#,
        ] {
            guard case .empty = AdParser.parse(body) else {
                return Check.expect(false, "expected an empty answer for: \(body)")
            }
        }
        guard case .filled = AdParser.parse(
            #"{"ad":{"code":"a","click_url":"https://c","impression_url":"https://i","fc_hours":"soon"}}"#
        ) else { return Check.expect(false, "usable enough to draw") }
    }

    // A field the server nulled must read as absence: a link code of "null" is
    // a 404 nobody can explain, and a headline of "null" ships to a phone.
    Check.test("an explicit null is absence, never the word null") {
        let body = """
        {"ad":{"code":"abc","click_url":"https://c","impression_url":"https://i",
        "format":null,"cta":null,"cta_label":null,"campaign_id":null,"headline":null}}
        """
        guard case let .filled(ad) = AdParser.parse(body) else {
            return Check.expect(false, "expected an ad")
        }
        Check.equal(ad.format, "banner")
        Check.equal(ad.cta, "view")
        Check.equal(ad.ctaLabel, "")
        Check.equal(ad.campaignID, "")
        Check.nilValue(ad.headline)
    }

    Check.test("an ad missing its click url is not drawable") {
        guard case let .empty(reason, _, _) =
            AdParser.parse(#"{"ad":{"code":"a","impression_url":"https://i"}}"#)
        else { return Check.expect(false, "expected an empty answer") }
        Check.equal(reason, "malformed_ad")
    }
}

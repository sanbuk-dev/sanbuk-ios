import Foundation
import SanbukCore

func runServeURLTests() {
    let request = AdRequest(
        placementCode: "plc123",
        mediaCode: "med456",
        installID: "8f14e45f-ceea-467a-9f1f-2b1c0b2d3e4a",
        sdkVersion: "ios-0.1.0",
        bundleIdentifier: "ir.charsoo.app",
        appVersion: "4.1.3",
        osVersion: "17.4",
        connection: .wifi
    )

    Check.test("serve url carries every field the edge reads") {
        let url = ServeURL.build(base: "https://t.sanbuk.com", request: request)
        Check.expect(url.hasPrefix("https://t.sanbuk.com/ad?"))
        for expected in [
            "placement=plc123", "media=med456", "platform=ios",
            "install_id=8f14e45f-ceea-467a-9f1f-2b1c0b2d3e4a", "sdk=ios-0.1.0",
            "render=default", "package=ir.charsoo.app", "app_version=4.1.3",
            "os=17.4", "conn=wifi",
        ] {
            Check.expect(url.contains(expected), "missing \(expected)")
        }
    }

    // The one field that decides whether app campaigns reach app inventory at
    // all: the server believes it over the user agent, and a native SDK has no
    // user agent to fall back to.
    Check.test("serve url always names its platform") {
        Check.expect(ServeURL.build(base: "https://t.sanbuk.com", request: request).contains("platform=ios"))
    }

    Check.test("serve url leaves out what it does not know") {
        let bare = AdRequest(
            placementCode: "plc123", mediaCode: "med456",
            installID: "install-1", sdkVersion: "ios-0.1.0"
        )
        let url = ServeURL.build(base: "https://t.sanbuk.com", request: bare)
        Check.expect(!url.contains("package="))
        Check.expect(!url.contains("app_version="))
        Check.expect(!url.contains("conn="), "an unknown connection is not a value")
        Check.expect(!url.contains("fc="), "an empty counter string is noise, not information")
    }

    Check.test("serve url escapes what publishers actually paste") {
        let odd = AdRequest(
            placementCode: "plc 123", mediaCode: "med&456",
            installID: "install-1", sdkVersion: "ios-0.1.0",
            appVersion: "4.1.3 (beta)"
        )
        let url = ServeURL.build(base: "https://t.sanbuk.com", request: odd)
        Check.expect(url.contains("placement=plc%20123"))
        Check.expect(url.contains("media=med%26456"), "an ampersand must not split the query")
        Check.expect(url.contains("app_version=4.1.3%20%28beta%29"))
    }

    Check.test("serve url tolerates a trailing slash on the origin") {
        Check.equal(
            ServeURL.build(base: "https://t.sanbuk.com/", request: request),
            ServeURL.build(base: "https://t.sanbuk.com", request: request)
        )
    }

    Check.test("serve url sends the frequency counters when there are any") {
        let withCounts = AdRequest(
            placementCode: "plc123", mediaCode: "med456",
            installID: "install-1", sdkVersion: "ios-0.1.0",
            frequency: "cid1:2,cid2:5"
        )
        Check.expect(
            ServeURL.build(base: "https://t.sanbuk.com", request: withCounts).contains("fc=cid1%3A2%2Ccid2%3A5")
        )
    }
}

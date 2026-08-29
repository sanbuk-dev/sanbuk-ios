// swift-tools-version: 5.9
import PackageDescription

// The publisher SDK is two layers on purpose, exactly as on Android
// (Mobile-Publisher-SDK-Design.md §13.2):
//
//   SanbukCore — plain Swift, Foundation only. Everything that is not a pixel:
//                the wire format, the offline queue, the frequency counters,
//                the viewability rule, the interruption rules. No UIKit, so it
//                builds and tests on any Swift toolchain — no Xcode, no
//                simulator — and so the platforms share ONE implementation.
//
//   Sanbuk     — the iOS layer: views, SFSafariViewController, storage.
//                A shell over Core, added when the iOS UI work begins.
//
// A rule that lives in a shell has to be written again for every shell, and
// they update at different speeds, so the copies drift.
//
// The tests are an executable rather than an XCTest target, deliberately.
// XCTest and swift-testing both ship with Xcode, so an XCTest suite cannot run
// on a machine with only the Command Line Tools — nor in a CI image without a
// full Xcode. A core that is Foundation-only should be verifiable anywhere,
// so its tests are too: `swift run sanbuk-core-tests`.
let package = Package(
    name: "Sanbuk",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        .library(name: "SanbukCore", targets: ["SanbukCore"]),
    ],
    targets: [
        .target(name: "SanbukCore"),
        .executableTarget(name: "sanbuk-core-tests", dependencies: ["SanbukCore"], path: "Sources/SanbukCoreTests"),
    ]
)

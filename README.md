# Sanbuk iOS SDK

Official iOS SDK for [Sanbuk](https://sanbuk.com) — publisher ad serving in the CPA model.

**[راهنمای فارسی →](README.fa.md)**

> **Status: core only.** The shared logic is written and tested; the iOS UI layer is not built yet, and nothing is published to CocoaPods or SPM. Iran's mobile market is overwhelmingly Android, so this deliberately follows [sanbuk-android](https://github.com/sanbuk-dev/sanbuk-android) rather than leading it.

```bash
swift build
swift run sanbuk-core-tests
```

---

## What is here

`SanbukCore` — everything that decides anything, in plain Swift over Foundation:

| Piece | Job |
|---|---|
| `ServeURL` | builds the ad request, carrying the full mobile context |
| `AdParser` | reads the reply; no malformed input can fail into the host app |
| `ImpressionQueue` | offline queue, bounded by size and age, deduplicated on event id |
| `ImpressionURL` | adds the `eid` the server recognises a retry by |
| `FrequencyCounters` | counts, prunes on the server's window, survives process death |
| `Viewability` | at least 50% of the pixels for a continuous second (MRC) |
| `FullscreenPolicy` | when an interstitial may interrupt, and when it may be closed |
| `RewardPolicy` | whether a rewarded ad was actually watched |

**109 checks, zero failures.**

## Why the core is separate

The same reason as on Android: a rule that lives in a platform layer has to be written again for every platform, and they update at different speeds, so the copies drift. `SanbukCore` is the one implementation of "what should happen"; the iOS layer will be the one implementation of "how it looks here".

It also means the core builds and tests anywhere a Swift toolchain does.

## Why the tests are an executable

XCTest and swift-testing both arrive with Xcode. A core that depends on nothing but Foundation should be verifiable on a machine with only the Command Line Tools, and in a CI image without a full Xcode — so its tests are a plain executable with a small assertion harness. `swift run sanbuk-core-tests` exits non-zero on failure, which is all a pipeline needs.

When the iOS layer lands and Xcode is in the loop anyway, an XCTest target can sit alongside this. It should not replace it.

## Time is elapsed, never a date

Every policy takes milliseconds from a monotonic source, not a wall clock. A clock that jumps backwards on an NTP correction is a duration that never finishes; one that jumps forwards is a reward anyone can collect by winding the device on fifteen seconds. Pass `DispatchTime`/`CACurrentMediaTime`-derived values, never `Date()`.

## Five rules this SDK is built on

**1. Never crash, never die.** No error from this SDK may reach the host app. The worst allowed outcome is an empty box.

**2. No I/O on the main thread.** A hang during launch is the fastest way to be removed.

**3. Decisions stay on the server.** Matching, pacing, frequency caps, budgets — all server-side. A version shipped to phones is frozen for months; any rule hardened here lives with us for years. Honour `kill` in the reply: it is how a bad build is retired.

**4. Clicks open a real browser.** `SFSafariViewController`, never `WKWebView`. A separate cookie jar breaks first-party attribution, and in a CPA network that means the publisher did the work and earns nothing.

**5. No advertising identifier.** No IDFA, no ATT prompt. Just a random, resettable install id for frequency capping and rate limiting.

## License

Apache-2.0

import Foundation
import SanbukCore

func runViewabilityTests() {
    Check.test("a view counts after half the pixels for a full second") {
        let rule = Viewability()
        Check.expect(!rule.sample(visibleFraction: 0.6, nowMilliseconds: 0))
        Check.expect(!rule.sample(visibleFraction: 0.6, nowMilliseconds: 500))
        Check.expect(rule.sample(visibleFraction: 0.6, nowMilliseconds: 1_000))
    }

    Check.test("a barely visible ad is not a view") {
        let rule = Viewability()
        Check.expect(!rule.sample(visibleFraction: 0.49, nowMilliseconds: 0))
        Check.expect(!rule.sample(visibleFraction: 0.49, nowMilliseconds: 5_000))
    }

    // Half a second twice is not a second of attention.
    Check.test("scrolling away restarts the clock") {
        let rule = Viewability()
        rule.sample(visibleFraction: 1.0, nowMilliseconds: 0)
        rule.sample(visibleFraction: 0.0, nowMilliseconds: 600)
        rule.sample(visibleFraction: 1.0, nowMilliseconds: 700)
        Check.expect(!rule.sample(visibleFraction: 1.0, nowMilliseconds: 1_400))
        Check.expect(rule.sample(visibleFraction: 1.0, nowMilliseconds: 1_700))
    }

    // One drawn ad is one view, however long the publisher leaves it up.
    Check.test("a view is never reported twice") {
        let rule = Viewability()
        rule.sample(visibleFraction: 1.0, nowMilliseconds: 0)
        Check.expect(rule.sample(visibleFraction: 1.0, nowMilliseconds: 1_000))
        Check.expect(!rule.sample(visibleFraction: 1.0, nowMilliseconds: 2_000))
        Check.expect(!rule.sample(visibleFraction: 1.0, nowMilliseconds: 60_000))
        Check.expect(rule.hasCounted)
    }

    Check.test("a publisher who wants a stricter bar can have one") {
        let rule = Viewability(minimumVisibleFraction: 1.0, requiredMilliseconds: 2_000)
        Check.expect(!rule.sample(visibleFraction: 0.9, nowMilliseconds: 0))
        rule.sample(visibleFraction: 1.0, nowMilliseconds: 0)
        Check.expect(!rule.sample(visibleFraction: 1.0, nowMilliseconds: 1_999))
        Check.expect(rule.sample(visibleFraction: 1.0, nowMilliseconds: 2_000))
    }
}

func runFullscreenPolicyTests() {
    let launch: Int64 = 0

    // An ad before the app has drawn its own first screen reads as "this app
    // is an ad", and it is the most common reason a publisher removes an SDK.
    Check.test("nothing interrupts a cold start") {
        let policy = FullscreenPolicy()
        Check.equal(policy.refusal(now: 10_000, sessionStartedAt: launch), .tooSoonAfterLaunch)
        Check.nilValue(policy.refusal(now: 30_000, sessionStartedAt: launch))
    }

    // Two in a row is not twice the money.
    Check.test("never back to back") {
        let policy = FullscreenPolicy()
        policy.recordShown(now: 60_000)
        Check.equal(policy.refusal(now: 90_000, sessionStartedAt: launch), .tooSoonAfterLast)
        Check.expect(policy.mayShow(now: 121_000, sessionStartedAt: launch))
    }

    Check.test("a session has a ceiling") {
        let policy = FullscreenPolicy()
        var now: Int64 = 60_000
        for index in 0..<FullscreenPolicy.maximumPerSession {
            Check.expect(policy.mayShow(now: now, sessionStartedAt: launch), "show \(index + 1) should be allowed")
            policy.recordShown(now: now)
            now += FullscreenPolicy.minimumGapMilliseconds + 1
        }
        Check.equal(
            policy.refusal(now: now, sessionStartedAt: launch), .sessionLimit,
            "the fourth is worth less than the first and costs far more"
        )
    }

    // Long enough to have been an ad, short enough not to be a hostage situation.
    Check.test("the close control appears after a few seconds") {
        let policy = FullscreenPolicy()
        let shownAt: Int64 = 100_000
        Check.expect(!policy.closeAllowed(shownAt: shownAt, now: shownAt + 4_999))
        Check.expect(policy.closeAllowed(shownAt: shownAt, now: shownAt + 5_000))
        Check.equal(policy.millisecondsUntilClose(shownAt: shownAt, now: shownAt), 5_000)
        Check.equal(policy.millisecondsUntilClose(shownAt: shownAt, now: shownAt + 9_000), 0, "never negative")
    }

    Check.test("a publisher who knows their app can loosen the gaps") {
        let policy = FullscreenPolicy(
            minimumGapMilliseconds: 1_000, maximumPerSession: 10, quietAfterLaunchMilliseconds: 0
        )
        Check.expect(policy.mayShow(now: 0, sessionStartedAt: 0))
        policy.recordShown(now: 0)
        Check.expect(policy.mayShow(now: 1_000, sessionStartedAt: 0))
    }

    // The launch window is measured from the process, not from init().
    Check.test("a late init does not reopen the quiet window") {
        let policy = FullscreenPolicy()
        Check.expect(
            policy.mayShow(now: 100_000, sessionStartedAt: 40_000),
            "the process started 60s ago; when we were initialised is not the question"
        )
    }
}

func runRewardPolicyTests() {
    Check.test("the reward is earned by staying") {
        let policy = RewardPolicy()
        Check.expect(!policy.onProgress(shownAt: 0, now: 14_999))
        Check.expect(policy.onProgress(shownAt: 0, now: 15_000))
    }

    // Leaving early earns nothing — and the person has to be told that first.
    Check.test("closing early earns nothing") {
        let policy = RewardPolicy()
        policy.onProgress(shownAt: 0, now: 3_000)
        Check.expect(!policy.hasEarned)
    }

    // One ad, one reward, however many progress ticks arrive.
    Check.test("the reward fires exactly once") {
        let policy = RewardPolicy()
        Check.expect(policy.onProgress(shownAt: 0, now: 15_000))
        Check.expect(!policy.onProgress(shownAt: 0, now: 16_000))
        Check.expect(!policy.onProgress(shownAt: 0, now: 60_000))
        Check.expect(policy.hasEarned)
    }

    Check.test("the reward can say how much longer") {
        let policy = RewardPolicy()
        Check.equal(policy.millisecondsRemaining(shownAt: 0, now: 0), 15_000)
        Check.equal(policy.millisecondsRemaining(shownAt: 0, now: 10_000), 5_000)
        Check.equal(policy.millisecondsRemaining(shownAt: 0, now: 20_000), 0, "never negative")
    }

    Check.test("a shorter ad can ask for less") {
        Check.expect(RewardPolicy(requiredMilliseconds: 5_000).onProgress(shownAt: 0, now: 5_000))
    }
}

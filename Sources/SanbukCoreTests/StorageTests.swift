import Foundation
import SanbukCore

func runFrequencyCounterTests() {
    Check.test("counters count what this install has seen") {
        let counters = FrequencyCounters.empty()
        counters.record(campaignID: "cmp-1", now: 1_000)
        counters.record(campaignID: "cmp-1", now: 2_000)
        counters.record(campaignID: "cmp-2", now: 2_000)
        Check.equal(counters.count(for: "cmp-1"), 2)
        Check.equal(counters.count(for: "cmp-2"), 1)
        Check.equal(counters.count(for: "never-seen"), 0)
    }

    // On the web these die with the page. An app process lives for days and is
    // then killed without warning; without a round trip through storage every
    // cold start resets the cap and the visitor sees one campaign forever.
    Check.test("counters survive a round trip through storage") {
        let counters = FrequencyCounters.empty()
        counters.record(campaignID: "cmp-1", now: 1_000)
        counters.record(campaignID: "cmp-1", now: 1_500)
        Check.equal(FrequencyCounters.decode(counters.encoded).count(for: "cmp-1"), 2)
    }

    Check.test("counters forget what the window no longer covers") {
        let counters = FrequencyCounters.empty()
        counters.record(campaignID: "old", now: 0)
        counters.record(campaignID: "recent", now: 23 * 3_600_000)
        counters.prune(windowHours: 24, now: 25 * 3_600_000)
        Check.equal(counters.count(for: "old"), 0)
        Check.equal(counters.count(for: "recent"), 1)
    }

    // The server can retune the cap without an SDK release.
    Check.test("a zero window clears the slate") {
        let counters = FrequencyCounters.empty()
        counters.record(campaignID: "cmp-1", now: 1_000)
        counters.prune(windowHours: 0, now: 1_000)
        Check.equal(counters.count(for: "cmp-1"), 0)
    }

    Check.test("counters write the pairs the edge parses") {
        let counters = FrequencyCounters.empty()
        counters.record(campaignID: "cmp-1", now: 1_000)
        counters.record(campaignID: "cmp-1", now: 1_000)
        counters.record(campaignID: "cmp-2", now: 1_000)
        Check.equal(counters.wire, "cmp-1:2,cmp-2:1")
    }

    // The edge truncates at 2000 characters and 100 pairs. Trimming here — by
    // count, busiest first — means the caps that matter most are the ones
    // still enforced when the string is cut.
    Check.test("counters keep the busiest campaigns when they must choose") {
        let counters = FrequencyCounters.empty()
        for index in 0..<150 {
            for _ in 0...index { counters.record(campaignID: "campaign-\(index)", now: 1_000) }
        }
        let wire = counters.wire
        Check.expect(wire.count <= 2_000, "length was \(wire.count)")
        Check.expect(wire.split(separator: ",").count <= 100)
        Check.expect(wire.hasPrefix("campaign-149:150"), "busiest first, got \(wire.prefix(40))")
    }

    Check.test("a corrupt counter store costs a repeated ad, never a crash") {
        let counters = FrequencyCounters.decode("garbage,cmp-1:2:1000,cmp-2:notanumber:1,,:::")
        Check.equal(counters.count(for: "cmp-1"), 2)
        Check.equal(counters.count(for: "cmp-2"), 0)
    }

    Check.test("nothing stored is simply nothing counted") {
        Check.equal(FrequencyCounters.decode(nil).wire, "")
        Check.equal(FrequencyCounters.empty().wire, "")
    }
}

func runImpressionTests() {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("sanbuk-queue-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    func queue(maximumEntries: Int = ImpressionQueue.maximumEntries) -> ImpressionQueue {
        ImpressionQueue(
            fileURL: directory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent("impressions.tsv"),
            maximumEntries: maximumEntries
        )
    }

    func impression(_ id: String, at created: Int64 = 1_000) -> QueuedImpression {
        QueuedImpression(eventID: id, url: "https://t.sanbuk.com/i/abc?eid=\(id)", createdAt: created)
    }

    Check.test("the queue holds what could not be sent, oldest first") {
        let subject = queue()
        subject.enqueue(impression("a", at: 1_000))
        subject.enqueue(impression("b", at: 2_000))
        Check.equal(subject.pending(now: 2_500).map(\.eventID), ["a", "b"])
    }

    // A queue flushed twice must not become two views of the same ad.
    Check.test("the same view is only ever held once") {
        let subject = queue()
        subject.enqueue(impression("a"))
        subject.enqueue(impression("a"))
        Check.equal(subject.count, 1)
    }

    Check.test("the queue forgets what the server has taken") {
        let subject = queue()
        subject.enqueue(impression("a"))
        subject.enqueue(impression("b"))
        subject.acknowledge(["a"])
        Check.equal(subject.pending(now: 1_500).map(\.eventID), ["b"])
    }

    // A view that lands the next day moves a number in a report someone has
    // already read — worse than losing it.
    Check.test("the queue drops views too old to belong to today") {
        let subject = queue()
        subject.enqueue(impression("stale", at: 0))
        subject.enqueue(impression("fresh", at: ImpressionQueue.maximumAgeMilliseconds))
        let pending = subject.pending(now: ImpressionQueue.maximumAgeMilliseconds + 1)
        Check.equal(pending.map(\.eventID), ["fresh"])
        Check.equal(subject.count, 1, "the expired entry is forgotten, not just hidden")
    }

    Check.test("a phone offline for a week does not grow the file forever") {
        let subject = queue(maximumEntries: 3)
        for index in 0..<10 { subject.enqueue(impression("id-\(index)", at: Int64(index))) }
        Check.equal(subject.count, 3)
        Check.equal(
            subject.pending(now: 100).map(\.eventID), ["id-7", "id-8", "id-9"],
            "the newest survive — an old impression is worth least"
        )
    }

    Check.test("a corrupt queue file costs impressions, never a crash") {
        let file = directory.appendingPathComponent("corrupt").appendingPathComponent("impressions.tsv")
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? "this is not a queue\n\t\t\nid\tnot-a-number\thttps://x".write(to: file, atomically: true, encoding: .utf8)
        let subject = ImpressionQueue(fileURL: file)
        Check.equal(subject.pending(now: 1_000).count, 0)
        subject.enqueue(impression("a"))
        Check.equal(subject.count, 1, "and the queue keeps working afterwards")
    }

    // Without the id the server has nothing to recognise a retry by, and the
    // offline queue turns one bad minute of signal into inflated revenue.
    Check.test("the impression url carries the event id the server dedupes on") {
        Check.equal(
            ImpressionURL.build(
                impressionURL: "https://t.sanbuk.com/i/abc123",
                eventID: "b21f5c9e-1d2a-4c3b-8e7f-0a1b2c3d4e5f",
                installID: "install-1"
            ),
            "https://t.sanbuk.com/i/abc123?eid=b21f5c9e-1d2a-4c3b-8e7f-0a1b2c3d4e5f&install_id=install-1"
        )
    }

    Check.test("the impression url appends to one that already has a query") {
        Check.expect(
            ImpressionURL.build(impressionURL: "https://t.sanbuk.com/i/abc?v=2", eventID: "eid-1", installID: "install-1")
                .contains("?v=2&eid=eid-1")
        )
    }

    Check.test("the impression url escapes ids rather than trusting them") {
        let url = ImpressionURL.build(impressionURL: "https://t.sanbuk.com/i/abc", eventID: "a&b=c", installID: "install 1")
        Check.expect(url.contains("eid=a%26b%3Dc"), url)
        Check.expect(url.contains("install_id=install%201"), url)
    }
}

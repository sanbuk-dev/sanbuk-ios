import Foundation

/// How often this install has already seen each campaign.
///
/// The server distrusts these and re-checks everything — lying only ever costs
/// the visitor some ads — but sending them is what lets a frequency cap work
/// at all without the platform tracking individuals.
///
/// On the web these counters live in memory and die with the page. An app
/// process lives for days and is then killed without warning, so they have to
/// survive: `encoded` and `decode` are for whatever the shell uses for
/// storage. The wire format is narrower than the stored one, because the
/// server needs the counts, never when they happened.
public final class FrequencyCounters {

    private static let maximumWirePairs = 100
    private static let maximumWireCharacters = 2_000
    private static let millisecondsPerHour: Int64 = 3_600_000

    private struct Entry {
        var count: Int
        let firstSeenAt: Int64
    }

    private var entries: [String: Entry]

    private init(entries: [String: Entry]) {
        self.entries = entries
    }

    public static func empty() -> FrequencyCounters { FrequencyCounters(entries: [:]) }

    public func record(campaignID: String, now: Int64) {
        guard !campaignID.isEmpty else { return }
        if var existing = entries[campaignID] {
            existing.count += 1
            entries[campaignID] = existing
        } else {
            entries[campaignID] = Entry(count: 1, firstSeenAt: now)
        }
    }

    /// Forgets what the window no longer covers. Driven by the server's own
    /// `fc_hours`, so the cap can be retuned without shipping an SDK.
    public func prune(windowHours: Int, now: Int64) {
        guard windowHours > 0 else {
            entries.removeAll()
            return
        }
        let cutoff = now - Int64(windowHours) * Self.millisecondsPerHour
        entries = entries.filter { $0.value.firstSeenAt > cutoff }
    }

    public func count(for campaignID: String) -> Int { entries[campaignID]?.count ?? 0 }

    /// The `fc` query parameter: `campaignId:count` pairs.
    ///
    /// Bounded twice, because the edge bounds it too and a request truncated
    /// there is worse than one trimmed here: the busiest campaigns are kept,
    /// so the cap that matters most is the one still enforced.
    public var wire: String {
        var out = ""
        let ordered = entries
            .sorted { left, right in
                left.value.count == right.value.count
                    ? left.key < right.key
                    : left.value.count > right.value.count
            }
            .prefix(Self.maximumWirePairs)

        for (campaignID, entry) in ordered {
            let pair = "\(campaignID):\(entry.count)"
            let added = out.isEmpty ? pair.count : pair.count + 1
            if out.count + added > Self.maximumWireCharacters { continue }
            if !out.isEmpty { out += "," }
            out += pair
        }
        return out
    }

    /// Storage form — the counts plus when each campaign was first seen.
    public var encoded: String {
        entries
            .map { "\($0.key):\($0.value.count):\($0.value.firstSeenAt)" }
            .sorted()
            .joined(separator: ",")
    }

    /// Anything malformed is dropped rather than rejected. A corrupt counter
    /// store must cost the visitor a repeated ad at worst, never an error on
    /// the way to drawing one.
    public static func decode(_ stored: String?) -> FrequencyCounters {
        var entries: [String: Entry] = [:]
        for chunk in (stored ?? "").split(separator: ",") {
            let parts = chunk.split(separator: ":", omittingEmptySubsequences: false)
            guard
                parts.count == 3,
                !parts[0].isEmpty,
                let count = Int(parts[1]), count > 0,
                let firstSeen = Int64(parts[2])
            else { continue }
            entries[String(parts[0])] = Entry(count: count, firstSeenAt: firstSeen)
        }
        return FrequencyCounters(entries: entries)
    }
}

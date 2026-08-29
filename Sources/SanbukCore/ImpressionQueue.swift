import Foundation

/// One view waiting to be reported.
public struct QueuedImpression: Sendable, Equatable {
    public let eventID: String
    public let url: String
    public let createdAt: Int64

    public init(eventID: String, url: String, createdAt: Int64) {
        self.eventID = eventID
        self.url = url
        self.createdAt = createdAt
    }
}

/// Views that could not be delivered yet.
///
/// An app runs on the metro, in a lift, on two bars of signal. Without this a
/// publisher loses every impression that happened during a bad minute — real
/// revenue, silently. With it, the same view can be sent twice, which is why
/// every entry carries the event id the server deduplicates on.
///
/// Three bounds, each for a reason: a size cap, so a phone offline for a week
/// does not grow a file forever; an age cap, because an impression that lands
/// on the wrong day moves a number in a report someone already read; and
/// dedupe on the id, so a queue flushed twice does not queue twice.
///
/// Never throws. A corrupt or unreadable file costs some impressions, which is
/// bad; an error on the way to drawing an ad costs the publisher's app.
public final class ImpressionQueue {

    public static let maximumEntries = 500
    /// Six hours: long enough for a commute, short enough to stay in the right day.
    public static let maximumAgeMilliseconds: Int64 = 6 * 60 * 60 * 1000

    private let url: URL
    private let maximumEntries: Int
    private let maximumAge: Int64

    public init(
        fileURL: URL,
        maximumEntries: Int = ImpressionQueue.maximumEntries,
        maximumAgeMilliseconds: Int64 = ImpressionQueue.maximumAgeMilliseconds
    ) {
        self.url = fileURL
        self.maximumEntries = maximumEntries
        self.maximumAge = maximumAgeMilliseconds
    }

    public func enqueue(_ impression: QueuedImpression) {
        let kept = (read().filter { $0.eventID != impression.eventID } + [impression])
            .suffix(maximumEntries)
        write(Array(kept))
    }

    /// What is still worth sending, oldest first. Expired entries are
    /// forgotten here rather than merely hidden.
    public func pending(now: Int64) -> [QueuedImpression] {
        let all = read()
        let fresh = all.filter { now - $0.createdAt < maximumAge }
        if fresh.count != all.count { write(fresh) }
        return fresh
    }

    /// Called once the server has answered — including for a duplicate, which
    /// it accepts.
    public func acknowledge(_ eventIDs: [String]) {
        guard !eventIDs.isEmpty else { return }
        let taken = Set(eventIDs)
        write(read().filter { !taken.contains($0.eventID) })
    }

    public var count: Int { read().count }

    private func read() -> [QueuedImpression] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap(decode)
    }

    private func write(_ entries: [QueuedImpression]) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? entries.map(encode).joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // A tab separates the fields because none of them can contain one: the id
    // is a uuid and the url is percent-encoded.
    private func encode(_ impression: QueuedImpression) -> String {
        "\(impression.eventID)\t\(impression.createdAt)\t\(impression.url)"
    }

    /// A line we cannot read is dropped, never thrown — see the type's note.
    private func decode(_ line: Substring) -> QueuedImpression? {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            !parts[0].isEmpty,
            !parts[2].isEmpty,
            let createdAt = Int64(parts[1])
        else { return nil }
        return QueuedImpression(eventID: String(parts[0]), url: String(parts[2]), createdAt: createdAt)
    }
}

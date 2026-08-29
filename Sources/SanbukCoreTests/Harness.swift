import Foundation

/// A test runner small enough to have no dependencies.
///
/// XCTest and swift-testing both arrive with Xcode. SanbukCore deliberately
/// depends on nothing but Foundation so that it builds anywhere a Swift
/// toolchain does — and tests that only run under Xcode would quietly undo
/// that: they would not run on a Command Line Tools machine, nor in a CI image
/// without a full Xcode, which is exactly where a regression slips through.
///
/// Failures are collected rather than fatal, so one broken expectation does
/// not hide the twenty after it.
enum Check {

    private(set) static var failures: [String] = []
    private(set) static var passed = 0
    private static var currentTest = ""

    static func test(_ name: String, _ body: () throws -> Void) {
        currentTest = name
        do {
            try body()
        } catch {
            failures.append("\(name): threw \(error)")
        }
    }

    static func expect(
        _ condition: Bool,
        _ message: @autoclosure () -> String = "",
        line: UInt = #line
    ) {
        if condition {
            passed += 1
        } else {
            let detail = message()
            failures.append("\(currentTest):\(line) \(detail.isEmpty ? "expectation failed" : detail)")
        }
    }

    static func equal<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: @autoclosure () -> String = "",
        line: UInt = #line
    ) {
        if actual == expected {
            passed += 1
        } else {
            let detail = message()
            failures.append(
                "\(currentTest):\(line) got \(actual), want \(expected)\(detail.isEmpty ? "" : " — \(detail)")"
            )
        }
    }

    static func nilValue<T>(_ actual: T?, _ message: @autoclosure () -> String = "", line: UInt = #line) {
        expect(actual == nil, message().isEmpty ? "expected nil, got \(String(describing: actual))" : message(), line: line)
    }

    static func notNil<T>(_ actual: T?, _ message: @autoclosure () -> String = "", line: UInt = #line) {
        expect(actual != nil, message().isEmpty ? "expected a value, got nil" : message(), line: line)
    }

    /// Exits non-zero on any failure, so CI and a human see the same verdict.
    static func report() -> Never {
        if failures.isEmpty {
            print("✓ \(passed) checks passed")
            exit(0)
        }
        print("✗ \(failures.count) failed, \(passed) passed\n")
        for failure in failures { print("  \(failure)") }
        exit(1)
    }
}

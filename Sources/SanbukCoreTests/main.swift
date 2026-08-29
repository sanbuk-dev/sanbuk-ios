import Foundation

// `swift run sanbuk-core-tests`. No Xcode, no simulator — SanbukCore depends
// on nothing but Foundation and its tests keep that true.
runServeURLTests()
runAdParserTests()
runViewabilityTests()
runFullscreenPolicyTests()
runRewardPolicyTests()
runFrequencyCounterTests()
runImpressionTests()

Check.report()

import Testing
@testable import RemoteMic

@Suite("Voice Fn tap activation policy")
struct VoiceFnTapActivationPolicyTests {
    @Test func transientMissingHIDMappingKeepsTheUserRequestWaiting() {
        #expect(VoiceFnTapActivationPolicy.state(
            requested: true,
            accessibilityTrusted: true,
            voiceKeyNeutralized: false
        ) == .waitingForMapping)
    }

    @Test func readyMappingActivatesAndExplicitDisableStaysDisabled() {
        #expect(VoiceFnTapActivationPolicy.state(
            requested: true,
            accessibilityTrusted: true,
            voiceKeyNeutralized: true
        ) == .active)
        #expect(VoiceFnTapActivationPolicy.state(
            requested: false,
            accessibilityTrusted: true,
            voiceKeyNeutralized: true
        ) == .disabled)
    }

    @Test func missingAccessibilityWaitsWithoutDiscardingTheRequest() {
        #expect(VoiceFnTapActivationPolicy.state(
            requested: true,
            accessibilityTrusted: false,
            voiceKeyNeutralized: false
        ) == .waitingForAccessibility)
    }
}

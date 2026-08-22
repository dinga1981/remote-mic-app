import Foundation

enum VoiceFnTapActivationState: Equatable {
    case disabled
    case waitingForAccessibility
    case waitingForMapping
    case active
}

enum VoiceFnTapActivationPolicy {
    static func state(
        requested: Bool,
        accessibilityTrusted: Bool,
        voiceKeyNeutralized: Bool
    ) -> VoiceFnTapActivationState {
        guard requested else { return .disabled }
        guard accessibilityTrusted else { return .waitingForAccessibility }
        return voiceKeyNeutralized ? .active : .waitingForMapping
    }
}

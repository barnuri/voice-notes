public enum RecordingPhase: Equatable, Sendable {
    case idle
    case recording
    case paused

    public var primaryActionTitle: String {
        switch self {
        case .idle: "Start Recording"
        case .recording: "Pause"
        case .paused: "Resume"
        }
    }
}

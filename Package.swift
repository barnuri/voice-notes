// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceNotes",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "VoiceNotesCore"),
        .executableTarget(name: "VoiceNotes", dependencies: ["VoiceNotesCore"]),
        .testTarget(name: "VoiceNotesCoreTests", dependencies: ["VoiceNotesCore"]),
    ]
)

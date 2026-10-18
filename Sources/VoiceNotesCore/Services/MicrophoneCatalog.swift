import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
public final class MicrophoneCatalog {
    private static let deviceTypes: [AVCaptureDevice.DeviceType] = [.microphone, .external]
    private static let deviceChangeNotifications = [
        AVCaptureDevice.wasConnectedNotification,
        AVCaptureDevice.wasDisconnectedNotification,
    ]

    public private(set) var devices: [MicrophoneDevice] = []
    public private(set) var defaultDevice: MicrophoneDevice?
    @ObservationIgnored private nonisolated(unsafe) var observers: [any NSObjectProtocol] = []

    public init() {
        refresh()
        observers = Self.deviceChangeNotifications.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    public func resolvedDevice(storedID: String) -> MicrophoneDevice? {
        let id = MicrophoneSelection.resolve(storedID: storedID, available: devices.map(\.id), defaultID: defaultDevice?.id)
        return devices.first { $0.id == id } ?? defaultDevice
    }

    private func refresh() {
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: Self.deviceTypes, mediaType: .audio, position: .unspecified)
        devices = discovery.devices.map(Self.microphone(for:))
        defaultDevice = AVCaptureDevice.default(for: .audio).map(Self.microphone(for:))
    }

    private static func microphone(for device: AVCaptureDevice) -> MicrophoneDevice {
        MicrophoneDevice(id: device.uniqueID, name: device.localizedName)
    }
}

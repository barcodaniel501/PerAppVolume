import AudioToolbox
import CoreAudio
import Foundation

/// Volume and mute of the current output device (the same as the Mac's volume keys).
@MainActor
final class SystemVolume: ObservableObject {
    static let shared = SystemVolume()

    @Published private(set) var volume: Double = 0      // 0.0 ... 1.0
    @Published private(set) var muted = false
    @Published private(set) var deviceName = ""
    @Published private(set) var canSetVolume = false
    @Published private(set) var canMute = false

    private let volumeSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
    private let muteSelector = kAudioDevicePropertyMute
    private let scope = kAudioDevicePropertyScopeOutput

    private var device = CA.unknown
    private var listener: AudioObjectPropertyListenerBlock?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        attach()
        CA.addSystemListener(kAudioHardwarePropertyDefaultOutputDevice) {
            Task { @MainActor in SystemVolume.shared.attach() }
        }
    }

    func setVolume(_ value: Double) {
        guard canSetVolume else { return }
        CA.write(device, volumeSelector, Float32(min(max(value, 0), 1)), scope: scope)
        if muted && value > 0 && canMute { CA.write(device, muteSelector, UInt32(0), scope: scope) }
        read()
    }

    func toggleMute() {
        guard canMute else { return }
        CA.write(device, muteSelector, UInt32(muted ? 0 : 1), scope: scope)
        read()
    }

    /// Demo values for `--screenshots` (does not touch the real device).
    func loadDemo(volume: Double, deviceName: String) {
        self.volume = volume
        self.deviceName = deviceName
        muted = false
        canSetVolume = true
        canMute = true
    }

    /// Follows the default output device and listens for changes (e.g. the volume keys).
    private func attach() {
        detach()
        guard let id = CA.defaultOutputDevice() else {
            deviceName = ""; canSetVolume = false; canMute = false
            return
        }
        device = id
        deviceName = CA.string(id, kAudioObjectPropertyName) ?? ""
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            Task { @MainActor in SystemVolume.shared.read() }
        }
        listener = block
        for selector in [volumeSelector, muteSelector] {
            var addr = CA.address(selector, scope: scope)
            AudioObjectAddPropertyListenerBlock(id, &addr, DispatchQueue.main, block)
        }
        read()
    }

    private func detach() {
        guard device != CA.unknown, let listener else { return }
        for selector in [volumeSelector, muteSelector] {
            var addr = CA.address(selector, scope: scope)
            AudioObjectRemovePropertyListenerBlock(device, &addr, DispatchQueue.main, listener)
        }
        self.listener = nil
        device = CA.unknown
    }

    private func read() {
        canSetVolume = CA.isSettable(device, volumeSelector, scope: scope)
        canMute = CA.isSettable(device, muteSelector, scope: scope)
        volume = Double(CA.read(device, volumeSelector, as: Float32(0), scope: scope) ?? 0)
        muted = (CA.read(device, muteSelector, as: UInt32(0), scope: scope) ?? 0) != 0
    }
}

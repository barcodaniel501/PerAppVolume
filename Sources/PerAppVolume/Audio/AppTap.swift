import AudioToolbox
import CoreAudio
import Foundation

/// Gain shared between the UI thread and the real-time audio thread.
final class GainBox: @unchecked Sendable {
    /// Target gain set by the UI (0 = silent, 1 = original, 2 = +100%).
    var target: Float
    /// Gain applied at the end of the last buffer (only touched by the audio thread).
    var applied: Float

    init(_ value: Float) {
        target = value
        applied = value
    }
}

/// Controls the volume of one app without any driver:
///
/// 1. A Core Audio *process tap* captures the app's audio and mutes its original output
///    (`mutedWhenTapped`: if PerAppVolume stops or crashes, the app is heard normally again).
/// 2. A private *aggregate device* combines that tap (input) with the current output device.
/// 3. An IO callback copies the tapped audio to the output, multiplied by the chosen gain.
final class AppTap {
    let processIDs: [AudioObjectID]
    let deviceUID: String
    let gain: GainBox

    private var tapID = CA.unknown
    private var aggregateID = CA.unknown
    private var ioProcID: AudioDeviceIOProcID?

    private static let ioQueue = DispatchQueue(label: "PerAppVolume.audio-io", qos: .userInteractive)

    init(processIDs: [AudioObjectID], deviceUID: String, gain: Float, name: String) throws {
        self.processIDs = processIDs
        self.deviceUID = deviceUID
        self.gain = GainBox(gain)

        do {
            try start(name: name)
        } catch {
            stop()
            throw error
        }
    }

    deinit { stop() }

    private func start(name: String) throws {
        // 1. Process tap
        let description = CATapDescription(stereoMixdownOfProcesses: processIDs)
        description.name = "PerAppVolume – \(name)"
        description.isPrivate = true
        description.muteBehavior = CATapMuteBehavior.mutedWhenTapped
        try caCheck(AudioHardwareCreateProcessTap(description, &tapID), "Create process tap")

        // 2. Aggregate device: output device + tap
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "PerAppVolume – \(name)",
            kAudioAggregateDeviceUIDKey: "io.github.perappvolume.aggregate.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: deviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: deviceUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        try caCheck(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "Create aggregate device")

        // 3. IO callback
        let gain = self.gain
        try caCheck(AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, Self.ioQueue) { _, input, _, output, _ in
            AppTap.render(input: input, output: output, gain: gain)
        }, "Create IO proc")
        try caCheck(AudioDeviceStart(aggregateID, ioProcID), "Start audio device")
    }

    func stop() {
        if aggregateID != CA.unknown, let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != CA.unknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = CA.unknown
        }
        if tapID != CA.unknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = CA.unknown
        }
    }

    /// Real-time render: copies tap channels to output channels applying a smoothed gain.
    /// Assumes 32-bit float samples (the canonical HAL format). No allocations happen here.
    private static func render(input: UnsafePointer<AudioBufferList>,
                               output: UnsafeMutablePointer<AudioBufferList>,
                               gain: GainBox) {
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputs = UnsafeMutableAudioBufferListPointer(output)

        for buffer in outputs {
            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
        }

        var inputChannelCount = 0
        for buffer in inputs { inputChannelCount += Int(buffer.mNumberChannels) }
        guard inputChannelCount > 0 else { return }

        let startGain = gain.applied
        let endGain = gain.target
        gain.applied = endGain

        var outputChannel = 0
        for outBuffer in outputs {
            let outChannels = max(Int(outBuffer.mNumberChannels), 1)
            guard let outData = outBuffer.mData?.assumingMemoryBound(to: Float.self) else {
                outputChannel += outChannels
                continue
            }
            let outFrames = Int(outBuffer.mDataByteSize) / (MemoryLayout<Float>.size * outChannels)

            for channel in 0..<outChannels {
                defer { outputChannel += 1 }
                // Stereo tap -> L/R of the device. A mono tap is sent to every channel.
                var source: Int
                if outputChannel < inputChannelCount { source = outputChannel }
                else if inputChannelCount == 1 { source = 0 }
                else { continue }

                for inBuffer in inputs {
                    let inChannels = Int(inBuffer.mNumberChannels)
                    if source >= inChannels { source -= inChannels; continue }
                    guard let inData = inBuffer.mData?.assumingMemoryBound(to: Float.self), inChannels > 0 else { break }
                    let inFrames = Int(inBuffer.mDataByteSize) / (MemoryLayout<Float>.size * inChannels)
                    let frames = min(outFrames, inFrames)
                    guard frames > 0 else { break }
                    let step = (endGain - startGain) / Float(frames)
                    var g = startGain
                    for frame in 0..<frames {
                        g += step
                        let sample = inData[frame * inChannels + source] * g
                        outData[frame * outChannels + channel] = min(max(sample, -1), 1)
                    }
                    break
                }
            }
        }
    }
}

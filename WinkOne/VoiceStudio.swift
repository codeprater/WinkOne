import Combine
import AVFoundation
import SwiftUI

// MARK: - Recorder

/// Records at most `WinkLimits.maxVoiceSeconds` of mono AAC and hands back the
/// encoded bytes. Levels are sampled while recording so the card can bake a
/// waveform rather than drawing a generic one.
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var levels: [CGFloat] = []
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var permissionDenied = false
    @Published var playThroughSilentSwitch = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meterTask: Task<Void, Never>?
    private var fileURL: URL?

    private static let sampleCount = 40

    // MARK: Recording

    /// Set by the recorder when a take finishes. The studio observes these
    /// rather than being handed an escaping closure, which keeps every hop
    /// on the main actor and satisfies Swift 6 sendability.
    @Published private(set) var recordedData: Data?
    @Published private(set) var recordedDuration: TimeInterval = 0

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task { await requestThenRecord() }
        }
    }

    private func requestThenRecord() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            permissionDenied = true
            return
        }
        permissionDenied = false
        beginRecording()
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wink-voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.isMeteringEnabled = true
            newRecorder.prepareToRecord()
            newRecorder.record(forDuration: WinkLimits.maxVoiceSeconds)
            recorder = newRecorder
            fileURL = url
            levels = []
            elapsed = 0
            recordedData = nil
            recordedDuration = 0
            isRecording = true
            startMetering()
        } catch {
            recorder = nil
            fileURL = nil
        }
    }

    /// A main-actor task rather than a Timer — Timer's block is @Sendable and
    /// cannot touch this actor's state without a warning.
    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, let recorder = self.recorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)      // -160...0 dB
                let clamped = max(-50, min(0, power))
                self.levels.append(CGFloat((clamped + 50) / 50))
                if self.levels.count > Self.sampleCount { self.levels.removeFirst() }
                self.elapsed = recorder.currentTime
                if recorder.currentTime >= WinkLimits.maxVoiceSeconds {
                    self.stopRecording()
                    return
                }
            }
        }
    }

    func stopRecording() {
        meterTask?.cancel()
        meterTask = nil
        guard let recorder else {
            isRecording = false
            return
        }
        let duration = recorder.currentTime
        recorder.stop()
        isRecording = false
        self.recorder = nil

        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              data.count <= WinkLimits.maxVoiceBytes else {
            recordedData = nil
            recordedDuration = 0
            return
        }
        recordedData = data
        recordedDuration = duration
    }

    // MARK: Playback

    /// Uses `.ambient` by default, which honours the ringer switch — a muted
    /// phone stays silent. The user opts into `.playback` explicitly.
    func play(_ data: Data) {
        stopPlayback()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(playThroughSilentSwitch ? .playback : .ambient)
            try session.setActive(true)
        } catch {
            return
        }
        do {
            let newPlayer = try AVAudioPlayer(data: data)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            isPlaying = true
        } catch {
            player = nil
            isPlaying = false
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func reset() {
        stopPlayback()
        meterTask?.cancel()
        meterTask = nil
        recorder?.stop()
        recorder = nil
        levels = []
        elapsed = 0
        isRecording = false
    }
}

extension VoiceRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}

// MARK: - Waveform

/// Shared by the studio and the card so a recorded wink looks the same in both.
struct WaveformView: View {
    let levels: [CGFloat]
    var barColor: Color
    var animates: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 3
            let barWidth = max(2, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(barColor)
                        .frame(width: barWidth, height: max(3, level * geo.size.height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .animation(
                (animates && !reduceMotion) ? .easeOut(duration: 0.12) : nil,
                value: levels.count
            )
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Studio

struct VoiceStudio: View {
    @Binding var voiceData: Data?
    @Binding var voiceDuration: TimeInterval
    @Binding var caption: String
    @Binding var bakedLevels: [CGFloat]
    var fromName: String
    var placeName: String?

    @StateObject private var recorder = VoiceRecorder()

    private var current: WinkMessage {
        WinkMessage(
            text: caption,
            pack: "Voice",
            atmosphere: Composer.voice.atmosphere,
            ink: Composer.voice.ink,
            placeName: placeName,
            voiceData: voiceData,
            voiceDuration: voiceDuration > 0 ? voiceDuration : nil
        )
    }

    var body: some View {
        StudioLayout {
            WinkCardView(
                message: current,
                fromName: fromName,
                bakedLevels: bakedLevels
            )
        } controls: {
            VStack(spacing: 14) {
            TextField("Caption", text: $caption)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .padding(.horizontal, 36)
                .winkWritingTools()
                .onChange(of: caption) { _, newValue in
                    if newValue.count > WinkLimits.symbolCaption {
                        caption = String(newValue.prefix(WinkLimits.symbolCaption))
                    }
                }
                .accessibilityLabel("Caption for your voice wink")

            SuggestLinesRow(composerName: "Voice", target: $caption)

            recordButton

            statusLine

            if voiceData != nil {
                HStack(spacing: 18) {
                    Button {
                        if recorder.isPlaying {
                            recorder.stopPlayback()
                        } else if let data = voiceData {
                            recorder.play(data)
                        }
                    } label: {
                        Label(recorder.isPlaying ? "Stop" : "Preview",
                              systemImage: recorder.isPlaying ? "stop.fill" : "play.fill")
                            .font(WinkFont.label(12))
                            .foregroundStyle(WinkColor.volt)
                    }
                    .accessibilityLabel(recorder.isPlaying ? "Stop preview" : "Preview your recording")

                    Button {
                        recorder.stopPlayback()
                        voiceData = nil
                        voiceDuration = 0
                        bakedLevels = []
                    } label: {
                        Label("Record again", systemImage: "arrow.counterclockwise")
                            .font(WinkFont.label(13))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityLabel("Discard and record again")
                }
            }
            }
        }
        .onChange(of: recorder.recordedData) { _, newValue in
            guard let newValue else { return }
            voiceData = newValue
            voiceDuration = recorder.recordedDuration
            bakedLevels = recorder.levels
        }
        .onDisappear { recorder.reset() }
        .alert("Microphone access is off", isPresented: .constant(recorder.permissionDenied)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Turn on the microphone for WINK in Settings to record a Voice Wink.")
        }
    }

    private var recordButton: some View {
        Button {
            recorder.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? WinkColor.ember : WinkColor.volt)
                    .frame(width: 76, height: 76)
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(WinkColor.night)
            }
        }
        .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Record up to three seconds")
        .accessibilityHint("Voice Winks are three seconds at most")
    }

    @ViewBuilder
    private var statusLine: some View {
        if recorder.isRecording {
            VStack(spacing: 8) {
                WaveformView(levels: recorder.levels, barColor: WinkColor.volt)
                    .frame(height: 34)
                    .padding(.horizontal, 48)
                Text(String(format: "%.1fs / %.0fs", recorder.elapsed, WinkLimits.maxVoiceSeconds))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(WinkColor.volt)
                    .monospacedDigit()
            }
        } else if voiceData != nil {
            Text(String(format: "%.1f second recording ready", voiceDuration))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Text("Tap to record. Three seconds, that's it.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

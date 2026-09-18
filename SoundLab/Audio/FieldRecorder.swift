import AVFoundation
import Observation

@Observable
final class FieldRecorder {
    var isRecording = false
    var elapsed: Double = 0
    var lastFilename: String?
    var lastDuration: Double = 0
    var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func requestPermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in self?.permissionDenied = !granted }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in self?.permissionDenied = !granted }
            }
        }
    }

    func startRecording() {
        AudioCore.shared.activateSession()

        let filename = "rec-\(Int(Date().timeIntervalSince1970)).m4a"
        let url = URL.documentsDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.isMeteringEnabled = true
            newRecorder.record()
            recorder = newRecorder
            lastFilename = filename
            isRecording = true
            elapsed = 0
            startTimer()
        } catch {
            print("Recording failed: \(error)")
        }
    }

    func stopRecording() {
        lastDuration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimer()
    }

    func play(filename: String) {
        let url = URL.documentsDirectory.appendingPathComponent(filename)
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Playback failed: \(error)")
        }
    }

    func discardLast() {
        guard let filename = lastFilename else { return }
        let url = URL.documentsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        lastFilename = nil
        lastDuration = 0
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = recorder.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

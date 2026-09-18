import Accelerate
import CoreGraphics

/// A patch rendered offline and reduced to what the eye can compare:
/// the loudness outline over time and a spectrogram.
struct SoundPicture: @unchecked Sendable {
    /// Seconds covered by the picture. Shared between target and user so the axes line up.
    let duration: Double
    /// Peak level per column, 0...1 where 1 is the voice's full output.
    let peaks: [Float]
    /// Time left to right, frequency bottom to top, brightness is level.
    let spectrogram: CGImage?
    /// Energy-weighted centre frequency. Drives the "register" description.
    let centroid: Double
}

enum SoundAnalyzer {
    static let sampleRate: Float = 44_100
    /// Spectrogram frequency axis. Logarithmic, like hearing.
    static let lowestFrequency: Float = 30
    static let highestFrequency: Float = 16_000

    private static let fftSize = 2_048
    private static let rows = 72
    private static let columns = 180
    /// Output level of a full-scale oscillator through `SynthVoice`.
    private static let fullScale: Float = 0.35
    private static let dynamicRange: Float = 72

    /// Common time span for a set of patches, so their pictures can be stacked.
    static func duration(for patches: [Patch]) -> Double {
        let longest = patches.map(\.length).max() ?? 0.3
        return min(max(longest * 1.08 + 0.03, 0.2), 6)
    }

    static func picture(of patch: Patch, duration: Double) -> SoundPicture {
        let samples = render(patch, duration: duration)
        let (image, centroid) = spectrogram(of: samples)
        return SoundPicture(duration: duration,
                            peaks: peaks(of: samples),
                            spectrogram: image,
                            centroid: centroid)
    }

    /// Plays the patch as a one-shot into a buffer using the same voice as the live synth.
    static func render(_ patch: Patch, duration: Double) -> [Float] {
        let voice = SynthVoice(sampleRate: sampleRate)
        voice.apply(patch)
        let total = Int(duration * Double(sampleRate))
        let gateOff = Int(patch.gateTime * Double(sampleRate))
        var samples = [Float](repeating: 0, count: total)
        voice.gateOn()
        for index in 0..<total {
            if index == gateOff { voice.gateOff() }
            samples[index] = voice.render()
        }
        return samples
    }

    private static func peaks(of samples: [Float]) -> [Float] {
        let width = 240
        let chunk = max(samples.count / width, 1)
        return (0..<width).map { column in
            let start = column * chunk
            guard start < samples.count else { return 0 }
            let end = min(start + chunk, samples.count)
            var peak: Float = 0
            samples.withUnsafeBufferPointer { buffer in
                vDSP_maxmgv(buffer.baseAddress! + start, 1, &peak, vDSP_Length(end - start))
            }
            return min(peak / fullScale, 1)
        }
    }

    private static func spectrogram(of samples: [Float]) -> (CGImage?, Double) {
        let n = fftSize
        let half = n / 2
        guard let fft = vDSP.FFT(log2n: vDSP_Length(log2(Float(n))), radix: .radix2, ofType: DSPSplitComplex.self)
        else { return (nil, 0) }

        let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: n, isHalfWindow: false)
        let binWidth = sampleRate / Float(n)
        // Reference: a full-scale sine through a Hann window lands at amplitude * n / 2
        // in vDSP's packed real FFT.
        let reference = pow(fullScale * Float(n) / 2, 2)

        // Which FFT bins each output row covers.
        let edges: [Float] = (0...rows).map { row in
            lowestFrequency * pow(highestFrequency / lowestFrequency, Float(row) / Float(rows))
        }
        let rowBins: [ClosedRange<Int>] = (0..<rows).map { row in
            let lo = max(Int(edges[row] / binWidth), 1)
            let hi = max(Int(edges[row + 1] / binWidth), lo)
            return lo...min(hi, half - 1)
        }

        var levels = [Float](repeating: 0, count: rows * columns)
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var power = [Float](repeating: 0, count: half)
        var frame = [Float](repeating: 0, count: n)
        var weightedLog: Double = 0
        var totalPower: Double = 0

        let hop = Double(max(samples.count - n / 2, 1)) / Double(columns)
        for column in 0..<columns {
            // Centre each window on its column.
            let centre = Int(Double(column) * hop) + n / 4
            let start = centre - n / 2
            for i in 0..<n {
                let index = start + i
                frame[i] = (index >= 0 && index < samples.count) ? samples[index] * window[i] : 0
            }

            real.withUnsafeMutableBufferPointer { realBuffer in
                imag.withUnsafeMutableBufferPointer { imagBuffer in
                    var split = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                    frame.withUnsafeBufferPointer { frameBuffer in
                        frameBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                            vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                        }
                    }
                    fft.forward(input: split, output: &split)
                    vDSP.squareMagnitudes(split, result: &power)
                }
            }
            // Bin 0 carries DC and Nyquist packed together; neither is drawn.
            power[0] = 0

            for row in 0..<rows {
                var strongest: Float = 0
                for bin in rowBins[row] { strongest = max(strongest, power[bin]) }
                let db = 10 * log10(max(strongest / reference, 1e-12))
                levels[row * columns + column] = min(max((db + dynamicRange) / dynamicRange, 0), 1)
            }

            for bin in rowBins[0].lowerBound...rowBins[rows - 1].upperBound {
                let p = Double(power[bin])
                weightedLog += p * log2(Double(Float(bin) * binWidth))
                totalPower += p
            }
        }

        let centroid = totalPower > 0 ? pow(2, weightedLog / totalPower) : 0
        return (image(from: levels), centroid)
    }

    /// Dark-to-bright heat map. Row 0 is the lowest frequency, drawn at the bottom.
    private static func image(from levels: [Float]) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: rows * columns * 4)
        for row in 0..<rows {
            let y = rows - 1 - row
            for column in 0..<columns {
                let (r, g, b) = heat(levels[row * columns + column])
                let offset = (y * columns + column) * 4
                pixels[offset] = r
                pixels[offset + 1] = g
                pixels[offset + 2] = b
                pixels[offset + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: columns, height: rows,
                       bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: columns * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private static let heatStops: [(Float, Float, Float)] = [
        (0.06, 0.05, 0.10),
        (0.28, 0.07, 0.42),
        (0.72, 0.15, 0.48),
        (0.98, 0.50, 0.25),
        (1.00, 0.93, 0.62)
    ]

    private static func heat(_ value: Float) -> (UInt8, UInt8, UInt8) {
        let scaled = min(max(value, 0), 1) * Float(heatStops.count - 1)
        let index = min(Int(scaled), heatStops.count - 2)
        let t = scaled - Float(index)
        let a = heatStops[index], b = heatStops[index + 1]
        func mix(_ x: Float, _ y: Float) -> UInt8 { UInt8((x + (y - x) * t) * 255) }
        return (mix(a.0, b.0), mix(a.1, b.1), mix(a.2, b.2))
    }
}

/// Plain-language description of a sound, so target and attempt can be compared
/// in words as well as pictures. Describes what is heard, not which knob is set.
struct SoundTraits: Equatable {
    let length: String
    let motion: String
    let material: String
    let register: String

    static let labels = ["길이", "움직임", "재료", "대역"]
    var values: [String] { [length, motion, material, register] }

    init(patch: Patch, picture: SoundPicture) {
        length = patch.sustain < 0.01 ? "짧게 치고 끝남" : "지속됨"

        switch patch.pitchSweep {
        case 6...:        motion = "위에서 떨어짐"
        case ...(-6):     motion = "아래에서 솟음"
        case 1.5..<6:     motion = "살짝 내려옴"
        case -6 ..< -1.5: motion = "살짝 올라감"
        default:          motion = "음높이 고정"
        }

        switch patch.noiseMix {
        case 0.7...:  material = "노이즈 · 음정 없음"
        case 0.2...:  material = "음 + 노이즈"
        default:
            material = (patch.waveform == .sine || patch.waveform == .triangle) ? "순한 음" : "거친 음"
        }

        switch picture.centroid {
        case ..<120:  register = "초저역 · 몸으로"
        case ..<400:  register = "저역"
        case ..<1_500: register = "중역"
        case ..<5_000: register = "중고역"
        default:      register = "고역"
        }
    }
}

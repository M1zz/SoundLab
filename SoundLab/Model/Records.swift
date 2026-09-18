import Foundation
import SwiftData

@Model
final class TaskCompletion {
    @Attribute(.unique) var taskID: String
    var completedAt: Date

    init(taskID: String, completedAt: Date = .now) {
        self.taskID = taskID
        self.completedAt = completedAt
    }
}

@Model
final class DrillResult {
    var date: Date
    var levelRaw: Int
    var correct: Int
    var total: Int
    /// Center frequencies the user got wrong, so weak bands can be surfaced.
    var missedFrequencies: [Double]

    init(date: Date = .now, level: DrillLevel, correct: Int, total: Int, missedFrequencies: [Double]) {
        self.date = date
        self.levelRaw = level.rawValue
        self.correct = correct
        self.total = total
        self.missedFrequencies = missedFrequencies
    }

    var level: DrillLevel { DrillLevel(rawValue: levelRaw) ?? .starter }
    var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

@Model
final class ReferenceNote {
    var title: String
    var source: String
    /// All four axes are 1...5. They exist to force a vocabulary, not to be precise.
    var attack: Int
    var lowEnd: Int
    var roughness: Int
    var tail: Int
    /// Written as a situation, not an adjective.
    var emotion: String
    var createdAt: Date

    init(title: String, source: String, attack: Int, lowEnd: Int, roughness: Int, tail: Int, emotion: String) {
        self.title = title
        self.source = source
        self.attack = attack
        self.lowEnd = lowEnd
        self.roughness = roughness
        self.tail = tail
        self.emotion = emotion
        self.createdAt = .now
    }
}

@Model
final class FieldRecording {
    var label: String
    /// Filename inside the app's Documents directory.
    var filename: String
    /// What this could be used as, which is the whole point of the exercise.
    var reimaginedAs: String
    var duration: Double
    var createdAt: Date

    init(label: String, filename: String, reimaginedAs: String, duration: Double) {
        self.label = label
        self.filename = filename
        self.reimaginedAs = reimaginedAs
        self.duration = duration
        self.createdAt = .now
    }

    var fileURL: URL {
        URL.documentsDirectory.appendingPathComponent(filename)
    }
}

@Model
final class Deliverable {
    var week: Int
    var title: String
    var note: String
    var createdAt: Date

    init(week: Int, title: String, note: String) {
        self.week = week
        self.title = title
        self.note = note
        self.createdAt = .now
    }
}

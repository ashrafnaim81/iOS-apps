import SwiftUI

enum Difficulty: String, CaseIterable, Codable, Identifiable {
    case easy, medium, hard, expert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: return "Relaxed warm-up"
        case .medium: return "A steady challenge"
        case .hard: return "Think a few steps ahead"
        case .expert: return "For true masters"
        }
    }

    var targetClues: Int {
        switch self {
        case .easy: return 40
        case .medium: return 32
        case .hard: return 27
        case .expert: return 23
        }
    }

    var color: Color {
        switch self {
        case .easy: return Color(hex: 0x2FB36E)
        case .medium: return Color(hex: 0x2A7BF6)
        case .hard: return Color(hex: 0xF08A24)
        case .expert: return Color(hex: 0x8B5CF6)
        }
    }
}

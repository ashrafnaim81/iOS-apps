import UIKit

enum Haptics {
    private static var enabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.haptics) }

    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

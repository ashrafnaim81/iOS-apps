import SwiftUI

struct SettingsView: View {
    let onShowTutorial: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.sound) private var sound = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.highlightRelated) private var highlightRelated = true
    @AppStorage(SettingsKey.highlightSame) private var highlightSame = true
    @AppStorage(SettingsKey.showTimer) private var showTimer = true

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Feedback") {
                    Toggle(isOn: $sound) { Label("Sound Effects", systemImage: "speaker.wave.2.fill") }
                    Toggle(isOn: $haptics) { Label("Vibration", systemImage: "iphone.radiowaves.left.and.right") }
                }
                Section("Gameplay") {
                    Toggle(isOn: $highlightRelated) { Label("Highlight Row, Column & Box", systemImage: "square.grid.3x3.fill") }
                    Toggle(isOn: $highlightSame) { Label("Highlight Matching Numbers", systemImage: "number") }
                    Toggle(isOn: $showTimer) { Label("Show Timer", systemImage: "timer") }
                }
                if let onShowTutorial {
                    Section {
                        Button {
                            onShowTutorial()
                        } label: {
                            Label("How to Play", systemImage: "questionmark.circle.fill")
                        }
                    }
                }
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version).foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Privacy", systemImage: "lock.shield.fill").font(.headline)
                        Text("Sudoku Santai does not collect, store or share any personal data. There are no ads, no tracking and no accounts. Your progress stays on this device.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .tint(Theme.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

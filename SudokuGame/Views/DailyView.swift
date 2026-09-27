import SwiftUI

struct DailyView: View {
    @ObservedObject var game: GameModel
    let onBack: () -> Void
    let onPlay: () -> Void

    @State private var monthOffset = 0
    @State private var loadingDay: String?

    private let calendar = Calendar(identifier: .gregorian)
    private let today = DayKey.today()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    todayCard
                    calendarCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left", action: onBack)
                .accessibilityLabel("Back")
            Spacer()
            Text("Daily Challenge").font(Theme.rounded(20, .bold)).foregroundColor(Theme.ink)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 6)
    }

    private var todayCard: some View {
        let done = game.stats.dailyStars[today] != nil
        let inProgress = game.dailyInProgress(today)
        return HStack(spacing: 14) {
            SantaiCat(mood: done ? .happy : .wave, size: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text(DayKey.shortLabel(for: today).uppercased())
                    .font(Theme.rounded(13, .heavy)).foregroundColor(.white.opacity(0.8))
                Text(done ? "Done for today!" : "Today's Puzzle")
                    .font(Theme.rounded(22, .heavy)).foregroundColor(.white)
                Text("\(DayKey.difficulty(for: today).displayName) · Same puzzle for everyone")
                    .font(Theme.rounded(13, .medium)).foregroundColor(.white.opacity(0.85))
                Button {
                    play(today)
                } label: {
                    HStack(spacing: 6) {
                        if loadingDay == today {
                            ProgressView().tint(Theme.accentDeep)
                        } else {
                            Image(systemName: done ? "arrow.clockwise" : "play.fill")
                        }
                        Text(done ? "Play Again" : (inProgress ? "Continue" : "Play"))
                    }
                    .font(Theme.rounded(16, .bold))
                    .foregroundColor(Theme.accentDeep)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF7EB0), Color(hex: 0xE84E8A), Color(hex: 0x8B5CF6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: Color(hex: 0xE84E8A).opacity(0.35), radius: 16, y: 8)
    }

    private var calendarCard: some View {
        let month = monthStart(offset: monthOffset)
        let days = daysGrid(for: month)
        let completedThisMonth = days.compactMap { $0 }.filter { game.stats.dailyStars[$0] != nil }.count
        return VStack(spacing: 14) {
            HStack {
                monthButton("chevron.left", enabled: monthOffset > -12) { monthOffset -= 1 }
                Spacer()
                VStack(spacing: 2) {
                    Text(monthTitle(month)).font(Theme.rounded(18, .bold)).foregroundColor(Theme.ink)
                    Text("\(completedThisMonth) completed").font(Theme.rounded(12, .medium)).foregroundColor(Theme.inkSoft)
                }
                Spacer()
                monthButton("chevron.right", enabled: monthOffset < 0) { monthOffset += 1 }
            }
            HStack(spacing: 0) {
                let symbols = weekdaySymbols()
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[i]).font(Theme.rounded(12, .bold)).foregroundColor(Theme.inkSoft).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, key in
                    if let key {
                        dayCell(key)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            HStack(spacing: 16) {
                legend(color: Theme.gold, text: "Completed")
                legend(color: Theme.accent, text: "Today")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
        .animation(.easeInOut(duration: 0.25), value: monthOffset)
    }

    private func dayCell(_ key: String) -> some View {
        let stars = game.stats.dailyStars[key]
        let isToday = key == today
        let isFuture = key > today
        let day = key.split(separator: "-").last.map { String(Int($0) ?? 0) } ?? ""
        return Button {
            play(key)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(stars != nil ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Color(hex: 0xF5A524)],
                                                                      startPoint: .top, endPoint: .bottom))
                                       : AnyShapeStyle(Theme.surfaceAlt))
                if isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2.5)
                }
                if loadingDay == key {
                    ProgressView()
                } else {
                    VStack(spacing: 0) {
                        Text(day).font(Theme.rounded(15, .bold))
                            .foregroundColor(stars != nil ? .white : (isFuture ? Theme.inkSoft.opacity(0.4) : Theme.ink))
                        if let stars {
                            HStack(spacing: 0) {
                                ForEach(0..<stars, id: \.self) { _ in
                                    Image(systemName: "star.fill").font(.system(size: 6))
                                }
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .disabled(isFuture || loadingDay != nil)
        .accessibilityLabel("\(DayKey.shortLabel(for: key))\(stars != nil ? ", completed" : "")")
    }

    private func monthButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            SoundManager.shared.play(.tap)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(enabled ? Theme.accent : Theme.inkSoft.opacity(0.3))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.surfaceAlt))
        }
        .disabled(!enabled)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text).font(Theme.rounded(12, .medium)).foregroundColor(Theme.inkSoft)
        }
    }

    // MARK: - Actions & dates

    private func play(_ key: String) {
        guard loadingDay == nil else { return }
        SoundManager.shared.play(.button)
        Haptics.impact(.medium)
        loadingDay = key
        game.startDaily(key) {
            loadingDay = nil
            onPlay()
        }
    }

    private func monthStart(offset: Int) -> Date {
        let now = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return calendar.date(byAdding: .month, value: offset, to: now) ?? now
    }

    /// Day keys for the month, padded with nils so the first day lands on its weekday column.
    private func daysGrid(for month: Date) -> [String?] {
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result = [String?](repeating: nil, count: leading)
        for d in 0..<count {
            if let date = calendar.date(byAdding: .day, value: d, to: month) {
                result.append(DayKey.key(for: date))
            }
        }
        return result
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(start + $0) % 7] }
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: date)
    }
}

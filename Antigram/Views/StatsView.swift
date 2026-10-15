import SwiftUI

struct StatsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    today
                    week
                    reasons
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(PanelBackground())
            .navigationTitle("Numeri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                        .font(.mono(14))
                }
            }
        }
    }

    // MARK: Oggi

    private var today: some View {
        let day = store.day()
        let personalSessions = day.sessions.filter { $0.profile == .personal }
        return VStack(alignment: .leading, spacing: 12) {
            Stamp("Oggi", color: .agText)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile("\(day.personalSeconds / 60)/\(store.dailyBudgetSeconds / 60)", "min personale")
                tile("\(personalSessions.count)", personalSessions.count == 1 ? "sessione" : "sessioni")
                tile("\(day.resisted)", "lasciato perdere")
                tile("\(day.emergencies)", "sblocchi")
                tile(Clock.minutes(day.workSeconds), store.settings.workName)
                tile(usefulText(personalSessions), "utili")
            }
        }
    }

    // MARK: Settimana

    private var week: some View {
        let days = store.lastDays(7)
        let budget = store.settings.dailyMinutes
        let peak = max(budget, days.map { $0.usage.personalSeconds / 60 }.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Stamp("Ultimi 7 giorni · personale", color: .agText)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { item in
                        let minutes = item.usage.personalSeconds / 60
                        VStack(spacing: 6) {
                            Text("\(minutes)")
                                .font(.mono(10, .semibold))
                                .foregroundStyle(Color.agDim)
                            Rectangle()
                                .fill(minutes > budget ? Color.agBright : Color.agLit)
                                .overlay(Rectangle().strokeBorder(Color.agLine, lineWidth: 1))
                                .frame(height: max(2, 120 * CGFloat(minutes) / CGFloat(peak)))
                            Text(item.date.formatted(.dateTime.weekday(.narrow)).uppercased())
                                .font(.mono(10, .semibold))
                                .foregroundStyle(Color.agDim)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 170, alignment: .bottom)
                let total = days.reduce(0) { $0 + $1.usage.personalSeconds } / 60
                Stamp("Totale \(total) min · media \(total / 7) min al giorno")
            }
            .panel()
        }
    }

    // MARK: Motivi

    private var reasons: some View {
        let sessions = store.lastDays(7).flatMap { $0.usage.sessions }.filter { $0.profile == .personal }
        return VStack(alignment: .leading, spacing: 12) {
            Stamp("Perché lo apri · 7 giorni", color: .agText)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Intention.allCases) { intention in
                    let count = sessions.filter { $0.intention == intention }.count
                    HStack {
                        Image(systemName: intention.systemImage)
                            .frame(width: 22)
                        Text(intention.title)
                        Spacer()
                        Text("\(count)")
                            .foregroundStyle(Color.agBright)
                            .monospacedDigit()
                    }
                    .font(.mono(13))
                    .foregroundStyle(Color.agText)
                }
            }
            .panel()
        }
    }

    // MARK: Pezzi

    private func tile(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.mono(22, .heavy))
                .foregroundStyle(Color.agBright)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Stamp(caption)
                .lineLimit(1)
        }
        .panel()
    }

    private func usefulText(_ sessions: [SessionRecord]) -> String {
        let answered = sessions.compactMap(\.useful)
        guard !answered.isEmpty else { return "–" }
        let yes = answered.filter { $0 }.count
        return "\(yes)/\(answered.count)"
    }
}

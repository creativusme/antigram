import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store

    let loggedIn: [ProfileKind: Bool]
    let onOpen: (ProfileKind) -> Void
    let onEmergency: () -> Void
    let onLogin: (ProfileKind) -> Void
    let onAccountsChanged: () -> Void

    @State private var showStats = false
    @State private var showSettings = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            let status = store.personalStatus(now: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    facade
                    personalTile(status, now: context.date)
                    workTile
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showStats) {
            StatsView()
                .environment(store)
        }
        .sheet(isPresented: $showSettings, onDismiss: onAccountsChanged) {
            SettingsView()
                .environment(store)
        }
    }

    // MARK: Sezioni

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ANTIGRAM")
                .font(.mono(34, .heavy))
                .tracking(6)
                .foregroundStyle(Color.agBright)
            Stamp("Instagram, senza la parte che ti mangia")
        }
    }

    private var facade: some View {
        let budgetMinutes = store.dailyBudgetSeconds / 60
        let leftSeconds = store.personalSecondsLeftToday
        let leftMinutes = Int(ceil(Double(leftSeconds) / 60))
        return VStack(alignment: .leading, spacing: 8) {
            FacadeView(total: budgetMinutes, lit: leftMinutes)
            HStack {
                Stamp("\(Clock.mmss(leftSeconds)) rimasti oggi", color: .agText)
                Spacer()
                Stamp("1 finestra = 1 min")
            }
        }
    }

    private func personalTile(_ status: PersonalStatus, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Stamp("01 · Personale", color: .agText)
                Spacer()
                Stamp(personalBadge(status))
            }

            if loggedIn[.personal] == false {
                Text("Nessun account collegato.")
                    .font(.mono(14))
                    .foregroundStyle(Color.agDim)
                Button("Accedi") { onLogin(.personal) }
                    .buttonStyle(.block)
            } else {
                switch status {
                case .available(let seconds):
                    bigValue(Clock.mmss(seconds), caption: "di sessione, poi si chiude")
                    Button {
                        Haptics.tap()
                        onOpen(.personal)
                    } label: {
                        Label("Entra", systemImage: "arrow.right")
                    }
                    .buttonStyle(.block)
                case .cooldown(let until):
                    let minutes = Int(ceil(until.timeIntervalSince(now) / 60))
                    bigValue("Pausa", caption: "riapre alle \(Clock.time(until)) · tra \(minutes) min")
                    emergencyButton
                case .exhausted:
                    bigValue("Chiuso", caption: "il tempo di oggi è finito, riapre domani")
                    emergencyButton
                }
            }
        }
        .panel()
    }

    private var emergencyButton: some View {
        Button {
            onEmergency()
        } label: {
            Label("Sblocco di emergenza", systemImage: "exclamationmark.triangle")
                .font(.mono(12, .semibold))
        }
        .buttonStyle(.block)
    }

    private var workTile: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Stamp("02 · \(store.settings.workName)", color: .agText)
                Spacer()
                Stamp("Lavoro")
            }
            if loggedIn[.work] == false {
                Text("Nessun account collegato.")
                    .font(.mono(14))
                    .foregroundStyle(Color.agDim)
                Button("Accedi") { onLogin(.work) }
                    .buttonStyle(.block)
            } else {
                bigValue(Clock.minutes(store.day().workSeconds), caption: "oggi · niente limiti, niente reels")
                Button {
                    Haptics.tap()
                    onOpen(.work)
                } label: {
                    Label("Entra", systemImage: "briefcase")
                }
                .buttonStyle(.block)
            }
        }
        .panel()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    showStats = true
                } label: {
                    Label("Numeri", systemImage: "chart.bar")
                }
                Button {
                    showSettings = true
                } label: {
                    Label("Regole", systemImage: "slider.horizontal.3")
                }
            }
            .buttonStyle(.block)

            let today = store.day()
            if today.resisted > 0 {
                Stamp("Oggi hai lasciato perdere \(today.resisted) \(today.resisted == 1 ? "volta" : "volte")")
            }
        }
    }

    // MARK: Pezzi

    private func bigValue(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.uppercased())
                .font(.mono(30, .heavy))
                .tracking(2)
                .foregroundStyle(Color.agBright)
            Text(caption)
                .font(.mono(12))
                .foregroundStyle(Color.agDim)
        }
    }

    private func personalBadge(_ status: PersonalStatus) -> String {
        if loggedIn[.personal] == false { return "Scollegato" }
        switch status {
        case .available: return "Aperto"
        case .cooldown: return "In pausa"
        case .exhausted: return "Esaurito"
        }
    }
}

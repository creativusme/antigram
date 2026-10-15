import SwiftUI

struct SessionEndView: View {
    @Environment(AppStore.self) private var store

    let record: SessionRecord
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Stamp(record.profile == .personal ? "Personale" : store.settings.workName)
                Text(title)
                    .font(.mono(34, .heavy))
                    .tracking(3)
                    .foregroundStyle(Color.agBright)
                Text(subtitle)
                    .font(.mono(13))
                    .foregroundStyle(Color.agText)
            }

            HStack(spacing: 10) {
                figure(Clock.mmss(record.seconds), caption: "questa sessione")
                if record.profile == .personal {
                    let used = store.day().personalSeconds / 60
                    figure("\(used)/\(store.dailyBudgetSeconds / 60)", caption: "minuti oggi")
                }
            }

            Spacer()

            if record.profile == .personal {
                VStack(alignment: .leading, spacing: 10) {
                    Stamp("Ti è stato utile?", color: .agText)
                    HStack(spacing: 10) {
                        Button("Sì") { answer(true) }
                        Button("No") { answer(false) }
                    }
                    .buttonStyle(.block)
                }
            } else {
                Button("Fatto", action: onClose)
                    .buttonStyle(.block)
            }
        }
        .padding(20)
        .onAppear { Haptics.warning() }
    }

    private var title: String {
        switch record.endReason {
        case .sessionLimit: return "TEMPO\nFINITO"
        case .dailyLimit: return "PER OGGI\nBASTA"
        case .leftApp: return "SESSIONE\nCHIUSA"
        case .userExit: return "USCITO"
        }
    }

    private var subtitle: String {
        switch record.endReason {
        case .sessionLimit:
            return nextSession
        case .dailyLimit:
            return "Il tempo di oggi è finito. Domani si riapre."
        case .leftApp:
            return "Sei uscito dall'app per più di un minuto e mezzo."
        case .userExit:
            return record.profile == .personal && record.seconds >= 60
                ? "Bene. \(nextSession)"
                : "Bene."
        }
    }

    private var nextSession: String {
        let minutes = store.settings.cooldownMinutes
        return minutes > 0 ? "Prossima sessione tra \(minutes) minuti." : "Prossima sessione quando vuoi."
    }

    private func figure(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.mono(24, .heavy))
                .foregroundStyle(Color.agBright)
            Stamp(caption)
        }
        .panel()
    }

    private func answer(_ useful: Bool) {
        Haptics.tap()
        store.setUseful(useful, for: record)
        onClose()
    }
}

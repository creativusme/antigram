import Foundation
import Observation

/// Stato di accesso al profilo personale.
enum PersonalStatus: Equatable {
    case available(seconds: Int)
    case cooldown(until: Date)
    case exhausted
}

struct DayEntry: Identifiable {
    let date: Date
    let usage: DayUsage
    var id: Date { date }
}

/// Impostazioni e statistiche, salvate in un unico JSON nella sandbox dell'app.
@Observable
final class AppStore {
    private(set) var settings: AppSettings
    private(set) var usage: UsageData

    private struct Persisted: Codable {
        var settings: AppSettings
        var usage: UsageData
    }

    private let fileURL: URL
    private var unsavedTicks = 0

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("antigram.json")

        if let data = try? Data(contentsOf: fileURL),
           let persisted = try? JSONDecoder.antigram.decode(Persisted.self, from: data) {
            settings = persisted.settings
            usage = persisted.usage
        } else {
            settings = AppSettings()
            usage = UsageData()
        }
    }

    func save() {
        unsavedTicks = 0
        let persisted = Persisted(settings: settings, usage: usage)
        guard let data = try? JSONEncoder.antigram.encode(persisted) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Giorni

    func day(_ date: Date = .now) -> DayUsage {
        usage.days[DayKey.of(date)] ?? DayUsage()
    }

    private func mutateDay(_ date: Date = .now, _ change: (inout DayUsage) -> Void) {
        let key = DayKey.of(date)
        var day = usage.days[key] ?? DayUsage()
        change(&day)
        usage.days[key] = day
    }

    /// Gli ultimi `count` giorni, dal più vecchio a oggi.
    func lastDays(_ count: Int, until date: Date = .now) -> [DayEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayEntry(date: day, usage: self.day(day))
        }
    }

    // MARK: Limiti

    var dailyBudgetSeconds: Int {
        settings.dailyMinutes * 60 + day().extraSeconds
    }

    var personalSecondsLeftToday: Int {
        max(0, dailyBudgetSeconds - day().personalSeconds)
    }

    func personalStatus(now: Date = .now) -> PersonalStatus {
        let left = max(0, settings.dailyMinutes * 60 + day(now).extraSeconds - day(now).personalSeconds)
        if left <= 0 { return .exhausted }
        if !usage.cooldownWaived, let last = usage.lastPersonalEnd {
            let until = last.addingTimeInterval(TimeInterval(settings.cooldownMinutes * 60))
            if until > now { return .cooldown(until: until) }
        }
        return .available(seconds: min(settings.sessionMinutes * 60, left))
    }

    /// Ogni sblocco di emergenza nello stesso giorno costa un minuto di attesa in più.
    var emergencyWaitSeconds: Int {
        60 * (day().emergencies + 1)
    }

    func grantEmergency() {
        mutateDay { day in
            day.emergencies += 1
            let left = settings.dailyMinutes * 60 + day.extraSeconds - day.personalSeconds
            let session = settings.sessionMinutes * 60
            if left < session {
                day.extraSeconds += session - max(0, left)
            }
        }
        usage.cooldownWaived = true
        save()
    }

    // MARK: Sessioni

    /// Chiamato ogni secondo durante una sessione; salva su disco ogni 10 secondi.
    func addUsage(_ seconds: Int, profile: ProfileKind) {
        mutateDay { day in
            switch profile {
            case .personal: day.personalSeconds += seconds
            case .work: day.workSeconds += seconds
            }
        }
        unsavedTicks += 1
        if unsavedTicks >= 10 { save() }
    }

    func finishSession(_ record: SessionRecord) {
        mutateDay(record.start) { $0.sessions.append(record) }
        if record.profile == .personal {
            usage.cooldownWaived = false
            // Una sbirciata sotto il minuto non fa scattare la pausa obbligatoria.
            if record.seconds >= 60 { usage.lastPersonalEnd = .now }
        }
        save()
    }

    func setUseful(_ useful: Bool, for record: SessionRecord) {
        mutateDay(record.start) { day in
            if let index = day.sessions.firstIndex(where: { $0.id == record.id }) {
                day.sessions[index].useful = useful
            }
        }
        save()
    }

    func addResisted() {
        mutateDay { $0.resisted += 1 }
        save()
    }

    // MARK: Impostazioni

    func updateSettings(_ new: AppSettings) {
        settings = new
        save()
    }
}

extension JSONEncoder {
    static let antigram: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let antigram: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

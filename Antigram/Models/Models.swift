import Foundation

// MARK: - Profili

/// I due account Instagram, ciascuno con login e cookie separati.
enum ProfileKind: String, Codable, CaseIterable, Identifiable {
    case personal
    case work

    var id: String { rawValue }

    /// Identificativo fisso del WKWebsiteDataStore: login e cookie restano tra una sessione e l'altra.
    var dataStoreID: UUID {
        switch self {
        case .personal: return UUID(uuidString: "6A1E7C1A-0000-4000-8000-000000000001")!
        case .work: return UUID(uuidString: "6A1E7C1A-0000-4000-8000-000000000002")!
        }
    }

    var isLimited: Bool { self == .personal }
}

// MARK: - Intenzioni

enum Intention: String, Codable, CaseIterable, Identifiable {
    case messages
    case feed
    case post
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .messages: return "Messaggi"
        case .feed: return "Storie e post"
        case .post: return "Pubblicare"
        case .search: return "Cercare qualcuno"
        }
    }

    var subtitle: String {
        switch self {
        case .messages: return "Solo DM. Il feed resta chiuso."
        case .feed: return "Storie e post statici di chi segui."
        case .post: return "Carica, poi esci."
        case .search: return "Trova una persona, non un passatempo."
        }
    }

    var systemImage: String {
        switch self {
        case .messages: return "bubble.left.and.bubble.right"
        case .feed: return "square.grid.2x2"
        case .post: return "plus.square"
        case .search: return "magnifyingglass"
        }
    }

    var startPath: String {
        switch self {
        case .messages: return "/direct/inbox/"
        case .search: return "/explore/search/"
        case .feed, .post: return "/"
        }
    }

    /// Secondi di respiro prima di entrare: guardare il feed costa di più.
    var breathSeconds: Int {
        self == .feed ? 15 : 8
    }
}

// MARK: - Impostazioni

struct AppSettings: Codable, Equatable {
    var sessionMinutes: Int = 5
    var dailyMinutes: Int = 20
    var cooldownMinutes: Int = 30
    var feedCap: Int = 20
    var grayscalePersonal: Bool = true
    var grayscaleWork: Bool = false
    var workName: String = "Artifex"

    func grayscaleDefault(for profile: ProfileKind) -> Bool {
        profile == .personal ? grayscalePersonal : grayscaleWork
    }

    /// Vero se `new` concede più tempo o meno attrito di `self`: in quel caso serve il cancello.
    func isLooser(_ new: AppSettings) -> Bool {
        new.sessionMinutes > sessionMinutes
            || new.dailyMinutes > dailyMinutes
            || new.cooldownMinutes < cooldownMinutes
            || new.feedCap > feedCap
    }
}

// MARK: - Statistiche

enum EndReason: String, Codable {
    case userExit
    case sessionLimit
    case dailyLimit
    case leftApp
}

struct SessionRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Date
    var seconds: Int
    var profile: ProfileKind
    var intention: Intention?
    var endReason: EndReason
    var useful: Bool?
}

struct DayUsage: Codable {
    var personalSeconds: Int = 0
    var workSeconds: Int = 0
    var extraSeconds: Int = 0
    var emergencies: Int = 0
    var resisted: Int = 0
    var sessions: [SessionRecord] = []
}

struct UsageData: Codable {
    var days: [String: DayUsage] = [:]
    var lastPersonalEnd: Date?
    var cooldownWaived: Bool = false
}

enum DayKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func of(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }
}

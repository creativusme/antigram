import Foundation
import Observation

/// Una sessione su Instagram: conta il tempo, la chiude allo scadere e la registra nelle statistiche.
@Observable
final class SessionController {
    let profile: ProfileKind
    let intention: Intention?
    let start = Date()
    /// Durata massima in secondi, `nil` per il profilo di lavoro.
    let limitSeconds: Int?
    private(set) var elapsed = 0
    private(set) var endReason: EndReason?

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let limitIsDaily: Bool
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored var onEnd: ((SessionRecord) -> Void)?

    /// Oltre questo tempo fuori dall'app la sessione personale si considera chiusa.
    private static let maxAwaySeconds: TimeInterval = 90

    init(profile: ProfileKind, intention: Intention?, store: AppStore) {
        self.profile = profile
        self.intention = intention
        self.store = store
        if profile.isLimited, case .available(let seconds) = store.personalStatus() {
            limitSeconds = seconds
            limitIsDaily = seconds < store.settings.sessionMinutes * 60
        } else if profile.isLimited {
            limitSeconds = 0
            limitIsDaily = true
        } else {
            limitSeconds = nil
            limitIsDaily = false
        }
    }

    var remaining: Int? {
        limitSeconds.map { max(0, $0 - elapsed) }
    }

    var isEnded: Bool { endReason != nil }

    func begin() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        // .common: il tempo scorre anche mentre scrolli.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard endReason == nil, backgroundedAt == nil else { return }
        elapsed += 1
        store.addUsage(1, profile: profile)
        if let limitSeconds, elapsed >= limitSeconds {
            end(limitIsDaily ? .dailyLimit : .sessionLimit)
        }
    }

    func didEnterBackground() {
        guard endReason == nil else { return }
        backgroundedAt = .now
        store.save()
    }

    func didBecomeActive() {
        guard let backgroundedAt else { return }
        self.backgroundedAt = nil
        if profile.isLimited, Date.now.timeIntervalSince(backgroundedAt) > Self.maxAwaySeconds {
            end(.leftApp)
        }
    }

    func end(_ reason: EndReason) {
        guard endReason == nil else { return }
        endReason = reason
        timer?.invalidate()
        timer = nil
        let record = SessionRecord(
            start: start,
            seconds: elapsed,
            profile: profile,
            intention: intention,
            endReason: reason
        )
        store.finishSession(record)
        onEnd?(record)
    }
}

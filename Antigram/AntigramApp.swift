import SwiftUI

@main
struct AntigramApp: App {
    @State private var store = AppStore()

    init() {
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Percorso: casa → intenzione → respiro → sessione → fine

enum Route: Hashable {
    case home
    case intention
    case breathing(Intention)
    case session
    case ended(SessionRecord)
    case emergency
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var route: Route = .home
    @State private var session: SessionController?
    @State private var browser: InstagramBrowser?
    @State private var loginProfile: ProfileKind?
    @State private var loggedIn: [ProfileKind: Bool] = [:]

    var body: some View {
        ZStack {
            PanelBackground()
            content
                .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.18), value: route)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: session?.didEnterBackground()
            case .active: session?.didBecomeActive()
            default: break
            }
        }
        .fullScreenCover(item: $loginProfile, onDismiss: refreshLogin) { profile in
            LoginView(profile: profile)
                .environment(store)
        }
        .task { refreshLogin() }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .home:
            HomeView(
                loggedIn: loggedIn,
                onOpen: open,
                onEmergency: { route = .emergency },
                onLogin: { loginProfile = $0 },
                onAccountsChanged: refreshLogin
            )
        case .intention:
            IntentionView(
                onChoose: { route = .breathing($0) },
                onResist: {
                    store.addResisted()
                    route = .home
                },
                onBack: { route = .home }
            )
        case .breathing(let intention):
            BreathingView(
                seconds: intention.breathSeconds,
                onDone: { startSession(.personal, intention: intention) },
                onCancel: {
                    store.addResisted()
                    route = .home
                }
            )
        case .session:
            if let session, let browser {
                SessionView(
                    session: session,
                    browser: browser,
                    gray: store.settings.grayscaleDefault(for: session.profile)
                )
            }
        case .ended(let record):
            SessionEndView(record: record) { route = .home }
        case .emergency:
            FrictionGateView(
                title: "Sblocco di emergenza",
                explanation: "Ti dà una sessione in più e salta la pausa. Ogni sblocco di oggi costa un minuto di attesa in più.",
                phrase: "Lo apro lo stesso, sapendo che non mi serve.",
                waitSeconds: store.emergencyWaitSeconds,
                onUnlock: {
                    store.grantEmergency()
                    route = .intention
                },
                onCancel: { route = .home }
            )
        }
    }

    private func open(_ profile: ProfileKind) {
        guard loggedIn[profile] == true else {
            loginProfile = profile
            return
        }
        switch profile {
        case .personal:
            if case .available = store.personalStatus() { route = .intention }
        case .work:
            startSession(.work, intention: nil)
        }
    }

    private func startSession(_ profile: ProfileKind, intention: Intention?) {
        let controller = SessionController(profile: profile, intention: intention, store: store)
        let browser = InstagramBrowser(
            profile: profile,
            intention: intention,
            settings: store.settings,
            gray: store.settings.grayscaleDefault(for: profile)
        )
        controller.onEnd = { record in
            browser.stop()
            self.browser = nil
            self.session = nil
            route = .ended(record)
        }
        browser.load(path: intention?.startPath ?? "/")
        self.browser = browser
        self.session = controller
        controller.begin()
        route = .session
    }

    private func refreshLogin() {
        Task {
            var result: [ProfileKind: Bool] = [:]
            for profile in ProfileKind.allCases {
                result[profile] = await InstagramBrowser.isLoggedIn(profile)
            }
            loggedIn = result
        }
    }
}

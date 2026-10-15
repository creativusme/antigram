import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store

    let session: SessionController
    let browser: InstagramBrowser

    @State private var gray: Bool
    @State private var loading = true
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    init(session: SessionController, browser: InstagramBrowser, gray: Bool) {
        self.session = session
        self.browser = browser
        _gray = State(initialValue: gray)
    }

    var body: some View {
        VStack(spacing: 0) {
            hud
            ZStack(alignment: .top) {
                InstagramWebView(browser: browser)
                if loading {
                    loadingCover
                        .transition(.opacity)
                }
                if let toast {
                    Text(toast.uppercased())
                        .font(.mono(12, .bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.agBright)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.agPanelRaised)
                        .overlay(Rectangle().strokeBorder(Color.agLine, lineWidth: 1))
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        // Instagram in tema scuro è nero: la fascia sotto la barra resta in tinta.
        .background(Color.black.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: toast)
        .animation(.easeOut(duration: 0.25), value: loading)
        .onAppear {
            browser.onEvent = handle
        }
        .onChange(of: session.elapsed) { _, elapsed in
            if let remaining = session.remaining, remaining == 60 {
                Haptics.warning()
                show("Ultimo minuto")
            }
            if session.limitSeconds == nil, elapsed > 0, elapsed % 600 == 0 {
                show("Sei qui da \(elapsed / 60) min. Ancora lavoro?")
            }
        }
    }

    // MARK: Barra in alto

    private var hud: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Stamp(profileName, color: .agText)
                if let intention = session.intention {
                    Stamp("· \(intention.title)")
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(timerText)
                    .font(.mono(15, .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.agBright)
                    .contentTransition(.numericText(countsDown: session.limitSeconds != nil))
                Button {
                    Haptics.tap()
                    gray.toggle()
                    browser.setGray(gray)
                } label: {
                    Image(systemName: gray ? "circle.lefthalf.filled" : "circle.fill")
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(gray ? "Togli scala di grigi" : "Metti scala di grigi")
                Button {
                    Haptics.tap()
                    session.end(.userExit)
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Chiudi sessione")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.agText)
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: 42)

            progressBar
        }
        .background(Color.agPanel)
    }

    @ViewBuilder
    private var progressBar: some View {
        if let limit = session.limitSeconds, limit > 0 {
            GeometryReader { proxy in
                let fraction = Double(session.remaining ?? 0) / Double(limit)
                Rectangle()
                    .fill(Color.agLit)
                    .frame(width: proxy.size.width * fraction)
                    .animation(.linear(duration: 1), value: fraction)
            }
            .frame(height: 2)
            .background(Color.agLine)
        } else {
            Rectangle().fill(Color.agLine).frame(height: 1)
        }
    }

    private var loadingCover: some View {
        ZStack {
            PanelBackground()
            VStack(spacing: 10) {
                ProgressView().tint(Color.agDim)
                Stamp("Apro il cancello")
            }
        }
    }

    private var profileName: String {
        session.profile == .personal ? "Personale" : store.settings.workName
    }

    private var timerText: String {
        if let remaining = session.remaining { return Clock.mmss(remaining) }
        return Clock.mmss(session.elapsed)
    }

    // MARK: Eventi dal browser

    private func handle(_ event: BrowserEvent) {
        switch event {
        case .loaded:
            loading = false
        case .caughtUp:
            show("Limite di post raggiunto")
        case .blocked(let reason):
            Haptics.tap()
            switch reason {
            case "reels": show("Reels chiusi")
            case "chain": show("Un reel alla volta")
            case "feed-reel": show("I reel si aprono dai DM e dai profili")
            case "explore": show("Esplora non c'è. Solo ricerca.")
            case "messages-only": show("Modalità messaggi: feed chiuso")
            default: show("Bloccato")
            }
        }
    }

    private func show(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}

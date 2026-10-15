import SwiftUI

// MARK: - Perché lo apri?

struct IntentionView: View {
    let onChoose: (Intention) -> Void
    let onResist: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: onBack) {
                Label("Indietro", systemImage: "chevron.left")
                    .font(.mono(13, .semibold))
                    .foregroundStyle(Color.agDim)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("PERCHÉ\nLO APRI?")
                    .font(.mono(34, .heavy))
                    .tracking(3)
                    .foregroundStyle(Color.agBright)
                Stamp("Una risposta. Poi conta il tempo.")
            }

            VStack(spacing: 10) {
                ForEach(Intention.allCases) { intention in
                    Button {
                        Haptics.tap()
                        onChoose(intention)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: intention.systemImage)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(intention.title)
                                Text(intention.subtitle)
                                    .font(.mono(11))
                                    .textCase(nil)
                                    .tracking(0)
                                    .foregroundStyle(Color.agDim)
                            }
                        }
                    }
                    .buttonStyle(.block)
                }
            }

            Spacer()

            Button {
                Haptics.done()
                onResist()
            } label: {
                Label("Niente, era un riflesso", systemImage: "hand.raised")
            }
            .buttonStyle(.blockProminent)
        }
        .padding(20)
    }
}

// MARK: - Respiro

struct BreathingView: View {
    let seconds: Int
    let onDone: () -> Void
    let onCancel: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var remaining: Int
    @State private var expanded = false
    @State private var timer: Timer?

    init(seconds: Int, onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.seconds = seconds
        self.onDone = onDone
        self.onCancel = onCancel
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Stamp(expanded ? "Inspira" : "Espira", color: .agText)

            Rectangle()
                .fill(Color.agPanelRaised)
                .overlay(Rectangle().strokeBorder(Color.agLine, lineWidth: 1))
                .frame(width: 180, height: 180)
                .scaleEffect(expanded ? 1 : 0.55)
                .animation(.easeInOut(duration: 4), value: expanded)

            Text("\(remaining)")
                .font(.mono(44, .heavy))
                .foregroundStyle(Color.agBright)
                .contentTransition(.numericText())

            Text("Resta qui. Se esci dall'app, si ricomincia.")
                .font(.mono(12))
                .foregroundStyle(Color.agDim)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                Haptics.done()
                stop()
                onCancel()
            } label: {
                Label("Lascia perdere", systemImage: "xmark")
            }
            .buttonStyle(.blockProminent)
        }
        .padding(20)
        .onAppear(perform: restart)
        .onDisappear(perform: stop)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { restart() } else { stop() }
        }
    }

    private func restart() {
        stop()
        remaining = seconds
        expanded = true
        var tick = 0
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            tick += 1
            if tick % 4 == 0 { expanded.toggle() }
            let left = seconds - tick
            withAnimation { remaining = left }
            if left <= 0 {
                stop()
                Haptics.done()
                onDone()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Cancello: frase da scrivere + attesa

struct FrictionGateView: View {
    let title: String
    let explanation: String
    let phrase: String
    let waitSeconds: Int
    let onUnlock: () -> Void
    let onCancel: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var typed = ""
    @State private var waiting: Int?
    @State private var timer: Timer?
    @FocusState private var focused: Bool

    private var phraseMatches: Bool {
        Self.normalize(typed) == Self.normalize(phrase)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button {
                    stop()
                    onCancel()
                } label: {
                    Label("Lascia perdere", systemImage: "chevron.left")
                        .font(.mono(13, .semibold))
                        .foregroundStyle(Color.agDim)
                }

                Text(title.uppercased())
                    .font(.mono(28, .heavy))
                    .tracking(3)
                    .foregroundStyle(Color.agBright)
                Text(explanation)
                    .font(.mono(13))
                    .foregroundStyle(Color.agText)

                VStack(alignment: .leading, spacing: 10) {
                    Stamp("1 · Scrivi, senza incollare")
                    Text("“\(phrase)”")
                        .font(.mono(15, .semibold))
                        .foregroundStyle(Color.agBright)
                    TextField("", text: $typed, axis: .vertical)
                        .font(.mono(15))
                        .foregroundStyle(Color.agBright)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .padding(12)
                        .background(Color.agBackground)
                        .overlay(Rectangle().strokeBorder(phraseMatches ? Color.agLit : Color.agLine, lineWidth: 1))
                        .disabled(waiting != nil)
                }
                .panel()

                VStack(alignment: .leading, spacing: 10) {
                    Stamp("2 · Aspetta \(waitSeconds) secondi qui dentro")
                    if let waiting {
                        Text(waiting > 0 ? Clock.mmss(waiting) : "Fatto")
                            .font(.mono(30, .heavy))
                            .foregroundStyle(Color.agBright)
                            .contentTransition(.numericText())
                        if waiting > 0 {
                            Text("Se esci dall'app, l'attesa ricomincia.")
                                .font(.mono(12))
                                .foregroundStyle(Color.agDim)
                        }
                    } else {
                        Button("Inizia l'attesa") {
                            focused = false
                            startWaiting()
                        }
                        .buttonStyle(.block)
                        .disabled(!phraseMatches)
                        .opacity(phraseMatches ? 1 : 0.4)
                    }
                }
                .panel()

                if waiting == 0 {
                    Button {
                        Haptics.warning()
                        onUnlock()
                    } label: {
                        Label("Sblocca", systemImage: "lock.open")
                    }
                    .buttonStyle(.blockProminent)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onDisappear(perform: stop)
        .onChange(of: typed) { old, new in
            // Più di qualche carattere alla volta = incollato: non vale.
            if new.count - old.count > 3 { typed = old }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, let waiting, waiting > 0 {
                stop()
                self.waiting = nil
            }
        }
    }

    private func startWaiting() {
        stop()
        waiting = waitSeconds
        var left = waitSeconds
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            left -= 1
            withAnimation { waiting = max(0, left) }
            if left <= 0 {
                stop()
                Haptics.done()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Ignora maiuscole, accenti, apostrofi tipografici e spazi doppi.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

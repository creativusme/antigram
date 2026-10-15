import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = AppSettings()
    @State private var showGate = false
    @State private var loginProfile: ProfileKind?
    @State private var logoutProfile: ProfileKind?
    @State private var loggedIn: [ProfileKind: Bool] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    stepper("Sessione", value: $draft.sessionMinutes, range: 1...30, step: 1, unit: "min")
                    stepper("Totale al giorno", value: $draft.dailyMinutes, range: 5...120, step: 5, unit: "min")
                    stepper("Pausa tra sessioni", value: $draft.cooldownMinutes, range: 0...180, step: 5, unit: "min")
                    stepper("Post nel feed", value: $draft.feedCap, range: 5...100, step: 5, unit: "")
                } header: {
                    Stamp("Limiti · profilo personale")
                } footer: {
                    Text("Stringere è gratis. Allargare costa una frase e un minuto di attesa.")
                        .font(.mono(11))
                        .foregroundStyle(Color.agDim)
                }
                .listRowBackground(Color.agPanel)

                Section {
                    Toggle("Personale", isOn: $draft.grayscalePersonal)
                    Toggle(draft.workName, isOn: $draft.grayscaleWork)
                } header: {
                    Stamp("Scala di grigi all'apertura")
                } footer: {
                    Text("Durante la sessione si cambia con il cerchio in alto.")
                        .font(.mono(11))
                        .foregroundStyle(Color.agDim)
                }
                .listRowBackground(Color.agPanel)

                Section {
                    TextField("Nome", text: $draft.workName)
                        .autocorrectionDisabled()
                } header: {
                    Stamp("Nome del profilo di lavoro")
                }
                .listRowBackground(Color.agPanel)

                Section {
                    ForEach(ProfileKind.allCases) { profile in
                        accountRow(profile)
                    }
                } header: {
                    Stamp("Account")
                } footer: {
                    Text("I due profili non condividono niente: login, cookie e cronologia sono separati.")
                        .font(.mono(11))
                        .foregroundStyle(Color.agDim)
                }
                .listRowBackground(Color.agPanel)

                Section {
                    infoRow("Reels", "Chiusi. Si aprono solo quelli ricevuti in DM o dal profilo di qualcuno, uno alla volta.")
                    infoRow("Esplora", "Sostituito dalla ricerca di persone.")
                    infoRow("Feed", "Solo foto e caroselli di chi segui. Niente suggeriti, niente pubblicità.")
                    infoRow("Fuori dall'app", "Oltre 90 secondi fuori, la sessione personale si chiude.")
                } header: {
                    Stamp("Come funziona")
                }
                .listRowBackground(Color.agPanel)

                Section {
                    Text("Antigram \(Bundle.main.appVersion)")
                        .font(.mono(12))
                        .foregroundStyle(Color.agDim)
                }
                .listRowBackground(Color.agPanel)
            }
            .concreteForm()
            .navigationTitle("Regole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                        .font(.mono(14))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save)
                        .font(.mono(14, .bold))
                        .disabled(draft == store.settings)
                }
            }
            .fullScreenCover(isPresented: $showGate) {
                ZStack {
                    PanelBackground()
                    FrictionGateView(
                        title: "Più tempo?",
                        explanation: "Stai allargando i limiti. Se è una decisione, reggerà un minuto di attesa.",
                        phrase: "Mi sto dando più tempo e lo so.",
                        waitSeconds: 60,
                        onUnlock: {
                            store.updateSettings(draft)
                            showGate = false
                            dismiss()
                        },
                        onCancel: { showGate = false }
                    )
                }
            }
            .fullScreenCover(item: $loginProfile, onDismiss: refresh) { profile in
                LoginView(profile: profile)
                    .environment(store)
            }
            .confirmationDialog(
                "Uscire dall'account?",
                isPresented: Binding(get: { logoutProfile != nil }, set: { if !$0 { logoutProfile = nil } }),
                titleVisibility: .visible
            ) {
                Button("Esci", role: .destructive) {
                    guard let profile = logoutProfile else { return }
                    Task {
                        await InstagramBrowser.logOut(profile)
                        refresh()
                    }
                }
            }
        }
        .onAppear {
            draft = store.settings
            refresh()
        }
    }

    // MARK: Righe

    private func stepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text(unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)")
                    .foregroundStyle(Color.agBright)
                    .monospacedDigit()
            }
        }
    }

    private func accountRow(_ profile: ProfileKind) -> some View {
        let name = profile == .personal ? "Personale" : draft.workName
        let connected = loggedIn[profile] == true
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Stamp(connected ? "Collegato" : "Non collegato")
            }
            Spacer()
            if connected {
                Button("Esci") { logoutProfile = profile }
                    .font(.mono(13, .semibold))
            } else {
                Button("Accedi") { loginProfile = profile }
                    .font(.mono(13, .semibold))
            }
        }
        .buttonStyle(.borderless)
    }

    private func infoRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Stamp(title, color: .agText)
            Text(text)
                .font(.mono(12))
                .foregroundStyle(Color.agDim)
        }
        .padding(.vertical, 2)
    }

    // MARK: Azioni

    private func save() {
        draft.workName = draft.workName.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.workName.isEmpty { draft.workName = "Lavoro" }
        if store.settings.isLooser(draft) {
            showGate = true
        } else {
            store.updateSettings(draft)
            dismiss()
        }
    }

    private func refresh() {
        Task {
            var result: [ProfileKind: Bool] = [:]
            for profile in ProfileKind.allCases {
                result[profile] = await InstagramBrowser.isLoggedIn(profile)
            }
            loggedIn = result
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

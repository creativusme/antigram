import SwiftUI

/// Accesso a un profilo. Il tempo non conta, ma appena il login riesce la pagina si chiude:
/// non è una porta di servizio per scrollare.
struct LoginView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let profile: ProfileKind

    @State private var browser: InstagramBrowser?
    @State private var done = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Stamp("Accedi · \(profile == .personal ? "Personale" : store.settings.workName)", color: .agText)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .foregroundStyle(Color.agText)
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: 42)
            .background(Color.agPanel)

            ZStack {
                if let browser {
                    InstagramWebView(browser: browser)
                }
                if done {
                    ZStack {
                        PanelBackground()
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .bold))
                            Stamp("Accesso fatto", color: .agText)
                        }
                        .foregroundStyle(Color.agBright)
                    }
                    .transition(.opacity)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: done)
        .task {
            let browser = InstagramBrowser(
                profile: profile,
                intention: nil,
                settings: store.settings,
                gray: false,
                restrictPaths: false
            )
            browser.load(path: "/accounts/login/")
            self.browser = browser
            await waitForLogin(browser)
        }
    }

    private func waitForLogin(_ browser: InstagramBrowser) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.5))
            if await browser.isLoggedIn() {
                Haptics.done()
                done = true
                browser.stop()
                try? await Task.sleep(for: .seconds(0.9))
                dismiss()
                return
            }
        }
    }
}

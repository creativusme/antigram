import SwiftUI
import UIKit
import WebKit

enum BrowserEvent {
    case blocked(String)
    case caughtUp
    case loaded
}

/// Il browser nascosto: un WKWebView su instagram.com mobile, con lo script di Antigram
/// e tutte le rifiniture che lo fanno sembrare un'app e non una pagina web.
final class InstagramBrowser: NSObject {
    let profile: ProfileKind
    let webView: WKWebView
    var onEvent: ((BrowserEvent) -> Void)?

    private var scriptConfig: ScriptConfig
    private let restrictPaths: Bool

    static let baseURL = URL(string: "https://www.instagram.com")!

    /// - Parameter restrictPaths: `false` durante il login, quando serve passare da pagine qualsiasi.
    init(profile: ProfileKind, intention: Intention?, settings: AppSettings, gray: Bool, restrictPaths: Bool = true) {
        self.profile = profile
        self.restrictPaths = restrictPaths
        scriptConfig = ScriptConfig(
            profile: profile.rawValue,
            intention: intention?.rawValue,
            gray: gray,
            feedCap: settings.feedCap
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.dataStoreID)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.applicationNameForUserAgent = Self.safariUserAgentSuffix
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.userContentController = WKUserContentController()

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        configuration.userContentController.add(WeakScriptHandler(self), name: "antigram")
        installScripts()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.agBackground
        webView.overrideUserInterfaceStyle = .dark
        webView.scrollView.backgroundColor = UIColor.agBackground
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.hideInputAccessoryBar()
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "antigram")
    }

    /// Come Safari su iPhone: Instagram serve la versione mobile completa, senza "browser non supportato".
    private static var safariUserAgentSuffix: String {
        let major = UIDevice.current.systemVersion.split(separator: ".").first ?? "17"
        return "Version/\(major).0 Mobile/15E148 Safari/604.1"
    }

    private func installScripts() {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(
            source: InjectedScript.configSource(scriptConfig),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: InjectedScript.main,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
    }

    func load(path: String) {
        guard let url = URL(string: path, relativeTo: Self.baseURL) else { return }
        webView.load(URLRequest(url: url))
    }

    func setGray(_ on: Bool) {
        scriptConfig.gray = on
        installScripts()
        webView.evaluateJavaScript("window.__agSetGray && window.__agSetGray(\(on))")
    }

    func stop() {
        webView.stopLoading()
        webView.evaluateJavaScript("document.querySelectorAll('video,audio').forEach(function(m){m.pause()})")
        webView.loadHTMLString("", baseURL: nil)
    }

    // MARK: Account

    func isLoggedIn() async -> Bool {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        return cookies.contains { $0.name == "sessionid" && $0.domain.contains("instagram.com") && !$0.value.isEmpty }
    }

    static func isLoggedIn(_ profile: ProfileKind) async -> Bool {
        let store = WKWebsiteDataStore(forIdentifier: profile.dataStoreID)
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { $0.name == "sessionid" && $0.domain.contains("instagram.com") && !$0.value.isEmpty }
    }

    static func logOut(_ profile: ProfileKind) async {
        let store = WKWebsiteDataStore(forIdentifier: profile.dataStoreID)
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }

    // MARK: Domini

    private static let allowedHostSuffixes = [
        "instagram.com", "cdninstagram.com", "facebook.com", "fb.com", "fbcdn.net", "fbsbx.com"
    ]

    private static func isAllowed(host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return allowedHostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    fileprivate func present(_ alert: UIAlertController) -> Bool {
        guard var top = webView.window?.rootViewController else { return false }
        while let presented = top.presentedViewController { top = presented }
        top.present(alert, animated: true)
        return true
    }
}

// MARK: - Regole per i caricamenti completi (lo script gestisce la navigazione interna)

enum PathRules {
    static func fullLoadBlock(path rawPath: String, profile: ProfileKind) -> String? {
        let path = rawPath.hasSuffix("/") ? rawPath : rawPath + "/"
        if path == "/reels/" { return "reels" }
        if path.hasPrefix("/explore/") && !path.hasPrefix("/explore/search/") { return "explore" }
        if profile == .personal, !path.hasPrefix("/reel"), path.hasSuffix("/reels/"),
           path.split(separator: "/").count == 2 {
            return "reels"
        }
        return nil
    }
}

// MARK: - WKNavigationDelegate

extension InstagramBrowser: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }
        if ["about", "blob", "data"].contains(scheme) {
            decisionHandler(.allow)
            return
        }
        // instagram://, itms-apps:// e simili: niente app ufficiale, niente App Store.
        guard scheme == "https" || scheme == "http" else {
            decisionHandler(.cancel)
            return
        }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame else {
            decisionHandler(.allow)
            return
        }
        guard Self.isAllowed(host: url.host) else {
            // Link esterni (siti nelle bio, link nei DM): si aprono in Safari.
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        if restrictPaths, url.host?.lowercased().hasSuffix("instagram.com") == true {
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            if let reason = PathRules.fullLoadBlock(path: path, profile: profile) {
                decisionHandler(.cancel)
                onEvent?(.blocked(reason))
                if reason == "explore" {
                    load(path: "/explore/search/")
                } else if webView.url == nil || webView.url?.absoluteString == "about:blank" {
                    load(path: "/")
                }
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        onEvent?(.loaded)
    }

    /// Senza rete o con un errore: si toglie comunque la copertura, così si vede cosa succede.
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onEvent?(.loaded)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - WKUIDelegate

extension InstagramBrowser: WKUIDelegate {
    /// target="_blank" e window.open: stessa vista se è Instagram, Safari altrimenti.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            if Self.isAllowed(host: url.host) {
                webView.load(navigationAction.request)
            } else if url.scheme == "https" || url.scheme == "http" {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(origin.host.hasSuffix("instagram.com") ? .grant : .deny)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        if !present(alert) { completionHandler() }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        if !present(alert) { completionHandler(false) }
    }
}

// MARK: - Messaggi dallo script

extension InstagramBrowser: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "blocked":
            onEvent?(.blocked(body["reason"] as? String ?? ""))
        case "caughtUp":
            onEvent?(.caughtUp)
        default:
            break
        }
    }
}

/// Evita il ciclo di riferimenti WKUserContentController → handler → browser.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - SwiftUI

struct InstagramWebView: UIViewRepresentable {
    let browser: InstagramBrowser

    func makeUIView(context: Context) -> WKWebView {
        browser.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

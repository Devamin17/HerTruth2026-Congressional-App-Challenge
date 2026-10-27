import SwiftUI
import UIKit
import WebKit

/// Shows hertruth.html from the app bundle in a WKWebView.
///
/// - The check itself makes no network requests. Only the Find help map talks to OpenStreetMap (map tiles, and the
///   place someone types or their location if they allow it). Links to outside sites open in Safari.
/// - The camera is used only when someone taps "Take or add a photo" or "Photo of the lab report". iOS then shows its
///   own Take Photo / Photo Library menu. Photos stay in the page's memory and are gone when the app closes.
/// - window.print() does nothing inside an app on its own, so the page's Print button opens the iOS print sheet,
///   which can also save the summary as a PDF.
struct HerTruthWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // OpenStreetMap's tile policy asks apps to identify themselves in the User-Agent
        config.applicationNameForUserAgent = "HerTruth/1.0 (org.thefactorfoundation.hertruth)"
        let printHook = WKUserScript(
            source: "window.print = function () { window.webkit.messageHandlers.print.postMessage(null); };",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true)
        config.userContentController.addUserScript(printHook)
        config.userContentController.add(context.coordinator, name: "print")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        let paper = UIColor(red: 1.0, green: 251.0 / 255.0, blue: 252.0 / 255.0, alpha: 1.0)
        webView.isOpaque = false
        webView.backgroundColor = paper
        webView.scrollView.backgroundColor = paper
        context.coordinator.webView = webView

        if let page = Bundle.main.url(forResource: "hertruth", withExtension: "html") {
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("<p style='font:17px -apple-system;padding:24px'>hertruth.html is missing from the app. Run python3 source/sync_apps.py, then build again.</p>", baseURL: nil)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?

        /// Keep the app on its own page; send web, email and phone links to the system (Safari, Mail, Phone).
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { return .allow }
            if ["http", "https", "mailto", "tel"].contains(scheme) {
                _ = await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }

        /// Links with target="_blank" ask for a new window; open them in Safari instead.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url { UIApplication.shared.open(url) }
            return nil
        }

        /// The page's Print button: print or save the summary as a PDF with the iOS print sheet.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "print", let webView else { return }
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = "HerTruth summary"
            info.outputType = .general
            let printer = UIPrintInteractionController.shared
            printer.printInfo = info
            printer.printFormatter = webView.viewPrintFormatter()
            printer.present(animated: true)
        }
    }
}

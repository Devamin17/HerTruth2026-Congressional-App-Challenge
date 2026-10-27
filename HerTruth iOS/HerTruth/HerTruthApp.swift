import SwiftUI

/// HerTruth for iPhone. The app shows the same tested HerTruth page that runs on the website,
/// bundled inside the app, so it works with no internet connection and sends nothing anywhere.
@main
struct HerTruthApp: App {
    var body: some Scene {
        WindowGroup {
            HerTruthWebView()
                .background(Color.herTruthPaper)
                // The page pads itself for the home indicator (env(safe-area-inset-bottom)), so let it reach the bottom edge
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

extension Color {
    /// The page background (#FFFBFC), shown behind the status bar so the app looks like one surface
    static let herTruthPaper = Color(red: 1.0, green: 251.0 / 255.0, blue: 252.0 / 255.0)
}

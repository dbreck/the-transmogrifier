import SwiftUI

@main
struct TransmogrifierApp: App {
    @StateObject private var appearanceManager = AppearanceManager()

    var body: some Scene {
        WindowGroup("The Transmogrifier") {
            ContentView(appearanceManager: appearanceManager)
                .frame(minWidth: 1280, minHeight: 768)
                .frame(idealWidth: 1500, idealHeight: 900)
                .preferredColorScheme(.dark)
                .background(Color(red: 0.047, green: 0.047, blue: 0.047))
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .help) {
                Button("The Transmogrifier Help") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenHelpWindow"),
                        object: nil
                    )
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        // Help window
        WindowGroup("Help", id: "help") {
            HelpView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.dark)
                .background(Color.gray900)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}

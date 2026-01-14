import AppKit
import SwiftUI

@MainActor
class HelpWindowManager: ObservableObject {
    static let shared = HelpWindowManager()

    private var helpWindowController: NSWindowController?

    private init() {}

    func showHelpWindow() {
        if let controller = helpWindowController, let window = controller.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
        } else {
            let helpWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            helpWindow.title = "Help"
            helpWindow.minSize = NSSize(width: 800, height: 600)
            helpWindow.center()
            helpWindow.isReleasedWhenClosed = false // Keep window around when closed

            // Create hosting controller instead of hosting view
            let helpView = HelpView()
                .preferredColorScheme(.dark)
                .background(Color.gray900)

            helpWindow.contentViewController = NSHostingController(rootView: helpView)

            let controller = NSWindowController(window: helpWindow)
            helpWindowController = controller
            controller.showWindow(nil)
        }
    }
}

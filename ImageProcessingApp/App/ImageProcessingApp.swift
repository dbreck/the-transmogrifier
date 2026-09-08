import SwiftUI

@main
struct TransmogrifierApp: App {
  @NSApplicationDelegateAdaptor(OpenFilesDelegate.self) private var fileOpener
  @StateObject private var historyManager = HistoryManager()
  @StateObject private var appearanceManager = AppearanceManager()

  var body: some Scene {
    WindowGroup("The Transmogrifier") {
      ContentView(
        appearanceManager: appearanceManager, fileOpener: fileOpener, historyManager: historyManager
      )
      .onOpenURL { fileOpener.receive($0) }
      .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
      .frame(minWidth: 1000, minHeight: 680)
      .frame(idealWidth: 1180, idealHeight: 860)
      .preferredColorScheme(.dark)
      .background(Color(red: 0.047, green: 0.047, blue: 0.047))
    }
    .windowStyle(.hiddenTitleBar)
    .handlesExternalEvents(matching: ["*"])
    .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    .commands {
      ExportCommands()
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

struct ExportActions {
  var canImport: Bool
  var canProcess: Bool
  var addImages: () -> Void
  var process: () -> Void
}
private struct ExportActionsKey: FocusedValueKey { typealias Value = ExportActions }
extension FocusedValues {
  var exportActions: ExportActions? {
    get { self[ExportActionsKey.self] }
    set { self[ExportActionsKey.self] = newValue }
  }
}
struct ExportCommands: Commands {
  @FocusedValue(\.exportActions) private var actions
  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("Add Images…") { actions?.addImages() }.keyboardShortcut("o", modifiers: .command)
        .disabled(actions?.canImport != true)
      Button("Process Images") { actions?.process() }.keyboardShortcut(.return, modifiers: .command)
        .disabled(actions?.canProcess != true)
    }
  }
}

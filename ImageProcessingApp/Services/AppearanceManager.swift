import SwiftUI

@MainActor
class AppearanceManager: ObservableObject {
    @Published var colorScheme: ColorScheme {
        didSet {
            UserDefaults.standard.set(colorScheme == .dark ? "dark" : "light", forKey: "ColorScheme")
        }
    }
    
    init() {
        let savedScheme = UserDefaults.standard.string(forKey: "ColorScheme")
        switch savedScheme {
        case "dark":
            self.colorScheme = .dark
        case "light":
            self.colorScheme = .light
        default:
            // Use system default
            self.colorScheme = .light
        }
    }
    
    /// Toggle between light and dark mode
    func toggleColorScheme() {
        colorScheme = colorScheme == .light ? .dark : .light
    }
    
    /// Set color scheme to light
    func setLightMode() {
        colorScheme = .light
    }
    
    /// Set color scheme to dark
    func setDarkMode() {
        colorScheme = .dark
    }
    
    /// Set color scheme to system default
    func setSystemMode() {
        // For simplicity, we'll set it to light mode
        // In a real app, you might want to detect system preference
        colorScheme = .light
    }
}
import SwiftUI

// MARK: - Color System
extension Color {
    // Style Guide colors
    // Primary Background: #1a1d29
    static let gray900 = Color(red: 0x1a/255.0, green: 0x1d/255.0, blue: 0x29/255.0)
    // Card/Panel Background: #242938
    static let gray800 = Color(red: 0x24/255.0, green: 0x29/255.0, blue: 0x38/255.0)
    // Intermediate surface used for inputs, secondary buttons
    static let gray700 = Color(red: 0x2c/255.0, green: 0x33/255.0, blue: 0x45/255.0)
    // Border/Divider: #374151
    static let gray600 = Color(red: 0x37/255.0, green: 0x41/255.0, blue: 0x51/255.0)
    // Text Secondary: #9ca3af
    static let gray400 = Color(red: 0x9c/255.0, green: 0xa3/255.0, blue: 0xaf/255.0)
    // Tertiary text
    static let gray500 = Color(red: 0x64/255.0, green: 0x74/255.0, blue: 0x8b/255.0)
    static let gray300 = Color.white // Text Primary fallback usage
    
    // Primary Blue: #4f7df7
    static let blue600 = Color(red: 0x4f/255.0, green: 0x7d/255.0, blue: 0xf7/255.0)
    static let blue700 = Color(red: 0x3f/255.0, green: 0x65/255.0, blue: 0xc6/255.0)
    static let blue900 = Color(red: 0x22/255.0, green: 0x34/255.0, blue: 0x7b/255.0)
    
    static let red500 = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let yellow500 = Color(red: 0.918, green: 0.765, blue: 0.157)
    static let green500 = Color(red: 0.133, green: 0.694, blue: 0.298)
}

// Expose custom colors for use as ShapeStyle
extension ShapeStyle where Self == Color {
    static var gray900: Color { Color.gray900 }
    static var gray800: Color { Color.gray800 }
    static var gray700: Color { Color.gray700 }
    static var gray600: Color { Color.gray600 }
    static var gray500: Color { Color.gray500 }
    static var gray400: Color { Color.gray400 }
    static var gray300: Color { Color.gray300 }
    static var blue600: Color { Color.blue600 }
    static var blue700: Color { Color.blue700 }
    static var blue900: Color { Color.blue900 }
    static var red500: Color { Color.red500 }
    static var yellow500: Color { Color.yellow500 }
    static var green500: Color { Color.green500 }
}

// MARK: - Typography (Style Guide)
extension Font {
    // Headings: 16px, medium
    static let cardTitle = Font.system(size: 16, weight: .medium)
    // App/window title
    static let transmogrifierTitle = Font.system(size: 16, weight: .medium)
    // Labels: 12px, medium
    static let label = Font.system(size: 12, weight: .medium)
    // File metadata: 11px, regular
    static let small = Font.system(size: 11, weight: .regular)
}

// MARK: - Spacing (Style Guide)
public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    // Element spacing: 16px vertical, 12px horizontal
    public static let md: CGFloat = 16
    public static let hmd: CGFloat = 12 // horizontal medium
    public static let lg: CGFloat = 24 // container padding
    public static let card: CGFloat = 20 // card padding
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

// MARK: - Custom Components
public struct MacOSWindowHeader: View {
    public init() {}
    
    public var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(.red500).frame(width: 12, height: 12)
                Circle().fill(.yellow500).frame(width: 12, height: 12)
                Circle().fill(.green500).frame(width: 12, height: 12)
            }
            Spacer()
            // Removed centered static title
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
        .background(.gray900)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.gray600), alignment: .bottom)
    }
}

public struct TransmogrifierCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    public init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                if !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(title)
                        .font(.cardTitle)
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.card)
            .padding(.top, Spacing.card)
            .padding(.bottom, Spacing.md)
            
            // Content
            content
                .padding(.horizontal, Spacing.card)
                .padding(.bottom, Spacing.card)
        }
        .background(.gray800)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.gray600, lineWidth: 1)
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4) // Style guide shadow
    }
}

public struct TransmogrifierButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let isDisabled: Bool
    let action: () -> Void
    
    public enum ButtonStyle {
        case primary
        case secondary
        case outline
    }
    
    public init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 14)) }
                Text(title).font(.label)
            }
            .padding(.horizontal, Spacing.hmd)
            .padding(.vertical, 8)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
            .cornerRadius(6)
        }
        .disabled(isDisabled)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isDisabled ? .gray700 : .blue600
        case .secondary:
            return .clear // Style guide: transparent with border
        case .outline:
            return .clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .gray300
        case .outline:
            return .gray300
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary:
            return .clear
        case .secondary:
            return .gray600
        case .outline:
            return .gray600
        }
    }
}

public struct TransmogrifierTextField: View {
    let placeholder: String
    @Binding var text: String
    
    public init(placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    
    public var body: some View {
        TextField(placeholder, text: $text)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.hmd)
            .padding(.vertical, 8)
            .background(.gray700)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray600, lineWidth: 1))
            .cornerRadius(6)
    }
}

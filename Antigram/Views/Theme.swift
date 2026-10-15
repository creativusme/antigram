import SwiftUI
import UIKit

// MARK: - Palette: cemento, a nessuno viene voglia di restare

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static let agBackground = UIColor(hex: 0x1E1D1C)
    static let agPanel = UIColor(hex: 0x2A2928)
    static let agPanelRaised = UIColor(hex: 0x343331)
    static let agLine = UIColor(hex: 0x4A4946)
    static let agText = UIColor(hex: 0xBDBBB5)
    static let agDim = UIColor(hex: 0x7D7B76)
    static let agBright = UIColor(hex: 0xD9D7D0)
    static let agLit = UIColor(hex: 0x9C9A93)
}

extension Color {
    static let agBackground = Color(uiColor: .agBackground)
    static let agPanel = Color(uiColor: .agPanel)
    static let agPanelRaised = Color(uiColor: .agPanelRaised)
    static let agLine = Color(uiColor: .agLine)
    static let agText = Color(uiColor: .agText)
    static let agDim = Color(uiColor: .agDim)
    static let agBright = Color(uiColor: .agBright)
    static let agLit = Color(uiColor: .agLit)
}

extension Font {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum Appearance {
    static func configure() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = .agBackground
        navigation.shadowColor = .agLine
        let titleFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        navigation.titleTextAttributes = [.font: titleFont, .foregroundColor: UIColor.agBright, .kern: 2]
        navigation.largeTitleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: UIColor.agBright,
            .kern: 3
        ]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().tintColor = .agText
    }
}

// MARK: - Componenti

/// Sfondo a pannelli prefabbricati: le fughe tra le lastre di un palazzone.
struct PanelBackground: View {
    var body: some View {
        Canvas { context, size in
            let panelWidth: CGFloat = 96
            let panelHeight: CGFloat = 132
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += panelWidth
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += panelHeight
            }
            context.stroke(path, with: .color(Color.agLine.opacity(0.22)), lineWidth: 1)
        }
        .background(Color.agBackground)
        .ignoresSafeArea()
    }
}

/// Etichetta piccola, maiuscola, spaziata: come la targhetta di una scala condominiale.
struct Stamp: View {
    let text: String
    var color: Color = .agDim

    init(_ text: String, color: Color = .agDim) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.mono(11, .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

struct BlockButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(15, .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(prominent ? Color.agBackground : Color.agBright)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(prominent ? Color.agLit : (configuration.isPressed ? Color.agPanelRaised : Color.agPanel))
            .overlay(Rectangle().strokeBorder(Color.agLine, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == BlockButtonStyle {
    static var block: BlockButtonStyle { BlockButtonStyle() }
    static var blockProminent: BlockButtonStyle { BlockButtonStyle(prominent: true) }
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.agPanel)
            .overlay(Rectangle().strokeBorder(Color.agLine, lineWidth: 1))
    }
}

extension View {
    func panel() -> some View { modifier(PanelModifier()) }

    func concreteForm() -> some View {
        scrollContentBackground(.hidden)
            .background(PanelBackground())
            .font(.mono(14))
            .foregroundStyle(Color.agText)
            .tint(Color.agLit)
    }
}

/// La facciata del palazzo: ogni finestra accesa è un minuto che ti resta oggi.
struct FacadeView: View {
    let total: Int
    let lit: Int
    var columns = 10

    var body: some View {
        let rows = max(1, Int(ceil(Double(max(total, 1)) / Double(columns))))
        VStack(spacing: 6) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        window(index: index)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.agPanel)
        .overlay(Rectangle().strokeBorder(Color.agLine, lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("\(lit) minuti rimasti su \(total)")
    }

    @ViewBuilder
    private func window(index: Int) -> some View {
        if index < total {
            Rectangle()
                .fill(index < lit ? Color.agLit : Color.agBackground)
                .overlay(Rectangle().strokeBorder(Color.agLine, lineWidth: 1))
                .aspectRatio(0.78, contentMode: .fit)
        } else {
            Rectangle().fill(Color.clear).aspectRatio(0.78, contentMode: .fit)
        }
    }
}

// MARK: - Formattazione

enum Clock {
    static func mmss(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func minutes(_ seconds: Int) -> String {
        "\(Int((Double(max(0, seconds)) / 60).rounded())) min"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func done() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

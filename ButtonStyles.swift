import SwiftUI

// MARK: - Общие стили нажатия и радио-контрол
//
// Вынесены из CardRow.swift, чтобы ими могли пользоваться и новая сетка
// (DesignTile), и legacy-список одновременно. CardRow уезжает в legacy,
// а эти примитивы остаются в живом пути.

// MARK: - Radio (Figma «RadioButton», node …:374:39)
//
// Box 24×24. Unselected: ОДНА тонкая серая окружность, инсет 12.5% от 24 (=3pt
// с каждой стороны) → диаметр 18. Selected: заполненное розовое кольцо + точка.
struct RadioButton: View {
    let isOn: Bool
    let f: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? Tokens.accentPink : Color.white.opacity(0.35),
                              lineWidth: isOn ? 2 * f : 1 * f)
                .frame(width: (isOn ? 20 : 18) * f, height: (isOn ? 20 : 18) * f)
            Circle()
                .fill(Tokens.accentPink)
                .frame(width: 10 * f, height: 10 * f)
                .scaleEffect(isOn ? 1 : 0.001)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 24 * f, height: 24 * f)
        .animation(MotionTokens.transition(reduceMotion: reduceMotion), value: isOn)
    }
}

// MARK: - Стиль кнопки: масштаб при нажатии на единой пружине (принципы 1, 7, 10)
struct PressScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(MotionTokens.transition(reduceMotion: reduceMotion),
                       value: configuration.isPressed)
    }
}

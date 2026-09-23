import SwiftUI

// MARK: - Главная кнопка внизу экрана (Figma 150:25526)
//
// Один источник правды для всех вариантов A/B/C: раньше этот блок был
// продублирован в футере сетки и в шите карусели, и правку приходилось
// делать дважды.
struct PrimaryButton: View {
    /// Подпись. nil → «Выбран»/«Выбрать» по состоянию (вариант A).
    var title: String? = nil
    /// Дизайн уже применён — кнопка гаснет (если не переопределено).
    var isAlreadyApplied: Bool = false
    /// Всегда активна (варианты B и C: «Продолжить», «Применить дизайн»).
    var alwaysEnabled: Bool = false
    let f: CGFloat
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var disabled: Bool { !alwaysEnabled && isAlreadyApplied }
    private var label: String { title ?? (isAlreadyApplied ? "Выбран" : "Выбрать") }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15 * f, weight: .medium))
                .tracking(0.3)
                // disabled: text/inner_disabled = белый 80%
                .foregroundStyle(.white.opacity(disabled ? 0.8 : 1))
                .frame(maxWidth: .infinity)
                .frame(height: 48 * f)
                // disabled: bg/button/primary_disabled = #D3EDAB
                .background(disabled ? Tokens.buttonPrimaryDisabled : Tokens.buttonPrimary)
                .clipShape(Capsule())
        }
        .disabled(disabled)
        .animation(MotionTokens.transition(reduceMotion: reduceMotion), value: disabled)
        .buttonStyle(PressScaleButtonStyle(scale: MotionTokens.pressScale(large: true),
                                           reduceMotion: reduceMotion))
    }
}

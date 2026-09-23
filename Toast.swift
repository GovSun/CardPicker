import SwiftUI

// MARK: - Тост (Figma node 3602:102833)
//
// bg #4A4A4A, радиус 12, padding 12, gap 12, зелёная галочка 24, текст 17/medium.
struct ToastState: Equatable, Identifiable {
    let id = UUID()
    let text: String
}

struct ToastView: View {
    let text: String
    let f: CGFloat

    var body: some View {
        HStack(spacing: 12 * f) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24 * f))
                .foregroundStyle(Tokens.toggleOn)
                .frame(width: 24 * f, height: 24 * f)
            Text(text)
                .font(.system(size: 17 * f, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12 * f)
        .background(
            RoundedRectangle(cornerRadius: 12 * f, style: .continuous)
                .fill(Tokens.toastBg)
        )
        .padding(.horizontal, 16 * f)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Хост тоста
//
// Живёт над NavigationStack, чтобы пережить анимацию возврата с пикера.
// Автоскрытие — отменяемый Task, НЕ asyncAfter: иначе таймер первого тоста
// погасил бы второй раньше времени. UUID в ToastState перезапускает .task.
struct ToastHost: View {
    @Binding var state: ToastState?
    let f: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Русская строка тоста читается ~1.4 с; остальное — запас.
    private let dwell: Duration = .seconds(2.6)

    var body: some View {
        ZStack(alignment: .top) {
            if let state {
                ToastView(text: state.text, f: f)
                    .transition(transition)
                    .onTapGesture { dismiss() }
                    .task(id: state.id) {
                        try? await Task.sleep(for: dwell)
                        guard !Task.isCancelled else { return }
                        dismiss()
                    }
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(state == nil ? MotionTokens.toastOut : MotionTokens.toastIn, value: state)
    }

    // При Reduce Motion — только прозрачность, без вертикального сдвига.
    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        // Тост живёт СВЕРХУ (макет 3602:102833): приезжает сверху и туда же
        // уходит — вход и выход по одной оси.
        return .asymmetric(
            insertion: .offset(y: -24).combined(with: .opacity),
            removal: .offset(y: -24).combined(with: .opacity)
        )
    }

    private func dismiss() {
        withAnimation(MotionTokens.toastOut) { state = nil }
    }
}

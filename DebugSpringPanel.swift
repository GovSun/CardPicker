import SwiftUI

// MARK: - Дебаг-панель настройки пружины (response / dampingFraction)
//
// Живая настройка единой пружины проекта. Открывается тройным тапом по AppBar
// (см. ContentView) или env DEBUG_SPRING=1. Меняет MotionSettings.shared на лету —
// все переходы/нажатия сразу используют новые значения.
struct DebugSpringPanel: View {
    @Bindable var settings: MotionSettings
    let f: CGFloat
    /// Сброс прототипа к состоянию первого запуска. Задаётся хостом (RootView).
    var onReset: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * f) {
            HStack {
                Text("Debug")
                    .font(.system(size: 13 * f, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    settings.showPanel = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18 * f))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            slider(title: "response", value: $settings.response, range: 0.15...0.6, step: 0.01)
            slider(title: "damping", value: $settings.damping, range: 0.6...1.0, step: 0.01)

            // Пресеты
            HStack(spacing: 8 * f) {
                preset("Быстро", r: 0.26, d: 0.85)
                preset("Средне", r: 0.34, d: 0.9)
                preset("ТЗ 0.44", r: 0.44, d: 0.88)
            }

            Divider().overlay(Color.white.opacity(0.15))

            // MARK: A/B-тест флоу
            VStack(alignment: .leading, spacing: 6 * f) {
                Text("Флоу выбора дизайна")
                    .font(.system(size: 12 * f, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Picker("Флоу", selection: $settings.flow) {
                    Text("A · тумблер").tag(ABFlow.a)
                    Text("B · 2 шага").tag(ABFlow.b)
                    Text("C · шит").tag(ABFlow.c)
                }
                .pickerStyle(.segmented)
                Text(flowHint(settings.flow))
                    .font(.system(size: 10 * f))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onReset {
                Button(action: onReset) {
                    Text("Reset прототипа")
                        .font(.system(size: 12 * f, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8 * f)
                        .background(Capsule().fill(Tokens.accentPink.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14 * f)
        .frame(width: 280 * f)
        .background(
            RoundedRectangle(cornerRadius: 14 * f, style: .continuous)
                // Панель ПЛОТНАЯ: на «Деталях карты» под ней белый шит, и при
                // 0.82 сквозь неё просвечивал текст — читать невозможно.
                .fill(Color(hex: 0x141414))
                .shadow(color: .black.opacity(0.5), radius: 20 * f, y: 8 * f)
                .overlay(RoundedRectangle(cornerRadius: 14 * f).strokeBorder(.white.opacity(0.12)))
        )
    }

    private func flowHint(_ flow: ABFlow) -> String {
        switch flow {
        case .a: return "Сетка ⇄ карусель на одном экране, «Выбрать» применяет."
        case .b: return "Сетка → «Продолжить» → свайп → «Применить дизайн»."
        case .c: return "Карта сверху, сетка в шите: скролл поднимает шит."
        }
    }

    private func slider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 2 * f) {
            HStack {
                Text(title).font(.system(size: 12 * f, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 12 * f, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.accentPink)
            }
            Slider(value: value, in: range, step: step)
                .tint(Tokens.accentPink)
        }
    }

    private func preset(_ label: String, r: Double, d: Double) -> some View {
        Button {
            settings.response = r
            settings.damping = d
        } label: {
            Text(label)
                .font(.system(size: 11 * f, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10 * f).padding(.vertical, 6 * f)
                .background(Capsule().fill(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

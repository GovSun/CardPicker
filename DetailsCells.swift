import SwiftUI

// MARK: - Ячейки белого шита «Детали карты» (Figma node 3602:102558)
//
// ВАЖНО: у приложения .preferredColorScheme(.dark), поэтому внутри БЕЛОГО шита
// цвет текста по умолчанию был бы белым по белому. Везде ниже цвет задан явно.

// MARK: Однострочная ячейка (OneLineCell, Figma 3602:102580)
//
// 48pt, bg #F7F7F7, радиус 20, иконка 32 слева на 12, текст с 56 (12+32+12),
// трейлинг на 8. Неинтерактивные ячейки НЕ Button — «работает только одна
// строка» обеспечено структурно, а не комментарием.
struct OneLineCell<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let f: CGFloat
    var action: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(PressScaleButtonStyle(scale: MotionTokens.pressScale(large: true),
                                                   reduceMotion: reduceMotion))
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 12 * f) {
            Image(systemName: icon)
                .font(.system(size: 17 * f))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: 32 * f, height: 32 * f)
            VStack(alignment: .leading, spacing: 2 * f) {
                Text(title)
                    .font(.system(size: 17 * f, weight: .regular))
                    .foregroundStyle(Tokens.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    // Подпись должна умещаться в ОДНУ строку целиком: перенос
                    // раздувал ячейку (из-за накопленной высоты рабочая строка
                    // «Цифровой дизайн карты» уезжала за экран), а обрезка
                    // многоточием выглядит небрежно. Поэтому не режем, а даём
                    // ужаться по ширине — как в макете.
                    Text(subtitle)
                        .font(.system(size: 15 * f, weight: .regular))
                        .foregroundStyle(Tokens.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            Spacer(minLength: 8 * f)
            trailing()
        }
        .padding(.leading, 12 * f)
        .padding(.trailing, 8 * f)
        .padding(.vertical, 4 * f)
        .frame(minHeight: 48 * f)
        .background(Tokens.cellBg)
        .clipShape(RoundedRectangle(cornerRadius: 20 * f, style: .continuous))
        .contentShape(Rectangle())
    }
}

extension OneLineCell where Trailing == Chevron {
    init(icon: String, title: String, subtitle: String? = nil,
         f: CGFloat, action: (() -> Void)? = nil) {
        self.init(icon: icon, title: title, subtitle: subtitle, f: f,
                  action: action, trailing: { Chevron(f: f) })
    }
}

struct Chevron: View {
    let f: CGFloat
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 15 * f, weight: .medium))
            .foregroundStyle(Tokens.textSecondary.opacity(0.5))
            .frame(width: 32 * f, height: 32 * f)
    }
}

// MARK: Тумблер
//
// Рисуем руками: системный Toggle с .disabled(true) отрисовался бы серым
// и неправильным, а нам нужен включённый зелёный из макета.
struct StaticToggle: View {
    let isOn: Bool
    let f: CGFloat
    var body: some View {
        Capsule()
            .fill(isOn ? Tokens.toggleOn : Color(hex: 0xE5E5EA))
            .frame(width: 51 * f, height: 31 * f)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 27 * f, height: 27 * f)
                    .padding(2 * f)
                    .shadow(color: .black.opacity(0.15), radius: 1 * f, y: 1 * f)
            }
            .padding(.trailing, 8 * f)
            .accessibilityLabel(Text(isOn ? "Включено" : "Выключено"))
    }
}

// MARK: Кнопка-действие 163×82 (Перевести / Пополнить)
struct ActionCard: View {
    let icon: String
    let title: String
    let f: CGFloat

    var body: some View {
        VStack(spacing: 8 * f) {
            Image(systemName: icon)
                .font(.system(size: 20 * f, weight: .medium))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: 32 * f, height: 32 * f)
            Text(title)
                .font(.system(size: 15 * f, weight: .regular))
                .foregroundStyle(Tokens.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76 * f)
        .background(Tokens.cellBg)
        .clipShape(RoundedRectangle(cornerRadius: 20 * f, style: .continuous))
    }
}

// MARK: Промо O!Prime — градиент #FFF0F8 → #FAF4FF
struct PromoCell: View {
    let f: CGFloat

    var body: some View {
        HStack(spacing: 12 * f) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [Color(hex: 0xF0047F), Color(hex: 0xC724B1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Image(systemName: "star.fill")
                    .font(.system(size: 15 * f))
                    .foregroundStyle(.white)
            }
            .frame(width: 32 * f, height: 32 * f)

            VStack(alignment: .leading, spacing: 4 * f) {
                Text("Получайте 2% кешбэка с O!Prime")
                    .font(.system(size: 17 * f, weight: .regular))
                    .foregroundStyle(Tokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Ваш текущий кешбэк — 0,5%")
                    .font(.system(size: 15 * f, weight: .regular))
                    .foregroundStyle(Tokens.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 12 * f)
        .padding(.trailing, 8 * f)
        .padding(.vertical, 8 * f)
        .background(Tokens.promoGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20 * f, style: .continuous))
    }
}

// MARK: Номер счёта + баланс
struct AccountNumberRow: View {
    let number: String
    let balance: String
    let f: CGFloat

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2 * f) {
                Text("Номер счёта")
                    .font(.system(size: 15 * f, weight: .regular))
                    .foregroundStyle(Tokens.textSecondary)
                HStack(spacing: 2 * f) {
                    Text(number)
                        .font(.system(size: 15 * f, weight: .regular))
                        .foregroundStyle(Tokens.textSecondary)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12 * f))
                        .foregroundStyle(Tokens.link)
                        .frame(width: 18 * f, height: 18 * f)
                }
            }
            Spacer(minLength: 8 * f)
            Text(balance)
                .font(.system(size: 17 * f, weight: .medium))
                .foregroundStyle(Tokens.textPrimary)
        }
    }
}

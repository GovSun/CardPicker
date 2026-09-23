import SwiftUI

// MARK: - Ячейка карты в списке (Figma «сard cell», node 3031:119637)
//
// Слева мини-карта 60×40 (rounded 6, тонкая рамка), по центру заголовок+подзаголовок,
// справа Radio (pink при выборе). Мини-карта несёт matchedGeometryEffect —
// именно она «перетекает» между режимами (ТЗ §5, принцип 2).
struct LegacyCardRow: View {
    let card: CardItem
    let globalIndex: Int
    let isSelected: Bool
    let f: CGFloat
    /// Является ли эта строка приёмником героя (её мини-карту рисует оверлей).
    let isHero: Bool
    /// Прятать ли пиксели мини-карты (пока их рисует герой-оверлей).
    let heroHidden: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Figma «сard cell» (node 3031:119638): outer HStack gap 8, padding-left 16,
        // padding-right 12, vertical padding 0, items centered.
        Button(action: onTap) {
            HStack(spacing: 8 * f) {
                // Left "content" group: HStack gap 12, items centered.
                HStack(spacing: 12 * f) {
                    miniCard
                    // Одна строка каждая → БЕЗ .lineSpacing (он добавлял лишнюю
                    // высоту и раздувал строку). gap 4 между title/subtitle.
                    VStack(alignment: .leading, spacing: 4 * f) {
                        Text(card.title)
                            .font(.system(size: 15 * f, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(card.subtitle)
                            .font(.system(size: 13 * f, weight: .regular))
                            .foregroundStyle(Color(hex: 0x8A8A8E))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8 * f)
                RadioButton(isOn: isSelected, f: f)
            }
            // Figma: ячейка ровно 40pt (= высота мини-карты), содержимое по центру.
            // Зазор между ячейками (pitch 60) даёт разделитель в ListModeView.
            .frame(height: 40 * f)
            .padding(.leading, 16 * f)
            .padding(.trailing, 12 * f)
            .contentShape(Rectangle())
        }
        // мелкий элемент → жмётся сильнее (принцип 7); отклик той же пружиной (принцип 1)
        .buttonStyle(PressScaleButtonStyle(scale: MotionTokens.pressScale(large: false),
                                           reduceMotion: reduceMotion))
    }

    private var miniCard: some View {
        RemoteImage(cardImage: card.image, kind: .mini, contentMode: .fill)
            .frame(width: 60 * f, height: 40 * f)
            .clipShape(RoundedRectangle(cornerRadius: 6 * f, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6 * f, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.303 * f)
            )
            .opacity(heroHidden ? 0 : 1)                     // пиксели рисует герой-оверлей
            .heroSlot(isHero ? .row(globalIndex) : nil,      // репер только у выбранной строки
                      cornerRadius: 6 * f, in: .named("screen"))
    }
}

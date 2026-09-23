import SwiftUI

// MARK: - Режим «Отображение списком» (Figma node 3031:119609)
//
// Вертикальный скролл: секция на коллекцию (заголовок + описание), внутри —
// ячейки карт с Radio. Открывается на позиции текущей коллекции (§4.2),
// один radio на весь список (Баг 1), футер закреплён через safeAreaInset (Баг 3).
struct LegacyListModeView: View {
    @Bindable var model: PickerModel
    let f: CGFloat
    let topInset: CGFloat
    /// true, пока пиксели выбранной карты рисует герой-оверлей (во время морфинга).
    let heroOwnsSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Скролл к выбранной карте выполняем ОДИН раз при появлении (Баг: незащищённый
    /// scrollTo мог повторно дёргать список в середине перелёта).
    @State private var didInitialScroll = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                // ВАЖНО: обычный VStack (не Lazy) — все строки существуют сразу,
                // поэтому scrollTo к любой карте и измерение её фрейма работают
                // с первого кадра (нет гонки ленивого рендера). 33 карты — не
                // «большой» набор, eager-стек здесь корректен.
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: topInset + 60 * f) // под AppBar
                    ForEach(model.collections.indices, id: \.self) { ci in
                        section(ci)
                            .id(model.anchorID(collection: ci))
                    }
                }
            }
            // Скроллим к ВЫБРАННОЙ КАРТЕ по центру ОДИН раз, пока список ещё
            // невидим (opacity=morphT=0). МГНОВЕННО (disablesAnimations) → позиция
            // строки финальна с первого кадра, перелёт не «доезжает».
            // Стабилизацию row-фрейма ловит watchdog в ContentView (awaitSettled).
            .onAppear {
                guard !didInitialScroll else { return }   // не дёргать скролл повторно
                didInitialScroll = true
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    proxy.scrollTo(model.cardAnchorID(globalIndex: model.selectedGlobal),
                                   anchor: .center)
                }
            }
        }
    }

    private func section(_ ci: Int) -> some View {
        let c = model.collections[ci]
        // Figma «Divider label» (node 3031:119635, instance 375×90):
        // title+icons row — 32pt tall, leading 16, title 17/bold, centered vertically;
        // gap 4pt; description — leading 16, up to 3 lines, 15/regular, lineHeight 1.25.
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4 * f) {
                // Заголовок — одна строка, БЕЗ lineSpacing (не раздуваем), центрирован
                // в 32pt строке (иконки info/chevron из Figma скрыты — не рендерим).
                Text(c.sheetTitle)
                    .font(.system(size: 17 * f, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(height: 32 * f, alignment: .leading)
                    .padding(.leading, 16 * f)
                // Описание — многострочное: тут lineHeight 1.25 уместен, до 3 строк.
                Text(c.desc)
                    .font(.system(size: 15 * f, weight: .regular))
                    .lineSpacing(15 * f * (1.25 - 1.0))
                    .lineLimit(3)
                    .foregroundStyle(Tokens.onDarkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 16 * f)
                    .frame(maxWidth: 343 * f, alignment: .leading)
            }
            .padding(.top, 16 * f)
            // Figma node 3031:119633: между низом описания и первой картой 20pt
            // (8pt зазор Items Container + 12pt внутри). Раньше было только 12 →
            // заголовок «прилипал» к картам. Добавляем недостающие 8pt.
            .padding(.bottom, 8 * f)

            // Figma: pitch ячеек 60 = 40 (ячейка) + 20 (зазор). Разделитель
            // центрируется в зазоре → 10pt сверху и снизу.
            ForEach(Array(c.range), id: \.self) { gi in
                LegacyCardRow(
                    card: Catalog.cards[gi],
                    globalIndex: gi,
                    isSelected: gi == model.selectedGlobal,     // один выбор на весь экран
                    f: f,
                    isHero: gi == model.selectedGlobal,          // приёмник героя
                    heroHidden: gi == model.selectedGlobal && heroOwnsSelected,
                    onTap: { select(global: gi) }
                )
                .id(model.cardAnchorID(globalIndex: gi))         // якорь для scrollTo
                .padding(.top, gi == c.range.lowerBound ? 12 * f : 10 * f)
                .padding(.bottom, 10 * f)
                if gi != c.range.upperBound - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.leading, 88 * f)
                }
            }
            // Больше воздуха МЕЖДУ коллекциями: увеличенный зазор снизу секции
            // (кроме последней). ~24pt делает границы коллекций заметнее.
            if ci < model.collections.count - 1 {
                Color.clear.frame(height: 24 * f)
            }
        }
    }

    private func select(global gi: Int) {
        Haptics.soft() // триада отклика (принцип 8): движение + haptics
        withAnimation(MotionTokens.transition(reduceMotion: reduceMotion)) {
            model.select(global: gi)
        }
    }
}

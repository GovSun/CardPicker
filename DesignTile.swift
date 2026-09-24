import SwiftUI

// MARK: - Плитка дизайна в сетке (Figma node 3632:80459 / 3748:59868)
//
// Геометрия из АКТУАЛЬНОГО макета (при ширине 375):
//   арт      — 108 × 72, радиус 12, бордер 0.5px white 15%, overflow clip
//   инстанс  — 112 × 76: те же 108×72 плюс padding 2 по кругу (место под
//              рамку выделения, чтобы она не съедала арт)
//   ряд      — x = 15.5 / 131.5 / 247.5 → шаг 116, т.е. зазор 8, поле 16
// Ширину 108 НЕ хардкодим: flex-слот (`maxWidth: .infinity`) даёт ровно её
// на 375 и корректно тянется на других ширинах.
//
// Прошлая версия была свёрстана по УСТАРЕВШЕМУ узлу 3584:66241 (радиус 16,
// бордер 1, зазор 4) — отсюда и расхождение, которое было видно на экране.
struct DesignTile: View {
    let card: CardItem
    let globalIndex: Int
    let isSelected: Bool
    let f: CGFloat
    /// Плитка — приёмник hero-перелёта (пока не используется: режим сетки
    /// переключается кросс-фейдом, см. план).
    var isHero: Bool = false
    var heroHidden: Bool = false
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let height: CGFloat = 72
    static let radius: CGFloat = 12
    private static let artW: CGFloat = 141
    private static let artH: CGFloat = 88

    var body: some View {
        Button(action: onTap) {
            art
                .overlay { selectionLayer }
                .opacity(heroHidden ? 0 : 1)
                .clipShape(shape)
                .overlay {
                    // Бордер 0.5 у ОБОИХ состояний (макет: border-[0.5px]
                    // rgba(255,255,255,0.15)). Выбранное состояние читается
                    // затемнением и галочкой, а белую рамку вокруг даёт
                    // отдельный слой selectionRing в сетке — в макете она
                    // лежит в padding-зоне инстанса, а не по краю арта.
                    shape.strokeBorder(Tokens.hairline, lineWidth: 0.5 * f)
                }
                .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle(scale: MotionTokens.pressScaleTile,
                                           reduceMotion: reduceMotion))
        // Анимируем именно по isSelected: и появление слоя, и смена бордера
        // идут одной пружиной, независимо от того, кто менял выбор.
        .animation(MotionTokens.transition(reduceMotion: reduceMotion), value: isSelected)
        .heroSlot(isHero ? .row(globalIndex) : nil,
                  cornerRadius: Self.radius * f, in: .named("screen"))
        .accessibilityLabel(Text(card.title))
        .accessibilityValue(Text(isSelected ? "Выбрано" : ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.radius * f, style: .continuous)
    }

    // Арт по макету крупнее плитки (141×88 против 111.67×72) и обрезается —
    // это семантика overflow-clip. ВАЖНО: фиксированный .frame(width:) здесь
    // нельзя: плитка живёт в flex-слоте (~112pt), а запрос 141pt заставлял бы
    // HStack просить больше ширины экрана и уезжать за края.
    // Перелив задаём ОТНОСИТЕЛЬНО слота. По макету это 141/111.67 ≈ 1.263, но
    // арт и плитка почти одного соотношения (1.577 против 1.551), поэтому
    // такой зум заметно срезает края — на картах живописи в кадр лезет
    // логотип. Берём минимальный перелив: ровно столько, чтобы закрыть
    // разницу пропорций, без лишнего приближения.
    // Кадрирование арта.
    //
    // В мастере (Figma 3632:80459) арт «image 378» переливает бокс в 1.42
    // раза — но копировать это число НЕЛЬЗЯ: там лежит исходник
    // 1536×1024 (пропорция 1.5, как у бокса), из которого вырезают центр.
    // Наш арт уже кадрирован под карту: 1224×776 = 1.577.
    //
    // Для нашего исходника минимальный кроп — заполнить по ВЫСОТЕ:
    // 1.577 / 1.5 = 1.051, то есть ~5% уходит по бокам поровну. Больший
    // перелив срезает логотип VISA (проверено на симуляторе: при 1.42 от
    // него оставалось «VIS»).
    private static let artOverscan: CGFloat = 1.577 / 1.5      // ≈1.051

    private var art: some View {
        artImage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }

    private var artImage: some View {
        RemoteImage(cardImage: card.image, kind: .mini, contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    // Выбранное состояние — замерено с мастер-компонента Selected_item,
    // вариант State=Selected (Figma 3632:80459):
    //   фрейм: чёрный 20% + BACKGROUND_BLUR радиус 4
    //   поверх: Overlay чёрный 50%
    //   поверх: галочка-вектор 20×20, strokeWeight 4, белая
    //
    // Блюр здесь ЕСТЬ. В промежуточной версии я его убрал, сверившись с
    // отдельным узлом grid_preview_card, где размытия нет, — но мастер
    // собран иначе, и авторитетен он.
    @ViewBuilder
    private var selectionLayer: some View {
        if isSelected {
            ZStack {
                // BACKGROUND_BLUR по арту под слоем. В SwiftUI нет
                // backdrop-filter, поэтому размываем копию арта.
                artImage
                    .blur(radius: 4 * f, opaque: false)
                Color.black.opacity(0.2)
                Color.black.opacity(0.5)
                // Макет 3632:104233: фрейм Check 32×32, внутри вектор 20×20
                // с отступом 6 по кругу — то есть бокс глифа именно 32,
                // а не 20. Путь из Check.svg уже построен в системе 32×32,
                // поэтому рамка должна совпадать с ней, иначе штрих сжимается.
                CheckGlyph()
                    .fill(.white)
                    .frame(width: 32 * f, height: 32 * f)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Крышка «+N еще» (Figma node 3584:66247)
//
// КЛЮЧЕВОЕ: это НЕ отдельная плитка-заглушка. Под крышкой лежит настоящая
// плитка следующей карты, а «+N еще» — полупрозрачный слой ПОВЕРХ неё.
// Поэтому при раскрытии крышка растворяется, и плитка, по которой тапнули,
// оказывается первой из раскрытых — причинность читается сама, без
// matchedGeometryEffect (который здесь был бы и хрупким, и лживым:
// один источник не может «стать» N приёмниками).
struct MoreLid: View {
    let count: Int
    let f: CGFloat
    /// Карта, лежащая ПОД крышкой. Нужна, чтобы размыть именно её арт:
    /// в SwiftUI нет backdrop-blur, поэтому размытую копию рисуем сами.
    /// nil → только градиентная подложка (фолбэк).
    ///
    /// ВАЖНО: вызывающая сторона обязана передавать карту ТОЛЬКО когда
    /// крышка реально видна. `.opacity(0)` не убирает вид из дерева, и
    /// блюр продолжал бы считаться на каждой плитке — этот проект уже
    /// ловил просадку кадров на 29 одновременных .blur-проходах.
    var card: CardItem? = nil

    var body: some View {
        ZStack {
            // Фолбэк-подложка, когда арт не передан (крышка невидима).
            Color.black.opacity(card == nil ? 0.92 : 0)

            // Слои замерены с мастер-компонента Selected_item, вариант
            // State=More (Figma 3632:80459):
            //   фрейм  — чёрный 20% + BACKGROUND_BLUR радиус 4
            //   Overlay — чёрный 50%, тоже с BACKGROUND_BLUR 4
            // В SwiftUI нет backdrop-filter, поэтому размываем копию арта,
            // а затемнения кладём поверх двумя слоями, как в макете.
            if let card {
                artImage(card)
                    .blur(radius: 4 * f, opaque: false)
            }
            Color.black.opacity(0.2)
            Color.black.opacity(0.5)

            // Текстовый блок 24×37: «+N» 17pt, «еще» 13pt (мастер).
            VStack(spacing: 0) {
                Text("+\(count)")
                    .font(.system(size: 17 * f, weight: .medium))
                    .frame(height: 21 * f)
                Text("еще")
                    .font(.system(size: 13 * f, weight: .regular))
                    .frame(height: 16 * f)
            }
            .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Показать ещё \(count)"))
    }

    /// Тот же кроп, что у обычной плитки, — иначе размытый арт под
    /// крышкой кадрировался бы иначе, чем соседние карты.
    private func artImage(_ card: CardItem) -> some View {
        RemoteImage(cardImage: card.image, kind: .mini, contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}


// MARK: - Галочка выбора (Figma node 3584:66838)
//
// Путь взят 1:1 из Check.svg, который прислал дизайнер, а не нарисован
// на глаз и не взят из SF Symbols: у системного глифа разная толщина
// плеч и скошенные торцы, он читается грубее.
struct CheckGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        // Путь 1:1 из Check.svg (viewBox 32×32, stroke-width 4,
        // round cap/join):
        //   M26 6 C 26 6, 15.4 17.2889, 12.6667 26 L 6 19.3333
        let s = min(rect.width, rect.height) / 32
        var p = Path()
        p.move(to: CGPoint(x: 26 * s, y: 6 * s))
        p.addCurve(to: CGPoint(x: 12.6667 * s, y: 26 * s),
                   control1: CGPoint(x: 26 * s, y: 6 * s),
                   control2: CGPoint(x: 15.4 * s, y: 17.2889 * s))
        p.addLine(to: CGPoint(x: 6 * s, y: 19.3333 * s))
        return p.strokedPath(
            .init(lineWidth: 4 * s, lineCap: .round, lineJoin: .round)
        )
    }
}


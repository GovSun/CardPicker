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
    private static let artOverscan: CGFloat = 1.04

    private var art: some View {
        artImage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }

    private var artImage: some View {
        GeometryReader { g in
            RemoteImage(cardImage: card.image, kind: .mini, contentMode: .fill)
                .frame(width: g.size.width * Self.artOverscan,
                       height: g.size.height * Self.artOverscan)
                .position(x: g.size.width / 2, y: g.size.height / 2)
        }
    }

    // Выбранное состояние (Figma node 3632:104233): арт ЗАТЕМНЯЕТСЯ
    // сплошным чёрным 50% и поверх ложится белая галочка 20pt.
    //
    // БЛЮРА ЗДЕСЬ НЕТ — и это главная правка. Прошлая версия размывала арт
    // (blur 8 + белая плашка 5%) по устаревшему узлу 3584:66838. В текущем
    // макете размытие осталось ТОЛЬКО у крышки «+N еще»; у выбранной плитки
    // чистое затемнение. Разница важна не только формально: блюр съедал
    // рисунок карты, а именно его пользователь и опознаёт — при выборе
    // нужно приглушить арт, но не прятать его.
    @ViewBuilder
    private var selectionLayer: some View {
        if isSelected {
            ZStack {
                Color.black.opacity(0.5)
                CheckGlyph()
                    .fill(.white)
                    .frame(width: 20 * f, height: 20 * f)
                    // Появление: 0.8 → 1 (не из нуля — ничто не возникает
                    // из ничего). Уход — просто растворяется вместе со слоем.
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
            // Градиент из макета: linear-gradient(240deg, #2E2E2E 14%, #000 100%).
            // 240° в CSS — направление «вниз-влево», т.е. старт сверху-справа.
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x2E2E2E), location: 0.14),
                    .init(color: Color(hex: 0x000000), location: 1.0),
                ],
                startPoint: UnitPoint(x: 0.933, y: 0.0),
                endPoint: UnitPoint(x: 0.067, y: 1.0)
            )
            .opacity(card == nil ? 0.92 : 0)

            // Макет 3632:111904: backdrop-blur(blur/xs ÷ 2) = 2pt поверх
            // чёрного 20%. Блюр тут осмыслен, в отличие от выбранной плитки:
            // под крышкой лежит НАСТОЯЩИЙ арт следующей карты, и размытие
            // подсказывает, что там что-то есть, не выдавая деталей.
            if let card {
                GeometryReader { g in
                    RemoteImage(cardImage: card.image, kind: .mini,
                                contentMode: .fill)
                        .frame(width: g.size.width * 1.04,
                               height: g.size.height * 1.04)
                        .position(x: g.size.width / 2, y: g.size.height / 2)
                }
                .blur(radius: 2 * f, opaque: false)
            }
            Color.black.opacity(0.2)

            VStack(spacing: 0) {
                Text("+\(count)")
                    .font(.system(size: 17 * f, weight: .medium))
                    .frame(height: 20.4 * f)
                Text("еще")
                    .font(.system(size: 13 * f, weight: .regular))
                    .frame(height: 15.6 * f)
            }
            .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Показать ещё \(count)"))
    }
}


// MARK: - Галочка выбора (Figma node 3584:66838)
//
// Рисуем путь сами, а не берём SF Symbol «checkmark»: у системного глифа при
// .bold РАЗНАЯ толщина плеч (замер: 4.0 против 5.33pt) и скошенные торцы,
// из-за чего он читается грубее макетного. Здесь — ровная линия со
// скруглёнными концами, вписанная в бокс 24×24.
struct CheckGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var p = Path()
        p.move(to: CGPoint(x: 4.5 * s, y: 12.8 * s))
        p.addLine(to: CGPoint(x: 9.6 * s, y: 18.0 * s))
        p.addLine(to: CGPoint(x: 19.5 * s, y: 6.4 * s))
        return p.strokedPath(
            .init(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round)
        )
    }
}

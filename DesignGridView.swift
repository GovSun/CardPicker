import SwiftUI

// MARK: - Сетка дизайнов (Figma node 3584:66192)
//
// Секция на коллекцию: заголовок + описание, под ними плитки арта по 3 в ряд.
// Свёрнутая секция показывает 5 плиток, шестой слот накрыт крышкой «+N еще»
// (см. MoreLid — под крышкой лежит НАСТОЯЩАЯ шестая плитка).
//
// Почему eager VStack, а не LazyVGrid: стартовый scrollTo к выбранной карте
// должен сработать с первого кадра — ленивый контейнер к этому моменту ещё не
// материализовал нужную строку. Это уже отлаженный инвариант проекта
// (см. комментарий в ListModeView_Legacy). 29 плиток — не «большой» набор.
struct DesignGridView: View {
    let model: PickerModel
    let f: CGFloat
    let topInset: CGFloat
    /// Куда крепить скролл: .center (вариант A/B) или .top.
    /// В свёрнутом шите варианта C вьюпорт низкий, и .center промахивается.
    var scrollAnchor: UnitPoint = .center
    /// Скроллить к СЕКЦИИ, а не к плитке. В варианте C якорь на плитке
    /// ставил список ровно на плитки, и заголовок коллекции оставался
    /// выше кадра — выглядело как обрезка.
    var scrollToSection: Bool = false
    /// Сетка на СВЕТЛОМ фоне (белый шит варианта C): иначе заголовки
    /// и описания белые по белому.
    var onLight: Bool = false
    /// Вариант C: сообщить наружу, что пользователь выбрал дизайн —
    /// шит сворачивается, чтобы показать карту.
    var onPick: (() -> Void)? = nil
    /// Вариант C: видна ли первая коллекция. Шит можно сворачивать
    /// только когда пользователь долистал до самого верха.
    var onFirstSectionVisible: ((Bool) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didInitialScroll = false

    private static let columns = 3
    /// Зазор между плитками в ряду. Макет 3748:59873 читается напрямую:
    /// у ряда gap=4 и padding 16 по бокам, шаг 116 = инстанс 112 + 4.
    /// (112 — это арт 108 плюс его собственный padding 2 по кругу.)
    /// Раньше здесь стояло 8: шаг считался от ширины АРТА, а не инстанса.
    private static let gap: CGFloat = 4
    /// Зазор между РЯДАМИ остаётся 4 (макет: y = 0 и 80 при высоте 76).
    private static let rowGap: CGFloat = 4

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        // В A/B сверху лежит аппбар и нужен большой зазор.
                        // В шите варианта C аппбара над сеткой нет, но и
                        // впритык к кромке шита первый ряд прижимать нельзя —
                        // держим минимум 4pt воздуха.
                        .frame(height: max(4 * f, topInset + 60 * f))
                    ForEach(model.collections.indices, id: \.self) { ci in
                        section(ci)
                            .id(model.anchorID(collection: ci))
                            .padding(.bottom, 24 * f)
                    }
                }
                // Замер прокрутки — через настоящий UIScrollView (KVO на
                // contentOffset), а НЕ через onAppear/onDisappear секции 0.
                //
                // onAppear/onDisappear у eager VStack ненадёжен: секция 0
                // никогда не выходит из ДЕРЕВА (VStack не Lazy, см. шапку
                // файла), поэтому onDisappear там не про «уехала из
                // вьюпорта», а про смену системных условий отрисовки —
                // на практике срабатывал не для того события.
                //
                // PreferenceKey тоже проверялся и не работал: пробник в
                // .background() контента едет вместе с контентом, его minY
                // относительно себя же не меняется (постоянный 0).
                //
                // scrollPosition(id:) + .scrollTargetLayout() тоже
                // проверялись изолированным тестом на eager VStack —
                // биндинг остаётся nil всю прокрутку, ни разу не сработал.
                //
                // UIScrollView.contentOffset через KVO — единственный путь,
                // который в изолированном тесте дал точные, непрерывно
                // обновляющиеся значения. См. ScrollOffsetProbe.swift.
                .background(ScrollOffsetProbe { onDistanceFromTopChange($0) })
            }
            // Одноразовый скролл к выбранной карте. В реальном потоке выбор
            // ставится ДО пуша (RootView.openPicker), поэтому onAppear его уже
            // видит; отдельный onChange тут не нужен и только мешал бы
            // пользовательскому скроллу.
            .onAppear { scrollToSelected(proxy) }
        }
    }

    /// Порог «список в самом верху», в поинтах. distanceFromTop от пробника
    /// уже учитывает adjustedContentInset — сравниваем с небольшим запасом,
    /// а не строго с 0: резиновый bounce на самом верху даёт слегка
    /// отрицательные значения, а лёгкий сабпиксельный дрейф при раскладке —
    /// слегка положительные (единицы поинтов). Небольшой запас гасит и то,
    /// и другое, не давая дребезжать true/false на границе.
    private var topThreshold: CGFloat { 4 * f }

    private func onDistanceFromTopChange(_ distance: CGFloat) {
        onFirstSectionVisible?(distance <= topThreshold)
    }

    private func scrollToSelected(_ proxy: ScrollViewProxy) {
        guard !didInitialScroll else { return }
        didInitialScroll = true

        // Раскрываем секцию СРАЗУ: если выбранная карта прячется под крышкой,
        // её плитки в дереве ещё нет и скроллить будет некуда.
        model.ensureSelectedVisible()

        // А сам scrollTo — СЛЕДУЮЩИМ тиком. В момент onAppear строки сетки ещё
        // не разложены, у якоря нет фрейма, и scrollTo молча уходит в никуда
        // (визуально список просто остаётся наверху).
        DispatchQueue.main.async {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                let target: String = scrollToSection
                    ? model.anchorID(collection: model.collectionIndex(
                        ofGlobal: model.selectedGlobal) ?? 0)
                    : model.cardAnchorID(globalIndex: model.selectedGlobal)
                proxy.scrollTo(target, anchor: scrollAnchor)
            }
        }
    }

    // MARK: - Секция коллекции

    @ViewBuilder
    private func section(_ ci: Int) -> some View {
        let c = model.collections[ci]
        let expanded = model.isExpanded(ci)
        let overflow = model.overflowCount(ci)

        // Figma 3748:59870 — Block_collection: gap 4 между хедером и рядами.
        VStack(alignment: .leading, spacing: 4 * f) {
            header(c)
            grid(ci: ci, collection: c, expanded: expanded, overflow: overflow)
            if expanded && overflow > 0 {
                collapseButton(ci)
                    .transition(.opacity)
            }
        }
    }

    // Figma «Divider label»: gap 4, py 8; заголовок 17/bold в строке min 32,
    // описание 15/regular #DDD, lineHeight 1.25, до 3 строк, оба с px 16.
    private func header(_ c: CardCollection) -> some View {
        // Макет 3748:59871 (Divider label): вертикальный gap 0 — воздух
        // между заголовком и описанием даёт бокс заголовка (32pt при
        // кегле 17), а не отдельный spacing.
        VStack(alignment: .leading, spacing: 0) {
            Text(c.sheetTitle)
                .font(.system(size: 17 * f, weight: .bold))
                .foregroundStyle(onLight ? Tokens.textPrimary : .white)
                .frame(height: 32 * f, alignment: .leading)
            Text(c.desc)
                .font(.system(size: 15 * f, weight: .regular))
                .lineSpacing(15 * f * 0.25)
                .lineLimit(3)
                .foregroundStyle(onLight ? Tokens.textSecondary : Tokens.onDarkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16 * f)
        .padding(.vertical, 8 * f)
    }

    // MARK: - Сетка плиток
    //
    // Все плитки коллекции ВСЕГДА в дереве; раскрытие анимирует высоту
    // контейнера (+ .clipped()), а не вставляет/удаляет вью. Так реверс
    // посреди анимации просто перенацеливает ту же пружину — прерываемость
    // достаётся бесплатно, без guard-ов на кнопке.
    private func grid(ci: Int, collection c: CardCollection,
                      expanded: Bool, overflow: Int) -> some View {
        let all = Array(c.range)
        let rows = chunked(all)
        let visibleRows = (expanded || overflow == 0)
            ? rows.count
            : Int(ceil(Double(PickerModel.previewLimit + 1) / Double(Self.columns)))
        let height = heightFor(rows: visibleRows)

        return VStack(spacing: Self.rowGap * f) {
            ForEach(rows.indices, id: \.self) { r in
                row(rows[r], rowIndex: r, ci: ci, expanded: expanded,
                    overflow: overflow, visibleRows: visibleRows)
            }
        }
        .padding(.horizontal, 16 * f)
        .frame(height: height, alignment: .top)
        .clipped()
        .animation(MotionTokens.expand(reduceMotion: reduceMotion), value: expanded)
    }

    private func row(_ items: [Int], rowIndex r: Int, ci: Int,
                     expanded: Bool, overflow: Int, visibleRows: Int) -> some View {
        // Ряды за пределами свёрнутой высоты гасим, чтобы они не просвечивали
        // сквозь край клипа во время анимации.
        let hidden = !expanded && r >= visibleRows
        let staggerRow = r - visibleRows
        return HStack(spacing: Self.gap * f) {
            ForEach(items, id: \.self) { gi in
                cell(gi: gi, ci: ci, expanded: expanded, overflow: overflow)
            }
            // Добиваем неполный ряд, иначе две плитки растянутся на всю строку.
            if items.count < Self.columns {
                ForEach(0..<(Self.columns - items.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
        // 76 = арт 72 + padding 2 сверху/снизу (макет: инстанс 112×76).
        .frame(height: (DesignTile.height + 4) * f)
        .opacity(hidden ? 0 : 1)
        .offset(y: hidden ? 6 * f : 0)
        // .clipped()/.opacity(0) НЕ отключают хит-тест: скрытые ряды остаются
        // в раскладке и ловят тапы ниже среза — пользователь мог, целясь в
        // заголовок следующей секции, молча выбрать невидимый дизайн.
        .allowsHitTesting(!hidden)
        .animation(
            MotionTokens.expand(reduceMotion: reduceMotion)?
                .delay(expanded ? MotionTokens.staggerDelay(staggerRow,
                                                            reduceMotion: reduceMotion) : 0),
            value: expanded
        )
    }

    @ViewBuilder
    private func cell(gi: Int, ci: Int, expanded: Bool, overflow: Int) -> some View {
        let li = gi - model.collections[ci].range.lowerBound
        let isLid = !expanded && overflow > 0 && li == PickerModel.previewLimit

        ZStack {
            DesignTile(
                card: Catalog.cards[gi],
                globalIndex: gi,
                isSelected: gi == model.selectedGlobal,
                f: f,
                onTap: { isLid ? toggleExpanded(ci) : select(global: gi) }
            )
            // Крышка поверх настоящей плитки: растворяется при раскрытии.
            // card передаём ТОЛЬКО для видимой крышки: иначе размытая
            // копия арта строилась бы на каждой из 29 плиток разом
            // (.opacity(0) вид из дерева не убирает) — ровно та просадка
            // кадров, которую тут уже однажды чинили.
            MoreLid(count: overflow, f: f, card: isLid ? Catalog.cards[gi] : nil)
                .clipShape(RoundedRectangle(cornerRadius: DesignTile.radius * f,
                                            style: .continuous))
                .opacity(isLid ? 1 : 0)
                .allowsHitTesting(false)
                .animation(MotionTokens.reveal, value: isLid)
        }
        // Инстанс в макете 112×76 вокруг арта 108×72 — это ПУСТОЙ отступ,
        // а не место под рамку. Замер эталонного рендера 3632:104233: по
        // краю инстанса лежит фон канвы (39,39,39), белого кольца там нет.
        // Выбранное состояние читается затемнением и галочкой — рамку сюда
        // не добавлять (в прошлой версии она была, и это расхождение).
        .padding(2 * f)
        .id(model.cardAnchorID(globalIndex: gi))
    }

    // MARK: - «Свернуть» (Figma node 3584:66979)

    private func collapseButton(_ ci: Int) -> some View {
        Button { toggleExpanded(ci) } label: {
            HStack(spacing: 8 * f) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 15 * f, weight: .semibold))
                    .frame(width: 24 * f, height: 24 * f)
                Text("Свернуть")
                    .font(.system(size: 15 * f, weight: .medium))
                    .tracking(0.3)
            }
            .foregroundStyle(Tokens.link)
            .frame(maxWidth: .infinity)
            .frame(height: 48 * f)
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scale: MotionTokens.pressScale(large: true),
                                           reduceMotion: reduceMotion))
        .padding(.horizontal, 16 * f)
    }

    // MARK: - Действия

    private func select(global gi: Int) {
        // Хаптик синхронно ДО анимации — одним кадром с движением.
        Haptics.selection()
        withAnimation(MotionTokens.transition(reduceMotion: reduceMotion)) {
            model.select(global: gi)
        }
        onPick?()
    }

    private func toggleExpanded(_ ci: Int) {
        Haptics.soft()
        // Без guard-а на «уже анимируется»: реверс посреди разворота обязан
        // работать (пружина по высоте перенацеливается с текущей точки).
        withAnimation(MotionTokens.expand(reduceMotion: reduceMotion)) {
            model.toggleExpanded(ci)
        }
    }

    // MARK: - Геометрия

    private func chunked(_ items: [Int]) -> [[Int]] {
        stride(from: 0, to: items.count, by: Self.columns).map {
            Array(items[$0..<min($0 + Self.columns, items.count)])
        }
    }

    private func heightFor(rows: Int) -> CGFloat {
        guard rows > 0 else { return 0 }
        // rowGap, а не gap: высота считает ВЕРТИКАЛЬНЫЕ промежутки.
        // Раньше обе константы совпадали (4), и подмена была незаметна —
        // после разведения зазоров она обрезала бы нижний ряд.
        return CGFloat(rows) * (DesignTile.height + 4) * f
            + CGFloat(rows - 1) * Self.rowGap * f
    }
}

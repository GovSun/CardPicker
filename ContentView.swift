import SwiftUI
import UIKit

struct ContentView: View {

    private let colls = Catalog.displayCollections   // только видимые, в нужном порядке
    private var N: Int { colls.count }

    // Единый источник истины для обоих режимов (карусель ↔ список).
    // Владелец — RootView: модель должна пережить возврат с «Деталей карты»,
    // а @State здесь пересоздавался бы на каждом пуше и терял выбор.
    let model: PickerModel

    /// Пользователь подтвердил дизайн кнопкой «Выбрать» (глобальный индекс).
    var onConfirm: ((Int) -> Void)? = nil
    /// Уход назад БЕЗ применения: экран деталей остаётся со старой картой.
    var onCancel: (() -> Void)? = nil
    /// Какой дизайн реально применён сейчас — по нему гасим кнопку «Выбрать».
    var committedGlobal: Int = -1

    // MARK: - Параметры A/B (у всех есть дефолты → вариант A вызывается как раньше)

    /// Прятать правую кнопку аппбара (переключатель режима). В варианте B её нет.
    var hideModeToggle: Bool = false
    /// Подпись главной кнопки. nil → поведение варианта A («Выбрать»/«Выбран»).
    var primaryTitle: String? = nil
    /// Главная кнопка всегда активна (вариант B: «Продолжить»/«Применить дизайн»).
    var primaryAlwaysEnabled: Bool = false
    /// Форсированный режим: B открывает сетку и свайп явно, не полагаясь
    /// на запомненный `model.mode`.
    var forcedMode: ViewMode? = nil
    /// Перехват тумблера режима. nil → обычное поведение (переключить режим
    /// внутри этого же экрана, вариант A). Вариант C передаёт сюда «уйти
    /// назад в шит»: там второй режим — не ветка внутри ContentView,
    /// а отдельный экран ниже по стеку.
    var onToggleMode: (() -> Void)? = nil

    // Карта-герой: единый слой, едет между режимами (Family Values).
    @State private var heroFrames: [HeroFrameValue] = []
    @State private var morphT: CGFloat = 0       // 0 = карусель, 1 = список
    @State private var morphing = false          // true ТОЛЬКО во время перелёта
    @State private var morphFrom: CGRect = .zero // снимок hero-фрейма на старте
    @State private var morphTo: CGRect = .zero   // снимок row-фрейма на старте
    @State private var morphImage = ""           // какая карта летит
    @State private var flightGeneration = 0      // отмена устаревшего поллера при ре-переключении
    @State private var viewport: CGSize = .zero  // размер вьюпорта в координатах "screen" (для клампа)

    // Сколько подряд идентичных ненулевых наблюдений фрейма считаем «стабильно».
    private let settleStreakRequired = 2
    // Потолок ожидания стабилизации (защита от зависания, если репер не публикуется).
    private let settleTimeout: TimeInterval = 1.0

    @State private var offset: CGFloat = 0       // непрерывный сдвиг карусели (px)
    @State private var startOffset: CGFloat = 0
    @State private var lastColl = 0
    // Коллекция, ПОКАЗЫВАЕМАЯ в bottomSheet/фоне — обновляется ТОЛЬКО в момент
    // релиза жеста (carouselDrag.onEnded) и при монтировании карусели, а НЕ на
    // каждый пересчёт curColl во время анимации доезда (offset непрерывно
    // меняется под timingCurve). bottomSheet — тяжёлая подветка (ScrollView с
    // превью, многострочный Text description) и её relayout синхронно с кадром,
    // где ещё и cardBlock/AmbientBackground пересчитываются — то, что давало
    // просадку кадра (замерено CADisplayLink-профилированием) ровно на стыке коллекций.
    // Карточки/точки/заголовок продолжают жить на непрерывном `curColl` — они
    // дёшевы (transform/opacity), а вот шит и фон теперь стабильны всю анимацию
    // доезда и меняются одним чистым скачком в её начале.
    @State private var settledColl = 0
    @State private var nameIndex = 0             // выбранное имя (Именная карта)
    // Свайп карусели: тянем 1:1 за пальцем, на релизе — доезд timing-curve.
    // БЕЗ `locked`-гейта: новый жест ловит карту там, где она сейчас (re-anchor
    // startOffset на первом onChanged), иначе при старте драга во время доезда
    // offset «замирал» и потом ТЕЛЕПОРТИРОВАЛСЯ — тот самый рывок под пальцем.
    @State private var dragging = false          // идёт ли уже текущий жест (для re-anchor)
    // Блокировка свайпа на время доезда — взято из Cardpircker_swipe.
    // Без неё второй свайп посреди анимации перепривязывал startOffset,
    // и переход «спотыкался»; с ней каждый переход проигрывается целиком.
    @State private var locked = false
    private var swipeLockDuration: Double { transitionDuration + 0.08 }
    @GestureState private var gestureActive = false  // авто-сброс на конце/отмене жеста
    private let transitionDuration = 0.42        // сек: длительность доезда

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Дебаг-настройки пружины (панель включается тройным тапом по заголовку AppBar).
    @State private var motion = MotionSettings.shared

    // доступ к выбору — через общую модель
    private func wrap(_ k: Int) -> Int { model.wrap(k) }
    private func selGlobal(_ c: Int) -> Int { model.selectedGlobalIndex(c) }
    private func selCard(_ c: Int) -> CardItem { model.selectedCard(c) }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let f = W / 375
            let bottomInset = geo.safeAreaInsets.bottom
            let stride = 314 * f   // точная линия стыковки соседей из дизайна (≈+314 от центра)
            // ЗАЩИТА ОТ NaN: при пуше в NavigationStack первый кадр приходит с
            // нулевой шириной → stride == 0 → progress == NaN/inf, и Int(...)
            // роняет приложение (Swift runtime failure). Раньше не всплывало,
            // потому что ContentView был корневым и всегда имел размер.
            let progress = stride > 0 ? -offset / stride : 0

            ZStack {
                // Содержимое режима: карусель ИЛИ список (фон/аппбар общие → морфинг, не свап экрана)
                if model.mode == .cards {
                    // Карусель + точки + заголовок. Свайп-жест — ТОЛЬКО здесь (Баг 2):
                    // он больше не висит на всём ZStack и не конфликтует ни с чем.
                    ZStack {
                        cardBlock(W: W, f: f, stride: stride, progress: progress)
                            .padding(.bottom, 220 * f)
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            bottomSheet(curColl: settledColl, f: f, stride: stride, bottomInset: bottomInset)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(carouselDrag(stride: stride))
                    // «обвязка» карт затухает по мере ухода в список — вторично (не карта)
                    .opacity(Double(1 - morphT))
                } else {
                    // верхний скрим (под AppBar) + список с закреплённым футером (Баг 3)
                    ZStack {
                        Group {
                            if motion.useLegacyList {
                                LegacyListModeView(model: model, f: f,
                                             topInset: geo.safeAreaInsets.top,
                                             heroOwnsSelected: morphing)
                            } else {
                                DesignGridView(model: model, f: f,
                                               topInset: geo.safeAreaInsets.top)
                            }
                        }
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                selectFooter(f: f)
                            }
                            // Явно ограничиваем размером geo и клипуем: ZStack внутри
                            // GeometryReader не клипует детей → контент списка иначе
                            // «протекает» ниже футера у нижнего края (пустая зона).
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                        VStack(spacing: 0) {
                            // Скрим под аппбаром. Держим сплошным до низа
                            // заголовка и только потом растворяем — иначе
                            // плитки просвечивают сквозь текст «Цифровой
                            // дизайн карты» при скролле.
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.62),
                                    .init(color: .black.opacity(0), location: 1),
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                                .frame(height: geo.safeAreaInsets.top + 112 * f)
                                .ignoresSafeArea(edges: .top)
                                .allowsHitTesting(false)
                            Spacer(minLength: 0)
                        }
                    }
                    // строки списка мягко проявляются по мере прихода — вторично
                    .opacity(Double(morphT))
                }

                // Карта-герой: рисуется ТОЛЬКО во время перелёта, между СНИМКАМИ
                // фреймов (Баг 5). Вне морфинга — оверлея нет, работает реальная
                // карта/строка → нет дёрганий на свайпе и прыжков.
                if morphing {
                    HeroCardOverlay(
                        cardImage: morphImage,
                        heroFrame: morphFrom,
                        rowFrame: morphTo,
                        t: morphT, f: f
                    )
                }

                // AppBar — общий для обоих режимов, поверх всего (в т.ч. героя).
                //
                // БАГ (починен): раньше это был VStack со Spacer на весь экран
                // внутри общего ZStack. В режиме сетки поверх него ложился
                // ScrollView, в карусели — полноэкранный DragGesture, и оба
                // перехватывали тап по шеврону «назад»: кнопка не срабатывала.
                // Теперь аппбар ограничен СВОЕЙ высотой (не растягивается
                // Spacer-ом) и поднят zIndex-ом — тапы доходят.
                VStack(spacing: 0) {
                    appbar(f: f)
                    Spacer(minLength: 0).allowsHitTesting(false)
                }
                .zIndex(10)

                // Дебаг-панель пружины (поверх всего)
                // Дебаг-панель поднята в RootView (нужна и на «Деталях карты»),
                // здесь её больше нет — иначе монтировалась бы дважды.
            }
            .coordinateSpace(name: "screen")
            .onPreferenceChange(HeroFramePreferenceKey.self) { heroFrames = $0 }
            .onChange(of: geo.size, initial: true) { _, s in viewport = s }
            // жест завершён/отменён системой → сбрасываем флаг (иначе следующий
            // свайп не переанкорит startOffset и снова прыгнет)
            .onChange(of: gestureActive) { _, active in if !active { dragging = false } }
            // Синхронизация модели (currentCollection/selectedGlobal) с
            // текущей коллекцией карусели ТЕПЕРЬ происходит один раз — в
            // конце жеста (carouselDrag.onEnded), а не на каждый пересчёт
            // `curColl` во время анимации доезда. Раньше `.onChange(of: curColl)`
            // писал в `@Observable model` на КАЖДОЙ границе коллекции, пока
            // `offset` анимировался — это вызывало повторный проход layout
            // всего body (bottomSheet/cardBlock) поверх уже идущего от смены
            // `offset`, что давало пачку тяжёлых re-render'ов подряд и просадку
            // кадра (~30-45мс) ровно в момент стыка коллекций (замерено
            // CADisplayLink-профилированием). Модель нужна консистентной только к моменту
            // переключения в список — двигать её по ходу анимации не требуется,
            // т.к. фон/карусель во время драга уже читают `curColl` напрямую.
            // при возврате из списка карусель встаёт на коллекцию из модели (§4.4)
            .onChange(of: model.mode) { _, newMode in
                if newMode == .cards {
                    let target = -CGFloat(model.currentCollection) * stride
                    offset = target
                    startOffset = target
                    lastColl = model.currentCollection
                    settledColl = model.currentCollection
                }
            }
            // фон — модификатором (не дочерним элементом!), чтобы ZStack уважал safe area.
            // ОДИН источник фона для обоих режимов (Баг 6).
            .background(
                background(W: geo.size.width,
                           H: geo.size.height + geo.safeAreaInsets.top + bottomInset,
                           cardImage: backgroundCardImage(curColl: settledColl))
                    .ignoresSafeArea()
            )
            .onAppear {
                // START_TAPBACK=1 — дёрнуть шеврон программно (проверка, что
                // кнопка вообще получает нажатие; тапать в симуляторе нельзя).
                if ProcessInfo.processInfo.environment["START_TAPBACK"] == "1" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { backTapped() }
                }
                CardImages.shared.preload(Catalog.cards.map { $0.image })
                // Прогрев MinIO-картинок (full+mini) → свайп без лага и без
                // «скачка» подмены: к моменту показа карта уже в кэше.
                let names = Catalog.cards.map { $0.image }
                RemoteImageLoader.shared.preload(fullNames: names, miniNames: names)
                // Синхронизируем карусель с моделью: без этого вход с уже
                // выбранной картой из N-й коллекции показал бы нулевую.
                let ci0 = model.currentCollection
                offset = -CGFloat(ci0) * stride
                startOffset = offset
                lastColl = ci0
                settledColl = ci0
                // Вариант B задаёт вид явно (сетка или свайп), не полагаясь
                // на запомненный режим.
                if let forced = forcedMode { model.mode = forced }
                // Ветка списка рендерится с .opacity(morphT); войдя сразу в режим
                // сетки при morphT == 0 мы получили бы ЧЁРНЫЙ ЭКРАН.
                if model.mode == .list { morphT = 1 } else { morphT = 0 }

                let env = ProcessInfo.processInfo.environment
                if let s = env["START_INDEX"], let v = Double(s) {
                    offset = -CGFloat(v) * stride
                    startOffset = offset
                    lastColl = wrap(Int(v.rounded()))
                    let ci = wrap(Int(v.rounded()))
                    model.currentCollection = ci
                    model.selectedGlobal = colls[ci].range.lowerBound
                    settledColl = ci
                }
                // START_CARD здесь БОЛЬШЕ НЕ обрабатываем.
                //
                // БАГ: onAppear выполняется на КАЖДОМ пуше пикера, поэтому
                // повторный вход сбрасывал выбор обратно на стартовую карту —
                // пользователь выбирал дизайн, выходил, возвращался и видел
                // старую галочку. Начальный выбор теперь задаёт только
                // RootView.init, один раз за запуск.
                // debug-хук: старт сразу в списке
                if env["START_MODE"] == "list" { model.mode = .list; morphT = 1 }
                // debug-хук: раскрыть коллекцию в сетке (проверка «+N еще» без тапа).
                // START_EXPAND=<индекс коллекции> или "all".
                if let s = env["START_EXPAND"] {
                    if s == "all" {
                        model.expanded = Set(model.collections.indices)
                    } else if let ci = Int(s) {
                        model.expanded.insert(ci)
                    }
                }
                // debug-хук: сразу открыть панель настройки пружины
                if env["DEBUG_SPRING"] == "1" { motion.showPanel = true }
            }
        }
        .background(Color.black)
    }

    // MARK: - Карусель с выглядывающими соседями + точки + заголовок
    private func cardBlock(W: CGFloat, f: CGFloat, stride: CGFloat, progress rawProgress: CGFloat) -> some View {
        let cardW = 320 * f
        let cardH = 203 * f
        // Санируем ЗДЕСЬ, а не полагаемся на дисциплину вызывающего: ниже три
        // конверсии в Int, и любая из них на NaN/inf роняет приложение.
        let progress = rawProgress.isFinite ? rawProgress : 0
        let lo = Int(floor(progress))
        let t = progress - CGFloat(lo)
        let curColl = wrap(Int(progress.rounded()))
        return VStack(spacing: 0) {
            ZStack {
                ForEach(Array((lo - 1)...(lo + 2)), id: \.self) { k in
                    let rel = CGFloat(k) - progress           // 0 = по центру
                    let a = min(abs(rel), 1)
                    // центральная карта = герой: публикует hero-фрейм и прячет
                    // свои пиксели, пока их рисует оверлей-герой (morphT > 0).
                    let centered = k == Int(progress.rounded())
                    cardFace(name: selCard(k).image, cardW: cardW, cardH: cardH, f: f,
                             isHero: centered, hidden: centered && morphing)
                        .scaleEffect(1 - 0.133 * a)
                        .rotationEffect(.degrees(5 * Double(max(-1, min(1, rel)))))
                        .offset(x: rel * stride, y: 24 * f * a)
                        .zIndex(-Double(abs(rel)))
                        .transition(.identity)   // карта на краю окна появляется/исчезает мгновенно — без «улёта»
                }
            }
            .frame(width: W, height: cardH + 26 * f)

            dots(curColl: curColl, f: f).padding(.top, 6 * f)

            // Заголовок — как в Prod: подпись ТЕКУЩЕЙ коллекции держится на карте
            // почти весь свайп, а смена происходит БЫСТРО в узкой полосе у стыка
            // (t≈0.5). Так old+new всегда ≈1 (нет «пустой» середины, где обе по
            // 50% → «текст исчезает/появляется»), а хендофф ощущается резким.
            ZStack {
                titleText(selCard(lo), f: f).opacity(Double(1 - titleCross(t)))
                titleText(selCard(lo + 1), f: f).opacity(Double(titleCross(t)))
            }
            .padding(.top, 16 * f)
        }
    }

    private func cardFace(name: String, cardW: CGFloat, cardH: CGFloat, f: CGFloat,
                          isHero: Bool = false, hidden: Bool = false) -> some View {
        RemoteImage(cardImage: name, kind: .full, contentMode: .fit)
            .frame(width: cardW, height: cardH)
            .clipShape(RoundedRectangle(cornerRadius: 8 * f, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 16 * f, x: 0, y: 10 * f)
            .opacity(hidden ? 0 : 1)                 // пиксели рисует герой-оверлей
            .heroSlot(isHero ? .hero : nil,          // репер только для центральной карты
                      cornerRadius: 8 * f, in: .named("screen"))
    }

    private func titleText(_ card: CardItem, f: CGFloat) -> some View {
        VStack(spacing: 4 * f) {
            Text(card.title)
                .font(.system(size: 20 * f, weight: .bold))
                .foregroundStyle(.white)
            Text(card.subtitle)
                .font(.system(size: 13 * f, weight: .regular))
                .foregroundStyle(Tokens.onDarkSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24 * f)
    }

    // Доля НОВОЙ подписи: 0 пока t<0.42, быстрый smoothstep-переход в узкой
    // полосе 0.42…0.58, затем 1. old = 1 - titleCross(t) → сумма всегда ≈1,
    // смена мгновенная у стыка (как в Prod), без «ватной» середины.
    private func titleCross(_ t: CGFloat) -> CGFloat {
        let e0: CGFloat = 0.42, e1: CGFloat = 0.58
        let u = min(1, max(0, (t - e0) / (e1 - e0)))
        return u * u * (3 - 2 * u)   // smoothstep
    }

    // MARK: - Фон (ambient blur) — ОДИН источник для обоих режимов (Баг 6)
    // Имя карты: в карусели — ТЕКУЩАЯ коллекция под пальцем (curColl, читаем
    // напрямую из offset — без записи в @Observable model на каждый кадр/
    // стык, см. комментарий у carouselDrag), в списке — глобально выбранная.
    private func backgroundCardImage(curColl: Int) -> String {
        model.mode == .cards ? selCard(curColl).image : model.selectedCard.image
    }

    private func background(W: CGFloat, H: CGFloat, cardImage: String) -> some View {
        // AmbientBackground — Equatable вью (Баг: лаг свайпа §1). Родительский
        // body (внутри GeometryReader) переисполняется на КАЖДЫЙ кадр драга,
        // т.к. зависит от `offset`. Без `.equatable()` SwiftUI каждый раз
        // заново диффит/укладывает целое поддерево с .blur(radius:30)
        // (дорогой Gaussian-проход), хотя cardImage/W/H не менялись между
        // кадрами драга. `.equatable()` заставляет SwiftUI сравнить старое и
        // новое значение через `==` и ПРОПУСТИТЬ body, если инпуты равны →
        // ветка фона больше не участвует в стоимости кадра во время свайпа.
        AmbientBackground(W: W, H: H, cardImage: cardImage, reduceMotion: reduceMotion)
            .equatable()
    }

    // MARK: - Appbar (Liquid Glass)
    private func appbar(f: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 1) {
                Text("Цифровой дизайн карты")
                    .font(.system(size: 15 * f, weight: .bold))
                    .foregroundStyle(.white)
                Text("Visa Cashback")
                    .font(.system(size: 13 * f, weight: .regular))
                    .foregroundStyle(Tokens.onDarkSecondary)
            }
            // тройной тап по заголовку → дебаг-панель пружины
            // contentShape только под самим текстом, иначе прозрачная зона
            // заголовка растягивалась на всю ширину аппбара.
            // Тройной тап оставляем как «скрытый» вход, но основной способ —
            // долгий тап: его находят, а тройной по узкому тексту — нет.
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                withAnimation(.easeInOut(duration: 0.2)) { motion.showPanel.toggle() }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                Haptics.soft()
                withAnimation(.easeInOut(duration: 0.2)) { motion.showPanel.toggle() }
            }
            .allowsHitTesting(true)
            .fixedSize()
            HStack {
                Button { backTapped() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17 * f, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48 * f, height: 48 * f)
                        .liquidGlass(Circle())
                        // БЕЗ contentShape тап-зоной остаётся то, что вернул
                        // liquidGlass (на iOS 26 это glassEffect), и нажатие
                        // до кнопки не доходило — ровно как у правой кнопки,
                        // где contentShape стоял с самого начала и всё работало.
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Назад")
                Spacer()
                // Правая кнопка — переключатель режима (иконка из Figma 2945-45810).
                // В варианте B её нет: там вид задаёт сам флоу.
                if !hideModeToggle {
                Button(action: toggleMode) {
                    Group {
                        if model.mode == .cards {
                            ListModeIcon()      // в карусели показываем «список»
                        } else {
                            CardsModeIcon()     // в списке показываем «стопку карт»
                        }
                    }
                    .foregroundStyle(.white)
                    // Макет 3584:101069: кнопка 48, глиф 24×24.
                    // Было 19×16 в кнопке 44 — иконка читалась мелкой.
                    .frame(width: 24 * f, height: 24 * f)
                    .frame(width: 48 * f, height: 48 * f)
                    .liquidGlass(Circle())
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.mode == .cards ? "Отображение списком" : "Отображение картами")
                }
            }
            .padding(.horizontal, 16 * f)
        }
        .frame(height: 48 * f)
        .padding(.top, 4 * f)
    }

    // Последний измеренный фрейм для слота героя (в координатах "screen").
    private func frame(_ slot: HeroSlot) -> CGRect? {
        heroFrames.last(where: { $0.slot == slot })?.rect
    }

    // Переключение режима с перелётом карты-героя.
    //
    // Ключ к отсутствию «доезда»: перелёт стартует не по фиксированному числу
    // async-хопов, а когда geometry ЦЕЛЕВОГО репера РЕАЛЬНО стабилизировалась
    // (awaitSettled: два одинаковых ненулевых замера подряд). Это работает для
    // любой глубины карты в коллекции — самоадаптивно к числу кадров лэйаута.
    //
    // morphFrom = hero-фрейм (карусель), morphTo = row-фрейм (список).
    // morphT: 0 = карусель, 1 = список.
    // Переключение режимов — ПРОСТОЙ КРОСС-ФЕЙД.
    //
    // Перелёт карты между каруселью и списком (morph-риг на HeroFrame +
    // awaitSettled) СНЯТ по решению заказчика: в сетке приёмник — плитка
    // другой геометрии, эффект читался как лишний. Сам риг остаётся в
    // проекте (HeroFrame/HeroCardOverlay) и используется legacy-списком.
    private func toggleMode() {
        // Вариант C: тумблер не меняет режим здесь, а возвращает в шит.
        if let onToggleMode {
            Haptics.soft()
            onToggleMode()
            return
        }
        Haptics.soft()
        let toList = model.mode == .cards
        withAnimation(MotionTokens.transition(reduceMotion: reduceMotion)) {
            model.mode = toList ? .list : .cards
            morphT = toList ? 1 : 0
        }
    }

    private func clampToScreenEdge(_ rect: CGRect) -> CGRect {
        guard viewport != .zero else { return rect }
        let top: CGFloat = 0
        let bottom = viewport.height
        // запас: карта стартует, отступив от края на свою высоту (короткий путь)
        let offAbove = top - rect.height
        let offBelow = bottom
        if rect.midY < top {
            return CGRect(x: rect.minX, y: offAbove, width: rect.width, height: rect.height)
        } else if rect.midY > bottom {
            return CGRect(x: rect.minX, y: offBelow, width: rect.width, height: rect.height)
        }
        return rect   // строка на экране — реальная позиция
    }

    // Watchdog: перепроверяет frame(slot) на каждом run-loop тике, пока не увидит
    // `settleStreakRequired` одинаковых ненулевых замеров подряд (= лэйаут замер),
    // затем зовёт onSettled с финальным rect. Не зависит от числа preference-
    // редиспатчей и переживает случай «финальное == первому опубликованному».
    // generation отменяет устаревший поллер, если пользователь переключил снова.
    private func awaitSettled(slot: HeroSlot, generation: Int, fallback: CGRect,
                              onSettled: @escaping (CGRect) -> Void) {
        // Опрашиваем РАЗ В КАДР (≈16мс), а не подряд в одном run-loop: иначе
        // два back-to-back замера видят ОДНУ И ТУ ЖЕ до-скролловую позицию и
        // ложно считаются «стабильными» ещё до того, как scrollTo сдвинул строку
        // (баг: карта летела в старую позицию y, строка уезжала в финальную).
        // Плюс минимум кадров ДО принятия — чтобы scrollTo успел отработать.
        let frameStep: TimeInterval = 1.0 / 60.0
        let minPolls = 4                       // ~4 кадра: даём scrollTo сдвинуть строку
        let deadline = Date().addingTimeInterval(settleTimeout)
        var lastRect: CGRect?
        var streak = 0
        var polls = 0
        func poll() {
            guard generation == flightGeneration else { return }   // отменён новым переключением
            polls += 1
            if let rect = frame(slot), rect != .zero {
                if let last = lastRect, last.equalTo(rect) { streak += 1 } else { streak = 1 }
                lastRect = rect
                // принимаем только после minPolls И при устойчивой позиции
                if polls >= minPolls, streak >= settleStreakRequired { onSettled(rect); return }
            }
            if Date() >= deadline { onSettled(lastRect ?? fallback); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + frameStep, execute: poll)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + frameStep, execute: poll)
    }

    /// Тап по шеврону «назад». Отдельный метод, чтобы дебаг-хук дёргал
    /// ровно тот же путь, что и реальное нажатие.
    private func backTapped() {
        Haptics.soft()
        onCancel?()
    }

    /// Показанный дизайн уже применён → кнопка «Выбрать» неактивна.
    private var isAlreadyApplied: Bool { model.selectedGlobal == committedGlobal }

    /// Подтверждение выбора: отдаём наверх глобальный индекс.
    private func confirmSelection() {
        Haptics.success()
        onConfirm?(model.selectedGlobal)
    }

    private func startFlight(toList: Bool) {
        withAnimation(MotionTokens.morph) {
            morphT = toList ? 1 : 0
        } completion: {
            morphing = false
        }
    }

    // Футер «Выбрать» + Home Indicator (Figma node 3031-119818): градиент
    // 0%→#010101, кнопка (pt8/pb16), затем зона home-indicator 34pt с белой
    // таблеткой 144×5. Системный safe-area-инсет SwiftUI добавит ниже сам.
    /// Главная кнопка внизу. ОДИН источник правды: раньше этот блок был
    /// продублирован байт-в-байт в футере сетки и в шите карусели, и любую
    /// правку приходилось делать дважды.
    private func primaryButton(f: CGFloat) -> some View {
        PrimaryButton(title: primaryTitle,
                      isAlreadyApplied: isAlreadyApplied,
                      alwaysEnabled: primaryAlwaysEnabled,
                      f: f,
                      action: confirmSelection)
    }

    private func selectFooter(f: CGFloat) -> some View {
        VStack(spacing: 0) {
            primaryButton(f: f)
            .padding(.horizontal, 16 * f)
            .padding(.top, 8 * f)
            .padding(.bottom, 16 * f)

            Capsule()
                .fill(Color.white)
                .frame(width: 144 * f, height: 5 * f)
                .padding(.bottom, 8 * f)
                .frame(height: 34 * f, alignment: .bottom)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x010101).opacity(0), Color(hex: 0x010101)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Свайп карусели (Баг 2): жест живёт ТОЛЬКО в режиме карт
    //
    // Тянем 1:1 за пальцем (с насыщающимся сопротивлением за пределом одной
    // коллекции), на релизе — доезд timing-curve. Прерываемый: новый жест
    // перепривязывает startOffset к текущему offset (re-anchor), без блокировки.
    private func carouselDrag(stride: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)   // не перехватываем случайные тапы
            .updating($gestureActive) { _, s, _ in s = true }
            .onChanged { v in
                // Пока идёт анимация перехода — палец не двигает карусель.
                guard !locked else { return }
                // Новый жест: перепривязываем startOffset к ТЕКУЩЕМУ offset
                // (карта могла ещё доезжать) — чтобы не было скачка «замер → прыжок».
                if !dragging { startOffset = offset; dragging = true }
                // тянем за пальцем, но не дальше одной коллекции; за пределом —
                // насыщающееся сопротивление с жёстким потолком
                let raw = v.translation.width
                let sign: CGFloat = raw < 0 ? -1 : 1
                let mag = abs(raw)
                let travel: CGFloat
                if mag <= stride {
                    travel = mag
                } else {
                    let over = mag - stride
                    let extra = (over / (over + stride * 0.6)) * (stride * 0.1)
                    travel = stride + extra
                }
                offset = startOffset + travel * sign
            }
            .onEnded { v in
                dragging = false
                guard !locked else { return }
                // Та же защита от NaN, что и у progress: clamp через max/min
                // NaN НЕ санирует (любое сравнение с NaN ложно), и Int(NaN) роняет.
                guard stride > 0 else { return }
                let currentPage = (-startOffset / stride).rounded()
                let predicted = startOffset + v.predictedEndTranslation.width
                var page = (-predicted / stride).rounded()
                page = max(currentPage - 1, min(currentPage + 1, page))
                guard page.isFinite else { return }

                let target = -page * stride
                let nc = wrap(Int(page))
                // Коллекция реально меняется → держим жест до конца доезда.
                if page != currentPage {
                    locked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + swipeLockDuration) {
                        locked = false
                    }
                }
                // Тяжёлый шит/фон переключаются СРАЗУ и БЕЗ анимации на новую
                // коллекцию — до старта доезда offset, а не посреди него (см.
                // комментарий у объявления settledColl) — и ОТДЕЛЬНОЙ транзакцией
                // с явно выключенной анимацией, чтобы они не попали в тот же
                // commit, что и timingCurve на offset (иначе SwiftUI на стыке
                // коллекции внутри доезда делает лишний повторный body-pass:
                // сначала со старым settledColl, через мгновение — с новым;
                // подтверждено логом вызовов bottomSheet в профилировании).
                withTransaction(Transaction(animation: nil)) {
                    settledColl = nc
                    if model.mode == .cards {
                        model.currentCollection = nc
                        if model.collectionIndex(ofGlobal: model.selectedGlobal) != nc {
                            model.selectedGlobal = colls[nc].range.lowerBound
                        }
                    }
                }
                withAnimation(.timingCurve(0.45, 0, 0.1, 1, duration: transitionDuration)) {
                    offset = target
                }
                startOffset = target
                if nc != lastColl { Haptics.soft(); lastColl = nc }
            }
    }

    // MARK: - Точки (по одной на коллекцию, активная = текущая коллекция)
    private func dots(curColl: Int, f: CGFloat) -> some View {
        HStack(spacing: 6 * f) {
            ForEach(0..<N, id: \.self) { i in
                Capsule()
                    .fill(i == curColl ? Color.white : Color.white.opacity(0.3))
                    .frame(width: (i == curColl ? 14 : 6) * f, height: 6 * f)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: curColl)
    }

    // MARK: - Нижний шит
    private func bottomSheet(curColl: Int, f: CGFloat, stride: CGFloat, bottomInset: CGFloat) -> some View {
        let c = colls[curColl]
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // заголовок + описание — с отступами по краям
                VStack(alignment: .leading, spacing: 0) {
                    Text(c.sheetTitle)
                        .font(.system(size: 17 * f, weight: .bold))
                        .foregroundStyle(Tokens.textPrimary)
                        .frame(height: 32 * f, alignment: .center)
                    Text(c.desc)
                        .font(.system(size: 15 * f, weight: .regular))
                        .foregroundStyle(Tokens.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16 * f)

                // лента превью — на всю ширину, обрезается у края экрана (bleed).
                // Для коллекции из одной карты (Классический дизайн) превью не показываем.
                // БЕЗ .id(curColl): сброс скролла к началу теперь делает сам
                // `thumbs` через ScrollViewReader.scrollTo (см. его комментарий) —
                // ScrollView/миниатюры переживают стык коллекции вместо полного
                // сноса+пересоздания на каждом кадре стыка.
                if c.range.count > 1 {
                    thumbs(curColl: curColl, f: f).padding(.top, 20 * f)
                }

                // Имена (только для Именной карты)
                if !c.names.isEmpty {
                    namesRow(c.names, f: f).padding(.top, 12 * f).padding(.horizontal, 16 * f)
                }
            }
            .padding(.top, 14 * f)

            primaryButton(f: f)
            .padding(.horizontal, 16 * f)
            .padding(.top, 24 * f)
            .padding(.bottom, 8 * f)
        }
        .frame(maxWidth: .infinity)
        // белый фон + Home Indicator у физического низа (отступ Safe Area от кнопки)
        .background(
            ZStack(alignment: .bottom) {
                RoundedCorner(radius: 20 * f, corners: [.topLeft, .topRight])
                    .fill(Tokens.sheetBg)
                Capsule()
                    .fill(Color.black)
                    .frame(width: 144 * f, height: 5 * f)   // Figma home-indicator 144×5
                    .padding(.bottom, 8 * f)
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .animation(.easeInOut(duration: 0.25), value: curColl)
    }

    // Ряд имён для Именной карты
    private func namesRow(_ names: [String], f: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8 * f) {
                ForEach(names.indices, id: \.self) { i in
                    let on = i == nameIndex
                    Text(names[i])
                        .font(.system(size: 14 * f, weight: .semibold))
                        .foregroundStyle(on ? .white : Tokens.textPrimary)
                        .padding(.horizontal, 16 * f)
                        .padding(.vertical, 9 * f)
                        .background(on ? Tokens.accentPink : Color(hex: 0xF2F2F2))
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { nameIndex = i }
                            Haptics.soft()
                        }
                }
            }
            .padding(.vertical, 2 * f)
        }
    }

    // ScrollViewReader вместо .id(curColl): сброс скролла ленты превью к
    // началу коллекции делаем программно (scrollTo), а не сносом identity
    // всей ScrollView. С .id() каждый стык коллекции синхронно уничтожал и
    // заново монтировал ВСЕ миниатюры (decode/blit каждой из них) — теперь
    // ScrollView и её содержимое переживают стык, SwiftUI просто диффит
    // ForEach по глобальным индексам карт (дёшево), а сам скролл долистывает
    // к первой карте новой коллекции.
    private func thumbs(curColl: Int, f: CGFloat) -> some View {
        let c = colls[curColl]
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16 * f) {
                    ForEach(Array(c.range), id: \.self) { gi in
                        thumb(Catalog.cards[gi], active: gi == model.selectedGlobal, f: f)
                            .id(gi)
                            .onTapGesture {
                                withAnimation(MotionTokens.transition(reduceMotion: reduceMotion)) {
                                    model.select(global: gi)   // один выбор на весь экран (Баг 1)
                                }
                                Haptics.soft()
                            }
                    }
                }
                .padding(.horizontal, 16 * f)   // контент начинается от 16, справа обрезается у края
                .padding(.vertical, 6 * f)      // место для обводки сверху/снизу
            }
            .onChange(of: curColl) { _, _ in
                if let first = c.range.first {
                    proxy.scrollTo(first, anchor: .leading)
                }
            }
        }
    }

    private func thumb(_ card: CardItem, active: Bool, f: CGFloat) -> some View {
        let ring = 48 * f
        let img = 40 * f
        // Круглые превью живут в ОТДЕЛЬНОЙ папке MinIO
        // (customize_design_card/change_design_preview) — раньше брались из
        // локального бандла, поэтому у новых коллекций были пустыми.
        return RemoteImage(cardImage: card.image, kind: .preview, contentMode: .fill)
            .frame(width: img, height: img)
            .clipShape(Circle())
            .padding(4 * f)
            // strokeBorder рисует обводку ВНУТРЬ круга → не выходит за рамку и не срезается
            .overlay(Circle().strokeBorder(Tokens.accentPink, lineWidth: active ? 2 * f : 0))
            .frame(width: ring, height: ring)
            .animation(.easeInOut(duration: 0.2), value: active)
    }
}

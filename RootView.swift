import SwiftUI
import Foundation

// MARK: - Корень приложения: «Детали карты» → пикер дизайна
//
// NavigationStack, а не самодельный ZStack-роутер: даём системе интерактивный
// свайп-назад, передачу скорости жеста и корректную деградацию при Reduce
// Motion. Плюс запушенный экран размонтирует предыдущий — а значит
// AmbientBackground с блюром и деревья RemoteImage не живут в двух копиях
// одновременно (ради чего в ContentView и городился Equatable+drawingGroup).
enum AppRoute: Hashable {
    /// Вариант A — один экран пикера с тумблером сетка↔карусель.
    case designPicker
    /// Вариант B, шаг 1 — сетка дизайнов, кнопка «Продолжить».
    case designGrid
    /// Вариант B, шаг 2 — свайп, кнопка «Применить дизайн».
    case designSwipe
    /// Вариант C — один экран: карта сверху, сетка в раскрывающемся шите.
    case designSheet
}

struct RootView: View {
    /// Владелец единой модели: она обязана пережить пуш и возврат.
    @State private var model: PickerModel
    @State private var path: [AppRoute] = []
    @State private var toast: ToastState?
    /// ПРИМЕНЁННЫЙ дизайн (то, что видит экран деталей). Отличается от
    /// `model.selectedGlobal`, который в пикере меняется на каждый тап:
    /// уход по шеврону должен вернуть именно применённый, а не «примеренный».
    @State private var committedGlobal: Int
    /// Настройки A/B и дебаг-панели (синглтон, @Observable).
    @State private var motion = MotionSettings.shared

    // Дебаг-хуки применяем в init, а НЕ в onAppear: onAppear случается уже
    // после первой композиции, и экран успевал отрисовать дефолтный выбор.
    init() {
        let m = PickerModel()
        let env = ProcessInfo.processInfo.environment
        // Проверяем принадлежность к ОТОБРАЖАЕМЫМ коллекциям, а не к
        // Catalog.cards: карты 26–27 («Именная») скрыты из displayCollections,
        // и выбор такой карты оставил бы модель рассогласованной — ни плитки,
        // ни якоря для скролла, ни галочки.
        if let s = env["START_CARD"], let gi = Int(s),
           m.collectionIndex(ofGlobal: gi) != nil {
            m.select(global: gi)
        }
        _model = State(initialValue: m)
        _committedGlobal = State(initialValue: m.selectedGlobal)
        // DEBUG_SPRING читался только в ContentView.onAppear, поэтому на
        // «Деталях карты» панель не открывалась. Теперь флаг обрабатывается
        // в корне — там же, где панель и живёт.
        if env["DEBUG_SPRING"] == "1" { MotionSettings.shared.showPanel = true }
        // START_RESET=1 — дёрнуть Reset программно (тапать в симуляторе нельзя).
        if env["START_TOAST"] == "1" {
            _toast = State(initialValue: ToastState(text: "Готово! Дизайн карты обновлён"))
        }
        // ВНИМАНИЕ: путь навигации здесь НЕ задаём. Стартовать NavigationStack
        // с непустым path в init нельзя — SwiftUI роняет приложение на первой
        // композиции. Пуш делаем после первого кадра, в .task ниже.
    }

    /// Дебаг-хук отложенного пуша (START_SCREEN=picker).
    /// START_PICK=<gi> — выбрать карту УЖЕ ПОСЛЕ открытия пикера: так
    /// воспроизводится реальный путь (выбор меняется при живой сетке).
    private func applyDeferredHooks() {
        let env = ProcessInfo.processInfo.environment
        guard env["START_SCREEN"] == "picker", path.isEmpty else { return }
        openPicker()
        if let s = env["START_PICK"], let gi = Int(s),
           Catalog.cards.indices.contains(gi) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                model.select(global: gi)
                // START_CONTINUE=1 — вариант B: нажать «Продолжить» и уйти на свайп.
                if env["START_CONTINUE"] == "1" {
                    try? await Task.sleep(for: .milliseconds(600))
                    continueToSwipe()
                }
                // START_CANCEL=1 — уйти назад по шеврону (проверка отката).
                // START_CONFIRM=1 — применить дизайн, как будто нажали
                // «Выбрать»: единственный путь, который иначе никак
                // не проверить без тапов.
                if env["START_CANCEL"] == "1" {
                    try? await Task.sleep(for: .milliseconds(600))
                    cancelPicker()
                } else if env["START_CONFIRM"] == "1" {
                    try? await Task.sleep(for: .milliseconds(600))
                    confirm(gi)
                }
                // START_REOPEN=1 — после возврата снова открыть пикер:
                // проверяем, что «примерка» НЕ потерялась.
                if env["START_REOPEN"] == "1" {
                    try? await Task.sleep(for: .milliseconds(900))
                    openPicker()
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let f = geo.size.width / 375
            let _ = resetHookIfNeeded()

            NavigationStack(path: $path) {
                CardDetailsView(model: model,
                                appliedGlobal: committedGlobal,
                                onOpenPicker: openPicker)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .designPicker:
                            // Вариант A — как было.
                            ContentView(model: model,
                                        onConfirm: confirm,
                                        onCancel: cancelPicker,
                                        committedGlobal: committedGlobal)
                                // Свой аппбар рисуется поверх safeArea — системный
                                // бар добавил бы второй и сдвинул макет вниз.
                                // Скрытая кнопка «назад» заодно снимает конфликт
                                // edge-свайпа с жестом карусели.
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarBackButtonHidden(true)

                        case .designGrid:
                            // Вариант B, шаг 1: только сетка, тумблера нет,
                            // кнопка ведёт дальше, а не применяет.
                            ContentView(model: model,
                                        onConfirm: { _ in continueToSwipe() },
                                        onCancel: cancelPicker,
                                        committedGlobal: committedGlobal,
                                        hideModeToggle: true,
                                        primaryTitle: "Продолжить",
                                        primaryAlwaysEnabled: true,
                                        forcedMode: .list)
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarBackButtonHidden(true)

                        case .designSheet:
                            SheetPickerView(model: model,
                                            committedGlobal: committedGlobal,
                                            onConfirm: confirm,
                                            onCancel: cancelPicker)
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarBackButtonHidden(true)

                        case .designSwipe:
                            // Вариант B, шаг 2: свайп, здесь дизайн применяется.
                            // Назад ведёт В СЕТКУ, а не сразу на Детали.
                            ContentView(model: model,
                                        onConfirm: confirm,
                                        onCancel: backFromSwipe,
                                        committedGlobal: committedGlobal,
                                        hideModeToggle: true,
                                        primaryTitle: "Применить дизайн",
                                        primaryAlwaysEnabled: true,
                                        forcedMode: .cards)
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarBackButtonHidden(true)
                        }
                    }
            }
            .task {
                // Дебаг-хуки — СРАЗУ, до любой сетевой работы.
                applyDeferredHooks()
                CardImages.shared.preload(Catalog.cards.map(\.image))
                // Грузим ПО ОЧЕРЕДИ, а не все 4 папки × 55 карт разом:
                // 220 одновременных запросов забивали пул URLSession, и то,
                // что нужно прямо сейчас, приезжало последним.
                // Порядок = порядок появления на экране.
                // Что грузить первым — зависит от ЗАПОМНЕННОГО режима:
                // в карусели нужна крупная карта и круглые превью,
                // в сетке — плитки.
                let firstScreen: [CardArtSource.Kind] =
                    model.mode == .cards ? [.full, .preview] : [.mini]
                await RemoteImageLoader.shared.warmInPriorityOrder(
                    selected: model.selectedCard.image,
                    all: Catalog.cards.map(\.image),
                    firstScreen: firstScreen
                )
            }
            // Тост — СВЕРХУ, под статус-баром (макет 3602:102833).
            .overlay(alignment: .top) {
                ToastHost(state: $toast, f: f)
                    .padding(.top, geo.safeAreaInsets.top + 8 * f)
            }
            // Дебаг-панель живёт НАД NavigationStack, а не внутри пикера:
            // переключать вариант A/B нужно и с экрана «Детали карты».
            //
            // Открывается ПЛАВАЮЩЕЙ КНОПКОЙ: жесты (тройной тап, долгое
            // нажатие) никто не находит — кнопка видна всегда.
            .overlay(alignment: .bottomTrailing) {
                // В варианте C низ занят шитом с закреплённой кнопкой —
                // плавающая кнопка легла бы на плитки. Там панель
                // открывается тройным тапом по заголовку.
                if !motion.showPanel && motion.flow != .c {
                    debugFab(f: f)
                        .padding(.trailing, 16 * f)
                        // В варианте C снизу шит с закреплённой кнопкой —
                        // поднимаем FAB выше, чтобы он не лёг на сетку.
                        .padding(.bottom, geo.safeAreaInsets.bottom + 92 * f)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if motion.showPanel {
                    DebugSpringPanel(settings: motion, f: f, onReset: resetPrototype)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 24 * f)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.dark)
    }

    private func openPicker() {
        // Режим НЕ перезатираем: он запоминается в PickerModel (и переживает
        // перезапуск). Пользователь переключился на свайп → вышел в детали →
        // вернулся — видит тот же вид. Первый запуск даёт сетку.
        // START_MODE — дебаг-хук, только он имеет право продавить режим.
        switch ProcessInfo.processInfo.environment["START_MODE"] {
        case "cards": model.mode = .cards
        case "list":  model.mode = .list
        default:      break
        }
        model.ensureSelectedVisible()
        // switch, а не тернарник: с тремя вариантами он бы молча увёл C в A.
        switch motion.flow {
        case .a: path.append(.designPicker)
        case .b: path.append(.designGrid)
        case .c: path.append(.designSheet)
        }
    }

    /// Вариант B: «Продолжить» из сетки → экран свайпа.
    private func continueToSwipe() {
        Haptics.soft()
        path.append(.designSwipe)
    }

    /// Вариант B: назад со свайпа → обратно в сетку (не на Детали).
    private func backFromSwipe() {
        path.removeLast()
    }

    private func confirm(_ globalIndex: Int) {
        model.select(global: globalIndex)
        committedGlobal = globalIndex
        // removeAll, а не removeLast: в варианте B стек глубиной 2
        // (сетка → свайп), и removeLast вернул бы на сетку вместо Деталей.
        path.removeAll()
        toast = ToastState(text: "Готово! Дизайн карты обновлён")
    }

    /// Плавающая кнопка открытия дебаг-панели. Намеренно маленькая и
    /// полупрозрачная — это инструмент прототипа, а не часть интерфейса.
    private func debugFab(f: CGFloat) -> some View {
        Button {
            Haptics.soft()
            withAnimation(.easeInOut(duration: 0.2)) { motion.showPanel = true }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17 * f, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44 * f, height: 44 * f)
                .background(
                    Circle()
                        .fill(Color(hex: 0x141414).opacity(0.9))
                        .overlay(Circle().strokeBorder(.white.opacity(0.18)))
                        .shadow(color: .black.opacity(0.4), radius: 8 * f, y: 3 * f)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Настройки прототипа")
    }

    /// Дебаг-хук для Reset: срабатывает один раз.
    @MainActor private func resetHookIfNeeded() {
        guard ProcessInfo.processInfo.environment["START_RESET"] == "1",
              !Self.resetHookFired else { return }
        Self.resetHookFired = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            resetPrototype()
        }
    }
    nonisolated(unsafe) private static var resetHookFired = false

    /// Сброс прототипа к состоянию первого запуска.
    ///
    /// Кэш картинок НЕ трогаем: он на диске и его очистка означала бы повторную
    /// закачку ~11 МБ и минуту скелетонов — для демо это хуже, чем польза
    /// от «совсем чистого» старта.
    private func resetPrototype() {
        Haptics.success()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: ABFlow.storageKey)
        defaults.removeObject(forKey: PickerModel.modeStorageKey)

        withAnimation(MotionTokens.transition(reduceMotion: false)) {
            motion.flow = .a
            model.expanded.removeAll()
            model.mode = .list
            let start = Catalog.displayCollections.first?.range.lowerBound ?? 0
            model.select(global: start)
            committedGlobal = start
            path.removeAll()
            toast = nil
            motion.showPanel = false
        }
    }

    /// Назад по шеврону: просто закрываем пикер.
    ///
    /// Выбор НЕ сбрасываем. Сначала шеврон откатывал «примерку» к применённому
    /// дизайну, но это ощущалось как потеря выбора: пользователь пролистал,
    /// выбрал карту, вышел — и выбор исчез. Теперь состояние пикера
    /// сохраняется, а применённым дизайн делает только кнопка «Выбрать».
    private func cancelPicker() {
        path.removeLast()
    }
}

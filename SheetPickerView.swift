import SwiftUI

// MARK: - Вариант C: карта сверху + раскрывающийся шит с сеткой
//
// Референс — Sber.mp4, разобранный по кадрам. Ключевые наблюдения оттуда:
//   • один экран, никаких переходов;
//   • тап по плитке МГНОВЕННО меняет карту вверху (примерка видна сразу),
//     а кнопка внизу только фиксирует выбор;
//   • шит НАЕЗЖАЕТ поверх карты — карта не сжимается и не уезжает,
//     она просто остаётся под ним;
//   • шит поднимается ПОД аппбар, шапка видна всегда.
//
// Почему отдельный экран, а не ещё один набор параметров у ContentView:
// у C своя раскладка и своё состояние высоты, а в ContentView уже две ветки
// (карусель/сетка) — третья сделала бы файл нечитаемым.
struct SheetPickerView: View {
    let model: PickerModel
    var committedGlobal: Int = -1
    var onConfirm: ((Int) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Два положения, без промежуточного (решение по плану).
    private enum SheetState { case collapsed, expanded }
    @State private var sheet: SheetState = .collapsed
    /// Решение принимается ОДИН раз за жест. Без этой защёлки onChanged,
    /// который сыплется на каждое движение пальца, успевал перещёлкнуть
    /// состояние 2-3 раза за один непрямой свайп (вверх-вниз-вверх) —
    /// с хаптиком и анимацией на каждый щелчок.
    @State private var gestureResolved = false
    /// Сетка прокручена в самое начало — тогда тяга вниз сворачивает шит.
    @State private var gridAtTop = true
    /// Режим выбора свайпом (карусель варианта A) поверх шита.
    ///
    /// Это НЕ отдельный экран и не push в NavigationStack: переключение
    /// должно ощущаться как смена вида внутри одного экрана, а не как
    /// уход в другой раздел. Обе ветки живут в одном ZStack и
    /// кросс-фейдятся по swipeT — ровно тот же приём, что в варианте A
    /// (ContentView.morphT).
    @State private var swipeMode = false
    @State private var swipeT: CGFloat = 0     // 0 = шит, 1 = карусель


    var body: some View {
        // Шит и карусель — СИБЛИНГИ в одном ZStack, а не вложены друг в
        // друга: у ContentView свой GeometryReader и свой аппбар от
        // safeAreaInsets, и вложенным он этих инсетов не получает —
        // аппбар наезжал на статус-бар.
        ZStack {
            sheetScreen
            // Переиспользуем ContentView целиком, а не вытаскиваем карусель
            // отдельным компонентом: её жест завязан на offset/stride/
            // settledColl и уже отлажен под гонки SwiftUI (carouselDrag),
            // копия неизбежно разошлась бы с оригиналом.
            //
            // onToggleMode: тумблер в аппбаре карусели возвращает сюда же,
            // а не переключает режим внутри ContentView.
            if swipeMode || swipeT > 0 {
                ContentView(model: model,
                            onConfirm: onConfirm,
                            onCancel: { toggleSwipe() },
                            committedGlobal: committedGlobal,
                            forcedMode: .cards,
                            onToggleMode: { toggleSwipe() })
                    .opacity(Double(swipeT))
                    .allowsHitTesting(swipeT > 0.5)
            }
        }
    }

    private var sheetScreen: some View {
        GeometryReader { geo in
            // START_SHEET=open — раскрыть шит программно (тапать и скроллить
            // в симуляторе нельзя).
            let _ = openHookIfNeeded()
            let f = geo.size.width / 375
            let topInset = geo.safeAreaInsets.top
            let H = geo.size.height + topInset + geo.safeAreaInsets.bottom
            // Раскрытый шит встаёт под аппбар (как в референсе), а не под
            // статус-бар: шапка должна оставаться видимой.
            let maxH = H - (topInset + 52 * f)
            let minH = H * 0.46
            let height = sheetHeight(min: minH, max: maxH)

            ZStack(alignment: .top) {
                // Карта и подпись — НЕ двигаются: шит наезжает поверх них.
                VStack(spacing: 0) {
                    appbar(f: f).padding(.top, topInset)
                    cardHero(f: f)
                        .padding(.top, 20 * f)
                        .padding(.horizontal, 37 * f)
                        .onTapGesture { setSheet(.collapsed) }
                    // Макет 3632:118391 — имя и описание ВЫБРАННОГО дизайна.
                    // (Раньше здесь по ошибке стоял дисклеймер из референса
                    // Сбера — это не наш макет.)
                    VStack(spacing: 4 * f) {
                        Text(model.selectedCard.title)
                            .font(.system(size: 20 * f, weight: .bold))
                            .foregroundStyle(.white)
                        Text(model.selectedCard.subtitle)
                            .font(.system(size: 13 * f))
                            .foregroundStyle(Tokens.onDarkSecondary)
                    }
                    .multilineTextAlignment(.center)
                    // Макет: gap 20 между картой и подписью, поля 24.
                    .padding(.top, 20 * f)
                    .padding(.horizontal, 24 * f)
                    .animation(MotionTokens.transition(reduceMotion: reduceMotion),
                               value: model.selectedGlobal)
                    Spacer(minLength: 0)
                }

                // Шит
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    sheetBody(f: f, height: height, bottomInset: geo.safeAreaInsets.bottom)
                }
            }
            .frame(width: geo.size.width, height: H)
            .background(
                AmbientBackground(W: geo.size.width, H: H,
                                  cardImage: model.selectedCard.image,
                                  reduceMotion: reduceMotion)
                    .equatable()
                    .ignoresSafeArea()
            )
            .ignoresSafeArea()
        }
        .background(Color.black)
        // Вся ветка шита гаснет разом — вместе с картой и аппбаром.
        // Скрытый шит не должен ловить тапы: невидимая сетка иначе
        // воровала бы жесты у карусели.
        .opacity(Double(1 - swipeT))
        .allowsHitTesting(swipeT < 0.5)
    }

    // MARK: - Шит

    private func sheetBody(f: CGFloat, height: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Верхняя кромка (в макете грабера нет) — просто отступ.
            Color.clear
                .frame(height: 16 * f)
                .frame(maxWidth: .infinity)

            DesignGridView(model: model, f: f,
                           // Аппбара над сеткой тут нет: спейсер не нужен.
                           topInset: -60 * f,
                           // В свёрнутом шите вьюпорт низкий, и .center
                           // промахнулся бы мимо выбранной карты.
                           scrollAnchor: .top,
                           scrollToSection: true,
                           onLight: true,
                           // Выбрал дизайн → шит сворачивается и показывает
                           // карту с новым артом.
                           onPick: { setSheet(.collapsed) },
                           onFirstSectionVisible: { gridAtTop = $0 })
                .padding(.top, 4 * f)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    PrimaryButton(isAlreadyApplied: model.selectedGlobal == committedGlobal,
                                  f: f) {
                        Haptics.success()
                        onConfirm?(model.selectedGlobal)
                    }
                    .padding(.horizontal, 16 * f)
                    .padding(.top, 12 * f)
                    .padding(.bottom, bottomInset + 8 * f)
                    // Сплошная подложка, а не градиент: сквозь прозрачный низ
                    // просвечивал заголовок следующей коллекции.
                    .background(
                        Tokens.sheetBg
                            .overlay(alignment: .top) {
                                LinearGradient(colors: [Tokens.sheetBg.opacity(0),
                                                        Tokens.sheetBg],
                                               startPoint: .top, endPoint: .bottom)
                                    .frame(height: 16 * f)
                                    .offset(y: -16 * f)
                            }
                            .allowsHitTesting(false)
                    )
                }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        // ЖЕСТ НА ВЕСЬ ШИТ, а не только на кромку.
        //
        // Раньше он висел на 16pt-полоске сверху, и до него было не
        // добраться: палец попадал в ScrollView, тот забирал жест себе,
        // а мой замер прокрутки не срабатывал вовсе. Понижение порога
        // не помогало — проблема была не в пороге.
        //
        // simultaneousGesture: жест И скролл живут вместе. Пока шит свёрнут,
        // тяга вверх поднимает его; когда раскрыт — просто скроллим сетку.
        .simultaneousGesture(sheetDrag(f: f))
        .background(
            RoundedCorner(radius: 20 * f, corners: [.topLeft, .topRight])
                .fill(Tokens.sheetBg)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(MotionTokens.sheet(reduceMotion: reduceMotion), value: sheet)
    }

    // MARK: - Жест и скролл

    private func sheetDrag(f: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                guard !gestureResolved else { return }
                if handleDrag(up: -v.translation.height) {  // >0 — тянем вверх
                    gestureResolved = true
                }
            }
            .onEnded { v in
                // Последний шанс: если за весь жест порог так и не был
                // превышен ни на одном промежуточном сэмпле, судим по
                // итоговому смещению. Иначе медленная, но длинная тяга
                // (палец идёт ровно, без рывков) осталась бы без реакции.
                if !gestureResolved { _ = handleDrag(up: -v.translation.height) }
                gestureResolved = false
            }
    }

    /// Решение «раскрыть / свернуть / просто скроллить» — единая точка,
    /// которую дёргает и реальный жест, и дебаг-хук START_DRAG (проверяет
    /// РЕАЛЬНУЮ логику, а не копию, которая могла бы с ней разойтись).
    /// Возвращает true, если жест РЕШЁН — состояние переключено и дальше
    /// этот же свайп трогать шит не должен.
    @discardableResult
    private func handleDrag(up: CGFloat) -> Bool {
        // СВЁРНУТ: любое движение вверх сразу раскрывает. Это и есть
        // «начал скроллить — шит поднялся»: пользователю не нужно
        // знать, что под пальцем список, а не ручка.
        if sheet == .collapsed, up > 6 {
            setSheet(.expanded)
            return true
        }
        // РАСКРЫТ: сворачиваем ТОЛЬКО если список уже долистан
        // до первой коллекции. Пока пользователь где-то в середине,
        // тяга вниз — это обычный скролл, шит не трогаем.
        //
        // gridAtTop читается ИМЕННО ЗДЕСЬ, в момент решения, а не
        // запоминается на старте жеста: пользователь может долистать до
        // верха и продолжить тянуть вниз одним движением — это и должно
        // свернуть шит.
        if sheet == .expanded, up < -40, gridAtTop {
            setSheet(.collapsed)
            return true
        }
        return false
    }

    /// Замер прокрутки нужен ровно для одного: понять, в самом ли верху
    /// список. По нему решаем, сворачивать шит или это обычный скролл.
    ///
    /// Раскрытием управляет ЖЕСТ, а не этот колбэк: до него дело не доходило,
    /// пока жест забирал себе ScrollView.


    @MainActor private func openHookIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        // Хуки независимы: свайп проверяется и без раскрытого шита.
        guard env["START_SHEET"] == "open" || env["START_SWIPE"] == "1",
              !Self.openHookFired else { return }
        Self.openHookFired = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            if env["START_SHEET"] == "open" { setSheet(.expanded) }
            // START_SHEET=pick — после раскрытия сымитировать ТАП по плитке
            // (тем же путём, что и палец), чтобы проверить сворачивание.
            if ProcessInfo.processInfo.environment["START_SHEET_PICK"] == "1" {
                try? await Task.sleep(for: .milliseconds(1200))
                model.select(global: model.selectedGlobal == 31 ? 32 : 31)
                setSheet(.collapsed)
            }
            // START_DRAG=down — сымитировать тягу вниз ПОСЛЕ раскрытия шита
            // (тапать/скроллить в симуляторе нельзя). Прогоняет ровно ту же
            // handleDrag(up:), что и палец — проверяет реальную логику
            // «сворачивать только если gridAtTop», а не отдельную копию.
            // START_CARD=52 в связке с этим хуком воспроизводит сценарий
            // «список долистан до середины (9-я коллекция), шит раскрыт,
            // тянем вниз» — шит НЕ должен свернуться.
            // START_SWIPE=1 — переключиться на карусель тем же toggleSwipe(),
            // что и кнопка в аппбаре (тапать в симуляторе нельзя).
            // START_SWIPE_BACK=1 — и вернуться обратно в шит.
            if ProcessInfo.processInfo.environment["START_SWIPE"] == "1" {
                try? await Task.sleep(for: .milliseconds(1000))
                toggleSwipe()
                if ProcessInfo.processInfo.environment["START_SWIPE_BACK"] == "1" {
                    try? await Task.sleep(for: .milliseconds(1500))
                    toggleSwipe()
                }
            }
            if ProcessInfo.processInfo.environment["START_DRAG"] == "down" {
                try? await Task.sleep(for: .milliseconds(1200))
                handleDrag(up: -80)
            }
        }
    }
    nonisolated(unsafe) private static var openHookFired = false

    /// Переключение шит ↔ карусель кросс-фейдом, без пуша экрана.
    ///
    /// swipeMode держится в дереве всю анимацию (снимается не сразу, а
    /// после её конца) — иначе уходящая ветка исчезала бы мгновенно и
    /// фейда не было бы видно вовсе.
    private func toggleSwipe() {
        Haptics.soft()
        let toSwipe = !swipeMode
        if toSwipe { swipeMode = true }
        withAnimation(MotionTokens.transition(reduceMotion: reduceMotion)) {
            swipeT = toSwipe ? 1 : 0
        }
        if !toSwipe {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                if swipeT == 0 { swipeMode = false }
            }
        }
    }

    private func setSheet(_ s: SheetState) {
        guard sheet != s else { return }
        Haptics.soft()
        withAnimation(MotionTokens.sheet(reduceMotion: reduceMotion)) { sheet = s }
    }

    /// Высота — только от КВАНТОВАННОГО состояния, без слежения за пальцем.
    ///
    /// Так задумано: под пальцем здесь живёт ScrollView, и тянуть шит
    /// за содержимое 1:1 означало бы драться со скроллом за каждый кадр.
    /// Шит вместо этого щёлкает между двумя положениями по порогу, а
    /// плавность даёт пружина MotionTokens.sheet. Заодно это снимает
    /// претензию к производительности из ContentView.swift:51-60 —
    /// в observable-состояние ничего не пишется на каждом кадре.
    private func sheetHeight(min minH: CGFloat, max maxH: CGFloat) -> CGFloat {
        sheet == .expanded ? maxH : minH
    }

    // MARK: - Аппбар и карта

    private func appbar(f: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 1) {
                Text("Цифровой дизайн карты")
                    .font(.system(size: 15 * f, weight: .bold))
                    .foregroundStyle(.white)
                Text("Visa Cashback")
                    .font(.system(size: 13 * f))
                    .foregroundStyle(Tokens.onDarkSecondary)
            }
            // Плавающей кнопки в этом варианте нет (низ занят шитом) —
            // дебаг-панель открывается тройным тапом по заголовку.
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    MotionSettings.shared.showPanel.toggle()
                }
            }
            HStack {
                Button { onCancel?() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17 * f, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48 * f, height: 48 * f)
                        .liquidGlass(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Назад")
                Spacer()
                // Правая кнопка — переход на выбор свайпом (макет 3702:71210).
                // Тот же глиф «стопка карт», что и в варианте A: там он тоже
                // означает «показать карусель», и менять смысл иконки между
                // вариантами нельзя.
                Button(action: toggleSwipe) {
                    CardsModeIcon()
                        .foregroundStyle(.white)
                        .frame(width: 24 * f, height: 24 * f)
                        .frame(width: 48 * f, height: 48 * f)
                        .liquidGlass(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Отображение картами")
            }
            .padding(.horizontal, 16 * f)
        }
        .frame(height: 48 * f)
        .padding(.top, 4 * f)
    }

    private func cardHero(f: CGFloat) -> some View {
        // Макет 3748:58407 (Card_base): 300×188, радиус 8, поля по бокам 37.
        // Было 216 высоты и радиус 16 — карта выглядела крупнее и мягче,
        // чем в дизайне.
        RemoteImage(cardImage: model.selectedCard.image, kind: .detail, contentMode: .fill)
            .frame(height: 188 * f)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8 * f, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 16 * f, y: 10 * f)
            // Карта живёт под шитом и меняется по тапу, даже когда её не видно:
            // свернув шит, пользователь должен увидеть уже новый дизайн.
            .animation(MotionTokens.transition(reduceMotion: reduceMotion),
                       value: model.selectedGlobal)
    }
}

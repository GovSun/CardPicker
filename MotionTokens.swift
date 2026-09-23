import SwiftUI

// MARK: - Живо настраиваемые параметры пружины (для дебаг-панели)
//
// Одна пружина на всё (принцип 1). Значения по умолчанию — «побыстрее» по
// фидбеку. Дебаг-панель меняет их на лету через этот синглтон.
/// Вариант A/B-теста флоу выбора дизайна.
enum ABFlow: String, CaseIterable {
    case a, b, c
    static let storageKey = "ab.flow"
    /// switch, а НЕ тернарник: с тремя кейсами `self == .a ? "A" : "B"`
    /// молча возвращал бы «B» для варианта C.
    var title: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        }
    }
}

@Observable
final class MotionSettings {
    static let shared = MotionSettings()

    /// response (сек) — «как быстро». Меньше = резче/быстрее.
    var response: Double = 0.30
    /// dampingFraction (0…1) — «сколько отскока». Ближе к 1 = без отскока.
    var damping: Double = 0.86

    /// Показывать ли дебаг-панель (тап по кнопке-переключателю с зажатым... нет —
    /// просто флаг, включаемый через env DEBUG_SPRING=1 или тройным тапом).
    var showPanel = false

    /// LEGACY_LIST=1 — показать старый строчный список вместо сетки дизайнов.
    /// Старый режим сохранён «на будущее» и остаётся запускаемым для сравнения.
    var useLegacyList = ProcessInfo.processInfo.environment["LEGACY_LIST"] == "1"

    // MARK: - A/B-тест флоу выбора дизайна
    //
    // A — то, что уже реализовано: один экран пикера с тумблером сетка↔карусель,
    //     кнопка «Выбрать» применяет дизайн сразу.
    // B — трёхуровневый флоу: Детали → Сетка («Продолжить») → Свайп
    //     («Применить дизайн») → Детали. Тумблера режима нет.
    // C — один экран: карта сверху, сетка в шите снизу. Шит наезжает на карту
    //     при скролле; тап по плитке сразу меняет карту (референс — Сбер).
    var flow: ABFlow = ABFlow(rawValue: ProcessInfo.processInfo.environment["AB_FLOW"] ?? "")
        ?? ABFlow(rawValue: UserDefaults.standard.string(forKey: ABFlow.storageKey) ?? "")
        ?? .a
    {
        didSet {
            guard flow != oldValue else { return }
            UserDefaults.standard.set(flow.rawValue, forKey: ABFlow.storageKey)
        }
    }

    var spring: Animation { .spring(response: response, dampingFraction: damping) }
}

// MARK: - Единые токены движения (принцип 1: одна пружина на всё)
enum MotionTokens {

    /// Базовая пружина проекта (нажатия, вторичные переходы) — из настроек.
    static var spring: Animation { MotionSettings.shared.spring }

    /// Пружина перелёта режимов — та же настраиваемая пружина (одна на всё).
    static var morph: Animation { MotionSettings.shared.spring }

    /// Отклик нажатия — масштаб зависит от размера элемента (принцип 7):
    /// крупные карточки жмутся меньше, мелкие иконки сильнее.
    static func pressScale(large: Bool) -> CGFloat { large ? 0.97 : 0.90 }

    /// Плитка сетки (111×72) — третий размерный класс между крупным и мелким.
    /// 0.90 на арте читается как баг, 0.97 — как отсутствие отклика.
    static let pressScaleTile: CGFloat = 0.95

    // MARK: - Токены сверх базовой пружины
    //
    // ОСОЗНАННОЕ отступление от «одной пружины на всё». Базовая (0.30/0.86)
    // отлично работает для нажатий и мелких переходов, но ниже — два класса
    // движения, которые она обслуживает неверно. Не «чинить» обратно.

    /// Раскрытие/сворачивание секции («+N еще»).
    /// damping 1.0, потому что тап — жест БЕЗ инерции, отскок ему не положен:
    /// на росте контейнера в 300+pt перелёт базовой пружины превращается
    /// в заметный отскок всего, что ниже. response 0.42 — дистанция больше,
    /// значит и время больше (у Apple reposition ≈ 0.4).
    static let expand: Animation = .spring(response: 0.42, dampingFraction: 1.0)

    /// Чистая смена прозрачности (крышка «+N еще», уход галочки, «Свернуть»).
    /// У opacity нет физики — пружина на ней это карго-культ, нужен timed-кривой.
    static let reveal: Animation = .easeOut(duration: 0.18)

    /// Появление тоста: редкое событие, лёгкий отскок уместен.
    static let toastIn: Animation = .spring(response: 0.38, dampingFraction: 0.82)
    /// Уход тоста: быстрее входа — его никто не разглядывает.
    static let toastOut: Animation = .easeIn(duration: 0.22)

    /// Каскад раскрывающихся РЯДОВ (не плиток: плитки одного ряда на одной
    /// высоте, задерживать их друг относительно друга нечего).
    /// Потолок обязателен: без него на длинной коллекции последний ряд
    /// приезжает уже после остановки контейнера и читается как баг.
    static func staggerDelay(_ row: Int, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : min(Double(max(0, row)) * 0.022, 0.13)
    }

    /// Посадка шита после ПЕРЕТАСКИВАНИЯ (вариант C).
    ///
    /// Не переиспользуем `expand`: у него damping 1.0, потому что тап — жест
    /// без инерции. У отпускания пальца инерция есть, и полностью критическое
    /// демпфирование читается как «прилипло». 0.85 даёт лёгкую доводку,
    /// не переходящую в отскок.
    static let sheet: Animation = .spring(response: 0.42, dampingFraction: 0.85)

    static func sheet(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : sheet
    }

    /// Раскрытие с учётом Reduce Motion.
    static func expand(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : expand
    }

    /// Ветка Reduce Motion (принцип 10): мгновенный переход без пружины.
    static func transition(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : spring
    }
}

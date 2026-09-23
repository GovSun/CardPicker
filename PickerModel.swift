import SwiftUI

// MARK: - Режим отображения
enum ViewMode: String { case cards, list }

// MARK: - Единый источник истины для обоих режимов (ТЗ §4, §7.4; ТЗ2.0 Баг 1)
//
// Обе вьюхи (карусель и список) читают/пишут ОДНО состояние: текущая
// коллекция, ГЛОБАЛЬНО выбранная карта (одна на весь экран) и режим.
@Observable
final class PickerModel {
    let collections = Catalog.displayCollections

    /// Индекс текущей коллекции (в порядке `displayCollections`).
    var currentCollection = 0

    /// ЕДИНЫЙ выбор на весь экран — глобальный индекс карты в `Catalog.cards`.
    /// Один radio активен во всём списке и в карусели (Баг 1).
    var selectedGlobal: Int

    /// Текущий режим отображения.
    ///
    /// ЗАПОМИНАЕТСЯ между заходами в пикер и между запусками приложения:
    /// переключился на свайп → вышел в детали → вернулся — режим тот же.
    var mode: ViewMode = .cards {
        didSet {
            guard mode != oldValue else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
        }
    }

    static let modeStorageKey = "picker.viewMode"
    private static var modeKey: String { modeStorageKey }

    init() {
        // По умолчанию — первая карта первой отображаемой коллекции.
        selectedGlobal = Catalog.displayCollections.first?.range.lowerBound ?? 0
        // Восстанавливаем последний использованный режим; по умолчанию —
        // сетка («списком»), как требует ТЗ для первого запуска.
        let saved = UserDefaults.standard.string(forKey: Self.modeKey)
            .flatMap(ViewMode.init(rawValue:))
        mode = saved ?? .list
    }

    var count: Int { collections.count }

    func wrap(_ k: Int) -> Int { ((k % count) + count) % count }

    /// Коллекция, которой принадлежит глобальный индекс карты (в порядке display).
    func collectionIndex(ofGlobal gi: Int) -> Int? {
        collections.firstIndex { $0.range.contains(gi) }
    }

    /// Выбранная карта КОЛЛЕКЦИИ c: если глобальный выбор попадает в эту
    /// коллекцию — он; иначе первая карта коллекции (для отображения в карусели).
    func selectedGlobalIndex(_ c: Int) -> Int {
        let cc = wrap(c)
        if collections[cc].range.contains(selectedGlobal) { return selectedGlobal }
        return collections[cc].range.lowerBound
    }

    func selectedCard(_ c: Int) -> CardItem { Catalog.cards[selectedGlobalIndex(c)] }

    /// Глобально выбранная карта (для фона списка — Баг 6).
    var selectedCard: CardItem { Catalog.cards[selectedGlobal] }

    /// Выбрать карту по глобальному индексу (перезаписывает выбор в любой коллекции).
    func select(global gi: Int) {
        selectedGlobal = gi
        if let ci = collectionIndex(ofGlobal: gi) { currentCollection = ci }
    }

    // MARK: - Раскрытие коллекций в сетке («+N еще»)
    //
    // Живёт в модели, а НЕ в @State сетки: DesignGridView монтируется условно
    // (`if model.mode == .cards … else …`), поэтому переключение в карусель и
    // обратно уничтожило бы локальный @State и молча схлопнуло раскрытое.

    /// Сколько плиток показываем в свёрнутой секции.
    static let previewLimit = 5

    /// Индексы коллекций (в порядке display), раскрытых полностью.
    var expanded: Set<Int> = []

    func isExpanded(_ ci: Int) -> Bool { expanded.contains(ci) }

    func toggleExpanded(_ ci: Int) {
        if expanded.contains(ci) { expanded.remove(ci) } else { expanded.insert(ci) }
    }

    /// Локальный индекс карты внутри её коллекции.
    func localIndex(ofGlobal gi: Int) -> Int? {
        guard let ci = collectionIndex(ofGlobal: gi) else { return nil }
        return gi - collections[ci].range.lowerBound
    }

    /// Сколько карт скрыто под плиткой «+N еще» (0 — плитки нет).
    func overflowCount(_ ci: Int) -> Int {
        max(0, collections[wrap(ci)].range.count - Self.previewLimit)
    }

    /// Гарантирует, что выбранная карта ВИДИМА в свёрнутой сетке.
    /// Без этого выбранный 6-й+ дизайн не отрисован, скролл к нему уезжает
    /// в никуда, а hero-репер (.row) никто не публикует.
    func ensureSelectedVisible() {
        guard let ci = collectionIndex(ofGlobal: selectedGlobal),
              let li = localIndex(ofGlobal: selectedGlobal) else { return }
        if li >= Self.previewLimit { expanded.insert(ci) }
    }

    /// Стабильный якорь для `ScrollViewReader`.
    func anchorID(collection c: Int) -> String { "coll-\(wrap(c))" }
    func cardAnchorID(globalIndex gi: Int) -> String { "card-\(gi)" }
}

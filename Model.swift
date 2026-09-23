import SwiftUI

// Каталог дизайнов карт — сгенерирован из Figma (file y1jCDm8fP13bY2kfGs0wE4),
// 10 актуальных продовых коллекций, 55 карт.
//
// ВАЖНО про источник текстов: в этом Figma-файле имена ФРЕЙМОВ устарели почти
// везде (все карточки «Этно» называются «Кочкор муйуз», фреймы «Мемы» носят
// названия карт из «Движ»). Тайтлы и сабтайтлы взяты ТОЛЬКО из текстовых нод,
// названия и описания коллекций — из инстансов «Divider label».
//
// Ключ `image` — это и ключ локального арта (CardArt/<key>.png), и ключ
// маппинга на объект MinIO в CardArtSource. Для коллекций без локального
// экспорта арт грузится только из MinIO.

struct CardItem: Identifiable {
    let id: Int
    let image: String
    let title: String
    let subtitle: String
    let collection: Int
}

struct CardCollection: Identifiable {
    let id: Int
    let name: String
    let sheetTitle: String
    let desc: String
    let range: Range<Int>
    let names: [String]      // имена для Именной карты (иначе пусто)
}

enum Catalog {
    static let cards: [CardItem] = [
        // MARK: 0 — Кыргызстан (Figma 22:8727), 10 карт
        CardItem(id: 0,  image: "kg01", title: "Чуй", subtitle: "Башня Бурана", collection: 0),
        CardItem(id: 1,  image: "kg02", title: "Ысык-Көл", subtitle: "Яхта на озере", collection: 0),
        CardItem(id: 2,  image: "kg03", title: "Ош", subtitle: "Сулайман-Тоо", collection: 0),
        CardItem(id: 3,  image: "kg04", title: "Нарын", subtitle: "Юрта на Джайлоо", collection: 0),
        CardItem(id: 4,  image: "kg05", title: "Талас", subtitle: "Манас", collection: 0),
        CardItem(id: 5,  image: "kg06", title: "Жалал-Абад", subtitle: "Озеро Көл-Мазар", collection: 0),
        CardItem(id: 6,  image: "kg07", title: "Баткен", subtitle: "Пирамидальный пик", collection: 0),
        CardItem(id: 7,  image: "kg08", title: "Ысык-Көл", subtitle: "Жети-Өгүз", collection: 0),
        CardItem(id: 8,  image: "kg09", title: "Ошская область", subtitle: "Алайская долина", collection: 0),
        CardItem(id: 9,  image: "kg10", title: "Бишкек", subtitle: "Линии города", collection: 0),

        // MARK: 1 — Движ (Figma 20:1817), 5 карт
        CardItem(id: 10, image: "dv01", title: "Щёлк-щёлк", subtitle: "Тот самый вайб двора", collection: 1),
        CardItem(id: 11, image: "dv02", title: "Царап", subtitle: "Дерзкий и независимый", collection: 1),
        // Было «Разряд / Заряжен на максимум» — Figma новее и совпадает с DVIZH_IMPULS.
        CardItem(id: 12, image: "dv03", title: "Импульс", subtitle: "Энергия на максимум", collection: 1),
        CardItem(id: 13, image: "dv04", title: "Вираж", subtitle: "Выше, резче, свободнее", collection: 1),
        CardItem(id: 14, image: "dv05", title: "Разгон", subtitle: "Не сбавляй темп", collection: 1),

        // MARK: 2 — Мекеним (Figma 3173:63586), 5 карт
        CardItem(id: 15, image: "mk01", title: "Мурас", subtitle: "Наследие поколений", collection: 2),
        CardItem(id: 16, image: "mk02", title: "Алтын күн", subtitle: "Источник силы", collection: 2),
        CardItem(id: 17, image: "mk03", title: "Күн", subtitle: "Источник силы", collection: 2),
        CardItem(id: 18, image: "mk04", title: "Алтын түндүк", subtitle: "Символ единства", collection: 2),
        CardItem(id: 19, image: "mk05", title: "Түндүк", subtitle: "Символ единства", collection: 2),

        // MARK: 3 — Этно (Figma 6:16865), 5 карт
        CardItem(id: 20, image: "et01", title: "Кочкор мүйүз", subtitle: "Бараньи рога", collection: 3),
        CardItem(id: 21, image: "et02", title: "Кызгалдак", subtitle: "Мак самосейка", collection: 3),
        CardItem(id: 22, image: "et03", title: "Тоо кочкорунун башы", subtitle: "Голова горного барана", collection: 3),
        CardItem(id: 23, image: "et04", title: "Дарыя", subtitle: "Река", collection: 3),
        CardItem(id: 24, image: "et05", title: "Күн нуру", subtitle: "Солнце", collection: 3),

        // MARK: 4 — Этно-футуризм (Figma 864:36129), 5 карт
        CardItem(id: 25, image: "ef01", title: "Ала-тоо", subtitle: "Горные вершины", collection: 4),
        CardItem(id: 26, image: "ef02", title: "Боз үй", subtitle: "Дом кочевников", collection: 4),
        CardItem(id: 27, image: "ef03", title: "Бүркүт", subtitle: "Свободный полёт", collection: 4),
        CardItem(id: 28, image: "ef04", title: "Тулпар", subtitle: "Благородный скакун", collection: 4),
        CardItem(id: 29, image: "ef05", title: "Комуз", subtitle: "Звучание Кыргызстана", collection: 4),

        // MARK: 5 — Love Story (Figma 870:42207), 5 карт
        CardItem(id: 30, image: "ls01", title: "Любовь", subtitle: "С первого взгляда", collection: 5),
        CardItem(id: 31, image: "ls02", title: "Amor", subtitle: "Без лишних слов", collection: 5),
        CardItem(id: 32, image: "ls03", title: "Пульс", subtitle: "В ритме чувств", collection: 5),
        CardItem(id: 33, image: "ls04", title: "Cash lover", subtitle: "Это взаимно", collection: 5),
        CardItem(id: 34, image: "ls05", title: "В сердечко", subtitle: "Раз и навсегда", collection: 5),

        // MARK: 6 — Мемы (Figma 1737:48088), 5 карт
        CardItem(id: 35, image: "mm01", title: "Ветка", subtitle: "Вот, возьмите", collection: 6),
        CardItem(id: 36, image: "mm02", title: "Мышь", subtitle: "Ой, спасибки", collection: 6),
        CardItem(id: 37, image: "mm03", title: "ЪУЪ", subtitle: "Что такое, кто это?", collection: 6),
        CardItem(id: 38, image: "mm04", title: "На богатом", subtitle: "Жизнь удалась", collection: 6),
        CardItem(id: 39, image: "mm05", title: "Носок", subtitle: "Стесняшка", collection: 6),

        // MARK: 7 — Талисманы (Figma 2276:56014), 5 карт
        CardItem(id: 40, image: "tl01", title: "Назар", subtitle: "Оберег от сглаза", collection: 7),
        CardItem(id: 41, image: "tl02", title: "Тумар", subtitle: "Защитный амулет", collection: 7),
        CardItem(id: 42, image: "tl03", title: "Хамса", subtitle: "Символ благополучия", collection: 7),
        CardItem(id: 43, image: "tl04", title: "Четырёхлистник", subtitle: "На удачу", collection: 7),
        CardItem(id: 44, image: "tl05", title: "Монета удачи", subtitle: "Денежный талисман", collection: 7),

        // MARK: 8 — Цитаты (Figma 1736:44228), 5 карт
        // Слой на канвасе назван «Фразы», но пользователю показывается «Цитаты»
        // (так в Divider label) — берём то, что реально уходит в UI.
        CardItem(id: 45, image: "ct01", title: "Акча бар", subtitle: "Всё под контролем", collection: 8),
        CardItem(id: 46, image: "ct02", title: "Элдин баласы", subtitle: "Всегда лучший", collection: 8),
        CardItem(id: 47, image: "ct03", title: "Эркин кыялдан", subtitle: "Всё сбудется", collection: 8),
        CardItem(id: 48, image: "ct04", title: "Жашоо керемет", subtitle: "Лови момент", collection: 8),
        CardItem(id: 49, image: "ct05", title: "Кыйын кыз", subtitle: "Та самая", collection: 8),

        // MARK: 9 — Көчмөн мурас (Figma 3245:76858), 5 карт
        CardItem(id: 50, image: "km01", title: "Алыш", subtitle: "Борьба на поясах", collection: 9),
        CardItem(id: 51, image: "km02", title: "Салбуурун", subtitle: "Охота с беркутом", collection: 9),
        CardItem(id: 52, image: "km03", title: "Жаа атуу", subtitle: "Стрельба из лука", collection: 9),
        CardItem(id: 53, image: "km04", title: "Комуздун күүсү", subtitle: "Мелодия комуза", collection: 9),
        CardItem(id: 54, image: "km05", title: "Эр эңиш", subtitle: "Конная борьба", collection: 9),

        // MARK: 10 — Классическая. ОДНА карта: у продукта Visa Cashback
        // классический дизайн ровно один (остальные BANK_VISA_CLASSIC_* —
        // это другие продукты: Gold, Platinum, Virtual; тут им не место).
        CardItem(id: 55, image: "cl01", title: "Visa Cashback Gold", subtitle: "Классический дизайн", collection: 10),
    ]

    static let collections: [CardCollection] = [
        CardCollection(id: 0, name: "Кыргызстан", sheetTitle: "Кыргызстан",
                       desc: "Природа, архитектура и культурные символы страны в лаконичной графике",
                       range: 0..<10, names: []),
        CardCollection(id: 1, name: "Движ", sheetTitle: "Движ",
                       desc: "Коллекция с характером — смелые образы и яркие акценты в каждом дизайне",
                       range: 10..<15, names: []),
        CardCollection(id: 2, name: "Мекеним", sheetTitle: "Мекеним",
                       desc: "Специальная коллекция ко Дню Независимости Кыргызстана",
                       range: 15..<20, names: []),
        CardCollection(id: 3, name: "Этно", sheetTitle: "Этно",
                       desc: "Культурные символы и национальные мотивы Кыргызстана в современном исполнении",
                       range: 20..<25, names: []),
        CardCollection(id: 4, name: "Этно-футуризм", sheetTitle: "Этно-футуризм",
                       desc: "Образы Кыргызстана, наполненные цветом, формой и характером",
                       range: 25..<30, names: []),
        CardCollection(id: 5, name: "Love Story", sheetTitle: "Love Story",
                       desc: "Яркие дизайны с разным настроением, но одной историей",
                       range: 30..<35, names: []),
        CardCollection(id: 6, name: "Мемы", sheetTitle: "Мемы",
                       desc: "Культовые интернет-образы в новом формате",
                       range: 35..<40, names: []),
        CardCollection(id: 7, name: "Талисманы", sheetTitle: "Талисманы",
                       desc: "Коллекция талисманов из разных культур, каждый со своей историей и значением",
                       range: 40..<45, names: []),
        CardCollection(id: 8, name: "Цитаты", sheetTitle: "Цитаты",
                       desc: "Смелые, ироничные, вдохновляющие — фразы, ставшие частью повседневной жизни",
                       range: 45..<50, names: []),
        CardCollection(id: 9, name: "Көчмөн мурас", sheetTitle: "Көчмөн мурас",
                       desc: "Коллекция, посвящённая силе, мастерству и искусству кочевников",
                       range: 50..<55, names: []),
        CardCollection(id: 10, name: "Классическая", sheetTitle: "Классическая",
                       desc: "Стильный и минималистичный дизайн без лишних деталей",
                       range: 55..<56, names: []),
    ]

    /// Порядок коллекций на экране — как на канвасе Figma.
    static let displayCollections: [CardCollection] = collections
}

import SwiftUI
import UIKit

// MARK: - Источник картинок карт (MinIO) — ТЗ §2, §7.1
//
// Полные карты (карусель):  <base>/mybank/customize_design_card/change_design_animation_card/<name>
// Мини-карты (список):       <base>/mybank/<name>
// Имя <name> одинаково для обеих папок (проверено): напр.
// BANK_VISA_KYRGYZSTAN_CHUY.png. Имена получены из MinIO-консоли (Playwright).
//
// Ключ карты (`image`, напр. "c11") маппится на объект. Если карта не смаплена
// (nil) — RemoteImage прозрачно берёт локальный бандл CardArt/ (принцип 3).
enum CardArtSource {

    /// Базовый S3-эндпоинт (анонимный GET по объектам разрешён).
    /// Живёт в ArtEndpoint, а не здесь: адрес внутренний и не должен
    /// лежать в публичном репозитории. nil → работаем на локальном
    /// арте из CardArt/, приложение остаётся рабочим.
    static var base: URL? { ArtEndpoint.base }

    /// Четыре папки MinIO — по месту использования в UI (уточнено заказчиком).
    /// Имя объекта во всех папках ОДНО И ТО ЖЕ, различается только префикс.
    enum Kind: Equatable, CaseIterable {
        /// Карта на «Деталях карты» — mybank/bank-cards/dark/
        case detail
        /// Крупная карта в карусели (свайп влево-вправо) —
        /// customize_design_card/change_design_animation_card/
        case full
        /// Круглое превью под каруселью — customize_design_card/change_design_preview/
        case preview
        /// Плитка в сетке («списком») —
        /// customize_design_card/change_design_preview_list/
        /// Это арт БЕЗ логотипа Visa: в сетке логотип не нужен, он мелкий
        /// и лезет в обрез. В `mybank/` лежат карты С логотипом — они идут
        /// в другие места.
        case mini

        var folder: String {
            switch self {
            case .detail:  return "mybank/bank-cards/dark"
            case .full:    return "mybank/customize_design_card/change_design_animation_card"
            case .preview: return "mybank/customize_design_card/change_design_preview"
            case .mini:    return "mybank/customize_design_card/change_design_preview_list"
            }
        }

        /// До какой ширины ужимать при декоде (см. RemoteImageLoader).
        var maxWidth: CGFloat {
            switch self {
            case .detail, .full: return 720
            case .mini:          return 360
            case .preview:       return 180
            }
        }
    }

    /// image (c01…) → имя объекта MinIO. Только смапленные коллекции
    /// (Этно/Движ/Кыргызстан/Классическая). «Кыргызская живопись» в MinIO под
    /// этими именами отсутствует → nil → локальный фолбэк.
    private static let objectName: [String: String] = [
        // Кыргызстан (10/10)
        "kg01": "BANK_VISA_KYRGYZSTAN_CHUY.png",
        "kg02": "BANK_VISA_KYRGYZSTAN_YSYKKOL.png",
        "kg03": "BANK_VISA_KYRGYZSTAN_OSH.png",
        "kg04": "BANK_VISA_KYRGYZSTAN_NARYN.png",
        "kg05": "BANK_VISA_KYRGYZSTAN_TALAS.png",
        "kg06": "BANK_VISA_KYRGYZSTAN_DZHALALABAD.png",
        "kg07": "BANK_VISA_KYRGYZSTAN_BATKEN.png",
        "kg08": "BANK_VISA_KYRGYZSTAN_DZHETYOGUZ.png",
        "kg09": "BANK_VISA_KYRGYZSTAN_OSHSKAYAOBLAST.png",
        "kg10": "BANK_VISA_KYRGYZSTAN_BISHKEK.png",
        // Движ (5/5)
        "dv01": "BANK_VISA_DVIZH_SCHELKSCHELK.png",
        "dv02": "BANK_VISA_DVIZH_TSARAP.png",
        "dv03": "BANK_VISA_DVIZH_IMPULS.png",
        "dv04": "BANK_VISA_DVIZH_VIRAZH.png",
        "dv05": "BANK_VISA_DVIZH_RAZGON.png",
        // Этно (5/5)
        "et01": "BANK_VISA_ETHNO_KOCHKORMUYUZ.png",
        "et02": "BANK_VISA_ETHNO_KYZGALDAK.png",
        "et03": "BANK_VISA_ETHNO_TOOKOCHKORUNUNBASHY.png",
        "et04": "BANK_VISA_ETHNO_DARYYA.png",
        "et05": "BANK_VISA_ETHNO_KUNNURU.png",
        // Этно-футуризм (5/5)
        "ef01": "BANK_VISA_ETHNOFUTURISM_ALATOO.png",
        "ef02": "BANK_VISA_ETHNOFUTURISM_BOZUY.png",
        "ef03": "BANK_VISA_ETHNOFUTURISM_BURKUT.png",
        "ef04": "BANK_VISA_ETHNOFUTURISM_TULPAR.png",
        "ef05": "BANK_VISA_ETHNOFUTURISM_KOMUZ.png",
        // Love Story (5/5)
        "ls01": "BANK_VISA_LOVESTORY_ETOLYUBOV.png",
        "ls02": "BANK_VISA_LOVESTORY_AMOR.png",
        "ls03": "BANK_VISA_LOVESTORY_PULSE.png",
        "ls04": "BANK_VISA_LOVESTORY_CASHLOVER.png",
        "ls05": "BANK_VISA_LOVESTORY_VSERDECHKO.png",
        // Мемы (5/5). ВНИМАНИЕ: имена описывают КАРТИНКУ, а не заголовок карты —
        // «Ветка» это LEV, «Мышь» это HOMYAK. Подобрать перебором нельзя.
        "mm01": "BANK_VISA_MEME_LEV.png",            // Ветка
        "mm02": "BANK_VISA_MEME_HOMYAK.png",         // Мышь
        "mm03": "BANK_VISA_MEME_YIY.png",            // ЪУЪ
        "mm04": "BANK_VISA_MEME_MONEY.png",          // На богатом
        "mm05": "BANK_VISA_MEME_NOSOK.png",          // Носок
        // Мекеним (5/5) — суффиксы по ЦВЕТУ варианта, а не по названию.
        "mk01": "BANK_VISA_MEKENIM_PATTERN.png",     // Мурас
        "mk02": "BANK_VISA_MEKENIM_KUNRED.png",      // Алтын күн
        "mk03": "BANK_VISA_MEKENIM_KUNBLACK.png",    // Күн
        "mk04": "BANK_VISA_MEKENIM_TUNDUKRED.png",   // Алтын түндүк
        "mk05": "BANK_VISA_MEKENIM_TUNDUKBLACK.png", // Түндүк
        // Көчмөн мурас (5/5) — префикс WNG (World Nomad Games), с названием
        // коллекции никак не связан; имена снова описывают картинку.
        "km01": "BANK_VISA_WNG_ALYSH.png",           // Алыш
        "km02": "BANK_VISA_WNG_BYRKYT.png",          // Салбуурун
        "km03": "BANK_VISA_WNG_MERGEN.png",          // Жаа атуу
        "km04": "BANK_VISA_WNG_KYY.png",             // Комуздун күүсү
        "km05": "BANK_VISA_WNG_KYLYK.png",           // Эр эңиш
        // Талисманы (5/5). Внимание: часть имён — НЕ транслит, а английский
        // перевод названия (CLOVER, COIN).
        "tl01": "BANK_VISA_TALISMAN_NAZAR.png",
        "tl02": "BANK_VISA_TALISMAN_TUMAR.png",
        "tl03": "BANK_VISA_TALISMAN_HAMSA.png",
        "tl04": "BANK_VISA_TALISMAN_CLOVER.png",     // Четырёхлистник
        "tl05": "BANK_VISA_TALISMAN_COIN.png",       // Монета удачи
        // Цитаты (5/5) — префикс QUOTE в ЕДИНСТВЕННОМ числе.
        "ct01": "BANK_VISA_QUOTE_AKCHABAR.png",
        "ct02": "BANK_VISA_QUOTE_ELDINBALASY.png",
        "ct03": "BANK_VISA_QUOTE_ERKINKYIALDAN.png",
        "ct04": "BANK_VISA_QUOTE_JASHOOKEREMET.png",
        "ct05": "BANK_VISA_QUOTE_KYIYNKYZ.png",
        // Классическая (1/1) — Visa Cashback Gold
        "cl01": "BANK_VISA_CLASSIC_GOLD_CASHBACK.png",
        // Все 60 карт смаплены и проверены (200 во всех четырёх папках).
    ]

    static func objectKey(for cardImage: String, kind: Kind) -> String? {
        guard let name = objectName[cardImage] else { return nil }
        let folder = kind.folder
        return folder.hasSuffix("/") ? "\(folder)\(name)" : "\(folder)/\(name)"
    }

    /// Полный URL объекта, если он смаплен.
    static func url(for cardImage: String, kind: Kind) -> URL? {
        guard let base, let key = objectKey(for: cardImage, kind: kind) else { return nil }
        return base.appendingPathComponent(key)
    }
}

// MARK: - Загрузчик MinIO с кэшем ДАУНСКЕЙЛЕННЫХ копий в памяти
//
// Кэшируем не сырой 1MB PNG, а форс-декодированную уменьшенную копию под нужный
// размер (карусель ~720px, мини ~180px) — иначе SwiftUI даунскейлит 1224px
// исходник на КАЖДОМ кадре свайпа для 4 карт разом → лаг (тот же класс бага,
// что был с локальными). Ключ кэша учитывает maxW.
@MainActor
final class RemoteImageLoader {
    static let shared = RemoteImageLoader()
    private var cache: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    /// Дисковый кэш ДЕКОДИРОВАННЫХ уменьшенных копий.
    ///
    /// Без него каждый холодный старт заново качал ~11 МБ (55 карт × ~200 КБ),
    /// и плитки минуту стояли скелетонами. Кладём уже ужатый JPEG под нужный
    /// размер — второй запуск читает его с диска мгновенно.
    private static let diskDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CardArtCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func diskURL(_ url: URL, _ maxW: CGFloat) -> URL {
        // Имя файла из последнего сегмента URL + папки + размера.
        // ВАЖНО: НЕ hashValue — в Swift он рандомизируется между запусками,
        // и дисковый кэш никогда бы не попадал.
        let file = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent().lastPathComponent
        let name = "\(folder)_\(file)_\(Int(maxW)).png"
        return Self.diskDir.appendingPathComponent(name)
    }

    private func readDisk(_ url: URL, _ maxW: CGFloat) -> UIImage? {
        let f = diskURL(url, maxW)
        guard let data = try? Data(contentsOf: f) else { return nil }
        return UIImage(data: data)
    }

    private func writeDisk(_ img: UIImage, _ url: URL, _ maxW: CGFloat) {
        // ТОЛЬКО PNG. В JPEG нет альфы, а у арта карт по контуру идёт белая
        // кромка с alpha ≈ 5% — при сохранении в JPEG она становится
        // НЕПРОЗРАЧНО БЕЛОЙ, и вокруг карты появлялась белая рамка в 1pt.
        guard let data = img.pngData() else { return }
        try? data.write(to: diskURL(url, maxW), options: .atomic)
    }

    /// Сколько картинок прямо сейчас грузится ПО ТРЕБОВАНИЮ видимой вью.
    /// Прогрев обязан уступать им дорогу: иначе очередь из 200 фоновых
    /// запросов забивает URLSession, и центральная карта карусели приезжает
    /// последней (визуально — вечный скелетон на самом видном месте).
    private var onScreenDemand = 0

    private func key(_ url: URL, _ maxW: CGFloat) -> String { "\(url.absoluteString)#\(Int(maxW))" }

    func cached(_ url: URL, maxW: CGFloat) -> UIImage? {
        let k = key(url, maxW)
        if let hit = cache[k] { return hit }
        // Подхватываем с диска — это и есть «мгновенный» второй запуск.
        if let disk = readDisk(url, maxW) {
            cache[k] = disk
            return disk
        }
        return nil
    }

    /// Загрузка по требованию видимой вью — приоритетна перед прогревом.
    func loadOnScreen(_ url: URL, maxW: CGFloat) async -> UIImage? {
        onScreenDemand += 1
        defer { onScreenDemand -= 1 }
        return await load(url, maxW: maxW)
    }

    func load(_ url: URL, maxW: CGFloat) async -> UIImage? {
        let k = key(url, maxW)
        if let img = cache[k] { return img }
        if let task = inFlight[k] { return await task.value }
        // Диск проверяем ДО сети.
        if let disk = readDisk(url, maxW) {
            cache[k] = disk
            return disk
        }
        let task = Task<UIImage?, Never> {
            guard let (data, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let raw = UIImage(data: data)
            else { return nil }
            return Self.downscaled(raw, maxW: maxW)
        }
        inFlight[k] = task
        let img = await task.value
        inFlight[k] = nil
        if let img {
            cache[k] = img
            writeDisk(img, url, maxW)
        }
        return img
    }

    // Даунскейл + форс-декод (рисуем в маленький контекст) — дешёвая текстура.
    nonisolated private static func downscaled(_ img: UIImage, maxW: CGFloat) -> UIImage {
        let scale = min(1, maxW / max(img.size.width, 1))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // Прогрев кэша: качаем все MinIO-картинки заранее, чтобы свайп не подлагивал
    // и не было «скачка» подмены. Вызывается из ContentView.onAppear.
    func preload(fullNames: [String], miniNames: [String]) {
        preload(names: fullNames, kinds: [.full])
        preload(names: miniNames, kinds: [.mini])
    }

    /// Прогрев в порядке приоритета: сначала то, что видно немедленно,
    /// потом всё остальное. Внутри каждой пачки — ограниченный параллелизм,
    /// иначе сотни одновременных запросов забивают пул URLSession и нужное
    /// приезжает последним.
    /// - Parameter firstScreen: папки, которые понадобятся ПЕРВЫМИ (зависит от
    ///   запомненного режима: сетка → .mini, карусель → .full + .preview).
    func warmInPriorityOrder(selected: String, all: [String],
                             firstScreen: [CardArtSource.Kind]) async {
        // 1. Всё для ВЫБРАННОЙ карты — она видна сразу на обоих экранах.
        await warm([selected], kinds: [.detail, .full, .preview, .mini])
        // 2. Сначала СОСЕДИ по экрану (первая карта каждой коллекции —
        //    именно они видны в карусели и в верхних рядах сетки).
        //    Без этого центральная карта стояла в очереди за полусотней
        //    невидимых и висела скелетоном.
        let visibleFirst = Catalog.displayCollections.compactMap {
            Catalog.cards.indices.contains($0.range.lowerBound)
                ? Catalog.cards[$0.range.lowerBound].image : nil
        }
        await warm(visibleFirst, kinds: firstScreen)
        // 3. Первые ДВЕ коллекции целиком — это примерно первый экран сетки.
        //
        // Дальше НЕ греем. Замер: одна картинка ≈200 КБ / ~100 мс, т.е. все
        // 55 плиток это ~11 МБ. Такая очередь не ускоряется перестановкой —
        // она просто занимает канал и мешает тому, что видно сейчас.
        // Остальное RemoteImage догрузит по требованию при скролле.
        // Ровно первый экран сетки: по 6 плиток (5 + крышка) из двух верхних
        // коллекций. Больше грузить бессмысленно — при ~200 КБ на картинку
        // это уже около 2.5 МБ, а дальше пользователь всё равно скроллит.
        let firstSections = Catalog.displayCollections.prefix(2)
            .flatMap { $0.range.prefix(PickerModel.previewLimit + 1) }
            .filter { Catalog.cards.indices.contains($0) }
            .map { Catalog.cards[$0].image }
        await warm(firstSections, kinds: firstScreen)
    }

    private func warm(_ names: [String], kinds: [CardArtSource.Kind],
                      concurrency: Int = 10) async {
        var jobs: [(URL, CGFloat)] = []
        for n in names {
            for k in kinds {
                if let u = CardArtSource.url(for: n, kind: k), cached(u, maxW: k.maxWidth) == nil {
                    jobs.append((u, k.maxWidth))
                }
            }
        }
        var i = 0
        while i < jobs.count {
            // Уступаем дорогу видимым картинкам.
            while onScreenDemand > 0 {
                try? await Task.sleep(for: .milliseconds(120))
            }
            let slice = jobs[i..<min(i + concurrency, jobs.count)]
            await withTaskGroup(of: Void.self) { group in
                for (u, w) in slice {
                    group.addTask { _ = await self.load(u, maxW: w) }
                }
            }
            i += concurrency
        }
    }

    /// Прогрев произвольного набора папок.
    func preload(names: [String], kinds: [CardArtSource.Kind]) {
        for n in names {
            for k in kinds where CardArtSource.url(for: n, kind: k) != nil {
                let u = CardArtSource.url(for: n, kind: k)!
                Task { _ = await load(u, maxW: k.maxWidth) }
            }
        }
    }
}

// MARK: - RemoteImage: MinIO → (fallback) локальный бандл, со скелетоном
//
// Порядок: если карта смаплена на объект MinIO и он в кэше — показываем сразу;
// иначе грузим асинхронно, а до загрузки — скелетон-шиммер (не спиннер).
// Если объект не смаплен/не загрузился — локальный ассет из CardArt/.
struct RemoteImage: View {
    let cardImage: String
    let kind: CardArtSource.Kind
    var contentMode: ContentMode = .fit

    private let loader = RemoteImageLoader.shared
    @State private var remote: UIImage?
    @State private var shown = false     // true → картинка проявлена (для fade-in)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maxW: CGFloat { kind.maxWidth }
    private var url: URL? { CardArtSource.url(for: cardImage, kind: kind) }

    var body: some View {
        ZStack {
            // Подложка-скелетон видна, пока картинка проявляется (мягкий fade-in,
            // а не резкий «щелчок» — emil-design-eng: без кроссфейда двух картинок,
            // но проявление из скелетона органичнее внезапной подмены).
            if !shown {
                if url == nil, let local = localImage {
                    local.resizable().aspectRatio(contentMode: contentMode)
                } else if url == nil {
                    // Ни MinIO-имени, ни локального экспорта: вечный скелетон
                    // читался бы как «вечная загрузка». Показываем честную
                    // заглушку — видно, что арта нет, а не что он не грузится.
                    ArtPlaceholder()
                } else {
                    SkeletonView()
                }
            }
            if let remote {
                Image(uiImage: remote).resizable().aspectRatio(contentMode: contentMode)
                    .opacity(shown ? 1 : 0)
            }
        }
        .task(id: cardImage) { await attempt() }
    }

    private var localImage: Image? {
        switch kind {
        case .detail, .full:
            if let img = CardImages.shared.card(cardImage) { return Image(uiImage: img) }
        // Плитка сетки рендерится ~112pt, т.е. до ~340px на 3×. Дефолтные 90px
        // от small() там заметно мылят — просим 360px.
        case .mini:
            if let img = CardImages.shared.small(cardImage, maxW: 360) { return Image(uiImage: img) }
        case .preview:
            // Круглое превью: сначала локальное pNN, потом уменьшённая карта.
            if let p = LegacyArt.previewName(for: cardImage),
               let img = CardImages.shared.ui(p) { return Image(uiImage: img) }
            if let img = CardImages.shared.small(cardImage, maxW: 180) { return Image(uiImage: img) }
        }
        return CardImages.shared.ui(cardImage).map(Image.init(uiImage:))
    }

    private func attempt() async {
        // сброс на смену карты (переиспользование вью в ForEach)
        shown = false
        guard let url else { return }
        if let hit = loader.cached(url, maxW: maxW) {
            // уже в кэше (предзагружено) — показываем мгновенно, без fade и мигания скелетона
            remote = hit
            shown = true
            return
        }
        // сеть — проявляем мягким fade-in из скелетона
        if let img = await loader.loadOnScreen(url, maxW: maxW) {
            remote = img
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) { shown = true }
        }
    }
}

// MARK: - Скелетон (принцип 3): мягкий шиммер вместо лоадера
struct SkeletonView: View {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: w * 0.6)
                    .offset(x: phase * w)
                    .opacity(reduceMotion ? 0 : 1)
                )
                .clipped()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1.6
            }
        }
    }
}


// MARK: - Заглушка для карт без арта (нет ни MinIO-имени, ни локального файла)
struct ArtPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2A2A2A), Color(hex: 0x141414)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

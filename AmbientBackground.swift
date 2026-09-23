import SwiftUI

// MARK: - Фон-подложка (ambient blur), вынесена в Equatable-вью (Баг: лаг свайпа)
//
// EquatableView сравнивает `W`, `H`, `cardImage` и пропускает переисполнение
// body, если ничего не изменилось — а во время драга карусели меняется
// только `offset` в ContentView, эти три инпута стабильны. Плюс drawingGroup()
// рендерит блюр+градиент в один растровый слой (Metal), а не пересчитывает
// composited-эффект на CPU/GPU покадрово.
//
// БАГ (починен): фон брался ТОЛЬКО из локального бандла
// (`CardImages.shared.smallImage`). После перехода на каталог из 10 коллекций
// у 24 карт локального файла нет — они живут только в MinIO. Для них
// `smallImage` отдавал SF-символ-заглушку, и фон при выборе такой карты
// «не менялся». Теперь источник — сначала кэш MinIO, потом локальный бандл.
struct AmbientBackground: View, Equatable {
    let W: CGFloat
    let H: CGFloat
    let cardImage: String
    let reduceMotion: Bool

    /// Поднимается, когда удалённая картинка догрузилась, — чтобы фон
    /// проявился без перезахода на экран.
    @State private var remote: UIImage?

    static func == (lhs: AmbientBackground, rhs: AmbientBackground) -> Bool {
        lhs.W == rhs.W && lhs.H == rhs.H && lhs.cardImage == rhs.cardImage
            && lhs.reduceMotion == rhs.reduceMotion
    }

    private var url: URL? { CardArtSource.url(for: cardImage, kind: .mini) }

    /// Картинка для фона: MinIO-кэш → локальный бандл → ничего (чёрный фон).
    private var source: Image? {
        if let remote { return Image(uiImage: remote) }
        if let u = url, let cached = RemoteImageLoader.shared.cached(u, maxW: 360) {
            return Image(uiImage: cached)
        }
        if let local = CardImages.shared.small(cardImage) { return Image(uiImage: local) }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black
            if let source {
                source
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H * 0.55)
                    .clipped()
                    .blur(radius: 30)
                    .frame(width: W, height: H, alignment: .top)
                    .clipped()
                    .opacity(0.9)
                    .drawingGroup()   // растеризуем блюр один раз, не покадрово
                    // фон перетекает на общей пружине (Баг 6), мгновенно при Reduce Motion
                    .animation(MotionTokens.transition(reduceMotion: reduceMotion),
                               value: cardImage)
            }
            LinearGradient(
                colors: [.black.opacity(0.2), .black.opacity(0.55), .black.opacity(0.92), .black],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(width: W, height: H)
        // Если карты ещё нет в кэше — дотягиваем её и обновляем фон.
        .task(id: cardImage) {
            remote = nil
            guard let u = url else { return }
            if let cached = RemoteImageLoader.shared.cached(u, maxW: 360) {
                remote = cached
                return
            }
            remote = await RemoteImageLoader.shared.load(u, maxW: 360)
        }
    }
}

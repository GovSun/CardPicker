import SwiftUI

// MARK: - Карта-герой: ОДИН слой, едет между режимами (Family Values, ТЗ2.0 Баг 5)
//
// Рисуется только во время перелёта, между снимками hero-фрейма (карусель) и
// row-фрейма (строка списка). Позиция/размер/радиус интерполируются по t: 0→1.
// Всё движение — transform (frame + position), одна пружина, без opacity-кроссфейда.
struct HeroCardOverlay: View {
    let cardImage: String
    let heroFrame: CGRect       // снимок крупной карты (карусель)
    let rowFrame: CGRect        // снимок мини-карты выбранной строки (список)
    let t: CGFloat              // 0 = карусель, 1 = список
    let f: CGFloat

    var body: some View {
        let frame = lerp(heroFrame, rowFrame, t)
        RemoteImage(cardImage: cardImage, kind: .full, contentMode: .fill)
            .frame(width: frame.width, height: frame.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.4 * Double(1 - t)),
                    radius: 16 * f * (1 - t), x: 0, y: 10 * f * (1 - t))
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
    }

    private var cornerRadius: CGFloat {
        let hero = 8 * f, row = 6 * f
        return hero + (row - hero) * t
    }

    private func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(
            x: a.minX + (b.minX - a.minX) * t,
            y: a.minY + (b.minY - a.minY) * t,
            width: a.width + (b.width - a.width) * t,
            height: a.height + (b.height - a.height) * t
        )
    }
}

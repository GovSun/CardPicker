import SwiftUI
import UIKit

// MARK: - Цвет из HEX (токены Figma)
extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8)  & 0xff) / 255,
            blue:  Double( hex        & 0xff) / 255,
            opacity: 1
        )
    }
}

// Дизайн-токены из макета
enum Tokens {
    static let buttonPrimary = Color(hex: 0x80C01B)   // bg/button/primary
    static let accentPink    = Color(hex: 0xF0047F)   // активный radiobutton/checkbox
    static let sheetBg       = Color.white            // bg/general/bottomsheet
    static let textPrimary   = Color(hex: 0x010101)   // text/primary (на белом)
    static let textSecondary = Color(hex: 0x3D3D3D)   // text/secondary (на белом)
    static let onDarkSecondary = Color(hex: 0xDDDDDD) // text/secondary (на тёмном)

    // Добавлено для сетки дизайнов и экрана «Детали карты» (Figma 3584:66192, 3602:102549)
    static let buttonPrimaryDisabled = Color(hex: 0xD3EDAB) // bg/button/primary_disabled
    static let link         = Color(hex: 0x007AFF) // text/link — «Свернуть», «Выбрать» в ячейке
    static let cellBg       = Color(hex: 0xF7F7F7) // bg/general/content_secondary — ячейки шита
    static let toastBg      = Color(hex: 0x4A4A4A) // bg/general/toast_bg
    static let toggleOn     = Color(hex: 0x32D74B) // selection_control/toggle/active
    static let hairline     = Color.white.opacity(0.15) // бордер плитки в сетке
    /// Градиент промо-ячейки O!Prime (90°, слева направо).
    static let promoGradient = LinearGradient(
        colors: [Color(hex: 0xFFF0F8), Color(hex: 0xFAF4FF)],
        startPoint: .leading, endPoint: .trailing
    )
}

// MARK: - Тактильный отклик
enum Haptics {
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    /// Смена выбора в сетке — легче, чем soft, и не конкурирует с движением.
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    /// Подтверждение выбора дизайна (вместе с тостом).
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Загрузка PNG карт из ресурсов пакета (с кэшем)
final class CardImages {
    static let shared = CardImages()
    private var cache: [String: UIImage] = [:]

    func ui(_ name: String) -> UIImage? {
        if let img = cache[name] { return img }
        // Ключи каталога (kg01…) не совпадают с именами файлов в бандле (c11…):
        // переводим через таблицу соответствия, иначе локального фолбэка нет.
        let name = LegacyArt.assetName(for: name) ?? name
        // ресурсы лежат в Resources/cards (скопированы через .copy в Package.swift)
        let candidates: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "CardArt"),
            Bundle.main.url(forResource: name, withExtension: "png")
        ]
        for case let url? in candidates {
            if let img = UIImage(contentsOfFile: url.path) {
                cache[name] = img
                return img
            }
        }
        if let img = UIImage(named: name) { cache[name] = img; return img }
        return nil
    }

    func image(_ name: String) -> Image {
        if let ui = ui(name) { return Image(uiImage: ui) }
        return Image(systemName: "creditcard.fill")
    }

    // Уменьшенная копия для фона: блюрить маленькую картинку дёшево (нет дёрганья).
    private var smallCache: [String: UIImage] = [:]
    func small(_ name: String, maxW: CGFloat = 90) -> UIImage? {
        let key = "\(name)#\(Int(maxW))"
        if let c = smallCache[key] { return c }
        guard let base = ui(name) else { return nil }
        let scale = maxW / base.size.width
        let size = CGSize(width: maxW, height: base.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
        }
        smallCache[key] = img
        return img
    }

    func smallImage(_ name: String) -> Image {
        if let ui = small(name) { return Image(uiImage: ui) }
        return image(name)
    }

    // Карта в экранном размере: даунскейл 1224px → ~720px + форс-декод.
    // Перерисовка маленькой текстуры каждый кадр на свайпе дёшева → нет лагов.
    private var cardCache: [String: UIImage] = [:]
    func card(_ name: String, maxW: CGFloat = 720) -> UIImage? {
        if let c = cardCache[name] { return c }
        guard let base = ui(name) else { return nil }
        let scale = min(1, maxW / max(base.size.width, 1))
        let size = CGSize(width: base.size.width * scale, height: base.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
        }
        cardCache[name] = img
        return img
    }

    func cardImage(_ name: String) -> Image {
        if let ui = card(name) { return Image(uiImage: ui) }
        return image(name)
    }

    // Прогрев кэша, чтобы свайп не подлагивал (декодируем заранее).
    func preload(_ names: [String]) {
        for n in names {
            _ = card(n)                                // даунскейл карты
            _ = small(n)                               // фон
            if let p = LegacyArt.previewName(for: n) { _ = ui(p) }   // круглое превью
        }
    }
}

// MARK: - Liquid Glass (iOS 26) с фолбэком на материал
extension View {
    @ViewBuilder
    func liquidGlass(_ shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

import SwiftUI

// MARK: - Измерение реперных фреймов карты-героя
//
// Единый оверлей-герой (подход Family Values): карта — ОДИН непрерывный слой,
// который едет между hero-позицией (карусель) и позицией строки (список).
// Здесь — инфраструктура, чтобы измерить обе точки в общих координатах.

/// Роль репера: откуда и куда летит герой.
enum HeroSlot: Equatable {
    case hero            // крупная карта в карусели
    case row(Int)        // мини-карта строки списка (глобальный индекс карты)
}

/// Один измеренный фрейм в координатах общего пространства "screen".
struct HeroFrameValue: Equatable {
    var slot: HeroSlot
    var rect: CGRect
    var cornerRadius: CGFloat
}

struct HeroFramePreferenceKey: PreferenceKey {
    static var defaultValue: [HeroFrameValue] = []
    static func reduce(value: inout [HeroFrameValue], nextValue: () -> [HeroFrameValue]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Пометить вью как репер героя. Публикует его фрейм в координатах `space`.
    /// Если `slot == nil` — ничего не публикует (вью не участвует в морфинге).
    @ViewBuilder
    func heroSlot(_ slot: HeroSlot?, cornerRadius: CGFloat, in space: CoordinateSpace) -> some View {
        if let slot {
            background(
                GeometryReader { g in
                    Color.clear.preference(
                        key: HeroFramePreferenceKey.self,
                        value: [HeroFrameValue(slot: slot,
                                               rect: g.frame(in: space),
                                               cornerRadius: cornerRadius)]
                    )
                }
            )
        } else {
            self
        }
    }
}

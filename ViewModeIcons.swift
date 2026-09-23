import SwiftUI

// MARK: - Иконки переключателя режимов (Figma node 2945:45810)
//
// Оба глифа — точные пути из Figma-экспорта (viewBox 24×24), отрисованные
// через Path и отмасштабированные под запрошенный размер. Раньше здесь была
// ручная реконструкция из примитивов, и она заметно расходилась с макетом.
/// Список: два скруглённых квадрата слева + четыре строки справа.
/// Точный путь из Figma (node 2945:43121, viewBox 24×24).
struct ListModeIcon: View {
    var body: some View {
        ListGlyph()
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct ListGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()

        // Два квадрата: x 2.627…8.991, радиус ≈1.71.
        for y in [4.0 as CGFloat, 13.636] {
            path.addRoundedRect(
                in: CGRect(x: 2.627 * s, y: y * s, width: 6.364 * s, height: 6.364 * s),
                cornerSize: CGSize(width: 1.71 * s, height: 1.71 * s),
                style: .continuous
            )
        }
        // Четыре строки: x 10.909…21.373, высота 1.727, скруглены до капсулы.
        for y in [4.0 as CGFloat, 8.755, 13.518, 18.273] {
            path.addRoundedRect(
                in: CGRect(x: 10.909 * s, y: y * s, width: 10.464 * s, height: 1.727 * s),
                cornerSize: CGSize(width: 0.864 * s, height: 0.864 * s),
                style: .continuous
            )
        }
        return path
    }
}

/// Карусель: наклонная карта позади + сплошная карта спереди.
///
/// Это ТОЧНЫЙ путь из Figma-экспорта (node 2945:45811, viewBox 24×24),
/// а не реконструкция из прямоугольников — прежние приближения на 24pt
/// схлопывались в бесформенное пятно.
struct CardsModeIcon: View {
    var body: some View {
        ScrollGlyph()
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct ScrollGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()

        // Задняя (наклонная) карта.
        path.move(to: p(3.6465, 15.6108))
        path.addLine(to: p(2.40949, 8.63582))
        path.addCurve(to: p(4.39914, 5.82646),
                      control1: p(2.13377, 7.07092), control2: p(2.81189, 6.10963))
        path.addLine(to: p(14.4145, 4.06036))
        path.addCurve(to: p(17.2387, 6.02021),
                      control1: p(16.0017, 3.78464), control2: p(16.963, 4.45531))
        path.addLine(to: p(17.4176, 6.99641))
        path.addLine(to: p(9.03422, 6.99641))
        path.addCurve(to: p(5.50202, 10.5062),
                      control1: p(6.82101, 6.99641), control2: p(5.50202, 8.30794))
        path.addLine(to: p(5.50202, 17.6004))
        path.addCurve(to: p(3.6465, 15.6108),
                      control1: p(4.48111, 17.4961), control2: p(3.85515, 16.8329))
        path.closeSubpath()

        // Передняя карта.
        path.move(to: p(9.03422, 20))
        path.addCurve(to: p(6.59, 17.5855),
                      control1: p(7.41716, 20), control2: p(6.59, 19.1802))
        path.addLine(to: p(6.59, 10.5062))
        path.addCurve(to: p(9.03422, 8.08438),
                      control1: p(6.59, 8.91154), control2: p(7.41716, 8.08438))
        path.addLine(to: p(19.206, 8.08438))
        path.addCurve(to: p(21.6503, 10.5062),
                      control1: p(20.8082, 8.08438), control2: p(21.6503, 8.91154))
        path.addLine(to: p(21.6503, 17.5855))
        path.addCurve(to: p(19.206, 20),
                      control1: p(21.6503, 19.1728), control2: p(20.8082, 20))
        path.addLine(to: p(9.03422, 20))
        path.closeSubpath()

        return path
    }
}

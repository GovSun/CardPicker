import SwiftUI
import UIKit

// MARK: - Надёжный замер прокрутки через UIScrollView (обходит SwiftUI)
//
// Почему не PreferenceKey и не scrollPosition(id:)/scrollTargetLayout():
// оба пути проверены и не работают для eager VStack в обычном ScrollView
// на iOS 17/26 SDK этого проекта.
//   • PreferenceKey — пробник в .background() контента едет ВМЕСТЕ с
//     контентом, поэтому его minY относительно своего же контейнера не
//     меняется никогда (сообщает 0 постоянно).
//   • scrollPosition(id:) + .scrollTargetLayout() — эмпирически проверено
//     изолированным тестом (программный proxy.scrollTo на 40-строчном
//     eager VStack): биндинг остаётся nil ВСЮ прокрутку, ни разу не
//     срабатывает onChange, хотя список реально едет (подтверждено
//     скриншотом). Похоже, scrollTargetLayout не размечает элементы как
//     scroll targets, если контейнер — не Lazy-стек.
//
// Что работает: SwiftUI ScrollView ВСЕГДА подложен настоящим UIScrollView
// (SwiftUI.HostingScrollView). KVO на его contentOffset даёт точные,
// непрерывно обновляющиеся значения — проверено тем же изолированным
// тестом (offsetY менялся на каждом кадре анимации scrollTo).
struct ScrollOffsetProbe: UIViewRepresentable {
    /// Расстояние до самого верха в поинтах контента: contentOffset.y +
    /// adjustedContentInset.top. У полностью проскроленного до верха списка
    /// это 0 (или чуть отрицательно на резиновом bounce) — НЕЗАВИСИМО от
    /// того, есть ли сверху отступ под аппбар (вариант A/B) или нет
    /// (вариант C, где topInset у сетки отрицательный). Считать это внутри
    /// пробника, а не сравнивать сырой contentOffset снаружи с константой —
    /// так вызывающая сторона не должна знать про inset-арифметику UIKit.
    var onDistanceFromTopChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ProbeUIView {
        let v = ProbeUIView()
        v.onDistanceFromTopChange = onDistanceFromTopChange
        return v
    }

    func updateUIView(_ uiView: ProbeUIView, context: Context) {
        uiView.onDistanceFromTopChange = onDistanceFromTopChange
    }
}

/// Невидимая (нулевого размера) UIView, которая поднимается по цепочке
/// superview до ближайшего UIScrollView и KVO-слушает его contentOffset.
final class ProbeUIView: UIView {
    var onDistanceFromTopChange: ((CGFloat) -> Void)?
    private weak var observedScrollView: UIScrollView?
    private var offsetToken: NSKeyValueObservation?
    private var insetToken: NSKeyValueObservation?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        attachIfNeeded()
    }

    private func attachIfNeeded() {
        guard offsetToken == nil else { return }
        var v: UIView? = superview
        while let cur = v {
            if let sv = cur as? UIScrollView {
                observedScrollView = sv
                offsetToken = sv.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                    self?.report(sv)
                }
                // adjustedContentInset.top может измениться позже сам
                // по себе (напр. поворот/смена safe area) — слушаем и его.
                insetToken = sv.observe(\.adjustedContentInset, options: [.new]) { [weak self] sv, _ in
                    self?.report(sv)
                }
                // Сразу сообщаем стартовое значение — иначе до первого
                // реального скролла состояние (gridAtTop) неопределённо.
                report(sv)
                return
            }
            v = cur.superview
        }
    }

    private func report(_ sv: UIScrollView) {
        onDistanceFromTopChange?(sv.contentOffset.y + sv.adjustedContentInset.top)
    }

    deinit {
        offsetToken?.invalidate()
        insetToken?.invalidate()
    }
}

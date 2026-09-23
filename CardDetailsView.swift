import SwiftUI

// MARK: - «Детали карты» (Figma node 3602:102549)
//
// Стартовый экран. Фон — размытый арт ВЫБРАННОЙ карты (тот же AmbientBackground,
// что и в пикере: «фон с карты подгружается везде»). Рабочая строка ровно одна —
// «Цифровой дизайн карты», она открывает пикер сеткой.
//
// Данные карты моковые (номер, срок, держатель) — по ТЗ важен вид, не содержимое.
struct CardDetailsView: View {
    let model: PickerModel
    /// ПРИМЕНЁННЫЙ дизайн. Именно его показывают карта и фон — не
    /// `model.selectedGlobal`, который в пикере меняется на каждый тап
    /// и остаётся «примеркой», пока не нажали «Выбрать».
    let appliedGlobal: Int
    let onOpenPicker: () -> Void

    private var appliedCard: CardItem {
        Catalog.cards.indices.contains(appliedGlobal)
            ? Catalog.cards[appliedGlobal] : model.selectedCard
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let f = geo.size.width / 375
            let topInset = geo.safeAreaInsets.top

            VStack(spacing: 0) {
                appbar(f: f)
                    .padding(.top, topInset)
                cardHero(f: f)
                    .padding(.top, 24 * f)
                    .padding(.horizontal, 16 * f)
                Spacer(minLength: 16 * f)
                sheet(f: f, bottomInset: geo.safeAreaInsets.bottom)
            }
            // ВАЖНО: высота — ФИЗИЧЕСКАЯ (geo.size уже без safe area). Без
            // добавки инсетов шит обрывался бы над home-индикатором, а его
            // фон, живущий с ignoresSafeArea, уезжал бы ниже содержимого.
            .frame(width: geo.size.width,
                   height: geo.size.height + topInset + geo.safeAreaInsets.bottom)
            .background(
                AmbientBackground(
                    W: geo.size.width,
                    H: geo.size.height + topInset + geo.safeAreaInsets.bottom,
                    cardImage: appliedCard.image,
                    reduceMotion: reduceMotion
                )
                .equatable()
                .ignoresSafeArea()
            )
            .ignoresSafeArea()
        }
        .background(Color.black)
    }

    // MARK: - Аппбар

    private func appbar(f: CGFloat) -> some View {
        ZStack {
            Text("Visa Cashback")
                .font(.system(size: 17 * f, weight: .semibold))
                .foregroundStyle(.white)
                // Тот же жест, что в пикере: тройной тап открывает дебаг-панель.
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        MotionSettings.shared.showPanel.toggle()
                    }
                }

            HStack {
                glassCircle(icon: "chevron.left", f: f)
                Spacer()
                // Карандаш из макета — декоративный. Дебаг открывается
                // плавающей кнопкой в RootView, дублировать вход не нужно.
                glassCircle(icon: "pencil", f: f)
            }
            .padding(.horizontal, 16 * f)
        }
        .frame(height: 48 * f)
        .padding(.top, 4 * f)
    }

    private func glassCircle(icon: String, f: CGFloat) -> some View {
        Image(systemName: icon)
            .font(.system(size: 19 * f, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 48 * f, height: 48 * f)
            .liquidGlass(Circle())
    }

    // MARK: - Карта 343×216 с моковыми данными

    private func cardHero(f: CGFloat) -> some View {
        ZStack {
            RemoteImage(cardImage: appliedCard.image, kind: .detail, contentMode: .fill)
                .frame(height: 216 * f)
                .frame(maxWidth: .infinity)
                .clipped()

            // Логотип O! Bank и VISA УЖЕ НАРИСОВАНЫ на арте карты — своих не
            // добавляем, иначе задваиваются поверх макетных.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Spacer()
                    Text("online")
                        .font(.system(size: 12 * f, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10 * f)
                        .padding(.vertical, 4 * f)
                        .background(Tokens.accentPink)
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8 * f)

                maskedField("4196  ••••  ••••  2394", f: f)
                    .padding(.bottom, 8 * f)
                maskedField("12 / 25", trailingDots: true, f: f)

                Spacer(minLength: 8 * f)

                HStack(alignment: .bottom) {
                    Text("IVANOV IVANOVSKII")
                        .font(.system(size: 12 * f, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.6), radius: 3 * f)
                    Spacer()
                }
            }
            .padding(16 * f)
        }
        .frame(height: 216 * f)
        .clipShape(RoundedRectangle(cornerRadius: 16 * f, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 16 * f, y: 10 * f)
        // Смена дизайна перетекает, а не щёлкает.
        .animation(MotionTokens.transition(reduceMotion: reduceMotion),
                   value: appliedGlobal)
    }

    // В макете (3602:102554) реквизиты лежат ПРЯМО на арте, без плашек —
    // читаемость держится на тени текста. Сплошная подложка любой плотности
    // на ярком арте («Разряд», «Царап») выглядела серым пятном, поэтому
    // подложек нет: только тень, как в дизайне.
    private func maskedField(_ text: String, trailingDots: Bool = false,
                             f: CGFloat) -> some View {
        HStack(spacing: 8 * f) {
            Text(text)
                .font(.system(size: 17 * f, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.75), radius: 4 * f)
                .shadow(color: .black.opacity(0.45), radius: 10 * f)
            Spacer(minLength: 8 * f)
            if trailingDots {
                Text("• • •")
                    .font(.system(size: 13 * f, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10 * f)
                    .padding(.vertical, 6 * f)
                    .background(Color.black.opacity(0.45), in: Capsule())
            }
            Image(systemName: "eye")
                .font(.system(size: 15 * f))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.75), radius: 4 * f)
        }
        .padding(.horizontal, 4 * f)
    }

    // MARK: - Белый шит со списком

    private func sheet(f: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0xD9D9D9))
                .frame(width: 36 * f, height: 5 * f)
                .padding(.top, 8 * f)
                .padding(.bottom, 16 * f)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12 * f) {
                    AccountNumberRow(number: "1250920002160193",
                                     balance: "0,00 с", f: f)

                    HStack(spacing: 12 * f) {
                        ActionCard(icon: "arrow.right", title: "Перевести", f: f)
                        ActionCard(icon: "plus", title: "Пополнить", f: f)
                    }

                    PromoCell(f: f)

                    OneLineCell(icon: "clock.arrow.circlepath",
                                title: "История платежей", f: f)

                    OneLineCell(icon: "creditcard", title: "Интернет-платежи", f: f,
                                action: nil) { StaticToggle(isOn: true, f: f) }

                    OneLineCell(icon: "star", title: "Счёт по умолчанию",
                                subtitle: "Для платежей и переводов", f: f,
                                action: nil) {
                        Text("Выбрать")
                            .font(.system(size: 17 * f, weight: .medium))
                            .fixedSize()
                            .foregroundStyle(Tokens.link)
                            .padding(.trailing, 8 * f)
                    }

                    // ЕДИНСТВЕННАЯ рабочая строка
                    OneLineCell(icon: "photo.on.rectangle.angled",
                                title: "Цифровой дизайн карты", f: f,
                                action: onOpenPicker)

                    OneLineCell(icon: "key", title: "Изменить ПИН-код", f: f)
                    OneLineCell(icon: "info.circle", title: "Вопрос – ответ", f: f)
                    OneLineCell(icon: "lock", title: "Заблокировать или закрыть карту", f: f)
                }
                .padding(.horizontal, 16 * f)
                .padding(.bottom, bottomInset + 24 * f)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            Tokens.sheetBg
                .clipShape(RoundedCorner(radius: 20 * f, corners: [.topLeft, .topRight]))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

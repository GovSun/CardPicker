import Foundation

// MARK: - Базовый адрес хранилища арта
//
// Вынесен из RemoteImage отдельно, чтобы внутренний адрес не лежал
// в публичном репозитории. Порядок разрешения:
//
//   1. переменная окружения `ART_BASE_URL` — для отладки и CI:
//        SIMCTL_CHILD_ART_BASE_URL=https://... xcrun simctl launch ...
//   2. Info.plist, ключ `ArtBaseURL` — так задаётся в сборке;
//   3. ничего не задано → nil, и RemoteImage прозрачно берёт локальный
//      бандл CardArt/. Приложение остаётся полностью рабочим, просто
//      без сетевого арта — поэтому свежий клон репозитория собирается
//      и запускается без какой-либо настройки.
enum ArtEndpoint {

    static let base: URL? = resolve()

    private static func resolve() -> URL? {
        if let s = ProcessInfo.processInfo.environment["ART_BASE_URL"],
           !s.isEmpty, let u = URL(string: s) {
            return u
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "ArtBaseURL") as? String,
           !s.isEmpty, let u = URL(string: s) {
            return u
        }
        return nil
    }
}

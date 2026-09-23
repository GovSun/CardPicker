# CardPicker

iOS-прототип выбора дизайна банковской карты для **O!Bank / Visa Cashback**.
Swift Playgrounds-пакет (`.swiftpm`), SwiftUI, таргет **iOS 17.0**.

Собран из Figma-макета [Дизайн карт IOS](https://www.figma.com/design/y1jCDm8fP13bY2kfGs0wE4/).
В коде указаны конкретные node id — по ним сверяются значения.

## Что это

Пользователь меняет дизайн своей карты: 11 коллекций, 56 дизайнов.
Прототип существует в **трёх вариантах флоу** для A/B-теста — это его смысл,
а не незавершённый рефакторинг:

| Вариант | Как устроен |
|---|---|
| **A** | Один экран пикера с тумблером «сетка ↔ карусель» в аппбаре |
| **B** | Двухшаговый: сетка → «Продолжить» → свайп → «Применить дизайн» |
| **C** | Один экран: карта сверху, сетка в раскрывающемся bottom sheet |

Переключаются в дебаг-панели (**тройной тап по заголовку в аппбаре**) или
переменной окружения `AB_FLOW=a|b|c`.

## Сборка

Симулятор:

```bash
xcodebuild -scheme CardPicker \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /tmp/cp_build build

xcrun simctl install booted /tmp/cp_build/Build/Products/Debug-iphonesimulator/CardPicker.app
xcrun simctl launch booted kg.devcats.memorila.cardpicker
```

Устройство:

```bash
xcodebuild -scheme CardPicker \
  -destination 'platform=iOS,id=<UDID>' \
  -derivedDataPath /tmp/cp_device_build \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=<TEAM_ID> CODE_SIGN_STYLE=Automatic build

xcrun devicectl device install app --device <UDID> \
  /tmp/cp_device_build/Build/Products/Debug-iphoneos/CardPicker.app
```

> **`-derivedDataPath` обязан лежать ВНЕ пакета.** Иначе копирование ресурсов
> рекурсивно заходит само в себя и сборка падает с «Cycle inside CardPicker».

## Дебаг-переменные

Передаются с префиксом `SIMCTL_CHILD_` перед `xcrun simctl launch`.
Нужны потому, что в симуляторе нельзя программно тапать и скроллить —
все состояния воспроизводятся через запуск.

| Переменная | Что делает |
|---|---|
| `AB_FLOW=a\|b\|c` | Какой вариант флоу открыть |
| `START_SCREEN=picker` | Открыть сразу пикер, минуя «Детали карты» |
| `START_CARD=<0..55>` | Какая карта выбрана (и куда встанет скролл) |
| `START_MODE=cards\|list` | Продавить вид в вариантe A |
| `START_SHEET=open` | Вариант C: раскрыть шит через ~1.4 c |
| `START_SWIPE=1` | Вариант C: переключиться на карусель |
| `START_PICK=<gi>` | Выбрать карту уже после открытия пикера |
| `DEBUG_SPRING=1` | Показать панель настройки пружин |
| `ART_BASE_URL=<url>` | Адрес хранилища арта (по умолчанию — локальный `CardArt/`) |

## Структура

| Файл | Роль |
|---|---|
| `Model.swift` | Каталог: 11 коллекций, 56 карт. Только данные |
| `PickerModel.swift` | `@Observable` — единый источник правды о выборе и режиме |
| `RootView.swift` | `NavigationStack`, маршруты, тост, переключение вариантов |
| `ContentView.swift` | Экран пикера: карусель и сетка (варианты A и B) |
| `SheetPickerView.swift` | Вариант C: карта + раскрывающийся шит |
| `DesignGridView.swift` | Сетка коллекций, раскрытие «+N еще» |
| `DesignTile.swift` | Плитка дизайна, крышка «+N еще», галочка выбора |
| `RemoteImage.swift` | Загрузка арта из MinIO + дисковый кэш, фолбэк на `CardArt/` |
| `MotionTokens.swift` | Все пружины и длительности в одном месте |
| `Theme.swift` | Токены цвета, хаптика, Liquid Glass |
| `ScrollOffsetProbe.swift` | Позиция скролла через KVO на `UIScrollView` |
| `ArtEndpoint.swift` | Адрес хранилища арта: env → Info.plist → локальный фолбэк |

`*_Legacy.swift` — прежний строчный список, сохранён намеренно
(запускается через `LEGACY_LIST=1`).

## Арт карт

Весь арт лежит локально в `CardArt/` — **репозиторий собирается и запускается
сразу после клонирования, без какой-либо настройки.**

Опционально карты могут подтягиваться из S3-совместимого хранилища. Адрес
в репозитории не зашит (он внутренний) и задаётся одним из двух способов:

```bash
# переменной окружения — для отладки
SIMCTL_CHILD_ART_BASE_URL=https://<эндпоинт>/media-service \
  xcrun simctl launch booted kg.devcats.memorila.cardpicker
```

либо ключом `ArtBaseURL` в `Info.plist` сборки. Если адрес не задан,
`RemoteImage` прозрачно берёт локальный бандл — см. `ArtEndpoint.swift`.

Соответствие «карта → имя объекта» прописано вручную в `RemoteImage.swift`:
листинг бакета закрыт, анонимный GET по конкретному объекту работает.
Без записи в этой таблице карта молча уходит на локальный фолбэк.

## Известные грабли

Каждая стоила реального времени — они описаны подробнее в комментариях по месту:

- Папку с ресурсами **нельзя** называть `Resources` — конфликт с раскладкой
  macOS-бандла, `simctl install` падает с невнятным «Missing bundle ID».
- Позицию скролла на iOS 17 даёт **только** KVO на `UIScrollView.contentOffset`.
  `PreferenceKey`, `scrollPosition(id:)` и `onAppear/onDisappear` проверены и
  не работают для eager-`VStack` (см. шапку `ScrollOffsetProbe.swift`).
- Сетка обязана оставаться **eager** `VStack`: ленивый контейнер ломает
  измерение фреймов и разовый `scrollTo` на первом кадре.
- `.opacity(0)` **не** убирает вид из дерева — скрытые `.blur`-слои продолжают
  считаться. Однажды это дало 29 живых блюр-проходов и просадку кадров.
- `TabView(.page)` на iOS 26 не рендерит контент внутри страниц — карусель
  собрана вручную на `DragGesture`.
- `Package.swift` управляется Xcode / Swift Playgrounds, правки руками могут
  быть затёрты.

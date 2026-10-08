# 2. Архитектура

## 2.1. Стек

| Что | Выбор | Почему |
|-----|-------|--------|
| Язык | Swift 6 (strict concurrency) | Нативно для iOS |
| UI | SwiftUI, `@Observable` (Observation) | Анимации переворота и свайпов делаются просто |
| Минимальная iOS | 17.0 | Нужны SwiftData и `@Observable` |
| Хранение прогресса | SwiftData | Встроено, не нужна внешняя БД, позже можно включить CloudKit |
| Словарь | `words.json` в бандле, только чтение, загружается в память | ~5000 записей ≈ 2 МБ, разбор < 0.3 с |
| Настройки | `UserDefaults` через обёртку `SettingsStore` | Простые значения |
| Озвучка | `AVSpeechSynthesizer` (en-GB / en-US) | Офлайн, бесплатно, не нужны аудиофайлы |
| Графики | Swift Charts | Встроено |
| Уведомления | `UserNotifications`, только локальные | Без сервера |
| Генерация проекта | XcodeGen (`project.yml`) | `.xcodeproj` не правится вручную, удобно для ИИ-агента |
| Тесты | Swift Testing (`@Test`) для логики, XCUITest для smoke-тестов UI | — |
| CI | GitHub Actions: `ubuntu-latest` для `swift test` StudyCore, `macos-15` для сборки и тестов приложения | — |
| Сторонние зависимости | **нет** | Меньше поддержки |

## 2.2. Слои

```
┌──────────────────────────────────────────────────────────────┐
│ Features (SwiftUI Views + @Observable ViewModels)            │
│   Learn · Review · Dictionaries · Progress · Settings · Help  │
├──────────────────────────────────────────────────────────────┤
│ DesignSystem: токены цветов/шрифтов, FlashCardView,          │
│   PillButton, Chip, Badge, CountdownView                     │
├──────────────────────────────────────────────────────────────┤
│ App Services (iOS-зависимые)                                 │
│   StudyService (фасад) · SpeechService · NotificationService │
│   HapticsService · BackupService · SettingsStore             │
├──────────────────────────────────────────────────────────────┤
│ Persistence: SwiftData-модели + SwiftDataProgressRepository  │
├──────────────────────────────────────────────────────────────┤
│ StudyCore (Swift Package, только Foundation, тестируется на  │
│ Linux): Word, WordProgress, DayClock, DailyPlanBuilder,      │
│ LeitnerScheduler, LearnSessionQueue, StatsCalculator,        │
│ WordCatalog (разбор words.json), протоколы репозиториев      │
└──────────────────────────────────────────────────────────────┘
```

Правила зависимостей:
- Зависимости направлены **только вниз**. `StudyCore` не импортирует SwiftUI, SwiftData, AVFoundation.
- View не обращается к SwiftData напрямую (никаких `@Query` во View), только через ViewModel → `StudyService`.
- Вся логика с датами получает `DayClock` извне, а не вызывает `Date()` сама. Иначе её нельзя протестировать.
- Случайность — только через переданный генератор с зерном (`SeededRandom`).

## 2.3. Модули StudyCore

### Модели (value types, `Sendable`, `Codable`)

```swift
enum CEFRLevel: String, Codable, CaseIterable, Comparable { case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1" }
enum WordList: String, Codable { case ox3000, ox5000 }
enum PartOfSpeech: String, Codable { case noun, verb, adjective, adverb, preposition, conjunction,
                                     pronoun, determiner, number, exclamation, modal, auxiliary, article, other }

struct Word: Identifiable, Codable, Sendable, Hashable {
    let id: String              // стабильный: "close_verb"
    let lemma: String           // "close"
    let pos: PartOfSpeech
    let cefr: CEFRLevel
    let list: WordList
    let ipaUK: String?
    let ipaUS: String?
    let translations: [String]  // ≥ 1, первый — основной
    let exampleEN: String?
    let exampleRU: String?
    let order: Int              // базовый порядок внутри словаря
}

enum WordStatus: String, Codable { case new, learning, review, mastered, known }

struct WordProgress: Codable, Sendable, Equatable {
    let wordId: String
    var status: WordStatus
    var box: Int                // 0…6
    var dueDayKey: DayKey?      // для review
    var firstSeenAt: Date?
    var lastSeenAt: Date?
    var timesSeen: Int
    var lapses: Int
    var isFavorite: Bool
}

struct DayKey: Codable, Hashable, Comparable { let year: Int; let month: Int; let day: Int } // "2026-10-08"

struct DailyPlan: Codable, Sendable {
    let dayKey: DayKey
    var wordIds: [String]       // carryover + new, в исходном порядке
    var queue: [String]         // текущая очередь показа
    var learnedIds: Set<String>
    var seenIds: Set<String>
    var extraBatches: Int       // сколько раз нажато «Ещё 10 слов»
}
```

### Логика

| Компонент | Ответственность | Чистая функция? |
|-----------|-----------------|-----------------|
| `DayClock` | `now`, `calendar`, `dayStartHour` → `dayKey(for:)`, `startOfNextDay()` | да (значения задаются извне) |
| `StudyOrder` | Порядок новых слов: по уровню / случайно / по алфавиту, с зерном | да |
| `DailyPlanBuilder` | `build(dayKey, catalog, progress, settings) -> DailyPlan` по формуле из спецификации §1.4 | да |
| `LearnSessionQueue` | Действия «Выучил», «Ещё учу», «Уже знаю», отмена; определяет «круг пройден» | да (принимает и возвращает состояние) |
| `LeitnerScheduler` | `apply(.remembered/.forgot, to: WordProgress, today:)`; интервалы `[1,3,7,14,30,60]` | да |
| `ReviewQueueBuilder` | Слова с `due ≤ today`, сортировка, лимит | да |
| `StatsCalculator` | Серия, итоги, данные для графиков, прогноз | да |
| `WordCatalog` | Разбор и проверка `words.json`, индексы по id/списку/уровню, поиск | да |
| `ProgressRepository` (протокол) | `progress(for:)`, `allProgress()`, `save(_:)`, `plan(for:)`, `savePlan`, `appendLog` | — |
| `InMemoryProgressRepository` | Реализация для тестов | — |

Каждое пользовательское действие — это транзакция: «старое состояние + действие → новое состояние
+ запись в журнал». Её применяет `StudyService` и сразу сохраняет. Отмена = применить сохранённый
снимок предыдущего состояния.

## 2.4. Хранение (SwiftData, в приложении)

```swift
@Model final class WordProgressEntity {      // одна строка на слово, которое хоть раз трогали
    @Attribute(.unique) var wordId: String
    var statusRaw: String; var box: Int; var dueDayKey: String?
    var firstSeenAt: Date?; var lastSeenAt: Date?
    var timesSeen: Int; var lapses: Int; var isFavorite: Bool
}
@Model final class DailyPlanEntity {
    @Attribute(.unique) var dayKey: String   // "2026-10-08"
    var wordIds: [String]; var queue: [String]
    var learnedIds: [String]; var seenIds: [String]; var extraBatches: Int
    var createdAt: Date
}
@Model final class ReviewLogEntity {         // журнал для статистики и экспорта
    var wordId: String; var at: Date; var dayKey: String
    var modeRaw: String                      // learn | review | manual
    var resultRaw: String                    // learned | stillLearning | known | remembered | forgot | reset
}
```

- У слов без строки `WordProgressEntity` статус `new`, поэтому при установке ничего не создаётся
  на все 5000 слов.
- Маппинг Entity ↔ value type из StudyCore живёт в `SwiftDataProgressRepository`.
- Схема версионируется через `VersionedSchema` и `SchemaMigrationPlan` с первого дня.
- Объём: примерно 60 + повторения записей журнала в день, около 50 тыс. в год. Для SwiftData это немного.

## 2.5. Поток данных

```
Запуск приложения
  └─ AppContainer
       ├─ WordCatalog.load(words.json)       (фоновая задача; на время загрузки экран-заставка)
       ├─ ModelContainer(SwiftData)
       ├─ SettingsStore, DayClock
       └─ StudyService(catalog, repo, clock, settings)

scenePhase → .active  (а также таймер на начало следующего учебного дня)
  └─ StudyService.ensureToday()
       ├─ dayKey = clock.dayKey(now)
       ├─ plan(for: dayKey) существует? → использовать
       └─ иначе DailyPlanBuilder.build(...) → savePlan → NotificationService.reschedule()

LearnView ──tap «Выучил»──▶ LearnViewModel.markLearned()
  └─ StudyService.apply(.learned(wordId))
       ├─ LearnSessionQueue.apply → новый план + новый WordProgress
       ├─ repo.save(progress), repo.savePlan(plan), repo.appendLog(...)
       ├─ undoStack.push(снимок «до»)
       └─ публикует обновлённое состояние → View перерисовывается; HapticsService.success()
```

`StudyService` помечен `@MainActor @Observable` и хранит текущее состояние: сегодняшний план,
счётчик повторений для бейджа, текущую карточку. Все вкладки читают состояние из него, поэтому
бейдж и счётчики всегда согласованы.

## 2.6. Структура репозитория

```
english_app/
├─ project.yml                     # XcodeGen
├─ App/
│  ├─ EnglishCardsApp.swift        # @main, AppContainer, RootTabView
│  ├─ Services/                    # StudyService, SpeechService, NotificationService, HapticsService,
│  │                               # BackupService, SettingsStore
│  ├─ Persistence/                 # SwiftData-модели, схема, миграции, SwiftDataProgressRepository
│  ├─ DesignSystem/                # Theme.swift (токены), Typography, FlashCardView, PillButton, Chip, ...
│  ├─ Features/
│  │  ├─ Learn/                    # LearnView, LearnViewModel, DayCompleteView, RoundCompleteSheet
│  │  ├─ Review/                   # ReviewView, ReviewViewModel
│  │  ├─ Dictionaries/             # DictionariesView, WordListView, WordDetailView
│  │  ├─ Progress/                 # ProgressView, графики
│  │  ├─ Settings/                 # SettingsView, BackupView
│  │  └─ Help/                     # HelpSheet / онбординг
│  └─ Resources/                   # words.json, Assets.xcassets (цвета, иконка), Localizable.xcstrings
├─ Packages/StudyCore/
│  ├─ Package.swift
│  ├─ Sources/StudyCore/
│  └─ Tests/StudyCoreTests/
├─ AppTests/                       # тесты репозитория SwiftData, StudyService
├─ AppUITests/                     # smoke-сценарии
├─ tools/                          # Python: подготовка словаря (см. 03-data-pipeline.md)
├─ data/                           # промежуточные CSV и исходные списки (raw/ не коммитим, если есть лицензия)
├─ docs/
└─ .github/workflows/ci.yml
```

## 2.7. Дизайн-система (по референсу)

### Цвета (токены в `Assets.xcassets` со светлым и тёмным вариантом)

| Токен | Светлая | Тёмная | Где |
|-------|---------|--------|-----|
| `bg` | `#F9F4EE` | `#15130F` | фон экрана (тёплый кремовый) |
| `surface` | `#FFFFFF` | `#211E1A` | карточка |
| `surfaceMuted` | `#F1E8DF` | `#2C2823` | чипы, плашка таймера, кнопка «Ещё учу» |
| `border` | `#E8DFD5` | `#38332D` | тонкая обводка карточки и чипов |
| `textPrimary` | `#1E1A16` | `#F3EEE8` | заголовки, слово |
| `textSecondary` | `#8B8279` | `#A59D94` | подписи |
| `accent` | `#4746B4` | `#7C7BF0` | кнопка «Выучил», активная вкладка |
| `accentGradientTop` | `#5B59D8` | `#8E8DF5` | круг с иконкой |
| `badge` | `#F0522F` | `#FF6A4A` | бейдж на вкладке |
| `success` | `#3E9B6E` | `#5BC08E` | подсказка свайпа «Выучил» |
| `warning` | `#D9912B` | `#E8A84A` | подсказка свайпа «Ещё учу» |
| CEFR A1…C1 | 5 приглушённых оттенков от зелёного к фиолетовому | | чип уровня |

### Типографика
- Заголовки и слово на карточке: системный шрифт с засечками (`.fontDesign(.serif)`, New York),
  полужирный. Слово 40 pt, заголовок экрана 28 pt.
- Основной текст: SF Pro Rounded (`.fontDesign(.rounded)`), 17 pt; подписи 15 pt, `textSecondary`.
- Таймер: моноширинные цифры (`.monospacedDigit()`), 40 pt, полужирный.
- Поддержка Dynamic Type: все размеры через `relativeTo:`.

### Формы и тени
- Карточка: скругление 32, обводка 1 pt `border`, мягкая тень `y: 8, blur: 24, opacity 0.06`.
- Кнопки: капсулы высотой 56; основная — `accent` с белым текстом и цветной тенью; вторичная — `surfaceMuted`.
- Чипы шапки (RU-EN, ?): капсула/круг 44 pt, `surfaceMuted` с обводкой.
- Отступы: 16/20/24 (поля экрана — 24, как на референсе).

### Анимации и отклик
- Переворот: `rotation3DEffect` по оси Y, пружина ~0.45 с. Лицевая сторона скрывается на 90°.
- Свайп: смещение + поворот до ±12°; порог 100 pt или скорость > 800 pt/s; улетает за край экрана за 0.25 с.
- Следующая карточка «подъезжает» из-под текущей (стопка из 2 видимых карточек).
- Haptics: `.success` на «Выучил», `.light` на «Ещё учу», `.soft` на переворот.
- Уважать «Уменьшение движения» (Reduce Motion): вместо 3D — плавная смена прозрачности.

## 2.8. Доступность и локализация
- Интерфейс на русском (`Localizable.xcstrings`), английский как второй язык интерфейса — опционально.
- VoiceOver: у карточки метка «слово, часть речи, уровень», действия «Перевернуть», «Выучил»,
  «Ещё учу», «Озвучить» через `accessibilityAction`.
- Контраст текста не ниже WCAG AA в обеих темах.

## 2.9. Резервная копия
`BackupService` экспортирует `{ "format": 1, "exportedAt", "dictionaryVersion", "settings", "progress": [...], "plans": [...], "log": [...] }`
в файл `english-cards-backup-YYYY-MM-DD.json` (`ShareLink`). Импорт через `fileImporter` с проверкой
формата и предупреждением «текущий прогресс будет заменён».

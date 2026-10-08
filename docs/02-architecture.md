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
│   StudyService (@Observable-обёртка над StudyEngine) ·       │
│   SpeechService · NotificationService · HapticsService ·     │
│   BackupService · SettingsStore                              │
├──────────────────────────────────────────────────────────────┤
│ Persistence: SwiftData-модели + SwiftDataProgressRepository  │
├──────────────────────────────────────────────────────────────┤
│ StudyCore (Swift Package, только Foundation, тестируется на  │
│ Linux): Word, WordProgress, DayClock, DailyPlanBuilder,      │
│ LeitnerScheduler, LearnSession, StatsCalculator, WordCatalog,│
│ StudyEngine (вся оркестрация), протокол ProgressRepository   │
└──────────────────────────────────────────────────────────────┘
```

Правила зависимостей:
- Зависимости направлены **только вниз**. `StudyCore` не импортирует SwiftUI, SwiftData, AVFoundation.
- View не обращается к SwiftData напрямую (никаких `@Query` во View), только через ViewModel → `StudyService` → `StudyEngine`.
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
    let id: String              // стабильный: "close-1_verb", "bank-money_noun"
    let lemma: String           // "close"
    let sense: String?          // пометка значения из списка Oxford: "money" для bank (money)
    let pos: PartOfSpeech
    let cefr: CEFRLevel
    let list: WordList
    let ipa: String?            // американская транскрипция: "/ˈkloʊs/" или два варианта через запятую
    let translations: [String]  // 1–3 группы значений, первая — основная: ["о, про", "около, примерно"]
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

Реализовано в `Packages/StudyCore/Sources/StudyCore/` (81 тест, покрытие строк 96 %):

| Файл / тип | Ответственность |
|------------|-----------------|
| `DayKey` | Календарный день без часового пояса, арифметика по григорианскому календарю (без `Calendar`), хранится строкой `"2026-10-08"` |
| `DayClock` | Учебный день, начинающийся в `dayStartHour`: `dayKey(for:)`, `startOfNextDay(after:)`, `secondsUntilNextDay(from:)`. Время получает снаружи, переход на летнее время не сдвигает границу |
| `SeededRandom` | SplitMix64; `stableValue(seed:key:)` — стабильное «случайное» число для слова (одинаково на всех платформах, не зависит от остальных слов) |
| `StudySettings` | N, буфер B, включённые словари, порядок, лимит повторений, зерно, час начала дня, размер «ещё слов» |
| `WordCatalog` | Разбор `words.json`, индексы по id/словарю/уровню, поиск по английскому и русскому (точное → префикс → подстрока) |
| `DailyPlanBuilder` | Хвост («ещё учу», самые давние первыми) + новые слова по формуле `min(N, max(0, N+B−хвост))`; порядок: по уровню / случайно / по алфавиту; следующая пачка для «Ещё 10 слов» |
| `LearnSession` | Чистые функции карточки: `apply(.learned/.stillLearning/.known)`, `review(.remembered/.forgot)`, `phase(of:)` (`card / roundComplete / dayComplete / allDone`), `startNextRound`, `finishForToday`, `addWords`. Каждое действие возвращает `ActionResult` со снимком для отмены |
| `LeitnerScheduler` | Интервалы `[1,3,7,14,30,60]`, «Выучил» → коробка 1, «Помню» → +1 коробка (после 6-й — `mastered`), «Забыл» → `learning`, `lapses+1` |
| `ReviewQueueBuilder` | Слова с `due ≤ today` (самые просроченные первыми), без слов сегодняшнего плана, с учётом дневного лимита и уже данных ответов |
| `ProgressRules` | Ручные действия из словарей: «Уже знаю», «Вернуть в изучение», «Сбросить», ★ |
| `UndoStack` | До 10 снимков; очищается при смене дня и при действиях, не являющихся ответом на карточку |
| `StatsCalculator` | Серия (день засчитывается при ≥ 80 % плана или всех повторениях), итоги по статусам/уровням/словарям, выученные по дням, прогноз повторений |
| `ProgressRepository` | Протокол хранилища с атомарной операцией `commit(StateChange)`; `InMemoryProgressRepository` для тестов |
| `StudyEngine` | Оркестрация: держит план и прогресс в памяти, применяет действие, **сначала** сохраняет в репозиторий и только потом обновляет память; смена дня, две раздельные отмены (учить / повторять), очередь повторений для бейджа, словарные действия, статистика |

Каждое пользовательское действие — это транзакция: «старое состояние + действие → новое состояние
+ запись в журнал» (`StateChange`). Её применяет `StudyEngine` и сразу сохраняет. Отмена =
применить сохранённый снимок предыдущего состояния; если у слова раньше не было строки прогресса,
откат её удаляет, так что состояние возвращается в точности.

`StudyEngine` не читает системное время: ему передают `now: @MainActor () -> Date`. SwiftUI-слой
оборачивает его в `@Observable`-сервис (`StudyService`), поэтому вся логика проверяется тестами
на Linux, без симулятора.

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
  └─ StudyService → StudyEngine.refreshDay()
       ├─ dayKey = clock.dayKey(for: now())
       ├─ plan(for: dayKey) существует? → использовать
       └─ иначе DailyPlanBuilder.build(...) → commit(plan) → NotificationService.reschedule()

LearnView ──tap «Выучил»──▶ LearnViewModel.markLearned()
  └─ StudyService → StudyEngine.perform(.learned)
       ├─ LearnSession.apply → новый план + новый WordProgress + запись журнала
       ├─ repository.commit(StateChange)  — атомарно; при ошибке память не меняется
       ├─ learnUndo.push(снимок «до»)
       └─ @Observable публикует состояние → View перерисовывается; HapticsService.success()
```

`StudyService` (`@MainActor @Observable`) делегирует всё `StudyEngine` и публикует его состояние:
сегодняшний план, очередь повторений для бейджа, текущую карточку. Все вкладки читают состояние
из одного места, поэтому бейдж и счётчики всегда согласованы.

## 2.6. Структура репозитория

```
english_app/
├─ project.yml                     # XcodeGen
├─ Config/
│  ├─ Shared.xcconfig              # общие настройки; подключает Local.xcconfig (не в git)
│  └─ Local.xcconfig.example       # шаблон: DEVELOPMENT_TEAM и APP_BUNDLE_ID
├─ Makefile                        # make data / review / extract / ipa
├─ App/
│  ├─ EnglishCardsApp.swift        # @main
│  ├─ RootTabView.swift, AppTab.swift, AppResources.swift
│  ├─ Services/                    # StudyService, SpeechService, NotificationService, HapticsService,
│  │                               # BackupService, SettingsStore
│  ├─ Persistence/                 # SwiftData-модели, схема, миграции, SwiftDataProgressRepository
│  ├─ DesignSystem/                # Theme.swift (токены, шрифты), Appearance.swift, FlashCardView, PillButton, Chip, ...
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
├─ AppUITests/                     # smoke-сценарии (XCTest)
├─ tools/                          # Python: словарь (03-data-pipeline.md) и make_assets.py (цвета, иконка)
├─ data/                           # interim/ в git; raw/ (PDF Oxford, ipa-dict) только локально
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
| `textSecondary` | `#5E564E` | `#A59D94` | подписи |
| `accent` | `#4746B4` | `#7C7BF0` | кнопка «Выучил», активная вкладка |
| `accentGradientTop` | `#5B59D8` | `#8E8DF5` | круг с иконкой |
| `badge` | `#F0522F` | `#FF6A4A` | бейдж на вкладке |
| `success` | `#2B7A52` | `#5BC08E` | подсказка свайпа «Выучил» |
| `warning` | `#9A5F00` | `#E8A84A` | подсказка свайпа «Ещё учу» |
| `LevelA1` | `#276A4B` | `#6DBE97` | чип уровня A1 (зелёный) |
| `LevelA2` | `#176468` | `#5DBBC0` | чип уровня A2 (бирюзовый) |
| `LevelB1` | `#2B5CA0` | `#72A0E3` | чип уровня B1 (синий) |
| `LevelB2` | `#5249B5` | `#9A95F0` | чип уровня B2 (индиго) |
| `LevelC1` | `#7E3F99` | `#C58BE0` | чип уровня C1 (фиолетовый) |

Таблица — источник для `tools/make_assets.py`, который генерирует `Assets.xcassets` (цвета со
светлым и тёмным вариантом, `AccentColor`, иконка приложения). Правки вносятся в скрипт.
Текстовые цвета подобраны так, чтобы контраст с фоном и поверхностью был не ниже 4.5 : 1 (WCAG AA);
проверка автоматическим аудитом доступности в UI-тестах.

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

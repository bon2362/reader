# Story 2: Menu visual polish и простая close transition для iPhone reader

Status: ready-for-dev

## Story

Как читатель EPUB на iPhone, я хочу видеть легкое, книжное меню с понятными мягкими иконками и аккуратным закрытием reader, чтобы overlay ощущался частью чтения, а не технической панелью.

## Context

Эта story покрывает замечания #1 и #7. Цель - визуально отполировать текущий lightweight menu, не возвращаясь к тяжелым panel UI и не вводя matched geometry flow между library и reader.

Сейчас `IPhoneEPUBReaderView.swift` использует:

- top bar: `list.bullet`, `xmark`, title;
- bottom bar: page counter и `ellipsis.circle`;
- action tray icons: `textformat.size`, `magnifyingglass`, `note.text.badge.plus`, `bookmark`;
- close через `closeReader()` сразу вызывает `onClose` или `dismiss()`;
- menu overlay transition `.opacity`.

План требует заменить технические SF Symbols на более reader-like, уменьшить до около 17pt, использовать `.secondary`, добавить компактные circular thin-material icon containers и сделать простой custom removal transition на закрытие reader. `matchedGeometryEffect` оставить future/non-goal.

## Acceptance Criteria

1. Menu icons выглядят менее техническими и более reader-like, оставаясь понятными и доступными.
2. Иконки в top/bottom menu и action tray используют компактные circular material containers, а не тяжелые панели.
3. Размер иконок примерно 17pt, visual weight мягкий; foreground преимущественно `.secondary`, selected/primary states не выглядят шумно.
4. Hit target остается не меньше 44x44 там, где это интерактивная кнопка.
5. Закрытие reader имеет простую плавную transition-анимацию без изменения library/opening flow.
6. `matchedGeometryEffect` не внедряется в рамках этой story.
7. Меню остается читаемым в light/sepia/dark/auto themes.

## Tasks / Subtasks

- Провести polish menu icons.
  - Пересмотреть `menuOverlay` icons: TOC, close, more/action tray.
  - Пересмотреть `actionTrayButton` symbols для settings/search/note/bookmarks на более reader-like варианты, если доступные SF Symbols поддерживают смысл.
  - Применить компактный circular thin-material background к icon buttons.
  - Сохранить accessibility labels.
- Уточнить visual style.
  - Использовать smaller icon font около 17pt.
  - Использовать `.secondary` для icon foreground, с достаточным contrast.
  - Не превращать overlay в большую card/panel композицию.
- Добавить простую close transition.
  - В `IPhoneEPUBReaderView` добавить локальное состояние закрытия, если нужно, и проигрывать короткую opacity/scale/offset removal animation перед `closeReader()`.
  - Убедиться, что закрытие через swipe down (`requestReaderDismiss`) и кнопку close используют один путь или визуально совместимы.
  - Не трогать library cell/open animation.
- Проверить accessibility и layout.
  - Кнопки не сжимаются и не перекрывают title.
  - `store.chapterTitle` с двумя строками не ломает top bar.

## Dev Notes

- `closeReader()` сейчас синхронно вызывает `onClose`/`dismiss`; для transition может понадобиться `requestCloseReader()` с state flag и delayed actual close.
- Если используется delayed close, защититься от повторных taps.
- `requestReaderDismiss()` в store только выставляет `requestDismiss = true`; view слушает `.onChange` и вызывает `closeReader()`. Для единого transition лучше направить этот путь в тот же close handler.
- Не усложнять: достаточно простой fade/scale/slide на reader shell. Цель - отсутствие резкого исчезновения, не shared element transition.
- Проверить, что action tray из Story 1 с anchor `.bottomTrailing` не конфликтует с новым circular material style.

## References

- Plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-ux-bugfix-plan-2026-04-29.md`
- Current view: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

## Affected Files

- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

## Non-goals / Risks

- Не внедрять `matchedGeometryEffect`.
- Не менять навигационную архитектуру library-to-reader.
- Не увеличивать визуальный вес меню: no heavy cards, no large bottom sheets.
- Риск: слишком маленькие иконки могут ухудшить tap confidence. Сохранять 44x44 target даже при smaller symbol.

## Verification Notes

- Проверить overlay в portrait iPhone, включая long chapter title.
- Проверить light/sepia/dark/auto.
- Закрыть reader кнопкой close и swipe down: transition видна, нет двойного dismiss.
- Открыть action tray: icons compact, readable, labels доступны VoiceOver/accessibility inspector.

# Story 5: Return navigation для footnotes и внутренних EPUB-ссылок

Status: ready-for-dev

## Story

Как читатель EPUB на iPhone, я хочу после перехода по сноске или внутренней ссылке иметь видимую кнопку возврата к прежнему месту, чтобы не терять контекст чтения.

## Context

Эта story покрывает замечание #10. Текущий JS intercept-ит anchor clicks и отправляет `linkTapped`; store обрабатывает их в `handleLinkTapped(href:)`.

Сейчас:

- `IPhoneEPUBWebView.readerJS` intercepts `a[href]`, делает `post({type: 'linkTapped', href})`.
- `IPhoneEPUBReaderStore.handleLinkTapped`:
  - для `#fragment` вызывает JS `goToAnchor`;
  - для cross-chapter href находит chapter и `loadChapter(at: idx, restorePage: 0)`;
  - fragment в cross-chapter ссылке сейчас игнорируется.
- `currentPageStartOffset()` уже умеет асинхронно получить offset текущей страницы из JS.
- `goToOffset(chapterIndex:offset:)` существует, но private.
- UI для floating return button пока нет.

## Acceptance Criteria

1. Перед навигацией по internal EPUB link сохраняется текущая позиция: `(chapterIndex, current page start offset)`.
2. Store хранит return stack, а не одиночное значение, чтобы несколько переходов по ссылкам можно было откатить по одному.
3. Когда stack не пустой, в reader UI показывается floating button с `arrow.uturn.backward` или эквивалентным символом.
4. Tap по return button pop-ает последнюю позицию и вызывает navigation к сохраненному offset.
5. Возврат работает для same-chapter fragment links и cross-chapter links.
6. Возврат не появляется для обычного перелистывания страниц, поиска, TOC или manual global page entry, если эти действия не являются link navigation.
7. Return stack очищается или корректно инвалидируется при закрытии книги/reader lifecycle; не протекает между книгами.
8. UI кнопки не перекрывает критичные controls меню и не мешает чтению.

## Tasks / Subtasks

- Добавить модель return position.
  - В `IPhoneEPUBReaderStore` добавить lightweight struct для `(chapterIndex, offset)`.
  - Добавить `private(set)` или observable состояние для stack/non-empty, доступное view.
- Сохранять позицию перед link navigation.
  - Сделать `handleLinkTapped(href:)` async-friendly или запускать Task перед фактической навигацией.
  - Перед переходом вызвать `currentPageStartOffset()` и push `(currentChapterIndex, offset)`.
  - Не push, если href не удалось обработать или он ведет nowhere.
- Реализовать return action.
  - Добавить public method вроде `returnToPreviousLinkPosition()`.
  - Pop stack и вызвать существующий `goToOffset(chapterIndex:offset:)`.
  - Если offset/chapter invalid, пропустить или очистить запись безопасно.
- Поддержать cross-chapter anchors.
  - При href вида `chapter.xhtml#note1` желательно сохранять fragment и переходить к anchor после load, а не всегда restorePage 0.
  - Если это слишком рискованно, минимум сохранить return path и текущую cross-chapter behavior; явно проверить UX с typical footnotes.
- Добавить floating UI.
  - В `IPhoneEPUBReaderView` показать кнопку при non-empty stack.
  - Разместить так, чтобы она не конфликтовала с menu overlay/action tray; например trailing/bottom с safe area, скрывать или смещать при open menu.
  - Использовать material/circle style в духе Story 2.

## Dev Notes

- `goToOffset(chapterIndex:offset:)` сейчас private. Для UI/action внутри store можно оставить private и вызвать из нового public method.
- `currentPageStartOffset()` async private; `handleLinkTapped` сейчас sync private. Не блокировать main actor надолго; использовать `Task`.
- Для same-chapter `goToAnchor`, если сохраняется offset before navigation, return должен попасть на page start, а не точное tap position. Это соответствует плану.
- Для cross-chapter link with fragment текущая реализация игнорирует anchor. Сноски часто используют fragments; улучшение cross-chapter anchor может понадобиться для полного UX, но не ломайте existing chapter load sequencing.
- Guard against duplicate pushes при double tap на одну ссылку.

## References

- Plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-ux-bugfix-plan-2026-04-29.md`
- Store navigation/link handling: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- Reader JS link intercept: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- Reader overlay UI: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

## Affected Files

- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` only if cross-chapter anchor support requires JS changes

## Non-goals / Risks

- Не строить full browser-like history для всех reader navigations.
- Не менять progress persistence semantics для обычного чтения.
- Не добавлять permanent toolbar; только contextual floating return.
- Риск: async save current offset before navigation can race with quick repeated taps. Disable/debounce link handling or tolerate duplicate stack entries.

## Verification Notes

- Открыть EPUB со сноской `#id`: tap link, появляется return button, tap return возвращает на прежнюю страницу.
- Проверить nested footnote navigation: два перехода, две обратные операции.
- Проверить cross-chapter internal link: return ведет назад.
- Проверить обычные page turns/search/TOC: return button не появляется сам по себе.
- Проверить button placement with menu visible/hidden and action tray visible.

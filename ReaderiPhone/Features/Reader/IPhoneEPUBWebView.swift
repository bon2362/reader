import SwiftUI
import WebKit

struct IPhoneEPUBWebView: UIViewRepresentable {
    let store: IPhoneEPUBReaderStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        // Inject viewport meta at document start so EPUB HTML files get
        // device-width rendering. Without this, WKWebView defaults to 980px
        // viewport and scales content down, making text tiny on iPhone.
        let viewportScript = WKUserScript(
            source: """
            (function() {
                var existing = document.querySelector('meta[name="viewport"]');
                if (existing) {
                    existing.setAttribute('content', 'width=device-width, initial-scale=1.0');
                } else {
                    var meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = 'width=device-width, initial-scale=1.0';
                    var head = document.head || document.documentElement;
                    if (head) head.insertBefore(meta, head.firstChild);
                }
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(viewportScript)

        let userScript = WKUserScript(
            source: IPhoneEPUBWebView.readerJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)

        let handler = MessageHandler()
        handler.store = store
        config.userContentController.add(handler, name: "native")
        context.coordinator.handler = handler

        let webView = WKWebView(frame: .zero, configuration: config)
        // Transparent WebView — SwiftUI container provides the background colour.
        // Without this, WKWebView draws black in dark mode, hiding EPUB text.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }

        // Swipe gestures for page turning
        let swipeLeft = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSwipeLeft)
        )
        swipeLeft.direction = .left
        swipeLeft.delegate = context.coordinator
        webView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSwipeRight)
        )
        swipeRight.direction = .right
        swipeRight.delegate = context.coordinator
        webView.addGestureRecognizer(swipeRight)

        store.attachWebView(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "native")
        coordinator.handler?.store = nil
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var handler: MessageHandler?
        private weak var store: IPhoneEPUBReaderStore?

        init(store: IPhoneEPUBReaderStore) {
            self.store = store
        }

        @objc func handleSwipeLeft(_ sender: UISwipeGestureRecognizer) {
            store?.goToNextPage()
        }

        @objc func handleSwipeRight(_ sender: UISwipeGestureRecognizer) {
            store?.goToPreviousPage()
        }

        // Allow swipe gestures to fire alongside WebKit's own recognizers
        nonisolated func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }

    final class MessageHandler: NSObject, WKScriptMessageHandler {
        weak var store: IPhoneEPUBReaderStore?

        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.store?.handleMessage(type: type, data: body)
            }
        }
    }

    static let readerJS: String = """
    (function() {
        'use strict';
        if (window.__readerInstalled) return;
        window.__readerInstalled = true;

        function post(obj) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.native) {
                    window.webkit.messageHandlers.native.postMessage(obj);
                }
            } catch (e) {}
        }

        var __wrap = null;
        var __page = 0;

        function setupLayout() {
            var style = document.createElement('style');
            style.textContent = [
                'html, body { margin:0; padding:0; overflow: hidden; height: 100vh; width: 100vw; background: transparent; color: #000;',
                '  font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", serif;',
                '  font-size: 17px; line-height: 1.65; text-align: justify;',
                '  -webkit-user-select: text; user-select: text;',
                '}',
                '#__reader_wrap { padding: 56px 24px; box-sizing: border-box;',
                '  column-width: calc(100vw - 48px); column-gap: 48px; column-fill: auto;',
                '  height: 100vh; width: 100vw;',
                '  will-change: transform; transition: none;',
                '}',
                'img, svg, video { max-width: 100% !important; max-height: 90vh !important; height: auto !important; }',
                'mark.reader-hl { border-radius: 2px; padding: 0 1px; cursor: pointer; }',
                'mark.reader-note { background: transparent !important; color: inherit; border-bottom: 2px dashed rgba(255, 180, 0, 0.9); cursor: pointer; padding-bottom: 1px; }',
                '@media (prefers-color-scheme: dark) { mark.reader-note { border-bottom-color: rgba(255, 200, 80, 0.85); } }',
                'a { color: inherit; text-decoration: underline; }',
                'p { orphans: 2; widows: 2; }',
                '@media (prefers-color-scheme: dark) { html, body { background: #1a1a1a !important; color: #e0e0e0 !important; } * { color: inherit; } }'
            ].join('');
            document.head.appendChild(style);

            var wrap = document.createElement('div');
            wrap.id = '__reader_wrap';
            while (document.body.firstChild) wrap.appendChild(document.body.firstChild);
            document.body.appendChild(wrap);
            __wrap = wrap;
        }

        function pageSize() { return window.innerWidth; }
        function totalPages() {
            if (!__wrap) return 1;
            var w = __wrap.scrollWidth;
            return Math.max(1, Math.ceil(w / pageSize()));
        }
        function currentPage() { return __page; }
        function applyTransform() {
            if (!__wrap) return;
            __wrap.style.transform = 'translateX(' + (-__page * pageSize()) + 'px)';
        }

        function reportPage() {
            post({
                type: 'pageChanged',
                page: currentPage(),
                totalPages: totalPages(),
                iw: window.innerWidth,
                sw: __wrap ? __wrap.scrollWidth : 0
            });
        }

        window.__reader = {
            currentPage: function() { return currentPage(); },
            totalPages: function() { return totalPages(); },
            goToPage: function(i) {
                var max = totalPages() - 1;
                __page = Math.min(Math.max(0, i), max);
                applyTransform();
                setTimeout(reportPage, 0);
            },
            nextPage: function() { this.goToPage(currentPage() + 1); },
            prevPage: function() { this.goToPage(currentPage() - 1); },
            goToLastPage: function() { this.goToPage(totalPages() - 1); },
            goToAnchor: function(id) {
                if (!id || !__wrap) return;
                var el = null;
                try { el = document.getElementById(id); } catch (e) {}
                if (!el) {
                    var nameEsc = id.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
                    try { el = document.querySelector('[name="' + nameEsc + '"]'); } catch (e) {}
                }
                if (!el) return;
                // Reset transform so getBoundingClientRect returns untranslated coords.
                __wrap.style.transform = 'translateX(0px)';
                var r = el.getBoundingClientRect();
                var target = Math.max(0, Math.floor(r.left / pageSize()));
                this.goToPage(target);
            },
            goToOffset: function(offset) {
                if (!__wrap) return;
                var rng = rangeForOffsets(offset, Math.max(offset + 1, offset));
                if (!rng) return;
                __wrap.style.transform = 'translateX(0px)';
                var r = rng.getBoundingClientRect();
                var target = Math.max(0, Math.floor(r.left / pageSize()));
                this.goToPage(target);
            },
            applyHighlights: function(list) {
                clearAllHighlights();
                for (var i = 0; i < list.length; i++) applyOne(list[i], 'hl');
            },
            addHighlight: function(h) {
                var existing = document.querySelectorAll('mark.reader-hl[data-hl-id="' + cssEsc(h.id) + '"]');
                for (var i = 0; i < existing.length; i++) unwrap(existing[i]);
                applyOne(h, 'hl');
            },
            removeHighlight: function(id) {
                var marks = document.querySelectorAll('mark.reader-hl[data-hl-id="' + cssEsc(id) + '"]');
                for (var i = 0; i < marks.length; i++) unwrap(marks[i]);
            },
            applyNotes: function(list) {
                clearAllNotes();
                for (var i = 0; i < list.length; i++) applyOne(list[i], 'note');
            },
            addNote: function(n) {
                var existing = document.querySelectorAll('mark.reader-note[data-note-id="' + cssEsc(n.id) + '"]');
                for (var i = 0; i < existing.length; i++) unwrap(existing[i]);
                applyOne(n, 'note');
            },
            setTheme: function(theme) {
                var el = document.getElementById('__reader_theme');
                if (el) el.parentNode.removeChild(el);
                if (theme === 'auto') return;
                var s = document.createElement('style');
                s.id = '__reader_theme';
                var bg, fg;
                if (theme === 'light')      { bg = '#faf8f4'; fg = '#1a1a1a'; }
                else if (theme === 'sepia') { bg = '#f5efe0'; fg = '#3b2e1a'; }
                else if (theme === 'dark')  { bg = '#1a1a1a'; fg = '#e8e4dc'; }
                if (bg) s.textContent = 'html,body{background:' + bg + '!important;color:' + fg + '!important} *{color:inherit}';
                document.head.appendChild(s);
            },
            setFontSize: function(px) {
                var el = document.getElementById('__reader_fs');
                if (el) el.parentNode.removeChild(el);
                var s = document.createElement('style');
                s.id = '__reader_fs';
                s.textContent = 'html,body{font-size:' + px + 'px!important}';
                document.head.appendChild(s);
                setTimeout(function() {
                    var max = totalPages() - 1;
                    if (__page > max) __page = max;
                    applyTransform(); reportPage();
                }, 120);
            },
            setLineHeight: function(v) {
                var el = document.getElementById('__reader_lh');
                if (el) el.parentNode.removeChild(el);
                var s = document.createElement('style');
                s.id = '__reader_lh';
                s.textContent = 'html,body{line-height:' + v + '!important}';
                document.head.appendChild(s);
                setTimeout(function() {
                    var max = totalPages() - 1;
                    if (__page > max) __page = max;
                    applyTransform(); reportPage();
                }, 120);
            },
            // NOTE: Search matches within individual text nodes only. Phrases that span
            // an inline element boundary (e.g. text split by <em> or <strong>) will not be
            // found. This is a known limitation of the offset-based architecture.
            search: function(query) {
                if (!query) return [];
                var lower = query.toLowerCase();
                var nodes = collectTextNodes();
                var pos = 0;
                var results = [];
                for (var i = 0; i < nodes.length; i++) {
                    var text = nodes[i].nodeValue;
                    var ltext = text.toLowerCase();
                    var idx = 0;
                    while (true) {
                        var found = ltext.indexOf(lower, idx);
                        if (found === -1) break;
                        var ss = Math.max(0, found - 40);
                        var se = Math.min(text.length, found + query.length + 40);
                        results.push({ offset: pos + found, length: query.length, snippet: text.substring(ss, se) });
                        idx = found + 1;
                    }
                    pos += text.length;
                }
                return results;
            }
        };

        function cssEsc(s) { return String(s).replace(/["\\\\]/g, '\\\\$&'); }

        function clearAllHighlights() {
            var marks = document.querySelectorAll('mark.reader-hl');
            for (var i = 0; i < marks.length; i++) unwrap(marks[i]);
        }
        function clearAllNotes() {
            var marks = document.querySelectorAll('mark.reader-note');
            for (var i = 0; i < marks.length; i++) unwrap(marks[i]);
        }
        function unwrap(el) {
            var parent = el.parentNode;
            if (!parent) return;
            while (el.firstChild) parent.insertBefore(el.firstChild, el);
            parent.removeChild(el);
            parent.normalize();
        }

        function collectTextNodes() {
            var out = [];
            if (!document.body) return out;
            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
            var n;
            while ((n = walker.nextNode())) {
                var p = n.parentNode;
                if (!p) continue;
                var name = p.nodeName;
                if (name === 'SCRIPT' || name === 'STYLE') continue;
                out.push(n);
            }
            return out;
        }

        function rangeOffsets(range) {
            var nodes = collectTextNodes();
            var pos = 0, start = null, end = null;
            for (var i = 0; i < nodes.length; i++) {
                var n = nodes[i];
                if (n === range.startContainer && start === null) start = pos + range.startOffset;
                if (n === range.endContainer && end === null) end = pos + range.endOffset;
                if (start !== null && end !== null) break;
                pos += n.nodeValue.length;
            }
            // startContainer may be an element — try to resolve
            if (start === null) start = resolveContainerOffset(range.startContainer, range.startOffset, nodes);
            if (end === null) end = resolveContainerOffset(range.endContainer, range.endOffset, nodes);
            if (start === null || end === null) return null;
            if (start > end) { var t = start; start = end; end = t; }
            return {start: start, end: end};
        }

        function rangeForOffsets(start, end) {
            var nodes = collectTextNodes();
            var pos = 0;
            var range = document.createRange();
            var didStart = false;
            for (var i = 0; i < nodes.length; i++) {
                var n = nodes[i];
                var len = n.nodeValue.length;
                var ns = pos, ne = pos + len;
                if (!didStart && start >= ns && start <= ne) {
                    range.setStart(n, Math.min(len, Math.max(0, start - ns)));
                    didStart = true;
                }
                if (didStart && end >= ns && end <= ne) {
                    range.setEnd(n, Math.min(len, Math.max(0, end - ns)));
                    return range;
                }
                pos = ne;
            }
            if (didStart && nodes.length > 0) {
                var last = nodes[nodes.length - 1];
                range.setEnd(last, last.nodeValue.length);
                return range;
            }
            return null;
        }

        function resolveContainerOffset(container, offset, nodes) {
            if (container.nodeType === Node.TEXT_NODE) return null;
            // Find position of offset-th child's first text node
            var target = container.childNodes[offset] || container.childNodes[container.childNodes.length - 1];
            if (!target) return null;
            var pos = 0;
            for (var i = 0; i < nodes.length; i++) {
                if (contains(target, nodes[i])) return pos;
                pos += nodes[i].nodeValue.length;
            }
            return pos;
        }
        function contains(parent, child) {
            var n = child;
            while (n) { if (n === parent) return true; n = n.parentNode; }
            return false;
        }

        function applyOne(h, kind) {
            var nodes = collectTextNodes();
            var pos = 0;
            var pending = [];
            for (var i = 0; i < nodes.length; i++) {
                var n = nodes[i];
                var len = n.nodeValue.length;
                var ns = pos, ne = pos + len;
                if (ne > h.startOffset && ns < h.endOffset) {
                    var ls = Math.max(0, h.startOffset - ns);
                    var le = Math.min(len, h.endOffset - ns);
                    if (le > ls) pending.push({node: n, s: ls, e: le});
                }
                pos = ne;
                if (pos >= h.endOffset) break;
            }
            for (var j = pending.length - 1; j >= 0; j--) {
                var p = pending[j];
                wrap(p.node, p.s, p.e, h.id, h.color, kind);
            }
        }

        function wrap(node, start, end, id, color, kind) {
            try {
                var rng = document.createRange();
                rng.setStart(node, start);
                rng.setEnd(node, end);
                var m = document.createElement('mark');
                if (kind === 'note') {
                    m.className = 'reader-note';
                    m.setAttribute('data-note-id', id);
                } else {
                    m.className = 'reader-hl';
                    m.setAttribute('data-hl-id', id);
                    m.style.backgroundColor = colorCSS(color);
                    m.style.mixBlendMode = 'multiply';
                }
                rng.surroundContents(m);
            } catch (e) {
                post({type: 'jsError', msg: 'wrap: ' + (e.message || e)});
            }
        }

        function colorCSS(name) {
            switch (name) {
                case 'yellow': return 'rgba(255, 221, 0, 0.55)';
                case 'red':    return 'rgba(255, 110, 110, 0.55)';
                case 'green':  return 'rgba(100, 220, 120, 0.55)';
                case 'blue':   return 'rgba(120, 180, 255, 0.55)';
                case 'purple': return 'rgba(200, 140, 255, 0.55)';
                default:       return 'rgba(255, 221, 0, 0.55)';
            }
        }

        // Selection events
        var selTimer = null;
        var hadSelection = false;
        document.addEventListener('selectionchange', function() {
            if (selTimer) clearTimeout(selTimer);
            selTimer = setTimeout(function() {
                var sel = window.getSelection();
                if (!sel || sel.isCollapsed) {
                    if (hadSelection) {
                        hadSelection = false;
                        post({type: 'selectionCleared'});
                    }
                    return;
                }
                var text = sel.toString();
                if (!text || !text.trim()) {
                    if (hadSelection) {
                        hadSelection = false;
                        post({type: 'selectionCleared'});
                    }
                    return;
                }
                var rng;
                try { rng = sel.getRangeAt(0); } catch (e) { return; }
                var offs = rangeOffsets(rng);
                if (!offs) return;
                var rects = rng.getClientRects();
                var rect = null;
                if (rects && rects.length > 0) {
                    // Use the last rect (caret tail) for picker anchor
                    var r = rects[rects.length - 1];
                    rect = {x: r.left, y: r.top, w: r.width, h: r.height};
                }
                hadSelection = true;
                post({type: 'textSelected', startOffset: offs.start, endOffset: offs.end, text: text, rect: rect});
            }, 200);
        }, true);

        document.addEventListener('click', function(e) {
            var t = e.target;
            // Intercept anchor clicks (footnotes, internal links) — never let WebKit navigate.
            var link = t && t.closest ? t.closest('a[href]') : null;
            if (link) {
                var href = link.getAttribute('href');
                if (href) {
                    e.preventDefault();
                    e.stopPropagation();
                    post({type: 'linkTapped', href: href});
                    return;
                }
            }
            var noteMark = t && t.closest ? t.closest('mark.reader-note') : null;
            if (noteMark) {
                var nid = noteMark.getAttribute('data-note-id');
                if (nid) {
                    var r = noteMark.getBoundingClientRect();
                    post({type: 'noteTapped', id: nid, x: r.left + r.width / 2, y: r.bottom});
                    e.preventDefault();
                    e.stopPropagation();
                    return;
                }
            }
            var mark = t && t.closest ? t.closest('mark.reader-hl') : null;
            if (mark) {
                var id = mark.getAttribute('data-hl-id');
                if (id) post({type: 'highlightTapped', id: id});
                return;
            }
            // Tap on empty area — toggle menu
            var sel = window.getSelection();
            if (!sel || sel.isCollapsed) {
                post({type: 'tap'});
            }
        }, true);

        function isEditableTarget(t) {
            if (!t) return false;
            var tag = (t.tagName || '').toLowerCase();
            return tag === 'input' ||
                tag === 'textarea' ||
                tag === 'select' ||
                t.isContentEditable ||
                (t.closest && t.closest('[contenteditable="true"]'));
        }

        document.addEventListener('keydown', function(e) {
            if (isEditableTarget(e.target)) return;
            if (e.key === 'ArrowRight' || e.key === 'PageDown' || e.key === ' ' || e.code === 'Space') {
                window.__reader.nextPage();
                e.preventDefault();
            } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
                window.__reader.prevPage();
                e.preventDefault();
            }
        }, true);

        window.addEventListener('resize', function() {
            setTimeout(function() {
                var max = totalPages() - 1;
                if (__page > max) __page = max;
                applyTransform();
                reportPage();
            }, 50);
        });

        function onReady() {
            setupLayout();
            // Wait for two rAF + a bit to ensure fonts/layout settled
            requestAnimationFrame(function() {
                requestAnimationFrame(function() {
                    setTimeout(function() {
                        reportPage();
                        post({type: 'ready'});
                    }, 120);
                });
            });
        }
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', onReady);
        } else {
            onReady();
        }
    })();
    """
}

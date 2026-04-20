import SwiftUI
import WebKit

struct NativeEPUBWebView: NSViewRepresentable {
    let onBridgeReady: (EPUBBridgeProtocol) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.masksToBounds = true // clip offscreen preflight webview

        let main = Self.makeWebView()
        main.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(main)

        let preflight = Self.makeWebView()
        preflight.translatesAutoresizingMaskIntoConstraints = false
        // Positioned far offscreen to the right, same size as container.
        // Needs real layout dimensions (WKWebView skips layout when hidden/alpha=0),
        // but must never be visible — container clips to bounds.
        container.addSubview(preflight, positioned: .below, relativeTo: main)

        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            main.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            main.topAnchor.constraint(equalTo: container.topAnchor),
            main.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            preflight.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10_000),
            preflight.topAnchor.constraint(equalTo: container.topAnchor),
            preflight.widthAnchor.constraint(equalTo: container.widthAnchor),
            preflight.heightAnchor.constraint(equalTo: container.heightAnchor),
        ])

        let bridge = NativeEPUBBridge(webView: main, preflightView: preflight)
        context.coordinator.bridge = bridge

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            onBridgeReady(bridge)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        let userScript = WKUserScript(source: NativeEPUBWebView.readerJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        if #available(macOS 13.3, *) { webView.isInspectable = true }
        return webView
    }

    @MainActor
    final class Coordinator {
        var bridge: NativeEPUBBridge?
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
                '  font-size: 18px; line-height: 1.6; text-align: justify;',
                '  -webkit-user-select: text; user-select: text;',
                '}',
                '#__reader_wrap { padding: 48px 64px; box-sizing: border-box;',
                '  column-width: calc(100vw - 128px); column-gap: 128px; column-fill: auto;',
                '  height: 100vh; width: 100vw;',
                '  will-change: transform; transition: none;',
                '}',
                'img, svg, video { max-width: 100% !important; max-height: 90vh !important; height: auto !important; }',
                'mark.reader-hl { border-radius: 2px; padding: 0 1px; cursor: pointer; }',
                'mark.reader-note { background: transparent !important; color: inherit; border-bottom: 2px dashed rgba(255, 180, 0, 0.9); cursor: pointer; padding-bottom: 1px; }',
                '@media (prefers-color-scheme: dark) { mark.reader-note { border-bottom-color: rgba(255, 200, 80, 0.85); } }',
                'a { color: inherit; text-decoration: underline; }',
                'p { orphans: 2; widows: 2; }',
                '@media (prefers-color-scheme: dark) { html, body { color: #e0e0e0; } }'
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
                    try { el = document.querySelector('[name="' + id.replace(/"/g, '\\\\"') + '"]'); } catch (e) {}
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

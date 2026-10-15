import Foundation

/// Configurazione passata allo script iniettato in instagram.com.
struct ScriptConfig: Encodable {
    var profile: String
    var intention: String?
    var gray: Bool
    var feedCap: Int
}

enum InjectedScript {
    static func configSource(_ config: ScriptConfig) -> String {
        let data = (try? JSONEncoder().encode(config)) ?? Data("{}".utf8)
        let json = String(decoding: data, as: UTF8.self)
        return "window.__AG__ = \(json);"
    }

    /// Toglie Reels, Esplora, post suggeriti, pubblicità e video dal feed, e fa sembrare
    /// il sito un'app nativa (niente zoom, niente selezione, niente menu del tieni premuto di Safari).
    ///
    /// Le regole guardano soprattutto gli indirizzi (/reels/, /explore/...), che cambiano molto
    /// meno spesso delle classi CSS di Instagram.
    static let main = #"""
(function () {
  if (window.__agLoaded) return;
  window.__agLoaded = true;

  var C = window.__AG__ || {};
  var personal = C.profile === 'personal';
  var messagesOnly = C.intention === 'messages';
  var feedCap = C.feedCap || 20;

  function post(msg) {
    try { window.webkit.messageHandlers.antigram.postMessage(msg); } catch (e) {}
  }

  // ---------------------------------------------------------------- Stili

  var css = [
    'html, body { -webkit-tap-highlight-color: transparent !important; overscroll-behavior-y: none; }',
    '* { -webkit-touch-callout: none !important; }',
    'body *:not(input):not(textarea):not([contenteditable]):not([contenteditable] *) { -webkit-user-select: none; user-select: none; }',
    'a[href="/reels/"], a[href^="/reels/?"], a[href="/reels"] { display: none !important; }',
    '.ag-hide { display: none !important; }',
    '#ag-end { margin: 24px 16px 120px; padding: 28px 20px; border: 1px solid #4a4946; background: #2a2928; color: #bdbbb5;',
    '  font: 600 13px/1.5 ui-monospace, Menlo, monospace; letter-spacing: .08em; text-transform: uppercase; text-align: center; }',
    '#ag-end b { display: block; font-size: 22px; letter-spacing: .12em; margin-bottom: 8px; color: #d9d7d0; }'
  ];
  if (personal) {
    // Scheda Reels nei profili.
    css.push('a[href$="/reels/"] { display: none !important; }');
  }

  var style = document.createElement('style');
  style.id = 'ag-style';
  style.textContent = css.join('\n');
  var grayStyle = document.createElement('style');
  grayStyle.id = 'ag-gray';

  function attachStyles() {
    var root = document.head || document.documentElement;
    if (!root) return;
    if (!style.isConnected) root.appendChild(style);
    if (!grayStyle.isConnected) root.appendChild(grayStyle);
  }

  window.__agSetGray = function (on) {
    grayStyle.textContent = on ? 'html { filter: grayscale(1) !important; }' : '';
    attachStyles();
  };
  window.__agSetGray(!!C.gray);

  // ---------------------------------------------------------------- Viewport: niente zoom

  function lockViewport() {
    var content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      if (!document.head) return;
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    if (meta.getAttribute('content') !== content) meta.setAttribute('content', content);
  }

  // ---------------------------------------------------------------- Regole sugli indirizzi

  function norm(p) {
    p = p || '/';
    return p.charAt(p.length - 1) === '/' ? p : p + '/';
  }

  // ID del reel se il percorso è un singolo reel (/reel/ID/ oppure /reels/ID/).
  function reelId(p) {
    var m = /^\/reels?\/([^\/?#]+)\//.exec(norm(p));
    return m ? m[1] : null;
  }

  function isHome(p) { return norm(p) === '/'; }

  // Restituisce il motivo del blocco, oppure null se il percorso è permesso.
  function classify(path, from) {
    path = norm(path);
    from = norm(from || '');

    if (path === '/reels/') return 'reels';
    if (/^\/explore\//.test(path) && !/^\/explore\/search\//.test(path)) return 'explore';
    if (personal && /^\/[^\/]+\/reels\/$/.test(path) && !/^\/reels?\//.test(path)) return 'reels';

    var id = reelId(path);
    if (id) {
      var fromId = reelId(from);
      // Da un reel a un altro: niente scroll infinito.
      if (fromId && fromId !== id) return 'chain';
      // Sul personale i reel si aprono dai DM e dai profili, non dal feed.
      if (personal && !fromId && (isHome(from) || /^\/explore\//.test(from))) return 'feed-reel';
    }

    if (messagesOnly && isHome(path)) return 'messages-only';
    return null;
  }

  var lastPath = location.pathname;

  function goBackOr(fallback) {
    var before = location.href;
    history.back();
    setTimeout(function () {
      if (location.href === before) location.replace(fallback);
    }, 700);
  }

  // `swallowed`: Instagram aveva già iniziato a cambiare pagina, quindi va riportata indietro.
  function act(reason, swallowed) {
    post({ type: 'blocked', reason: reason });
    if (reason === 'explore') {
      location.assign('/explore/search/');
      return;
    }
    if (reason === 'messages-only') {
      if (swallowed || isHome(location.pathname)) location.assign('/direct/inbox/');
      return;
    }
    if (!swallowed) return;
    if (reason === 'chain') goBackOr('/direct/inbox/');
    else location.reload();
  }

  // Tocchi sui link: si bloccano prima che arrivino a React.
  window.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    var url;
    try { url = new URL(a.getAttribute('href'), location.href); } catch (err) { return; }
    if (url.host !== location.host) return;
    var reason = classify(url.pathname, location.pathname);
    if (!reason) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    act(reason, false);
  }, true);

  // Navigazione interna di Instagram (pushState/replaceState).
  ['pushState', 'replaceState'].forEach(function (method) {
    var original = history[method];
    history[method] = function (state, title, url) {
      if (url != null) {
        var target = null;
        try { target = new URL(url, location.href); } catch (err) {}
        if (target && target.host === location.host) {
          var reason = classify(target.pathname, location.pathname);
          if (reason) {
            act(reason, true);
            return;
          }
        }
      }
      var result = original.apply(this, arguments);
      pathChanged();
      return result;
    };
  });

  window.addEventListener('popstate', function () {
    var reason = classify(location.pathname, '');
    if (reason && reason !== 'chain' && reason !== 'feed-reel') {
      act(reason, true);
      return;
    }
    pathChanged();
  });

  function pathChanged() {
    if (location.pathname === lastPath) return;
    lastPath = location.pathname;
    schedule();
  }

  // ---------------------------------------------------------------- Feed: solo post statici

  var SUGGESTED = /(suggeriti per te|suggerimenti per te|post suggeriti|suggested for you|suggested posts|suggested reels|reel suggeriti|sponsorizzat|sponsored|pubblicit)/i;
  var BANNER = /^(apri l'app|apri instagram|usa l'app|ottieni l'app|scarica l'app|passa all'app|open app|open instagram|use the app|get the app|switch to the app)$/i;
  var caughtUpSent = false;

  function isCarousel(article) {
    return article.querySelectorAll('ul li').length > 1
      || !!article.querySelector('button[aria-label="Next"], button[aria-label="Avanti"], button[aria-label="Successivo"]');
  }

  function headText(el) {
    return (el.textContent || '').slice(0, 240);
  }

  function leaves(root, selector) {
    var out = [];
    root.querySelectorAll(selector).forEach(function (el) {
      if (el.children.length === 0) out.push(el);
    });
    return out;
  }

  function hideModule(el) {
    var node = el;
    while (node && node.parentElement && !node.parentElement.querySelector('article')) {
      node = node.parentElement;
    }
    if (node && node !== document.body && node.parentElement && !node.querySelector('article')) {
      node.classList.add('ag-hide');
    }
  }

  // Il feed può togliere dal DOM i post già passati: il limite conta i post visti, non quelli presenti.
  // Salvati in sessionStorage così ricaricare la pagina non azzera il conteggio.
  var allowedPosts = [];
  try { allowedPosts = JSON.parse(sessionStorage.getItem('agPosts') || '[]'); } catch (e) {}

  function postKey(article) {
    var link = article.querySelector('a[href^="/p/"], a[href*="/p/"]');
    return link ? link.getAttribute('href').replace(/[?#].*$/, '') : null;
  }

  function filterFeed(leafNodes) {
    var articles = document.querySelectorAll('article');
    if (!articles.length) return;

    // Moduli suggeriti fuori dagli articoli (persone da seguire, reel suggeriti...).
    leafNodes.forEach(function (el) {
      var text = (el.textContent || '').trim();
      if (text.length < 60 && SUGGESTED.test(text) && !el.closest('article')) hideModule(el);
    });

    var full = allowedPosts.length >= feedCap;
    var lastShown = null;
    articles.forEach(function (article) {
      if (article.dataset.agHidden === '1') return;
      var hide = SUGGESTED.test(headText(article))
        || (!!article.querySelector('video') && !isCarousel(article));
      var key = postKey(article);
      if (!hide && personal && key) {
        if (allowedPosts.indexOf(key) === -1) {
          if (full) hide = true;
          else {
            allowedPosts.push(key);
            try { sessionStorage.setItem('agPosts', JSON.stringify(allowedPosts)); } catch (e) {}
            full = allowedPosts.length >= feedCap;
          }
        }
      }
      if (hide) {
        article.classList.add('ag-hide');
        article.dataset.agHidden = '1';
        return;
      }
      lastShown = article;
    });

    var end = document.getElementById('ag-end');
    if (personal && full && lastShown) {
      if (!end) {
        end = document.createElement('div');
        end.id = 'ag-end';
        end.innerHTML = '<b>Basta così</b>Hai visto ' + feedCap + ' post. Il resto è solo abitudine.';
      }
      if (end.previousElementSibling !== lastShown) lastShown.insertAdjacentElement('afterend', end);
      if (!caughtUpSent) {
        caughtUpSent = true;
        post({ type: 'caughtUp' });
      }
    }
  }

  function hideBanners(leafNodes) {
    leafNodes.forEach(function (el) {
      var text = (el.textContent || '').trim();
      if (text.length < 30 && BANNER.test(text)) {
        var target = el.closest('a, button, [role="button"]') || el;
        target.classList.add('ag-hide');
      }
    });
  }

  function rewriteExploreLinks() {
    document.querySelectorAll('a[href="/explore/"]').forEach(function (a) {
      a.setAttribute('href', '/explore/search/');
    });
  }

  // ---------------------------------------------------------------- Ciclo

  var pending = false;
  function run() {
    pending = false;
    if (!document.body) return;
    attachStyles();
    lockViewport();
    rewriteExploreLinks();
    // Un solo passaggio sugli elementi di testo, condiviso da banner e feed.
    var leafNodes = leaves(document.body, 'span, h2, h3, a, button');
    hideBanners(leafNodes);
    if (isHome(location.pathname)) filterFeed(leafNodes);
    if (location.pathname !== lastPath) pathChanged();
  }

  function schedule() {
    if (pending) return;
    pending = true;
    setTimeout(run, 250);
  }

  function boot() {
    run();
    new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
    // Rete di sicurezza: cambi di pagina che sfuggono ai controlli sopra.
    setInterval(function () {
      if (location.pathname === lastPath) return;
      var reason = classify(location.pathname, lastPath);
      if (reason) act(reason, true);
      else pathChanged();
    }, 1000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
"""#
}

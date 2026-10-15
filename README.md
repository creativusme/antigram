# Antigram

Instagram senza la parte che ti mangia il tempo. App iOS 17+ per uso personale, in sideload.

Antigram apre instagram.com dentro un browser nascosto (WKWebView) e ci inietta uno script che toglie
quello che crea dipendenza. L'app Instagram ufficiale non serve: va disinstallata.

## Cosa fa

| | Personale | Lavoro (Artifex) |
|---|---|---|
| Domanda "Perché lo apri?" + respiro | ✅ | — |
| Sessione massima | 5 min (modificabile) | nessun limite, promemoria ogni 10 min |
| Totale giornaliero | 20 min (modificabile) | — |
| Pausa tra sessioni | 30 min (modificabile) | — |
| Scala di grigi all'apertura | sì | no (si cambia al volo dal cerchio in alto) |
| Feed | solo foto e caroselli, max 20 post | solo foto e caroselli |
| Reels | solo quelli dei DM e dai profili, uno alla volta | idem, scheda Reels dei profili visibile |
| Esplora | sostituito dalla ricerca | sostituito dalla ricerca |
| Storie, DM, pubblicare, seguire | ✅ | ✅ |

- **Login separati**: i due profili hanno cookie e dati distinti.
- **Sblocco di emergenza**: scrivi una frase a mano e aspetta (1 minuto in più per ogni sblocco del giorno).
- **Allargare i limiti** dalle Regole richiede la stessa frase + attesa. Stringerli è libero.
- **Uscire dall'app** per più di 90 secondi chiude la sessione personale.
- **Numeri**: minuti al giorno, sessioni, motivi, quante volte hai lasciato perdere, se è stato utile.
- **Sembra un'app**: niente zoom, niente selezione del testo, niente menu del "tieni premuto" di Safari,
  niente barra ‹ › Fine sopra la tastiera, swipe indietro dal bordo, link esterni in Safari.

## Compilare da Windows (senza Mac)

Come Pageboxd: a ogni push su `main`, GitHub Actions compila l'app su un Mac nel cloud.

1. **Actions › Build Antigram**: la build parte a ogni push (circa 10 minuti).
2. A build finita, in fondo alla pagina del run: **Artifacts › Antigram-ipa** → `Antigram.ipa`.
3. Installa con Sideloadly usando il tuo Apple ID. La firma dura 7 giorni: reinstalla **sopra**
   l'app esistente e login e statistiche restano (bundle ID `com.creativusme.antigram`).

## Primo avvio

1. Disinstalla Instagram.
2. Apri Antigram › **Accedi** sul profilo personale, poi su quello di lavoro.
   Il login non consuma tempo e la pagina si chiude da sola appena entri.
3. Fine. I limiti si cambiano da **Regole**.

## Se qualcosa smette di funzionare

Instagram cambia spesso il sito. Le regole si basano soprattutto sugli indirizzi (`/reels/`, `/explore/`),
che cambiano poco. Il filtro del feed (video, suggeriti, pubblicità) dipende invece dalla pagina e
potrebbe aver bisogno di ritocchi: sono tutti in `Antigram/Web/InjectedScript.swift`.

## Struttura

```
project.yml                         Specifica XcodeGen (il .xcodeproj viene generato in CI)
.github/workflows/build.yml         Build .ipa
tools/make_icon.py                  Genera l'icona
Antigram/
├── AntigramApp.swift               App e percorso casa → intenzione → respiro → sessione → fine
├── Models/
│   ├── Models.swift                Profili, intenzioni, impostazioni, statistiche
│   ├── AppStore.swift              Limiti, pausa, sblocchi, salvataggio JSON
│   └── SessionController.swift     Timer della sessione
├── Web/
│   ├── InstagramBrowser.swift      WKWebView, domini, login separati, permessi
│   ├── InjectedScript.swift        Script iniettato: blocchi Reels/Esplora, filtro feed, stile "app"
│   └── WKWebView+Accessory.swift   Toglie la barra sopra la tastiera
└── Views/                          Casa, cancelli, sessione, fine, numeri, regole, login
```

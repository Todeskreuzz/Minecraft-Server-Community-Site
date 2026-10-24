# Codex – Einsatzanleitung für Friends & Foes

## Auftrag

Das ZIP enthält eine **vollständige statische Website**. Du sollst die Dateien in mein **bereits von mir erstelltes GitHub-Repository** übertragen und GitHub Pages aktivieren, ohne ein neues kostenpflichtiges Produkt einzuschalten. Lies vorher `README.md`.

### Prompt zum Einfügen in Codex

> Arbeite mit dem entpackten Projekt „Friends and Foes Co. KG“. Lies `README.md` und prüfe zuerst die vorhandenen Dateien. Verwende GitHub Pages im bereits bestehenden, von mir angegebenen Repository; überschreibe keine bereits vorhandenen fremden Dateien ohne Rückfrage. Führe `node scripts/check.mjs`, `node --test tests/uid-manager.test.mjs` und `node --check assets/js/app.js` aus. Prüfe die Website mit einem lokalen HTTP-Server im Browser auf Desktop und Smartphone und teste den DE/EN-Schalter, die Navigation und Platzhalter. Lade die statischen Dateien in den `main`-Branch, richte in GitHub Settings → Pages die Quelle `Deploy from a branch`, `main`, `/ (root)` ein, und gib mir anschließend die tatsächliche URL zurück. Verwende keine zusätzlichen kostenpflichtigen Dienste, keine Tokens im Quellcode und keine reale UUID-Registry im öffentlichen Repository. Füge Server-IP, Spieler, News, Discord oder Modpack-Download nur hinzu, wenn ich dazu echte Daten zur Verfügung gestellt habe. Bearbeite bei Bedarf die JSON-Dateien in `assets/data/`, aber erfinde keine realen Serverdaten. Die UIDs in `#000001 → #000002` sind nur Beispiele für die Reihenfolge. Prüfe auch Accessibility und responsive Verhalten. Installiere keine Bibliotheken, solange es nicht wirklich nötig ist.

## Reihenfolge

1. ZIP entpacken und den Projektordner öffnen.
2. `node scripts/check.mjs` + Tests ausführen.
3. Lokal mit `python -m http.server 8000` ansehen.
4. Den Namen / Link des **bereits erstellten** Repos erfragen, falls unbekannt.
5. Vor dem Commit `git status` und `git diff --cached` sorgfältig prüfen. Insbesondere `private/` darf keine persönlichen Daten enthalten, die öffentlich werden.
6. Dateien zum `main`-Branch pushen.
7. GitHub Pages über das Repository-Menü aktivieren, sofern die passenden Berechtigungen vorliegen.
8. Reale GitHub Pages URL prüfen und melden.

## Konfiguration

| Aufgabe | Datei |
|---|---|
| Server-IP, Forge-Version, Modanzahl, ZIP-Link | `assets/data/config.json` |
| Owner / Admin / Mod-Namen (nur mit Freigabe) | `assets/data/team.json` |
| Öffentlich sichtbare Spieler-UIDs | `assets/data/members.json` (durch UID-Tool) |
| News in DE und EN | `assets/data/news.json` |
| Entwurf / bestätigte Serverregeln in DE und EN | `assets/data/rules.json` |
| Farben und Animationen | `assets/css/style.css` |
| Inhalte und Statusanzeige | `assets/js/app.js`, `index.html` |

## Keine erfundenen Live-Daten

- Minecraft `1.20.1`, Forge `47.4.10`, gegenwärtig `39` Mods sind Nutzerangaben.
- „Content von 50“ ist nicht eindeutig: vor Anzeige nachfragen.
- Server-IP, Discord-Link, echte Personen, vorhandene UIDs und das Modpack-ZIP fehlen: Platzhalter bewusst stehen lassen.
- Die formulierten Serverregeln sind ausdrücklich **noch unbestätigte Vorschläge**.
- Das öffentliche Register enthält nur explizit freigegebene Profile; ein öffentliches Repository ist kein Ort für private Minecraft-UUIDs.

## Späterer Umzug auf Cloudflare

Sobald der zweite Cloudflare Free-Account nutzbar ist: In **Workers & Pages → Create application → Pages → Connect to Git** das bestehende GitHub-Repo auswählen. Framework `None`; Build-Command leer, Build-Output-Verzeichnis `.`; Branch `main`. Repo muss dazu nicht umgeschrieben werden. Cloudflare-Einstellungen und Free-Tier-Status vor Veröffentlichung prüfen.

## UID-Integration in Zukunft

Auf **GitHub Pages** kann keine sichere serverseitige UID-Erfassung laufen. Das beigefügte Node-Tool ist administrativ/offline. Wenn später *automatisch bei Minecraft-Join* vergeben werden soll, entwirf ein separates Forge-Servermod + authentifizierte Backend-Schnittstelle. Niemals API-Schlüssel in `assets/js/app.js` einbauen und niemals vom Besucherbrowser neue UIDs vergeben lassen. Vorher bitte um meine ausdrückliche Freigabe.

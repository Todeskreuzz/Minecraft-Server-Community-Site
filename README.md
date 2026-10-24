# Friends & Foes — Community-Forum

Neu: lokaler **Anonym**-Lesemodus ohne Konto/UID, automatische Browser-Sprachwahl (DE/EN) und geschützter Inhabername mit eigener Freundesfreigabe. Bestehende Installationen benötigen `supabase/002-identity.sql`; Anleitung und Prüfdatei unter [supabase/README.md](supabase/README.md). Ohne diese Erweiterung ist der Namensschutz in der Datenbank noch nicht eingerichtet.

Die aktuelle Startseite ist ein DE/EN-Forum mit Supabase-Anmeldung, Themen, Antworten und einem durch Datenbankregeln geschützten Adminbereich. Einrichtung: **[supabase/README.md](supabase/README.md)**. Zuerst `supabase/setup.sql`, dann `supabase/permission-tests.sql` im Supabase SQL Editor ausführen. Datenbank und echte Konten sind ohne diesen Schritt noch nicht einsatzbereit.

Frontend lokal: `python -m http.server 8018 --bind 127.0.0.1`. Tests: `node --test tests/forum.test.mjs tests/uid-manager.test.mjs`; Syntax: `node --check assets/js/forum.mjs`. Statische Strukturprüfung: `node scripts/check.mjs`.

Falix, reale Serveradresse und Modpack-Download sind noch nicht eingerichtet. Die alte Landingpage ist als `landing-archive.html` erhalten. Keine privilegierten Schlüssel gehören ins Repository. Die lokale Original-ZIP wird nicht mit veröffentlicht.

---

## Ursprüngliche Projektunterlagen (Landingpage und Offline-UID-Tool)

Eine eigenständige, responsive, **zweisprachige (DE/EN)** Minecraft-Webseite für **Minecraft Java 1.20.1 / Forge 47.4.10**. Sie ist für **GitHub Pages** gebaut und lässt sich anschließend ohne Framework auf **Cloudflare Pages** umziehen.

> **WICHTIG:** Das ist ein fertiges *statisches Webseitenprojekt*, kein Minecraft-Server. Keine Serveradresse, echten Personen, News, Discord-Links oder Modpack-Dateien wurden erfunden. Die dazugehörigen Funktionen zeigen ehrliche Platzhalter, bis du deine Daten einträgst.

## Die Funktionen

- Animierte Hero-Bühne, Laufband, feine Hover-Animationen; `prefers-reduced-motion` wird beachtet.
- Deutsch/Englisch-Schalter; Sprachwahl bleibt nur lokal im Browser gespeichert (kein Tracking).
- Eigener Modpack-Downloadbutton (erst aktiv, wenn eine gültige URL hinterlegt ist) und Forge/CurseForge-Anleitung.
- Optionaler Live-Status über die öffentliche [mcstatus.io API](https://mcstatus.io/docs) (nur nach Eintrag der echten Java-Serveradresse).
- Spielerzahl; optional Namen aus der vom Minecraft-Server selbst veröffentlichten *unvollständigen* Spieler-Stichprobe (`players.list`). Standardmäßig **deaktiviert**.
- Besonderes Rollen-Design für Owner, Admin und Moderatoren; Teamprofile nur bei Freigabe.
- UID-Design und **funktionierendes lokales UID-Vergabetool** mit chronologisch steigenden Zahlen, nicht erneut vergebenen IDs und Opt-in für öffentliche Profile.
- Dynamische News aus einer lokalen JSON-Datei, Entwurf für Serverregeln.
- Null externe Frontend-Frameworks, Fonts, Tracker oder kostenpflichtige Abhängigkeiten.

## Projektaufbau

```
index.html                    Startseite
assets/css/style.css          Design, Animationen, mobile Ansichten
assets/js/app.js              Sprachwechsel, Status, Rendern der Inhalte
assets/img/                  Vektorlogo/Favicon
assets/data/config.json       Minecraft-Version, Adresse, Modpack-URL usw.
assets/data/team.json         Öffentliche Teamprofile
assets/data/members.json      Freiwillig öffentliche UID-Profile (generiert)
assets/data/news.json         Zweisprachige News
assets/data/rules.json        Zweisprachige Regeln (derzeit ENTWURF)
scripts/uid-manager.mjs       Lokale UID-Zuteilung / Pflege / CSV-Import
scripts/check.mjs             Statische Prüfung ohne Abhängigkeiten
tests/uid-manager.test.mjs    Automatisierte UID-Tests
private/                     NICHT ÖFFENTLICH; Registry bleibt gitignoriert
CODEX-ANLEITUNG.md            Veröffentlichung und Arbeitsauftrag für Codex
```

## 1. Sofort lokal ansehen

HTML-Dateien wegen `fetch()` nicht einfach per `file://` starten, sonst blockieren Browser die lokalen JSON-Dateien.

```bash
# Im entpackten Projektordner
python -m http.server 8000
# Anschließend http://localhost:8000 öffnen
```

Alternativ kann Codex einen beliebigen lokalen Static-Server nutzen. Es ist keine Build-Phase nötig.

## 2. Einstellungen bearbeiten

Öffne `assets/data/config.json`:

| Feld | Bedeutung |
|---|---|
| `name`, `slogan` | Projektname und Leitspruch |
| `minecraftVersion`, `forgeVersion` | Derzeit 1.20.1 und 47.4.10 |
| `modCount` | Aktuell gemeldet: 39; vor Release aktualisieren |
| `server.address` | **Leer bis die echte IP/Domain bekannt ist**; beispielhaft Format `play.example.org:25565` (KEINE echte Adresse) |
| `server.showOnlineNames` | Standardmäßig `false` (Privatsphäre) |
| `server.refreshSeconds` | Polling, mindestens 60 Sekunden |
| `modpack.downloadUrl` | HTTPS-Link zum legal verteilbaren CurseForge-Export oder lokaler `./downloads/...zip`-Pfad |
| `modpack.version` | Eigene Versionskennung, z. B. `1.0.0` |
| `community.discordUrl` | Für eine spätere Discord-Einbindung reserviert; leer = keine verlinkte Community |

**Zur Angabe „Content von 50“:** Der genaue Inhalt dieser Angabe ist unklar; er ist in `contentCountNote` notiert, aber wird absichtlich noch nicht als erfundene Kennzahl auf der Webseite dargestellt.

### Live-Status und Spieleranzeige

- Sobald `server.address` gesetzt ist, ruft der Browser `https://api.mcstatus.io/v2/status/java/<adresse>` ab.
- Wenn keine Verbindung zustande kommt, kann das **Ruhezustand**, eine Firewall oder ein tatsächlicher Ausfall sein. Die Webseite kann das nicht unterscheiden.
- Bei Ausfall des Statusdienstes wird **„Status unbekannt“**, nicht irreführend „Server offline“, angezeigt.
- Der Dienst kann Angaben zwischenspeichern. `players.list` ist serverabhängig und keine vollständige Liste aller Online-Spieler.
- **Erst nach bewusster Entscheidung** `showOnlineNames` auf `true` setzen. Namen werden dann nur angezeigt, wenn der Server sie ohnehin in seiner öffentlichen Statusantwort preisgibt.
- Keine Live-Spielerdaten werden von dieser Webseite gespeichert. Ohne konfigurierten Server gibt es überhaupt keine Statusanfragen.

### Modpack richtig exportieren

In CurseForge dein Profil über **Share Profile → Export** als ZIP exportieren. Idealerweise enthält die ZIP `manifest.json` und `overrides/` mit den nötigen Konfigurationen. CurseForge lädt beim Import die referenzierten Mods. Sorge dafür, dass das Exportprofil mit Minecraft **1.20.1**, Forge **47.4.10** und der Servermod-Konfiguration kompatibel ist.

**Achtung Lizenzen:** Veröffentliche nicht ungeprüft die gesammelten `.jar`-Dateien. Nutze vorzugsweise den offiziellen CurseForge-Profil-Export und respektiere die Lizenzen einzelner Mods. Nicht jede Client-Mod gehört auf den Server und nicht jede Server-Mod auf die Clients. Manche Drittanbieter-Mods lassen sich ggf. nicht automatisch über ein Manifest installieren.

Für den Download gilt:
- HTTPS-Link unter `modpack.downloadUrl` eintragen (z. B. veröffentlichte CurseForge-Datei oder freigegebene Downloadseite).
- Für eine kleine eigene Datei ist optional `./downloads/DEINE_DATEI.zip` möglich; den Ordner musst du selbst hinzufügen.
- **Keine Modpack-ZIP ist derzeit enthalten**, weil dein Profil nicht übergeben wurde. Download-Button ist deshalb sicher deaktiviert.
- GitHub Pages ist **kein universeller großer Datei-Host**. Für größere Modpacks empfiehlt sich eine dafür geeignete externe Downloadquelle.

## 3. Team / News / Regeln

`assets/data/team.json` enthält ein Feld `team` mit freigegebenen Mitgliedern:

```json
{
  "team": [
    {"name": "DEIN_ECHTER_MINECRAFT_NAME", "role": "owner", "visible": true}
  ]
}
```

Erlaubte Rollen: `owner`, `admin`, `mod`, `member`. **Beispiel nicht unverändert veröffentlichen.** Verwende nur öffentlich freigegebene Namen. Optional ist im Teamprofil `uid` (Zahl) möglich; bevorzugt konsistent mit der UID-Registry.

`assets/data/news.json`:

```json
{
  "news": [
    {
      "date": "2026-11-01",
      "de": {"title": "TATSÄCHLICHE NEWS EINTRAGEN", "body": "Wirklichen Text eintragen."},
      "en": {"title": "ADD REAL NEWS", "body": "Enter the real message."}
    }
  ]
}
```

Nur eine Schema-Demo, **kein echtes Event** und nicht in der gelieferten Website eingetragen.

`assets/data/rules.json` enthält **fünf vorgeschlagene Regeln** (DE/EN). Die Website nennt sie ausdrücklich **Entwurf**. Sobald du sie kontrolliert und verbindlich beschlossen hast, setze `status` von `draft` auf `approved`. Erst dann verschwindet der Entwurfs-Hinweis.

## 4. UID-System: Frühere Spieler = kleinere UID

Ein reines GitHub-Pages-Projekt besitzt weder Datenbank noch Forge-Join-Hook. **Weder der Browser noch GitHub Pages können beim Minecraft-Join eine fälschungssichere persistente UID vergeben.** Deshalb enthält das Projekt ein reales **Offline-Administrationsskript**, das Codex ausführen kann.

### Grundprinzip

1. Jedem Spieler wird über seine stabile **Minecraft-UUID** genau eine eigene laufende Nummer zugeordnet.
2. Die Reihenfolge richtet sich beim Erstimport nach `firstSeen` (erstes Betreten / belegbarer Zeitstempel); niedrige UID = früher erfasst.
3. Einmal vergebene Nummern bleiben bestehen und werden **nicht erneut vergeben**, selbst wenn ein Spieler nicht mehr in der öffentlichen Liste steht.
4. Die Zuordnung `UUID ↔ UID` lebt **nur auf deinem Admin-PC** in `private/uid-registry.json`; `.gitignore` sperrt sie für das öffentliche Repo.
5. In `assets/data/members.json` landen nur Name, UID und Rang von Personen mit **expliziter Zustimmung** (`public:true`).
6. Die in der Webseiten-UID-Grafik sichtbare Folge `#000001 → #000002 → …` ist eine **illustrative Erklärung**, kein vergebener Account.

### Mit Node.js UIDs zuweisen

Node.js 20+ reicht; keine Pakete installieren:

```bash
# Neuen Spieler eintragen; ohne --public bleibt er verborgen
node scripts/uid-manager.mjs add --uuid UUID_AUS_DEM_SERVER --name ECHTER_NAME --joined 2026-10-24T18:00:00Z --role member

# Mit ausdrücklicher Erlaubnis im öffentlichen Register anzeigen
node scripts/uid-manager.mjs update --uuid UUID_AUS_DEM_SERVER --public

# Rolle ändern
node scripts/uid-manager.mjs update --uuid UUID_AUS_DEM_SERVER --role mod

# Einwilligung zurückziehen (UID bleibt intern reserviert)
node scripts/uid-manager.mjs update --uuid UUID_AUS_DEM_SERVER --private

# Öffentlichen Export neu erstellen
node scripts/uid-manager.mjs export

# Statistik ohne Veröffentlichung geheimer Zuordnungen
node scripts/uid-manager.mjs stats
```

Ersetze `UUID_AUS_DEM_SERVER`, `ECHTER_NAME` und Zeitstempel mit **echten Werten**. Erfinde keine Join-Zeiten. **Bevor du UIDs vergibst, importiere einmalig alle bisherigen Spieler chronologisch** (wenn deren echte Eintrittszeiten bekannt sind). Nachträglich gefundene ältere Spieler können nicht mehr kleinere UIDs bekommen, ohne bereits vergebene Nummern zu ändern; das Tool verhindert daher rückdatierte Vergaben.

Batch-Import via CSV (Spalten exakt `uuid,name,firstSeen,role,public`, `public` nur bei Einwilligung auf `true`):

```bash
node scripts/uid-manager.mjs import --file players.csv
```

Eine leere Kopfzeilen-Vorlage liegt unter `players.csv.example`.

**Vorsicht:** Die Datei `private/uid-registry.json` ist sensibel und gitignoriert. Sichere sie regelmäßig **privat/verschlüsselt** und teile sie nicht über ein öffentliches Repository. Auf mehreren PCs nicht gleichzeitig UIDs vergeben. Eine spätere vollautomatische Join-Vergabe erfordert eine Forge-Mod / Bridge plus vertrauenswürdiges Backend mit Datenbank und Authentifizierung; die statische Webseite allein kann das nicht leisten.

## 5. GitHub Pages

1. Ein **öffentliches** GitHub-Repository erstellen (GitHub Free veröffentlicht Pages aus öffentlichen Repositories).
2. Dieses Projekt **inhaltlich in das Repo-Root** kopieren. `index.html` muss direkt im Root liegen. `private/uid-registry.json` **niemals committen**.
3. `git add .`, `git commit`, `git push origin main` (Codex kann das für dich ausführen).
4. Auf GitHub **Settings → Pages → Build and deployment → Source: Deploy from a branch**, Branch `main`, Folder `/ (root)` auswählen.
5. Die Site wird unter `https://<dein-github-name>.github.io/<repository-name>/` veröffentlicht.
6. `assets/data/config.json` bearbeiten und erneut pushen, sobald echte Daten vorliegen. Keine Build-Commands und keine Frameworkinstallation nötig.

Links sind absichtlich **relativ**, daher funktioniert ein Repository-Unterpfad bei GitHub Pages.

## 6. Später Cloudflare Pages

- Dashboard des neuen Cloudflare-Accounts → **Workers & Pages → Create application → Pages → Connect to Git** → bestehendes Repo auswählen.
- Framework-Preset: **None** / kein Framework. Build Command leer lassen (oder gemäß Cloudflare-Anleitung `exit 0`), Build Output Directory: **`.`** (das Repository-Root).
- Production Branch `main`; deployen. Neue Änderungen via GitHub automatisch übernehmen.
- Erst nach erfolgreichem Test ggf. eine eigene Domain mit Cloudflare Pages verbinden. Github-Pages-Veröffentlichung später bei Bedarf abschalten, um doppelte öffentliche URLs zu vermeiden.
- Kein Workers-Skript, kein R2, keine D1-Datenbank und keine Zahlungsmethode für dieses reine statische Projekt nötig.

Cloudflare-Dokumentation: https://developers.cloudflare.com/pages/framework-guides/deploy-anything/ und https://developers.cloudflare.com/pages/get-started/git-integration/

## 7. Qualitätstests

```bash
node scripts/check.mjs
node --test tests/uid-manager.test.mjs
node --check assets/js/app.js
```

Optional kann Codex mit Browser-Tests mobile Ansichten (360px, 768px, 1440px) und den DE/EN-Schalter kontrollieren.

## 8. Datenschutz / Betrieb

- Alle Dateien in einem **öffentlichen** GitHub-Repository sind einsehbar, auch entfernte Dateien in der Commit-Historie. Nie Tokens, Passwörter, private IP-Adressen, echte UUID-Registry oder nicht freigegebene Spielernamen committen.
- `localStorage` wird nur für deine Spracheinstellung verwendet. Kein eigener Cookie-Banner nötig, solange keine weiteren Tracker/Analytics eingebaut werden (rechtlich bitte selbst prüfen).
- Die Statusfunktion kontaktiert nach Konfiguration die Drittanbieter-Domain `api.mcstatus.io` aus dem **Browser deiner Besucher**. Erwähne dies in einer passenden Datenschutzerklärung, bevor der Status aktiviert wird.
- Das öffentliche UID-Profil ist ein separates freiwilliges Feature. Die Community-Anmeldung und Minecraft-Registrierung erfolgen **nicht** über die statische Webseite.
- Es ist ein unabhängiges Fanprojekt und nicht von Mojang/Microsoft autorisiert.
- „Co. KG“ wurde als gewünschter Projektname übernommen; prüfe vor offizieller Verwendung, ob die Firmierung rechtlich zutreffend ist.

## Weiterentwicklung

Für *echte automatische UID-Vergabe beim ersten Join* ist später eine Forge-seitige Integration empfehlenswert, z. B. ein kleines serverseitiges Mod, das beim ersten Join die UUID mit dem echten Zeitstempel in einer kontrollierten Datenbank erfasst. Erst nach deiner Freigabe dürfen diese Daten als öffentliche UID-Karten auf der Webseite erscheinen. Das ist eine eigene Ausbaustufe und **keine vorhandene Funktion des statischen GitHub-Pages-Projekts**.

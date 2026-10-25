# Automatischer Betrieb ohne geöffneten Codex-Chat

## Was automatisch läuft

Nach jedem Push in main: JavaScript- und UID-Tests → Migrationen und Rechteprüfungen in einer isolierten Testdatenbank → ausstehende Migrationen im fest zugeordneten Supabase-Projekt → Veröffentlichung bei GitHub Pages. Pull Requests testen ausschließlich isoliert ohne Produktionszugang. Die Pipeline läuft auf GitHub, nicht auf deinem PC und nicht in diesem Chat.

Anmeldung, Beiträge, Antworten, Notizen und Freundesfreigaben laufen regulär über Website und Supabase. Die Pipeline erfindet keine Funktionen und entscheidet nicht, wer dein Freund oder Administrator ist. Es wird kein KI-Agent dauerhaft gestartet.

## Einmalige Freischaltung

Im Repository Todeskreuzz/Minecraft-Server-Community-Site:

1. Settings → Secrets and variables → Actions → New repository secret:
   - SUPABASE_DB_PASSWORD: Datenbankpasswort dieses Projekts.
2. Settings → Pages → Source: **GitHub Actions**. Noch aktive Veröffentlichung direkt aus dem Branch auf Actions umstellen, damit sie die Datenbankprüfungen nicht umgeht.
3. Actions → **Test, migrate and publish** → Run workflow → main.

Zugangsdaten direkt in die geschützten GitHub-Secret-Felder eingeben, niemals in Chat, Dateien oder Commits. Der öffentliche Publishable Key reicht nicht. Der Workflow verbindet sich direkt mit dem verifizierten Session-Pooler über das Datenbankpasswort. Es wird kein Personal Access Token erzeugt, gespeichert oder zum Lesen von API-Key-Secrets berechtigt. Ohne dieses Datenbank-Secret bleibt der Produktionsschritt gesperrt. Keine kostenpflichtigen Zusatzprodukte aktivieren.

Freigabe für diesen dauerhaften Produktionszugriff wurde vom Nutzer am 24.10.2026 ausdrücklich erteilt. Umfang: dieses Repository, das Supabase-Projekt iewltgawdodbmwcdgzxy und dessen Website. Wer main ändern kann, kann über den Workflow Datenbankänderungen ausführen; Repository-Zugriff entsprechend begrenzen.

## Bestehende Daten und neue Änderungen

Die erste versionierte Migration übernimmt das bekannte, zuvor per setup.sql angelegte Schema ohne beabsichtigte Löschung vorhandener Profile, Beiträge, Notizen oder Adminzuweisungen. Seeds überspringen vorhandene Einträge. Eine abweichende bestehende Struktur muss zuerst geprüft werden. Kein Produktionsreset und keine automatische Reparatur der Migrationshistorie.

Die zweite Migration enthält Namensschutz und Freundesregeln. Falls sie schon manuell ausgeführt wurde, darf sie erneut angewendet werden. Supabase protokolliert angewendete Migrationen und überspringt sie bei späteren Deployments.

Die Funktion `supabase/functions/turnstile-post` prüft Beitrags-Captchas. Sie liest das Geheimnis nur über `private.get_turnstile_secret()`, das ausschließlich `service_role` ausführen darf. Der Name im Vault bleibt `turnstile_secret_key`. Actions hat dafür keinen Management-Token, deshalb wird die Funktion getrennt vom Seiten-Deploy bereitgestellt. Der Klartext kommt nicht ins Repository.

Neue Änderungen nur als neue versionierte SQL-Datei in supabase/migrations/ hinzufügen. Bereits angewendete Migrationen nicht umschreiben. Die alten setup.sql/002-identity.sql bleiben historische Einrichtungsunterlagen; nach Aktivierung nicht mehr parallel im SQL Editor am Schema arbeiten.

## Fehler und Rückweg

Bei fehlgeschlagenen Tests oder Migrationen wird die neue Website nicht veröffentlicht. Actions zeigt den fehlgeschlagenen Lauf; Benachrichtigungen hängen von deinen GitHub-Einstellungen ab. Produktionsläufe arbeiten nacheinander. Wiederholung wendet nur ausstehende Migrationen an.

Kein automatisches Datenbank-Rollback, das neue Beiträge vernichten könnte. Fehlerhafte Schemaänderungen durch eine neue korrigierende Migration beheben. Die bisherigen Migrationen entfernen keine Tabellen/Spalten; ein Frontend-Rollback kann per Git-Revert mit neuem Deployment erfolgen.

Der Pages-Ordner enthält nur index.html, .nojekyll und assets/. Lokale ZIPs, private/, SQL, Tests, Vorschaubilder und Zugangsdaten werden nicht ausgeliefert.

## Grenzen und Prüfstatus

Free-Tarife behalten ihre Limits; Supabase kann bei geringer Aktivität pausieren. Kein Ablauf garantiert unbegrenzte oder dauerhafte Verfügbarkeit. Falix ist ein separater Minecraft-Hoster und wird von diesem Deployment nicht als 24/7-Server eingerichtet.

Der erste GitHub-Verify-Lauf war erfolgreich, einschließlich realer PostgreSQL-Rechteprüfungen und beider bisherigen Einrichtungswege. Ein erfolgreicher Produktionslauf ist erst nach der Datenbankverbindung nachgewiesen. Auf diesem PC ist kein Docker vorhanden; echte PostgreSQL-Integrationstests laufen auf dem GitHub-Runner.

Grundlagen: [Supabase CI/CD](https://supabase.com/docs/guides/deployment/managing-environments), [Supabase Migrationen](https://supabase.com/docs/guides/deployment/database-migrations), [GitHub Pages Workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

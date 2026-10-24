# Forum einrichten (Supabase Free + GitHub Pages)

Der öffentliche Publishable Key ist in `assets/data/supabase.json` hinterlegt. Er ist kein Administratorschlüssel. Alle echten Zugriffsrechte liegen in PostgreSQL/RLS.

## 1. Datenbank

Supabase → SQL Editor → New query: den gesamten Inhalt von `setup.sql` einfügen und einmal ausführen. Die Datei ist für ein noch nicht eingerichtetes Forum gedacht. Keine vorhandenen Tabellen löschen, um sie erneut auszuführen; bei Fehlern zuerst die Meldung prüfen. Die Transaktion verhindert eine halb ausgeführte Einrichtung.

Anschließend `permission-tests.sql` im SQL Editor ausführen. Die Testdaten werden durch ROLLBACK verworfen. Erwartet: `Forum permission tests passed`.

## 2. Anmeldung

Authentication → Providers: Email aktivieren, E-Mail-Bestätigung eingeschaltet lassen.

Authentication → URL Configuration:
- Site URL: `https://todeskreuzz.github.io/Minecraft-Server-Community-Site/`
- Für lokale Tests zusätzlich erlaubte Redirect URL: `http://127.0.0.1:8018/`
- Beim späteren Cloudflare-Umzug die tatsächliche neue Website-URL ergänzen und als Site URL setzen.

Unter Authentication den für dein Projekt geltenden E-Mail-Versand prüfen. Supabases eingebauter Test-Maildienst kann Empfänger beschränken; eine öffentliche Registrierung mit Bestätigung benötigt gegebenenfalls einen eigenen SMTP-Anbieter. Nicht als funktionierend betrachten, bevor eine Registrierung mit einem zweiten freigegebenen Testkonto bestätigt wurde. Kein kostenpflichtiger SMTP-Dienst wird automatisch aktiviert.

## 3. Dein Administratorkonto

Registriere dich über die Website und bestätige die E-Mail. Danach im SQL Editor folgende Abfrage mit DEINER E-Mail ausführen:

```sql
insert into private.forum_admins(user_id)
select id from auth.users where email = 'DEINE_EIGENE_EMAIL'
on conflict do nothing;
```

Die Meldung muss eine eingefügte Zeile zeigen (oder das Konto war schon Admin). Anschließend Website neu laden. Der Admin-Tab erscheint. Niemand bekommt automatisch Adminrechte, auch nicht der zuerst registrierte Nutzer. Mitglieder können keine Adminrechte oder fremde Autoren setzen. Ein direkt aufgerufenes `#admin` gewährt keine Datenrechte.

## 4. Minecraft / Falix / Modpack

Falix ist noch nicht eingerichtet. In `assets/data/config.json` später echte Serveradresse und den freigegebenen Modpack-Link ergänzen. Die übernommenen Profilangaben 47.4.10 / 39 Mods wurden absichtlich nicht als Serverinventar ersetzt: Das Spielerprofil kann vom Serverbestand abweichen. Vor Freigabe das echte Clientprofil abgleichen.

Am besten einen CurseForge-Profil-Export zum Download anbieten; Moddateien nur mit passenden Verteilungsrechten direkt veröffentlichen. Öffentliche Minecraft-Statusabfragen nutzen mcstatus.io. Interne CPU-, RAM-, Konsolen- und Backupdaten sind noch nicht mit Falix verbunden; der Adminbereich enthält geschützte Notizen und einen Link zum Falix-Panel. Keine API-Schlüssel in die Notizen schreiben.

## 5. GitHub Pages

Repository → Settings → Pages → Deploy from a branch → main → /(root).
Das Frontend benötigt keinen Build und funktioniert auch in einem Repository-Unterpfad.

## Prüfstatus und Grenzen

- Lokale API-/Validierungstests und Browserprüfungen sind unabhängig vom SQL-Setup möglich.
- Auth-/Datenbanktests mit echten verschiedenen Konten erst nach SQL-Ausführung und Mailkonfiguration möglich.
- SQL-Permission-Tests müssen in deinem Supabase-Projekt ausgeführt werden; ein Publishable Key erlaubt keine Schemaänderungen.
- Beiträge sind öffentlich, E-Mail-Adressen und Ownernotizen nicht. Anzeigenamen sind nicht eindeutig und belegen keine Minecraft-Identität.
- Sitzung liegt im sessionStorage dieses Browser-Tabs, Sprachwahl im localStorage. Browserdaten löschen/Abmelden beendet die lokale Sitzung.
- Free-Tarife haben Limits; Supabase kann bei geringer Aktivität pausieren. Keine 24/7-Garantie.
- Vor öffentlichem Betrieb Betreiber-/Kontaktdaten, Löschverfahren und passende Datenschutzhinweise ergänzen. Die Datenschutzauskunft in der Vorschau ist noch kein vollständig ausgefüllter Betreibertext.
- Löschung von Konten derzeit durch den Betreiber in Supabase Auth; zugehörige Beiträge werden kaskadierend gelöscht.
- Eigene Profilbearbeitung, Passwort-Reset-Oberfläche, Anhänge und Minecraft-Join-UID-Integration sind nicht Teil dieser ersten Forumsfassung. UID-Tool unverändert offline nutzbar.

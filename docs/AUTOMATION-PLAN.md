# Dauerhafter automatischer Deployment-Ablauf — zur Freigabe

Status: Nutzer hat den dauerhaften Ablauf am 24.10.2026 ausdrücklich freigegeben. Workflow und Migrationen sind im Repository; der erste isolierte Testlauf ist erfolgreich. Produktionsverbindung wird eingerichtet.

## Ziel und Umfang

Die Website und Supabase sollen unabhängig von einem geöffneten Codex-Chat funktionieren. Nach Änderungen in main des Repositories Todeskreuzz/Minecraft-Server-Community-Site soll GitHub Actions Tests ausführen, ausstehende SQL-Migrationen in genau dem Supabase-Projekt iewltgawdodbmwcdgzxy anwenden und erst danach die statische Website bei GitHub Pages veröffentlichen. Pull Requests bekommen keine Produktionszugangsdaten.

Das ist ein dauerhafter Deployment-Ablauf, kein KI-Agent, der unbeaufsichtigt Funktionen erfindet oder Freundschaften/Adminrechte entscheidet. Bestehende Website-Funktionen verarbeiten ihre Daten selbstständig über Supabase.

## Erforderliche Freigabe

- GitHub Actions darf dauerhaft bei Push auf main und bei manuellem Start laufen.
- GitHub Actions darf das für dieses Supabase-Projekt hinterlegte Datenbankpasswort aus GitHub Actions Secrets verwenden.
- Der Ablauf darf damit ausstehende Migrationen auf die Produktionsdatenbank anwenden und die öffentliche Website deployen.
- Nur dieses Repository und das genannte Supabase-Projekt gehören zum Auftrag.

Risiko: Wer Code in main ändern kann, kann über den Workflow Änderungen mit den gespeicherten Produktionsrechten ausführen. Fehlerhafte Migrationen können den Betrieb oder Daten beeinträchtigen. Tests und Transaktionen verringern dieses Risiko, ersetzen aber keine Zugriffskontrolle und Datensicherung.

Keine Zugangsdaten in Chat oder Quellcode. Einmaliges Hinterlegen der Verbindung und Aktivieren von Pages/Actions bleiben notwendig. Der öffentliche Publishable Key ist keine ausreichende Maschinenberechtigung.

## Vorbereitete Dateien

- supabase/migrations/20261024000100_forum.sql: Übernahme des bekannten bestehenden Schemas ohne beabsichtigte Löschung von Daten. Seed-Einträge überspringen vorhandene Datensätze.
- supabase/migrations/20261024000200_identity.sql: Namensschutz/Freundschaften; wiederholbar wie die vorbereitete manuelle Erweiterung.

Noch zu tun nach Freigabe: Workflow erstellen, migrationsbezogene PostgreSQL-Integrationstests in einer isolierten Testdatenbank ausführen, einmalige Secrets/Pages-Verbindung herstellen und ersten erfolgreichen Lauf nachweisen. Kein Produktionsreset oder automatische Reparatur der Migrationshistorie.

## Betrieb und Rückweg

Nur ausstehende, versionierte Migrationen anwenden; Produktionsläufe nacheinander. Bei Test- oder Migrationsfehlern Veröffentlichung stoppen. Keine automatischen Datenbank-Rollbacks, die neue Beiträge löschen könnten: Fehler durch eine neue korrigierende Migration beheben. Website-Versionen per Git-Revert zurücknehmen.

Free-Tarife behalten ihre Anbieterlimits. Der Ablauf garantiert keine unbegrenzte oder dauerhafte Verfügbarkeit.

Grundlagen: https://supabase.com/docs/guides/deployment/managing-environments und https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages

## Vereinfachte Verbindung

Die endgültige Variante nutzt ausschließlich das bereits hinterlegte Datenbankpasswort und die im Supabase-Connect-Dialog bestätigte Session-Pooler-Adresse. Kein Personal Access Token und kein Zugriff auf API-Key-Secrets sind erforderlich.

# Friends & Foes Bridge auf Falix

Die Website legt Spielergruppen an. Ein kleines Forge-Mod auf dem Server liest die Warteschlange und setzt dafür Vanilla-Scoreboard-Teams. TAB zeigt das Präfix. Der geheime Brückenschlüssel steht nur in der Server-Konfiguration und in der Datenbank, nie im Repository.

## 1. Schlüssel in Supabase setzen

Im SQL-Editor des Projekts, als Datenbank-Inhaber:

```sql
select private.set_bridge_secret('hier-ein-eigenes-geheimnis-mit-mindestens-24-zeichen');
```

Den Klartext danach nur auf den Minecraft-Server kopieren. Nicht in Git, nicht in den Chat, nicht in `config.json`.

## 2. Mod bauen

Voraussetzungen auf dem eigenen Rechner: Java 17 und der Quellordner `minecraft-bridge/`.

```bash
cd minecraft-bridge
chmod +x gradlew || true
gradle wrapper --gradle-version 8.8
./gradlew build
```

Die JAR liegt danach unter `minecraft-bridge/build/libs/`. Sie heißt `friendsfoes-bridge-1.0.0.jar`. Forge 1.20.1 / 47.4.10 ist die Zielversion, passend zum bestehenden Modpack.

Wenn der Build lokal nicht möglich ist, bleiben Website, Warteschlange und der Quelltext trotzdem gültig. Die JAR kann später nachgezogen werden.

## 3. Auf Falix installieren

1. Die JAR in den Ordner `mods/` des Forge-Servers legen, neben TAB, JourneyMap, Create und AE2.
2. Server einmal starten und wieder stoppen, damit `config/friendsfoes-bridge.properties` entsteht.
3. Die Datei füllen:

```properties
supabaseUrl=https://iewltgawdodbmwcdgzxy.supabase.co
publishableKey=HIER_DEN_OEFFENTLICHEN_SCHLUESSEL_AUS_assets/data/supabase.json
bridgeSecret=HIER_DASSELBE_GEHEIMNIS_WIE_IN_SQL
```

4. In der Falix-Oberfläche den automatischen Neustart einschalten. Die Brücke stoppt den Server nicht von selbst. Sie setzt nur Teams. Ein geplanter Modpack-Neustart später braucht denselben automatischen Neustart, sonst bleibt der Server nach einem Stopp aus.
5. Server starten. In der Konsole erscheint alle 30 Sekunden höchstens ein kurzer Abruf. Ohne Schlüssel bleibt die Brücke still.

## 4. Spieler verknüpfen

Auf der Website im eigenen Profil den Minecraft-Namen eintragen, speichern und „Verknüpfungscode“ wählen. Im Spiel innerhalb von 15 Minuten:

```text
/ff link CODE
```

Der Server bestätigt den Namen. Erst danach trägt die Brücke die Person in das Scoreboard-Team ein. Der Befehl funktioniert nur, wenn das Mod geladen ist.

## 5. Was die Warteschlange tut

| Auftrag | Befehl auf dem Server |
| --- | --- |
| Gruppe anlegen | `/team add TAG`, Farbe und Präfix `[TAG]` |
| Mitglied dazu | `/team join TAG Spieler` |
| Mitglied entfernen | `/team leave Spieler` |
| Gruppe löschen | `/team remove TAG` |

Es gibt kein Teams- oder Claims-Mod. Die Präfixe laufen über die vorhandenen Vanilla-Teams, die TAB bereits anzeigt.

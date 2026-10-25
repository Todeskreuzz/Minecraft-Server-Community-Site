# Serverbeitritt und Community – 25.10.2026

## Datenbasis

Implementiert auf dem GitHub-Stand ef6f90bf01c3daa7cc64e68eacbd1045663e28d5. Die bisherige lokale Kopie wurde nicht über neuere Repository-Dateien kopiert. Isolierter Checkout im lokalen Projekt unter private/implementation; dieselbe Repository-URL, keine anderen Repositories.

Der vom Nutzer bereitgestellte CurseForge-Export wurde unverändert lokal im übergeordneten private/-Ordner gesichert. SHA-256: bf419ffb9e2048ed4baac6a31cef9b53c404313c70d65e55a32fb1b6d8e7a352. Er enthält 39 Mods, 7 Shader und 4 Ressourcenpakete für Minecraft 1.20.1, Forge 47.4.10.

Öffentlicher Import: assets/downloads/friends-and-foes.zip, nur Manifest, Modliste und Text-Konfigurationen. Kein Mod-JAR wird kopiert. ColoredSigns.jar ist anhand von plugin.yml als Bukkit-Plugin erkannt und deshalb für Forge ungeeignet. Es bleibt im Original erhalten, wird aber nicht öffentlich weiterverteilt. Cape-/Ohren-Caches und eine Shader-Hinweisdatei werden ebenfalls ausgelassen. Die Oberfläche und modpack.json dokumentieren das ausdrücklich. Keine Welt wird übernommen; der Nutzer wünscht eine neue Welt.

Die Modseiten verlinken die exakten CurseForge-Datei-IDs aus dem Export. Wenn ein offizieller Versionsname nicht abrufbar war, wird die eindeutige Dateinummer angezeigt. Keine automatische Auswahl von „Latest“. Öffentliche Projektseiten sind die Quellen der redaktionell gekürzten Beschreibungen. Eine Kennzeichnung „Client und Server“ bedeutet Eignung, nicht zwingend erforderliche Installation auf beiden Seiten. Vor dem Serverstart Abhängigkeiten und Falix-Free-Einschränkungen prüfen; JourneyMap nicht ungeprüft serverseitig installieren.

## Verhalten und Schnittstellen

- #server: vier Schritte, Launcherwahl, Packdownload, Modsuche; #mod/<kennung>: Details mit Rücknavigation.
- #profile/edit: ausschließlich eigenes Profil; ungespeicherte Änderungen werden beim Verlassen erkannt. Medienrechte und Namensschutz bleiben bei den bestehenden Funktionen.
- forum_follows(follower_id, followed_id, created_at): öffentliche Folgebeziehungen mit Primärschlüssel und Fremdschlüsseln. forum_follow_stats(p_id): öffentliche Anzahl und eigener Folgestatus. Kein Einfluss auf Freundschaften oder private Inhabernamen.
- Anonym: ausschließlich sessionStorage, kein Auth-Aufruf, kein Konto/UID, keine Schreibrechte. Alte anonyme Auth-Sitzungen werden clientseitig verworfen; bestehende Daten werden nicht gelöscht.

## Optionaler Windows-Direktstart

Die Download-ZIP enthält eine kleine native Windows-Anwendung, ihren C#-Quellcode, dessen SHA-256 und eine Entfernungshilfe. Sie wird mit dem vorhandenen .NET-Framework-Compiler gebaut; es gibt keine neue Laufzeitabhängigkeit oder PowerShell-Ausführungsrichtlinienänderung. Das ist eine bewusste Anpassung gegenüber dem ersten Skriptentwurf: heruntergeladene PowerShell-Dateien können unter RemoteSigned nicht ohne zusätzliche Freigabe ausgeführt werden.

Der Nutzer importiert das Pack in Prism, entpackt die Einrichtung und führt Setup-FriendsAndFoes.exe bewusst selbst aus. Die Einrichtung fragt nach Prism und dem Instanzordner, prüft die Minecraft-/Forge-Komponenten in mmc-pack.json sowie die feste öffentliche Serveradresse und registriert nur HKCU/Software/Classes/friendsandfoes. Lokale Einstellungen liegen unter LocalAppData/FriendsAndFoes. Kein Administratorzugriff, keine Änderung von Sicherheitsrichtlinien, kein automatischer Download einer Launcher-EXE. Bei einer Windows-Schutzabfrage entscheidet der Nutzer; die Website umgeht sie nicht.

Der URI friendsandfoes://join enthält keine Parameter. Alle anderen URI-Aktionen und Zusatzparameter werden abgewiesen. Die Anwendung startet die ausgewählte Prism-EXE ohne Shell, mit korrekt quotierten --dir-, --launch- und --server-Argumenten. Sie prüft auch beim Start, dass Instanz und Versionsmetadaten noch vorhanden sind. Der lokale --self-test prüft URI, Server/Port, Windows-Argumentquotierung sowie passende, falsche und fehlende Instanzmetadaten ohne Registry-Zugriff oder Minecraft-Start. Er wurde unabhängig mit Exitcode 0 ausgeführt.

Die Seite kann einen erfolgreichen Spielstart nicht beweisen und bietet immer eine manuelle Verbindung. Uninstall.cmd entfernt nach bewusster Bestätigung die eigene Protokollregistrierung und Einstellungen. Die laufende EXE bleibt wegen der Windows-Dateisperre als inaktive Datei zurück und kann danach regulär gelöscht werden.

## Tatsächliche Servereinrichtung

Falix-Server 3540910, öffentliche Adresse friends-foes.falixsrv.me, interner Anschluss eu13-free.falixserver.net:28533. Free, Europa/Deutschland, 3072 MB RAM, fünf Plätze, Survival, Normal, Online-Mode aktiviert. Neue Welt; keine bestehende Welt wurde übertragen. Sichtweite 6, Simulationsdistanz 4.

Falix installierte Minecraft 1.20.1 mit Forge 47.4.28. Die Client-Version bleibt wie im Export Forge 47.4.10 und wird auf der Website ausdrücklich als Modpack-Version bezeichnet. Alle 39 gepinnten JARs wurden privat über das von CurseForge verlinkte CurseMaven-Repository heruntergeladen und anhand ihrer Mod-Metadaten geprüft. SHA-256 und interne Modversionen stehen im Katalog; die JARs werden nicht öffentlich verteilt. Der private Serverimport enthält 20 serverseitige Mods/Bibliotheken plus Text-Konfigurationen. Die restlichen Client-Funktionen bleiben im Spieler-Modpack; JourneyMap wird entsprechend der Falix-Free-Einschränkung nicht serverseitig installiert. Create liefert Ponder, Flywheel und Registrate bereits als eingebettete Abhängigkeiten mit.

Erster Start nach Import: Done (82.548s), neue Welt erzeugt, Server-Port geöffnet. Bekannte nicht startverhindernde Meldungen: vier Create-Kompatibilitätsrezepte verweisen auf in der gepinnten älteren Biomes-O’-Plenty-Version fehlende Pflanzen; außerdem eine abgefangene clientseitige Mixin-Klassenwarnung. Keine Mods wurden dafür stillschweigend aktualisiert. Echter Spielerbeitritt anschließend im Serverlog durch Login und „joined the game“ bestätigt; der Nutzer meldete die neue Welt. Browser-Prism-Start bleibt separat offen, da Prism auf diesem Gerät noch nicht eingerichtet wurde.

## Freigabe und Rollout

Der Nutzer hat Umsetzung, Falix Free mit neuer Welt, freie Launcherwahl, optionalen Prism-Windows-Direktstart sowie öffentliche Follower bestätigt. Bestehende Freigabe für automatische Migrationen und Veröffentlichung gilt weiterhin nur für dieses Repository und das zugeordnete Supabase-Projekt. Migration 013 ist additiv; bestehende Migrationen werden nicht umgeschrieben.

Falix-Zugang und eventuelle Vertrags-/EULA-Bestätigungen erfolgen durch den Nutzer. Kein kostenpflichtiges Angebot aktivieren. Tatsächlichen Serverstart und Clientbeitritt erst nach Prüfung behaupten. Prüfstatus und noch fehlende Schritte werden im Abschlussbericht getrennt angegeben.

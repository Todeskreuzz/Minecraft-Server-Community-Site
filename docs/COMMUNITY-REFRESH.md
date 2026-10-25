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

Die Download-ZIP enthält lesbare Installations-, Start- und Entfernungsskripte. Der Nutzer importiert das Pack in Prism, entpackt die Einrichtung und führt Setup.cmd bewusst selbst aus. Die Einrichtung fragt nach Prism und dem Instanzordner, prüft die feste öffentliche Serveradresse und registriert nur HKCU/Software/Classes/friendsandfoes. Lokale Einstellungen liegen unter LocalAppData/FriendsAndFoes. Kein Administratorzugriff, keine Änderung der PowerShell-Ausführungsrichtlinie und kein automatischer Download/Start einer fremden EXE.

Der URI friendsandfoes://join enthält keine Parameter. Alle anderen Aktionen, Zusatzparameter und unbekannten Pfade werden abgewiesen. Prism erhält getrennte Argumente --dir, --launch und --server. Die Seite kann weder den installierten Handler noch einen erfolgreichen Spielstart beweisen und bietet immer eine manuelle Verbindung. Bei von Windows blockierten unsignierten Skripten die manuelle Verbindung verwenden. Die Entfernung löscht nur die eigene Registrierung und drei eigene Dateien.

## Freigabe und Rollout

Der Nutzer hat Umsetzung, Falix Free mit neuer Welt, freie Launcherwahl, optionalen Prism-Windows-Direktstart sowie öffentliche Follower bestätigt. Bestehende Freigabe für automatische Migrationen und Veröffentlichung gilt weiterhin nur für dieses Repository und das zugeordnete Supabase-Projekt. Migration 013 ist additiv; bestehende Migrationen werden nicht umgeschrieben.

Falix-Zugang und eventuelle Vertrags-/EULA-Bestätigungen erfolgen durch den Nutzer. Kein kostenpflichtiges Angebot aktivieren. Tatsächlichen Serverstart und Clientbeitritt erst nach Prüfung behaupten. Prüfstatus und noch fehlende Schritte werden im Abschlussbericht getrennt angegeben.

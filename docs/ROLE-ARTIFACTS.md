# Magische Rollenartefakte

Umgesetzt nach dem freigegebenen Design: Inhaber als smaragdgrünes Runensiegel mit Krone und umlaufenden Energiepunkten, Day One als Amethystrelikt mit Sternenorbits und Konstellation, Admin als facettierter Energiekristall, Moderator als bewegte Schildbarriere. Beschriftungen bewegen sich nicht. Mitglied bleibt neutral. Rollenrechte, Namensschutz und Datenbank wurden nicht geändert.

`rankBadge()` verwendet überall denselben SVG-Renderer. Drei dekorative Ebenen pro besonderem Tag, maximal vier Lichtpunkte einschließlich Hauptstern, keine externen Assets oder Bibliotheken. Kompakt 22 px, Profil 30 px; mobile Ansichten reduzieren Partikel. Light/Dark und DE/EN verwenden dieselben Komponenten.

Rolleneffekte lassen sich über das Sternsymbol in der bestehenden Navigation pausieren. Die Einstellung wird als `faf-role-effects` pro Browser gespeichert und zwischen offenen Tabs synchronisiert. `prefers-reduced-motion` hat Vorrang. Ein gemeinsamer IntersectionObserver pausiert unsichtbare Tags; VisibilityChange pausiert ausgeblendete Dokumente. Entfernte Tags werden nicht im Observer gehalten. Autorenlinks behalten ihre vorhandenen Tabstopps; Tastaturfokus aktiviert über den gemeinsamen Person-Container dieselben Hervorhebungen wie Hover.

## Validierung

- Node-Tests: unterschiedliche SVGs, sichere Textbeschriftung ohne zusätzliche Tabstopps, bevorzugte reduzierte Bewegung, manuelle Pause, Speicherung, Sichtbarkeit und Entfernen von Tags.
- Lokale private Vergleichsansicht mit allen Rollen, Profil-/Kompaktgröße und einer Liste aus 50 Tags. Sie ist nicht Teil des Pages-Artefakts.
- Desktop 1280 px und echte eingebettete 390-px-Viewports: keine sichtbaren Tagüberlappungen; Profil, Hell/Dunkel und englische Beschriftungen kontrolliert.
- Pause im Browser ausgeführt, alle Animationen pausiert; nach Reload weiterhin ausgeschaltet. Tastaturfokus am Autorenlink aktiviert Kronenbewegung und Zusatzorbit. Tags außerhalb des Viewports pausiert.
- Fünf Sekunden instrumentierte Messung bei unveränderter Ansicht: 817 Frames, mittlerer Abstand 6,13 ms, 0 Long Animation Frames, 0 Layout Shift. Das ist eine lokale Stichprobe über Browser-PerformanceObserver und requestAnimationFrame, keine Garantie für andere Geräte und kein vollständiger GPU-/DevTools-Trace. Animiert werden Transform, Opacity und kleine SVG-Strichkonturen, keine Layoutgrößen oder großen Filterflächen.
- Reduzierte Bewegung ist durch Controller-Tests und CSS-Regelprüfung abgedeckt; die Betriebssystemeinstellung wurde auf dem Nutzer-PC nicht umgeschaltet.
- Unabhängiges Review: Tastaturfokus bei nebeneinanderliegenden Autorenlinks/Tags und eine alte Rollenanzeige korrigiert. Eigenständige lokale Profilansicht ohne Browserfehler; Inhaber- und Day-One-Tags animieren.

Die vorhandene Test-/Migrations-/Pages-Pipeline bleibt der Veröffentlichungsweg. Keine neue Migration erforderlich.

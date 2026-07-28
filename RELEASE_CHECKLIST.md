# Release-Checkliste

KeystoneWheel wird in Testphasen ausschließlich lokal weiterentwickelt. Kleine
Korrekturen werden gesammelt und nicht einzeln zu GitHub gepusht oder als
Release veröffentlicht.

## 1. Änderungen sammeln

- Gewünschte Korrekturen lokal umsetzen.
- Noch keine Versionsnummer erhöhen und keinen Tag erstellen.
- Nach jeder relevanten Änderung `/reload` ausführen.
- Weitere kurzfristige Rückmeldungen in denselben lokalen Teststand aufnehmen.

## 2. Release Candidate testen

- `powershell -ExecutionPolicy Bypass -File .\tools\Test-Release.ps1` ausführen.
- Das Addon mit deaktivierten und mit den üblichen Raid-Addons laden.
- Fenster, Minimap-Button und gespeicherte Einstellungen nach einem Neustart prüfen.
- Eigener Schlüssel, LibKeystone, Chat-Fallback und manueller Eintrag prüfen.
- Ignorieren und erneutes Aktivieren einzelner Schlüssel prüfen.
- Drehung, Animation, Sound und Ergebnisnachricht prüfen.
- Synchronisierte Auswahl mit mindestens einem weiteren Addon-Nutzer prüfen.
- Übereinstimmenden und absichtlich abweichenden Pool-Sync mit mindestens zwei
  Addon-Nutzern prüfen.
- Wiederholungsschutz bis zum automatischen Start einer neuen Runde prüfen.
- Ergebnisverlauf und beide Möglichkeiten zum Zurücksetzen prüfen.
- Drehberechtigung als Gruppenmitglied, Gruppenleitung und Raid-Assistenz prüfen.
- Schicksalssperre, Abstimmungsmehrheit und Ablauf ohne Mehrheit prüfen.
- Normale und reduzierte Animation sowie mehrere UI-Skalierungen prüfen.
- Deutsche und englische Oberfläche inklusive Tooltips, Chatmeldungen,
  Abstimmungsdialog und Debug-Bericht prüfen.
- Minimap-Button und Blizzard-Addonfach jeweils per Links- und Rechtsklick prüfen.
- Port-Button, Cooldown und Verhalten im Kampf prüfen.
- Darstellung mit unterschiedlich vielen Schlüsseln prüfen.

Neue Fehler oder kurzfristige Wünsche beginnen erneut bei Schritt 1. Der
Release Candidate gilt erst als freigegeben, wenn die gemeinsame Testrunde
abgeschlossen ist.

## 3. Einmalig veröffentlichen

Erst nach ausdrücklicher Freigabe:

1. `## Version:` in `KeystoneWheel.toc` auf die neue Version setzen.
2. Das lokale Prüfskript erneut ausführen.
3. Alle zusammengehörenden Änderungen in einem Release-Commit festhalten.
4. `main` einmal pushen.
5. Den passenden Tag erstellen und einmal pushen:

```bash
git push origin main
git tag v1.2.3
git push origin v1.2.3
```

Der Tag startet den GitHub-Actions-Workflow und erzeugt genau ein GitHub
Release. Weitere Patch-Releases folgen nur nach einer neuen abgeschlossenen
Testrunde. Eine Ausnahme sind kritische Fehler, die Installation, Login oder
gespeicherte Daten beeinträchtigen.

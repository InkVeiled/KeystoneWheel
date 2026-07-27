# KeystoneWheel

KeystoneWheel sammelt die Mythic+-Schlüssel einer Gruppe und lässt ein
animiertes Glücksrad einen davon auswählen. Das Addon ist für World of
Warcraft Retail ausgelegt.

## Funktionen

- Erkennt den eigenen Mythic+-Schlüssel direkt über die WoW-API.
- Tauscht Schlüssel mit anderen KeystoneWheel-Nutzern über das gemeinsame
  `LibKS`-Protokoll aus.
- Synchronisiert das Ergebnis eines Drehs automatisch mit allen
  KeystoneWheel-Nutzern in Gruppe, Raid oder Instanzgruppe.
- Verwendet vorhandene LibKeystone-Daten, wie sie unter anderem BigWigs und
  BossHelper bereitstellen.
- Erkennt als Fallback Keystone-Links im Gruppenchat.
- Unterstützt manuell eingefügte Keystone-Links.
- Lässt einzelne Steine per Linksklick ignorieren und wieder zulassen.
- Zeigt ein animiertes Glücksrad mit kompakten quadratischen Steinkacheln,
  gut lesbaren Stufen-Badges, glatten gezeichneten Ringen, Sound, Konfetti
  und optionaler Ergebnisnachricht im Gruppenkanal.
- Bietet beim ausgewählten Dungeon einen Port-Button mit Zaubericon und
  Cooldown. Noch nicht freigeschaltete Portale werden deaktiviert angezeigt.
- Bietet einen verschiebbaren Minimap-Button und Diagnosebefehle.

Die Datenquellen werden pro Spieler in dieser Reihenfolge verwendet:

1. Eigener Schlüssel und direkte Kommunikation mit KeystoneWheel
2. LibKeystone
3. Im Gruppenchat verlinkte Keystone-Items
4. Manuell eingefügte Keystone-Links

KeystoneWheel registriert kein zusätzliches eigenes Kommunikations-Prefix.
Ist `LibKS` bereits durch ein anderes Addon vorhanden, wird kein weiterer
Platz aus WoWs begrenztem Prefix-Pool verbraucht.

Auch die Dreh-Ergebnisse werden als eindeutig markierte KeystoneWheel-
Nachricht über `LibKS` übertragen. Andere LibKeystone-Addons ignorieren diese
Erweiterung, während KeystoneWheel-Nutzer in derselben Gruppe das gleiche
Ergebnis sehen.

## Installation mit WowUp

1. In WowUp den Bereich **Get Addons** öffnen.
2. **Install from URL** auswählen.
3. Die Repository-URL
   `https://github.com/InkVeiled/KeystoneWheel` einfügen.
4. Das gefundene Addon importieren und installieren.

WowUp erkennt nach der ersten GitHub-Installation neue getaggte Releases und
kann sie automatisch aktualisieren.

## Manuelle Installation

1. Die ZIP des neuesten GitHub Releases herunterladen.
2. Das Archiv in
   `World of Warcraft/_retail_/Interface/AddOns/` entpacken.
3. Prüfen, dass die Datei
   `Interface/AddOns/KeystoneWheel/KeystoneWheel.toc` existiert.
4. World of Warcraft neu starten oder im Spiel `/reload` ausführen.

Nicht die von GitHub automatisch angebotene **Source code**-ZIP verwenden,
sondern das Release-Asset `KeystoneWheel-vX.Y.Z.zip`.

## Bedienung

Der Minimap-Button öffnet das Rad mit Linksklick und sammelt die
Gruppenschlüssel mit Rechtsklick neu ein. Die Zahl am Button zeigt die aktuell
gefundenen Steine.

Ein Linksklick auf eine Steinkarte markiert genau diesen Stein als ignoriert.
Er bleibt sichtbar, wird aber nicht mehr gezogen. Ein weiterer Linksklick
lässt ihn wieder zu. Ändern sich Dungeon oder Stufe des Spielers, gilt der
neue Stein automatisch als eigener, nicht ignorierter Kandidat. Chat- und
manuelle Einträge können weiterhin mit Rechtsklick entfernt werden.

Nach einem Dreh wird das Ergebnis an andere KeystoneWheel-Nutzer in der
Gruppe übertragen. Ist deren Rad geöffnet, springt es auf denselben Stein und
zeigt die Ergebnisanimation. Bei geschlossenem Rad erscheint nur eine kurze
Chatmeldung; das Fenster wird nicht ungefragt geöffnet.

Der Port-Button erscheint beim Ergebnis, sobald für den Dungeon ein
Teleport-Zauber hinterlegt ist. Ein freigeschalteter Port kann direkt
angeklickt werden. Im Kampf wird der geschützte Button vorübergehend
ausgeblendet und danach automatisch wiederhergestellt.

## Befehle

- `/kwheel` oder `/steinrad`: Fenster öffnen oder schließen
- `/kwheel drehen`: Rad drehen
- `/kwheel neu`: Gruppendaten neu abfragen
- `/kwheel fragen`: Gruppe um Keystone-Links bitten
- `/kwheel add Spieler [Keystone-Link]`: Link manuell hinzufügen
- `/kwheel clear`: Chat- und manuelle Fallbacks entfernen
- `/kwheel minimap`: Minimap-Button einblenden und zurücksetzen
- `/kwheel debug`: Diagnosebericht und erneute Abfrage starten
- `/kwheel debug on` oder `off`: Live-Protokoll ein- oder ausschalten

## Releases

Ein Tag im Format `v1.2.3` startet den Workflow
`.github/workflows/release.yml`. Vor dem Taggen muss die Zeile
`## Version:` in `KeystoneWheel.toc` dieselbe Version ohne führendes `v`
enthalten.

Beispiel:

```bash
git tag v1.2.3
git push origin v1.2.3
```

Der Workflow:

1. prüft das Tagformat und die TOC-Version,
2. erzeugt `KeystoneWheel-v1.2.3.zip`,
3. prüft `KeystoneWheel/KeystoneWheel.toc` im Archiv und
4. erstellt ein GitHub Release mit automatisch generierten Release Notes.

## Lizenz

KeystoneWheel steht unter der [MIT-Lizenz](LICENSE).

Die Zuordnung der Dungeon-Teleporte wurde mit
[DungeonTeleport](https://github.com/dfrezell/DungeonTeleport) abgeglichen,
das ebenfalls unter der MIT-Lizenz veröffentlicht wird.

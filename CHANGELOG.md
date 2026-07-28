# Changelog

Alle wichtigen Änderungen an KeystoneWheel werden in dieser Datei dokumentiert.

## [0.5.0] - 2026-07-28

### Hinzugefügt

- Direkter Addon-Transport über `KSWheel1` parallel zum gemeinsamen
  `LibKS`-Fallback.
- Pool-Status im Sync-Handshake, damit andere KeystoneWheel-Nutzer schneller
  und zuverlässiger erkannt werden.
- Notfall-Fallback über die deutsche oder englische Ergebnisnachricht im
  Gruppenchat.
- Build-, Transport- und Peer-Details im Debug-Bericht und Sync-Tooltip.
- Schlüssel- und Ergebnisabgleich für Raid- und Raidleiter-Chat.

### Behoben

- Einseitiger Sync, bei dem nur einer von zwei Addon-Nutzern den anderen
  erkannt hat.
- Falsche Ablehnung von Gruppenmitgliedern, wenn Realm-Namen mit oder ohne
  Leerzeichen übermittelt wurden.
- Doppelte Ergebnisanzeigen, wenn direkter Transport, `LibKS` und Chat-Fallback
  dasselbe Ergebnis liefern.
- Unnötiger Debug-Spam durch Nachrichten fremder Addon-Prefixe.

### Geändert

- Lokale Testpakete tragen eine eigene Build-Kennung, ohne die öffentliche
  Release-Version während der Testphase zu erhöhen.
- Die lokale Release-Prüfung validiert und paketiert den aktuellen Changelog.

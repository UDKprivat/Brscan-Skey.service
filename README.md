# Brscan-Skey.service

Startet den Brother-`brscan-skey`-Daemon als systemd-Service.

Dadurch können Benutzer, die aktiv an einem Linux-Rechner angemeldet sind, einen Scan über die Scan-Tasten eines Brother-Multifunktionsgeräts an diesen Rechner senden. Die Scan-Aktionen werden dabei durch den Brother Scan-Key-Dienst verarbeitet und anschließend im Benutzerkontext ausgeführt.

Das Projekt ist insbesondere für Linux-Systeme gedacht, auf denen mehrere Benutzer arbeiten und der Scanner zentral über einen Rechner erreichbar ist.

## Funktionsumfang

- Start des Brother-`brscan-skey`-Daemons über systemd
- Automatischer Start des Dienstes beim Booten
- Unterstützung mehrerer lokal angemeldeter Benutzer
- Übergabe eines Scanauftrags an den aktiven Benutzer
- Installation der benötigten Dateien an den vorgesehenen Systempfaden
- Einfache Installation und Deinstallation über Shell-Skripte
- Nutzung der Brother-Scan-Key-Funktionen direkt über die Tasten am Scanner

## Voraussetzungen

Vor der Installation müssen die Brother-Scanner-Treiber und das Brother-Scan-Key-Tool installiert sein.

Benötigt werden üblicherweise:

- ein Linux-System mit `systemd`
- ein unterstütztes Brother-Multifunktionsgerät oder ein Brother-Scanner
- ein installierter Brother-Scanner-Treiber, beispielsweise:
  - `brscan`
  - `brscan2`
  - `brscan3`
  - `brscan4`
  - `brscan5`
- das Brother-Programm `brscan-skey`
- Root- oder `sudo`-Berechtigungen
- eine funktionierende Netzwerk- oder USB-Verbindung zum Scanner

Die genaue Treiberversion hängt vom verwendeten Brother-Modell ab. Der Scanner sollte vor der Installation dieses Projekts bereits mit dem Brother-Treiber funktionieren.

### Installation von `sudo`

Debian- und Ubuntu-basierte Systeme:

```bash
sudo apt update
sudo apt install sudo

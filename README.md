# Brscan-Skey.service

Startet den Brother-`brscan-skey`-Daemon als systemd-Service.

Dadurch können Benutzer, die aktiv an einem Linux-Rechner angemeldet sind, einen Scan über die Scan-Tasten
eines Brother-Multifunktionsgeräts an diesen Rechner senden. Die Scan-Aktionen werden dabei durch den 
Brother Scan-Key-Dienst verarbeitet und anschließend im Benutzerkontext ausgeführt.

Das Projekt ist insbesondere für Linux-Systeme gedacht, auf denen mehrere Benutzer arbeiten und der Scanner
zentral über einen oder mehrere Rechner erreichbar ist.

## Funktionsumfang

- Start des Brother-`brscan-skey`-Daemons als Dienst über systemd

  - der Daemon wird vor und nach einem Suspend beendet, bzw. gestartet

- Automatischer Start des Dienstes beim Booten

- Unterstützung mehrerer Rechner mit Multi-User-System

- Nutzung der Brother-Scan-Key-Funktionen direkt über die Tasten am Scanner

- Installation der benötigten Dateien an den vorgesehenen Systempfaden und der Shell-Skripte.

  - nach der ersten Benutzung der Scan-Funktionen, werden zwei Verzeichnisse im Home-Verzeichnis jedes Users erzeugt.

    - ``~/.brscan-skey``:<br>
    hier werden werden die persönlichen Konfigurationen für Scan-Funktionen abgelegt.

    - ``~/scannedDocuments``:<br> 
    in diesem Verzeichnis werden die gescannten Dokumente der abgelegt. In den
    einzelnen Job-Konfigurationen können diese Verzeichnisse und deren Aufbewahrungszeiten festgelegt werden.

- Übergabe eines Scan-Auftrags an den aktiven Benutzer

  - es wird eine *tiff* und eine *pdf*-Datei auf dem Rechner des aktiven Users erzeugt und in einem lokalen Verzeichnis abgelegt. Zusätzlich wird abhängig vom gewählten Job, ein Fenster mit dem Verzeichnis geöffnet oder der Email-Client geöffnet und eine Email-Vorlage erstellt mit dem Scan als Anhang geöffnet.

  - zur Zeit sind nur die Scann-Funktionen am Scanner **Datei**, **E-Mail** programmiert. Die Funktionen **Bild** und **Text** verhalten sich wie **Datei**.


## Voraussetzungen

Vor der Installation müssen die Brother-Scanner-Treiber und das Brother-Scan-Key-Tool installiert sein.

Benötigt werden üblicherweise:

- Distributionen mit einem *systemd* und *firewalld*, dies sind unter anderem
  **CentOS**, **Fedora**, **RHEL (Red Hat Enterprise Linux)** und **openSUSE**.
  Der Grund ist, diese Distributionen haben wahrscheinlich die folgenden Verzeichnisse:
  ```
  /etc/firewalld/
      +systemd/system/
              +system-sleep/
  /usr/local/
  ```
  Diese Verzeichnisse müssen ggf. an ein anderes System angepasst werden (siehe dazu `testInstall.sh`).

- ein unterstütztes Brother-Multifunktionsgerät oder ein Brother-Scanner

  - ein installierter Brother-Scanner-Treiber, beispielsweise `brscan5`
    Der Treiber von Brother legt auch ein Verzeichnis unter `/etc/opt/brother/scanner/brscan-skey/` an.
    In diesem Verzeichnis werden die Konfigurationen und Skripts abgelegt, die von dem *'Brother-service'*
    vom Scanner gestartet werden.

- das Brother-Programm `brscan-skey`

- eine funktionierende Netzwerk-Verbindung zum Scanner

Die genaue Treiber-Version hängt vom verwendeten Brother-Modell ab. Der Scanner sollte vor der Installation
dieses Projekts bereits mit dem Brother-Treiber funktionieren.

## Das System des Entwicklers:

  - OpenSUSE Tumbleeed

    - KDE Plasma (x11, Wayland)

    - iceWM (x11)

    - zeitweise auch GNOME (Wayland)

  - Drucker/Scanner: Brother DCP-L3520cdw

## Installation

  ``` 
    cd install/dir/
    sudo ./testInstall.sh --install
  ```


### Port öffnen

Nach der Installation ist in dem Verzeichnis `/etc/firewalld/services` die Datei `brscanskey.xml`
zu finden. Diese Datei definiert die Ports *brscan-skey = tcp: 54921, udp: 54925* zur Öffnung der Firewall.
Damit die Scan-Jobs funktionieren müssen diese Ports in der Firewall geöffnet werden.

### Service starten

```
  sudo ./startSkey.sh
```

### Konfiguration

Vor der ersten Nutzung des Scan-Funktion kann das Verzeichnis in dem die Scan-Dateien abgelegt werden
und Standardwerte zum Scannen angepasst werden. In ``/etc/opt/brother/scanner/brsan-skey/`` werden die
Standard-Konfigurationsdateien ``scantofile.conf`` und ``scantoemail.conf`` für alle User angepasst.
Diese Dateien werden während der ersten Nutzung des Programms, durch ein User, in sein Home-Verzeichnis
``~/.brcan-skey`` kopiert. Jede folgende Nutzung liest nur noch diese Konfiguration aus und 
damit kann für jeden User eine eigene Einstellung vorgenommen werden.

## Kommentar zur Nutzung von KI beim Programmieren

Die gesamte Programmierung ist durch menschliche Geisteskraft entstanden. KI ist hauptsächlich als bessere
Suche genutzt worden. Bei der Einarbeitung in die Bash-Programmierung, wurden von der KI Skript-Ausschnitte
vorgeschlagen, welche angepasst übernommen wurden.

Am Schluss ist die KI für das Formatieren und das Kommentieren der Skripte genutzt worden und auch hier ist
der gesamte Code von 'Hand' überprüft worden.

Mit diesem Kommentar möchte ich ausdrücken, das sehr viele Programmierer, die ihre Programmtexte für das 
Training der KIs zur Verfügung gestellt haben, indirekt an diesem Projekt mit gewirkt haben.
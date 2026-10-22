# FreePDF64ViewerPortable

**FreePDF64ViewerPortable** ist ein eigenständiger PDF-Viewer für Windows. PDF-Dokumente werden in einer übersichtlichen Oberfläche mit Registerkarten geöffnet.

## Schnellstart

1. `FreePDF64ViewerPortable.exe` zusammen mit den mitgelieferten Dateien in einen Ordner kopieren bzw. das Programmpaket entpacken.
2. `FreePDF64ViewerPortable.exe` starten.
3. Über **Datei → PDF öffnen …** oder **Strg+O** ein PDF auswählen. Alternativ können PDF-Dateien per Drag & Drop geöffnet werden.

## Funktionen und Bedienung

- **Registerkarten:** Jedes geöffnete PDF erhält einen eigenen Tab.
- **Tab schließen:** Das kleine **×** rechts im jeweiligen Tab oder **Strg+W** schließt das aktive Dokument.
- **Tab-Suche:** Über die **Lupe** rechts in der Registerkartenleiste lassen sich geöffnete PDF-Registerkarten suchen.
- **PDF-Zähler:** Neben der Lupe wird die Anzahl der geöffneten PDF-Dateien angezeigt.
- **Sitzung wiederherstellen:** Auf der leeren Startseite können über das Kontextmenü zuletzt geschlossene PDFs erneut geöffnet oder die letzte Sitzung wiederhergestellt werden, sofern entsprechende Einträge vorhanden sind.

## Hauptmenü

### Datei

| Menüpunkt | Funktion |
| --- | --- |
| **PDF öffnen …** | PDF-Datei auswählen (**Strg+O**). |
| **Exit** | Viewer vollständig beenden (**Alt+F4**). |

### Optionen

| Menüpunkt | Funktion |
| --- | --- |
| **Beim Schließen in den Infobereich** | Beim normalen Schließen wird der Viewer in den Windows-Infobereich ausgeblendet. Über das Infobereich-Symbol lässt er sich wieder öffnen oder vollständig beenden. |
| **PDF-Dateien mit dem FreePDF64-Viewer verknüpfen …** | Registriert den Viewer als mögliche PDF-Anwendung für den aktuellen Windows-Benutzer. |

### Hilfe

| Menüpunkt | Funktion |
| --- | --- |
| **Funktionsübersicht** | Hinweise zur Bedienung des Viewers. |
| **Über FreePDF64-Viewer** | Versions- und Programminformationen. |

## Portable Nutzung und Dateien

| Datei / Komponente | Beschreibung |
| --- | --- |
| `FreePDF64ViewerPortable.exe` | Ausführbare Programmdatei. |
| `FreePDFViewer.ini` | Einstellungsdatei im Programmverzeichnis. |
| `FreePDF64Viewer_Startbild.jpg` | Optionales Startbild für die leere Startansicht; muss neben der EXE liegen. |
| `FreePDF64ViewerLog.txt` | Kann bei bestimmten Vorgängen als Logdatei entstehen. |
| PDFium, qpdf, Xpdf | Verwendete Bibliotheken und Zusatzprogramme für die PDF-Anzeige und einzelne Funktionen. |

Die benötigten Bibliotheken und Zusatzprogramme müssen zusammen mit dem Viewer bereitgestellt werden.

## PDF-Dateiverknüpfung unter Windows

Die optionale Registrierung erfolgt **nur für den aktuellen Benutzer (HKCU)** und benötigt keine Administratorrechte.

Unter **Windows 10/11** muss die gewünschte Standard-App für PDF-Dateien gegebenenfalls zusätzlich in den Windows-Einstellungen ausgewählt werden.

> **Hinweis:** Wenn die EXE-Datei später in einen anderen Ordner verschoben wird, muss die Dateiverknüpfung gegebenenfalls erneut eingerichtet werden.

## Beenden und Datensicherheit

**Datei → Exit** beendet den Viewer ohne eine zusätzliche allgemeine Bestätigungsfrage. Falls ein PDF ungespeicherte Änderungen enthält, kann weiterhin eine Speicher- oder Sicherheitsabfrage erscheinen.

Es empfiehlt sich, wichtige Original-PDFs vor umfangreichen Änderungen zu sichern.

## Drittanbieterkomponenten und Lizenzen

Für **PDFium**, **qpdf**, **Xpdf** und weitere gegebenenfalls mitgelieferte Komponenten gelten deren jeweilige Lizenz- und Copyrightbedingungen. Die zugehörigen Lizenztexte sind bei der Weitergabe zu beachten.

## Projekt und Kontakt

- **GitHub:** https://github.com/FreePDF64
- **E-Mail:** FreePDF64@outlook.com

Copyright © 2026 FreePDF64

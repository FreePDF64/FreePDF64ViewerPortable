<div align="center">

<img src="images/freepdf64-viewer-logo.png" alt="FreePDF64-Viewer Portable" width="200">

# FreePDF64-Viewer Portable 3.2.2

**Free, open-source PDF and image viewer for Windows – portable, fast and versatile.**

[English](#english) · [Deutsch](#deutsch)

[**Download / Releases**](https://github.com/FreePDF64/FreePDF64ViewerPortable/releases) · [**Projektseite**](https://github.com/FreePDF64/FreePDF64ViewerPortable)

</div>

---

# English

FreePDF64-Viewer Portable is a free, open-source PDF viewer for Windows. It combines a fast PDF and image viewer with tabs, **named, reusable workspaces**, cross-document search, side-by-side viewing, and practical PDF tools. Save a collection of open documents and return to it later instead of reopening every file individually. Settings are stored locally in the application folder.

## New in version 3.2.2

- **Improved PDF hyperlinks:** Automatically add HTTPS to web addresses, show link destinations as tooltips, and reposition hyperlinks with Ctrl+drag.
- **Custom measurement colors:** Select a measurement color and see it in a compact toolbar color preview. Measurement borders retain consistent thickness when saved and reopened.
- **Refined toolbar and themes:** Clear orange active-tool indicators, compact color previews, and improved display across four interface themes.
- **PDF attachments and export:** Improved attachment handling and export of PDF pages as images or text, with refined German/English dialogs.
- **Simplified portable installation:** The `Xpdf` folder is no longer required by FreePDF64-Viewer Portable and may be deleted from existing viewer installations.

### Also introduced in version 3.2.1

- **Secure PDF redaction:** Preview redaction areas, inspect affected content, and permanently apply redactions to rasterized pages. Includes a redaction report and an automatic check of the resulting PDF.
- **Hand tool:** Dedicated toolbar button with an orange active-state highlight for moving zoomed PDF pages.

### Also introduced in version 3.2.0

- **Signatures:** Draw a signature or use a transparent PNG image; save, reopen, rename, delete, and place signatures on PDF pages. Adjust their position and size.
- **Improved dialogs:** Refined theme colors, buttons, and layout for 4K and WQHD displays, including comment editing and saved-signature management.
- **PDF measurements:** Measure rectangle width and height in mm/cm/in with a selectable drawing scale; copy or export measurement reports as CSV. Save measurements as PDF annotations.

## Key features

- **Tabs and workspaces:** Open multiple PDFs and images in tabs, save named workspaces, and restore collections of documents and their zoom settings.
- **Side-by-side comparison:** View two PDFs together; **S** synchronizes scrolling and **Z** synchronizes zoom (left → right).
- **Search:** Search one PDF or all open PDFs using **Ctrl+Shift+F**.
- **Page management:** Resizable thumbnails; drag and drop pages to reorder, rotate, delete, or extract them.
- **PDF editing:** Add text, comments, drawings, highlights, watermarks, and clickable hyperlinks; Undo/Redo for supported edits.
- **PDF forms:** Edit AcroForm and supported static XFA forms; run supported V8 JavaScript actions and calculations.
- **Images:** Open, zoom, rotate, and save JPG/JPEG, PNG, BMP, and single- or multipage TIFF files.
- **More:** Manage PDF attachments, export PDF pages as images or text, use bookmarks, switch between German and English, and choose interface themes.

## Workspaces – pick up where you left off

**Workspaces are a standout feature of FreePDF64-Viewer Portable:** Instead of reopening documents one by one, save the currently open PDFs and supported images as a **named workspace** and reopen that collection whenever you need it. This is particularly useful for recurring projects, research, or working with several related documents.

- **Save and restore:** Keep multiple named workspaces and reopen their documents, including saved zoom levels.
- **Manage efficiently:** Search, sort, inspect workspace contents, rename, and delete saved workspaces in a dedicated management window.
- **Portable workflow:** Workspace management is integrated into the viewer, without a separate project-management application.

See the **Workspaces** screenshot below for the management interface.

## Screenshots

*Click a thumbnail to open the full-size image.*

<div align="center">

<a href="images/Mainwindow_english.png"><img src="images/Mainwindow_english.png" alt="Main window" width="260"></a>
<a href="images/Twowindows_english.png"><img src="images/Twowindows_english.png" alt="Side-by-side view" width="260"></a>
<a href="images/Globalsearch_english.png"><img src="images/Globalsearch_english.png" alt="Global PDF search" width="260"></a>
<a href="images/Measure_english.png"><img src="images/Measure_english.png" alt="PDF measurement tools" width="260"></a>
<a href="images/Workspace_english.png"><img src="images/Workspace_english.png" alt="Workspaces" width="260"></a>

</div>

## Quick start

1. Extract the entire release ZIP to a folder, keeping bundled libraries and auxiliary tools.
2. Run **`FreePDF64ViewerPortable.exe`**.
3. Open PDFs using **Ctrl+O**, drag and drop, or Windows File Explorer. Supported image files can also be opened.

**Upgrade note:** The `Xpdf` folder from older viewer versions is no longer needed and can be deleted.

**Notes:** Measurements depend on the drawing scale and source PDF. **Visual redaction** only covers content; it does not securely remove it. Not every PDF JavaScript feature or XFA form is supported.

## Portable use and license

Settings are stored in **`FreePDFViewer.ini`** in the application folder.

**FreePDF64-Viewer Portable** is free and open-source software licensed under **GNU GPL v3 (GPL-3.0-only)**. Use, modification, and redistribution are subject to this license. See **`LIZENZ_DE.txt`** (German) and **`LICENSE_NOTICE_EN.txt`** (English).

**Third-party libraries and tools:**
- **[PDFium](https://pdfium.googlesource.com/pdfium/):** PDF rendering and processing, © The PDFium Authors.
- **[V8](https://v8.dev/):** JavaScript engine, © The V8 Project Authors.
- **QPDF:** Auxiliary tools governed by their own licenses.

License texts and copyright notices for PDFium, V8, and bundled third-party libraries are included in the **`PDFium`** subfolder (**`LICENSE`** file and **`licenses`** directory). Their respective license terms must be observed when redistributing the software. FreePDF64-Viewer Portable is **not an official product of PDFium, V8, or Google**.

**Contact:** [FreePDF64@outlook.com](mailto:FreePDF64@outlook.com) · [GitHub](https://github.com/FreePDF64/FreePDF64ViewerPortable)

---

# Deutsch

FreePDF64-Viewer Portable ist ein kostenloser Open-Source-PDF-Viewer für Windows. Er vereint einen schnellen PDF- und Bildbetrachter mit Registerkarten, **benannten und wiederverwendbaren Arbeitsbereichen**, dokumentübergreifender Suche, Zweifensteransicht und praktischen PDF-Werkzeugen. Zusammengehörige Dokumente lassen sich als Arbeitsbereich speichern und später bequem wieder öffnen. Die Einstellungen bleiben lokal im Programmordner.

## Neu in Version 3.2.2

- **Verbesserte PDF-Hyperlinks:** Webadressen automatisch um HTTPS ergänzen, Zieladressen als Hinweis anzeigen und Hyperlinks mit Strg+Ziehen verschieben.
- **Individuelle Messfarben:** Messfarbe frei wählen und in einer kompakten Farbvorschau der Symbolleiste erkennen. Messrahmen behalten beim Speichern und erneuten Öffnen ihre einheitliche Linienstärke.
- **Optimierte Symbolleisten und Designs:** Orangefarbene Aktivmarkierung für Werkzeuge, kompakte Farbvorschauen und verbesserte Darstellung in allen vier Designs.
- **PDF-Anlagen und Export:** Verbesserte Anlagenverwaltung und Export von PDF-Seiten als Bilder oder Text sowie überarbeitete Dialoge auf Deutsch und Englisch.
- **Vereinfachte portable Installation:** Das Verzeichnis `Xpdf` wird von FreePDF64-Viewer Portable nicht mehr benötigt und kann aus bestehenden Viewer-Installationen gelöscht werden.

### Bereits in Version 3.2.1 eingeführt

- **Sichere PDF-Schwärzung:** Schwärzungsbereiche in der Vorschau markieren, betroffene Inhalte prüfen und Schwärzungen auf gerasterten Seiten dauerhaft anwenden. Mit Schwärzungsprüfbericht und automatischer Prüfung der erzeugten PDF.
- **Hand-Werkzeug:** Eigener Symbolleisten-Button mit orangefarbener Aktivmarkierung zum Verschieben vergrößerter PDF-Seiten.

### Bereits in Version 3.2.0 eingeführt

- **Unterschriften:** Unterschriften zeichnen oder als transparente PNG-Grafik verwenden, speichern, erneut aufrufen, umbenennen, löschen und auf PDF-Seiten platzieren. Position und Größe lassen sich anpassen.
- **Verbesserte Dialoge:** Überarbeitete Designfarben, Schaltflächen und Darstellung auf 4K- und WQHD-Bildschirmen, unter anderem beim Bearbeiten von Kommentaren und Verwalten gespeicherter Unterschriften.
- **PDF-Messwerkzeuge:** Rechtecke mit Breite und Höhe messen, mm/cm/Zoll und Zeichnungsmaßstab wählen; Messbericht kopieren oder als CSV exportieren. Messungen lassen sich als PDF-Anmerkungen speichern.

## Funktionen im Überblick

- **Registerkarten und Arbeitsbereiche:** Mehrere PDFs und Bilder in Registerkarten öffnen, benannte Arbeitsbereiche speichern und Dokumente samt Zoom-Einstellungen wiederherstellen.
- **PDF-Vergleich:** Zwei PDFs nebeneinander anzeigen; **S** synchronisiert das Scrollen, **Z** den Zoom (jeweils links → rechts).
- **Suche:** Einzelne PDFs durchsuchen oder alle geöffneten PDFs gemeinsam mit **Strg+Umschalt+F**.
- **Seitenverwaltung:** Vergrößerbare Miniaturen; Seiten per Drag & Drop verschieben, drehen, löschen oder extrahieren.
- **PDF-Bearbeitung:** Text, Kommentare, Zeichnungen, Markierungen, Wasserzeichen und anklickbare Hyperlinks hinzufügen; Rückgängig/Wiederholen für unterstützte Bearbeitungen.
- **PDF-Formulare:** AcroForm und unterstützte statische XFA-Formulare bearbeiten; unterstützte JavaScript-V8-Aktionen und Berechnungen ausführen.
- **Bilder:** JPG/JPEG, PNG, BMP sowie ein- und mehrseitige TIFF-Dateien öffnen, zoomen, drehen und speichern.
- **Weitere Funktionen:** PDF-Anlagen verwalten, PDF-Seiten als Bilder oder Text exportieren, Inhaltsverzeichnis, DE/EN-Oberfläche und verschiedene Designs.

## Arbeitsbereiche – dort weitermachen, wo du aufgehört hast

**Die Arbeitsbereiche sind ein besonderes Merkmal von FreePDF64-Viewer Portable:** Statt Dokumente jedes Mal einzeln zu öffnen, lassen sich die aktuell geöffneten PDFs und unterstützten Bilder als **benannter Arbeitsbereich** speichern und bei Bedarf gemeinsam wieder aufrufen. Ideal für wiederkehrende Projekte, Recherchen und die Arbeit mit mehreren zusammengehörigen Dokumenten.

- **Speichern und wiederherstellen:** Mehrere benannte Arbeitsbereiche verwalten und die enthaltenen Dokumente einschließlich gespeicherter Zoom-Einstellungen erneut öffnen.
- **Komfortabel verwalten:** Arbeitsbereiche in einem eigenen Fenster durchsuchen, sortieren, Inhalte anzeigen, umbenennen und löschen.
- **Portabel arbeiten:** Die Arbeitsbereichsverwaltung ist direkt in den Viewer integriert – ohne zusätzliches Projektverwaltungsprogramm.

Der Screenshot **Arbeitsbereiche** weiter unten zeigt die Verwaltung.

## Screenshots

*Klicke auf ein Vorschaubild, um die vollständige Ansicht zu öffnen.*

<div align="center">

<a href="images/Hauptansicht_deutsch.png"><img src="images/Hauptansicht_deutsch.png" alt="Hauptansicht" width="260"></a>
<a href="images/Zweifensteransicht_deutsch.png"><img src="images/Zweifensteransicht_deutsch.png" alt="Zweifensteransicht" width="260"></a>
<a href="images/Globalesuche_deutsch.png"><img src="images/Globalesuche_deutsch.png" alt="Globale PDF-Suche" width="260"></a>
<a href="images/Messen_deutsch.png"><img src="images/Messen_deutsch.png" alt="PDF-Messwerkzeuge" width="260"></a>
<a href="images/Arbeitsbereiche_deutsch.png"><img src="images/Arbeitsbereiche_deutsch.png" alt="Arbeitsbereiche" width="260"></a>

</div>

## Schnellstart

1. Release-ZIP vollständig in einen Ordner entpacken; mitgelieferte Bibliotheken und Zusatzprogramme beibehalten.
2. **`FreePDF64ViewerPortable.exe`** starten.
3. PDFs über **Strg+O**, Drag & Drop oder den Windows-Explorer öffnen. Unterstützte Bilddateien können ebenfalls geöffnet werden.

**Hinweis zum Update:** Das Verzeichnis `Xpdf` aus älteren Viewer-Versionen wird nicht mehr benötigt und kann gelöscht werden.

**Hinweise:** Messwerte hängen vom Maßstab und der PDF-Vorlage ab. Die **optische Schwärzung** verdeckt Inhalte nur und entfernt sie nicht sicher. PDF-JavaScript und XFA werden nicht in allen Varianten unterstützt.

## Portabilität und Lizenz

Die Einstellungen werden in **`FreePDFViewer.ini`** im Programmordner gespeichert.

**FreePDF64-Viewer Portable** ist freie und quelloffene Software unter der **GNU GPL v3 (GPL-3.0-only)**. Nutzung, Änderung und Weitergabe richten sich nach dieser Lizenz. Der deutsche Lizenzhinweis steht in **`LIZENZ_DE.txt`**, der englische in **`LICENSE_NOTICE_EN.txt`**.

**Zusatzprogramme und Bibliotheken:**
- **[PDFium](https://pdfium.googlesource.com/pdfium/):** PDF-Darstellung und -Verarbeitung, © The PDFium Authors.
- **[V8](https://v8.dev/):** JavaScript-Engine, © The V8 Project Authors.
- **QPDF:** Zusatzwerkzeuge mit jeweils eigenen Lizenzbedingungen.

Die Lizenztexte und Copyright-Hinweise zu PDFium, V8 und eingebundenen Drittanbieter-Bibliotheken befinden sich im mitgelieferten Unterordner **`PDFium`** (Datei **`LICENSE`** und Ordner **`licenses`**). Bei der Weitergabe sind die jeweiligen Lizenzbedingungen zu beachten. FreePDF64-Viewer Portable ist **kein offizielles Produkt von PDFium, V8 oder Google**.

**Kontakt:** [FreePDF64@outlook.com](mailto:FreePDF64@outlook.com) · [GitHub](https://github.com/FreePDF64/FreePDF64ViewerPortable)

---

<div align="center">

Copyright © 2026 FreePDF64

</div>

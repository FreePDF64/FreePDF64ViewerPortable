unit uPDFLanguage;

interface

uses System.SysUtils, System.Classes, Winapi.Windows, System.IniFiles,
     Vcl.Controls, Vcl.Forms, Vcl.Menus, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Graphics;

procedure InitializePDFLanguage(const IniPath: string);
procedure SetPDFLanguage(const ALanguage: string);
function PDFLanguage: string;
function Tr(const German: string): string;
procedure TranslatePDFControls(AParent: TWinControl);
procedure TranslatePDFMenu(AMenu: TMenuItem);
// Gemeinsame Farbpalette fuer zusaetzliche PDF-Dialoge.
procedure SetPDFDialogDesign(ADesign: Integer);
procedure ApplyPDFDialogDesign(AForm: TCustomForm);

implementation

var
  FLanguage: string = 'de';
  FPDFDialogDesign: Integer = 0;
  FIniPath: string;
  PairsDE, PairsEN: TStringList;


procedure SetPDFDialogDesign(ADesign: Integer);
begin
  FPDFDialogDesign := ADesign;
end;

procedure ApplyPDFDialogDesign(AForm: TCustomForm);
var
  BaseColor, HeaderColor, TextColor, ListColor: TColor;
  procedure ApplyChildren(AParent: TWinControl);
  var
    I: Integer;
    C: TControl;
  begin
    for I := 0 to AParent.ControlCount - 1 do
    begin
      C := AParent.Controls[I];
      if C is TPanel then
      begin
        TPanel(C).ParentBackground := False;
        TPanel(C).ParentColor := False;
        if TPanel(C).Align = alTop then TPanel(C).Color := HeaderColor
        else TPanel(C).Color := BaseColor;
        TPanel(C).Font.Color := TextColor;
      end
      else if C is TScrollBox then
      begin
        TScrollBox(C).ParentColor := False;
        TScrollBox(C).Color := BaseColor;
        TScrollBox(C).Font.Color := TextColor;
      end
      else if C is TLabel then
        TLabel(C).Font.Color := TextColor
      else if C is TListBox then
      begin
        TListBox(C).Color := ListColor;
        TListBox(C).Font.Color := TextColor;
      end;
      // Eingabefelder behalten ihren hellen, gut lesbaren Hintergrund.
      if C is TWinControl then ApplyChildren(TWinControl(C));
    end;
  end;
begin
  if (AForm = nil) or (FPDFDialogDesign = 0) then Exit;
  case FPDFDialogDesign of
    1: begin
      BaseColor := RGB(229, 236, 246);
      HeaderColor := RGB(225, 232, 241);
      TextColor := RGB(35, 48, 65);
      ListColor := RGB(248, 250, 253);
    end;
    3: begin
      BaseColor := RGB(232, 232, 232);
      HeaderColor := RGB(222, 222, 222);
      TextColor := clBlack;
      ListColor := clWhite;
    end;
    5: begin
      BaseColor := RGB(220, 233, 247);
      HeaderColor := RGB(190, 214, 237);
      TextColor := RGB(24, 55, 88);
      ListColor := RGB(246, 250, 255);
    end;
  else
    Exit; // Nicht angebotene Designs unveraendert lassen.
  end;
  AForm.Color := BaseColor;
  AForm.Font.Color := TextColor;
  ApplyChildren(AForm);
end;

procedure AddPair(const DE, EN: string);
begin
  PairsDE.Add(DE);
  PairsEN.Add(EN);
end;

procedure EnsurePairs;
begin
  if PairsDE <> nil then Exit;
  PairsDE := TStringList.Create;
  PairsEN := TStringList.Create;
  AddPair('Textwasserzeichen hinzufügen ...', 'Add text watermark...');
  AddPair('Textwasserzeichen', 'Text watermark');
  AddPair('Bildwasserzeichen hinzufügen ...', 'Add image watermark...');
  AddPair('Bildwasserzeichen', 'Image watermark');
  AddPair('Bild für Wasserzeichen auswählen', 'Select watermark image');
  AddPair('Bildbreite (Prozent der Seitenbreite):', 'Image width (percent of page width):');
  AddPair('Deckkraft:', 'Opacity:');
  AddPair('Drehwinkel:', 'Rotation angle:');
  AddPair('Wasserzeichentext:', 'Watermark text:');
  AddPair('Seitenbereich:', 'Page range:');
  AddPair('Aktuelle Seite', 'Current page');
  AddPair('Alle Seiten', 'All pages');
  AddPair('Schriftgröße in Punkt (1–200):', 'Font size in points (1–200):');
  AddPair('Deckkraft in Prozent (1–100):', 'Opacity in percent (1–100):');
  AddPair('Drehwinkel in Grad (-180 bis 180):', 'Rotation angle in degrees (-180 to 180):');
  AddPair('Wasserzeichen auf allen PDF-Seiten einfügen?', 'Add watermark to all PDF pages?');
  AddPair('Nein = nur aktuelle Seite.', 'No = current page only.');
  AddPair('Ungültige Schriftgröße.', 'Invalid font size.');
  AddPair('Ungültige Deckkraft.', 'Invalid opacity.');
  AddPair('Ungültiger Drehwinkel.', 'Invalid rotation angle.');
  AddPair('Text einfügen', 'Insert text');
  AddPair('Text: EIN', 'Text: ON');
  AddPair('Text konnte nicht eingefügt werden: ', 'Could not insert text: ');
  AddPair('Enter: Text einfügen | Esc: Abbrechen', 'Enter: Insert text | Esc: Cancel');
  AddPair('Keine weiteren Formularfelder gefunden.', 'No more form fields found.');
  AddPair('Formularfeld %d auf Seite %d', 'Form field %d on page %d');
  AddPair('Alle nicht gespeicherten Änderungen verwerfen und den letzten Speicherstand wiederherstellen?', 'Discard all unsaved changes and restore the last saved version?');
  AddPair('Änderungen zurücksetzen (letzter Speicherstand)', 'Reset changes (last saved version)');
  AddPair('Alle nicht gespeicherten Änderungen verwerfen und die PDF neu laden?', 'Discard all unsaved changes and reload the PDF?');
  AddPair('Die Pflichtfeldprüfung konnte nicht ausgeführt werden: ', 'Could not check required fields: ');
  AddPair('Alle erkannten Pflichtfelder sind ausgefüllt.', 'All detected required fields are completed.');
  AddPair('Pflichtfeldprüfung fehlgeschlagen: ', 'Required-field check failed: ');
  AddPair('Pflichtfelder pruefen ...', 'Check required fields...');
  AddPair('Pflichtfeldpruefung fehlgeschlagen: ', 'Required-field check failed: ');
  AddPair('Pflichtfeldbericht', 'Required Fields Report');
  AddPair('Schliessen', 'Close');
  AddPair('Bericht kopieren', 'Copy report');
  AddPair('Als Text speichern', 'Save as text');
  AddPair('Fehlende Pflichtfelder: %d', 'Missing required fields: %d');
  AddPair('Pflichtfeldbericht speichern', 'Save required-fields report');
  AddPair('Textdateien', 'Text files');
  AddPair('Bericht konnte nicht gespeichert werden: ', 'Could not save report: ');
  AddPair('Alle nicht gespeicherten Aenderungen verwerfen und die PDF neu laden?', 'Discard all unsaved changes and reload the PDF?');
  AddPair('Die Pflichtfeldpruefung konnte nicht ausgefuehrt werden: ', 'Could not check required fields: ');
  AddPair('... und %d weitere Felder.', '... and %d more fields.');
  AddPair('%d Pflichtfeld(er) sind noch leer:', '%d required field(s) are still empty:');
  AddPair('Trotzdem als PDF-Kopie speichern?', 'Save as PDF copy anyway?');
  AddPair('Seite %d: %s', 'Page %d: %s');
  AddPair('Seite %d, Feld %d', 'Page %d, field %d');
  AddPair(' (Radio-Gruppe)', ' (radio group)');
  AddPair(' (Checkbox)', ' (checkbox)');
  AddPair(' (Text/Auswahl)', ' (text/choice)');
  AddPair('Dieses PDF-Formularfeld ist schreibgeschuetzt.', 'This PDF form field is read-only.');
  AddPair('Dieses Pflichtfeld ist leer. Trotzdem leeren?', 'This required field is empty. Clear it anyway?');
  AddPair('Das Formularfeld konnte nicht geaendert werden.', 'The form field could not be changed.');
  AddPair('PDF-Auswahlliste', 'PDF selection list');
  AddPair('Eintrag suchen ...', 'Search entries...');
  AddPair('Die Dropdown-Auswahl konnte nicht gespeichert werden.', 'The dropdown selection could not be saved.');
  AddPair('PDF-Formularfeld: Text bearbeiten', 'PDF form field: Edit text');
  AddPair('(Pflichtfeld)', '(required field)');
  AddPair('Pflichtfelder prüfen ...', 'Check required fields...');
  AddPair('Fehlende Pflichtfelder: ', 'Missing required fields: ');
  AddPair('Datei', 'File');
  AddPair('PDFs zusammenführen ...', 'Merge PDFs...');
  AddPair('PDFs auswählen und die Reihenfolge mit den Pfeilen festlegen.', 'Select PDFs and set their order using the arrows.');
  AddPair('Zusammenführen', 'Merge');
  AddPair('Zusammengeführte PDF speichern', 'Save merged PDF');
  AddPair('Bitte mindestens zwei PDF-Dateien öffnen.', 'Please open at least two PDF files.');
  AddPair('Bitte mindestens zwei PDF-Dateien auswählen.', 'Please select at least two PDF files.');
  AddPair('Das Zieldokument konnte nicht erstellt werden.', 'Could not create the destination document.');
  AddPair('PDF konnte nicht geöffnet werden: %s', 'Could not open PDF: %s');
  AddPair('PDF-Seiten konnten nicht übernommen werden: %s', 'Could not import PDF pages: %s');
  AddPair('Die zusammengeführte PDF konnte nicht gespeichert werden.', 'Could not save the merged PDF.');
  AddPair('Die Zieldatei darf keine der Quelldateien überschreiben.', 'The destination must not overwrite any source PDF.');
  AddPair('Die PDF-Dateien wurden erfolgreich zusammengeführt.', 'The PDF files were merged successfully.');
  AddPair('Bearbeiten', 'Edit');
  AddPair('Arbeitsbereiche', 'Workspaces');
  AddPair('Linksklick', 'Left-click');
  AddPair('Rechtsklick', 'Right-click');
  AddPair('Aktuelle PDFs als Arbeitsbereich speichern', 'Save current PDFs as workspace');
  AddPair('Arbeitsbereiche speichern und verwalten', 'Save and manage workspaces');
  AddPair('Optionen', 'Options');
  AddPair('Hilfe', 'Help');
  AddPair('PDF öffnen ...', 'Open PDF...');
  AddPair('PDF neu laden (Änderungen verwerfen)', 'Reload PDF (discard changes)');
  AddPair('FreePDF64 öffnen', 'Open FreePDF64');
  AddPair('Text suchen', 'Find text');
  AddPair('Globale PDF-Suche', 'Search all PDFs');
  AddPair('Arbeitsbereich speichern ...', 'Save workspace...');
  AddPair('Arbeitsbereich öffnen', 'Open workspace');
  AddPair('Arbeitsbereiche verwalten ...', 'Manage workspaces...');
  AddPair('Mit Windows starten', 'Start with Windows');
  AddPair('Beim Start minimieren', 'Start minimized');
  AddPair('Beim Schließen in den Infobereich', 'Minimize to notification area on close');
  AddPair('PDF-Dateien mit dem FreePDF64-Viewer verknüpfen ...', 'Associate PDF files with FreePDF64-Viewer...');
  AddPair('Funktionsübersicht', 'Feature overview');
  AddPair('Über FreePDF64-Viewer ...', 'About FreePDF64-Viewer...');
  AddPair('FreePDF64-Viewer anzeigen', 'Show FreePDF64-Viewer');
  AddPair('FreePDF64-Viewer beenden', 'Exit FreePDF64-Viewer');
  AddPair('Arbeitsbereiche verwalten', 'Manage workspaces');
  AddPair('Meine Arbeitsbereiche', 'My workspaces');
  AddPair('Arbeitsbereich suchen ...', 'Search workspaces ...');
  AddPair('Inhalt anzeigen ...', 'Show contents ...');
  AddPair('Gespeicherte PDF-Sammlungen öffnen und verwalten', 'Open and manage saved PDF collections');
  AddPair('Name', 'Name');
  AddPair('Gespeichert am', 'Saved on');
  AddPair('PDFs', 'PDFs');
  AddPair('Öffnen', 'Open');
  AddPair('Alle schließen + öffnen', 'Close all and open');
  AddPair('Umbenennen', 'Rename');
  AddPair('Löschen', 'Delete');
  AddPair('Schließen', 'Close');
  AddPair('Abbrechen', 'Cancel');
  AddPair('Ja', 'Yes');
  AddPair('Nein', 'No');
  AddPair('Weiter', 'Next');
  AddPair('Zurück', 'Back');
  AddPair('Speichern', 'Save');
  AddPair('Speichern unter ...', 'Save as...');
  AddPair('Seiten', 'Pages');
  AddPair('Inhalte', 'Bookmarks');
  AddPair('Inhaltsverzeichnis', 'Table of contents');
  AddPair('Ausgewählte Seite(n) löschen', 'Delete selected page(s)');
  AddPair('Ausgewählte Seite(n) 90° im Uhrzeigersinn drehen', 'Rotate selected page(s) 90° clockwise');
  AddPair('Ausgewählte Seite(n) 90° gegen den Uhrzeigersinn drehen', 'Rotate selected page(s) 90° counterclockwise');
  AddPair('↑ Seite nach oben', '↑ Move page up');
  AddPair('↓ Seite nach unten', '↓ Move page down');
  AddPair('Seite(n) extrahieren ...', 'Extract page(s)...');
  AddPair('Bitte warten ...', 'Please wait...');
  AddPair('Diese PDF-Datei ist kennwortgeschützt:', 'This PDF is password protected:');
  AddPair('Bitte geben Sie das Kennwort zum Öffnen ein:', 'Enter the password to open:');
  AddPair('1 Seite', '1 page');
  AddPair('2 Seiten', '2 pages');
  AddPair('● Speichern unter ...', '● Save as...');
  AddPair('Bearbeiten ▲', 'Edit ▲');
  AddPair('Bearbeiten ▼', 'Edit ▼');
  AddPair('Dokumenteigenschaften', 'Document properties');
  AddPair('Alle PDFs durchsuchen', 'Search all PDFs');
  AddPair('PDFs durchsuchen', 'Search PDFs');
  AddPair('Geöffnete Registerkarten suchen (Strg+Umsch+A)', 'Search open tabs (Ctrl+Shift+A)');
  AddPair('Alle speichern', 'Save all');
  AddPair('Nicht speichern', 'Do not save');
  AddPair('PDF-Anlagen', 'PDF attachments');
  AddPair('Drehe Seite:', 'Rotate page:');
  AddPair('Winkel:', 'Angle:');
  AddPair('Drehen', 'Rotate');
  AddPair('Anlagen', 'Attachments');
  AddPair('-> Anlagen', '-> Attachments');
  AddPair('Anlegen', 'Create');
  AddPair('Seite einpassen', 'Fit page');
  AddPair('Seite anpassen', 'Fit page');
  AddPair('Ganze Seite', 'Full page');
  AddPair('Durchgehend', 'Continuous');
  AddPair('Gehe zu', 'Go to');
  AddPair('Drucken', 'Print');
  AddPair('Fragen und Anregungen', 'Questions and feedback');
  AddPair('Fragen, Anregungen und eventuelle Fehlermeldungen', 'Questions, suggestions and possible error reports');
  AddPair('E-Mail an FreePDF64@outlook.com', 'Email FreePDF64@outlook.com');
  AddPair('Alles Wichtige auf einen Blick', 'Everything at a glance');
  AddPair('PDF-Dateien verknüpfen', 'Associate PDF files');
  AddPair('PDF-Verknüpfung eingerichtet', 'PDF association configured');
  AddPair('PDF-Dateien direkt im Viewer öffnen', 'Open PDF files directly in the viewer');
  AddPair(' als Standard-App einrichten', ' as the default app');
  AddPair(' wird für Ihr Windows-Benutzerkonto als PDF-Anwendung registriert.', ' will be registered as the PDF application for your Windows user account.');
  AddPair('So geht es weiter', 'What happens next');
  AddPair('1. Der Viewer wird in Windows registriert.', '1. The viewer will be registered in Windows.');
  AddPair('2. Die Windows-Einstellungen für Standard-Apps werden geöffnet.', '2. Windows Default apps settings will open.');
  AddPair('3. Dort wählen Sie ', '3. Select ');
  AddPair(' für PDF-Dateien aus.', ' for PDF files.');
  AddPair('Hinweis zur portablen Version', 'Note about the portable version');
  AddPair('Wenn Sie die EXE-Datei verschieben oder den Laufwerksbuchstaben ändern, müssen Sie die Verknüpfung erneut einrichten.', 'If you move the EXE file or change the drive letter, you must set up the association again.');
  AddPair('Registrierung erfolgreich', 'Registration successful');
  AddPair('Der Viewer wurde in Windows registriert.', 'The viewer has been registered in Windows.');
  AddPair('Die Windows-Einstellungen für Standard-Apps wurden geöffnet.', 'Windows Default apps settings have been opened.');
  AddPair('Wählen Sie dort den FreePDF64-Viewer Portable für den Dateityp .pdf aus.', 'Select FreePDF64-Viewer Portable there for the .pdf file type.');
  AddPair('Öffnen Sie Windows-Einstellungen > Apps > Standard-Apps.', 'Open Windows Settings > Apps > Default apps.');
  AddPair('Wichtig: Erst nach Ihrer Bestätigung in Windows wird die Zuordnung wirksam.', 'Important: The association takes effect only after you confirm it in Windows.');
  AddPair('Bei einer portablen Version muss die Verknüpfung nach dem Verschieben der EXE erneut eingerichtet werden.', 'For a portable version, the association must be set up again after moving the EXE.');
  AddPair('Über FreePDF64-Viewer Portable', 'About FreePDF64-Viewer Portable');
  AddPair('FreePDF64-Viewer Portable - Hilfe', 'FreePDF64-Viewer Portable - Help');
  AddPair('Willkommen beim FreePDF64-Viewer Portable', 'Welcome to FreePDF64-Viewer Portable');
  AddPair('PDF öffnen oder eine PDF-Datei hierher ziehen (Strg+O)', 'Open a PDF or drag a PDF file here (Ctrl+O)');
  AddPair('Arbeitsbereich öffnen ...', 'Open workspace...');
  AddPair('Zuletzt geöffnete PDF-Dateien', 'Recently opened PDF files');
  AddPair('Zuletzt geöffnete Dateien', 'Recently opened files');
  AddPair('Diese Datei ist nicht mehr vorhanden:', 'This file no longer exists:');
  AddPair('Möchten Sie den Verlauf der zuletzt geöffneten Dateien löschen?', 'Clear the recently opened file history?');
  AddPair('Verlauf löschen', 'Clear history');
  AddPair('Alle geöffneten PDFs durchsuchen', 'Search all open PDFs');
  AddPair('Fundstellen mit Doppelklick öffnen – das Suchfenster schließt sich automatisch.', 'Double-click a result to open it; the search window will close automatically.');
  AddPair('Suchen', 'Search');
  AddPair('Suchbegriff eingeben und Enter drücken.', 'Enter a search term and press Enter.');
  AddPair('Das Dokument wurde inzwischen geschlossen.', 'The document has been closed.');
  AddPair('Treffer-PDF konnte nicht rechtzeitig geladen werden.', 'The matching PDF could not be loaded in time.');
  AddPair('PDF nicht durchsuchbar: ', 'PDF cannot be searched: ');
  AddPair('Trefferlimit 3000 erreicht. Suche angehalten.', '3,000-result limit reached. Search stopped.');
  AddPair('Suche angehalten: ', 'Search stopped: ');
  AddPair('Das Dokument wurde inzwischen geschlossen oder gewechselt.', 'The document has been closed or switched.');
  AddPair('Treffer-PDF wird geladen ...', 'Loading matching PDF...');
  AddPair('Eingebettete PDF-Anlagen', 'Embedded PDF attachments');
  AddPair('Diese PDF-Datei enthält keine eingebetteten Anlagen.', 'This PDF contains no embedded attachments.');
  AddPair('Doppelklick: Anlage öffnen.', 'Double-click to open attachment.');
  AddPair('Extrahieren', 'Extract');
  AddPair('Hinzufügen', 'Add');
  AddPair('Entfernen', 'Remove');
  AddPair('FreePDF64-Viewer – PDF-Kennwort', 'FreePDF64-Viewer – PDF password');
  AddPair('FreePDF64-Viewer - Hilfe', 'FreePDF64-Viewer - Help');
  AddPair('Datei(en) öffnen', 'Open file(s)');
  AddPair('Es sind keine PDFs geöffnet.', 'No PDF documents are open.');
  AddPair('Arbeitsbereich löschen', 'Delete workspace');
  AddPair('Arbeitsbereich wirklich löschen?', 'Really delete this workspace?');
  AddPair('nicht verfügbar', 'unavailable');
  AddPair('Projektseite im Webbrowser öffnen', 'Open project page in browser');
  AddPair('Nein für alle', 'No to all');
  AddPair('Ja für alle', 'Yes to all');
  AddPair('Bestätigung', 'Confirmation');
  AddPair('Öffnen Sie nur Anlagen', 'Only open attachments');
  AddPair('Anlage(n) wurden hinzugefügt:', 'Attachment(s) added:');
  AddPair('PDFium konnte die PDF nicht öffnen: ', 'PDFium could not open the PDF: ');
  AddPair('Ungültige Seitennummer. Beispiel: 3 oder 1-5.', 'Invalid page number. Example: 3 or 1-5.');
  AddPair('Ungültiger Seitenbereich. Beispiel: 1-5.', 'Invalid page range. Example: 1-5.');
  AddPair('Bitte einen Drehwinkel auswählen.', 'Please select a rotation angle.');
  AddPair('Der ausgewählte Drehwinkel ist ungültig.', 'The selected rotation angle is invalid.');
  AddPair('Möglicherweise ist die Datei noch geöffnet oder schreibgeschützt.', 'The file may still be open or write-protected.');
  AddPair('Strg+F: PDF-Text suchen', 'Ctrl+F: Search PDF text');
  AddPair('F3: nächster Treffer', 'F3: Next match');
  AddPair('Umschalt+F3: vorheriger Treffer', 'Shift+F3: Previous match');
  AddPair('Alle geöffneten PDF-Dokumente durchsuchen (Strg+Umschalt+F)', 'Search all open PDFs (Ctrl+Shift+F)');
  AddPair('Um wieviel Grad man die Seite(n) drehen möchte', 'Angle by which to rotate the page(s)');
  AddPair('PDF wird geöffnet ...', 'Opening PDF...');
  AddPair('PDFs im neuen Tab, andere mit Windows öffnen.', 'Open PDFs in a new tab and other files with Windows.');
  AddPair('Anlagenfenster schließen', 'Close attachments window');
  AddPair('Diese Anlage kann aus Sicherheitsgründen nicht direkt gestartet werden.', 'This attachment cannot be opened directly for security reasons.');
  AddPair('Verwenden Sie bei Bedarf die Schaltfläche Extrahieren.', 'Use the Extract button if needed.');
  AddPair(' mit dem zugeordneten Windows-Programm öffnen?', ' with its associated Windows application?');
  AddPair('Öffnen Sie nur Anlagen aus vertrauenswürdigen PDF-Dateien.', 'Only open attachments from trusted PDF files.');
  AddPair('Für diese Anlage konnte kein zugeordnetes Windows-Programm gestartet werden.', 'No associated Windows application could be launched for this attachment.');
  AddPair('Die zugehörige PDF-Datei wurde nicht gefunden.', 'The associated PDF file was not found.');
  AddPair('Zielordner für markierte PDF-Anlagen wählen', 'Select destination folder for selected PDF attachments');
  AddPair('Überschreiben?', 'Overwrite?');
  AddPair('QPDF wurde nicht gefunden. Bitte prüfen Sie den QPDF-Pfad in den Einstellungen.', 'QPDF was not found. Check the QPDF path in settings.');
  AddPair('Dateien als PDF-Anlagen auswählen', 'Select files to attach to PDF');
  AddPair('PDF mit zusätzlichen Anlagen speichern', 'Save PDF with additional attachments');
  AddPair('Bitte einen anderen Dateinamen als die Ausgangs-PDF wählen.', 'Please choose a different filename from the source PDF.');
  AddPair('Die Anlagen konnten nicht hinzugefügt werden. QPDF meldete Fehlercode ', 'Attachments could not be added. QPDF error code ');
  AddPair('Die Quelldatei darf nicht überschrieben werden.', 'The source file must not be overwritten.');
  AddPair('Alle geöffneten PDFs nach dem eingegebenen Text durchsuchen', 'Search all open PDFs for the entered text');
  AddPair('Originalgröße (100 %)', 'Actual size (100%)');
  AddPair('Schwärzen (optisch)', 'Redact (visual only)');
  AddPair('Markierungsform auswählen; Schwärzen verdeckt Text nur optisch', 'Choose annotation shape; redaction only visually obscures text');
  AddPair('Strichstärke der neuen Markierungen', 'Stroke width for new annotations');
  AddPair('Farbe der neuen Markierungen auswählen', 'Choose color for new annotations');
  AddPair('Änderungen nicht gespeichert – Speichern unter erforderlich', 'Unsaved changes – Save As required');
  AddPair('Ausgewählte PDF-Seiten extrahieren', 'Extract selected PDF pages');
  AddPair('Bitte einen anderen Dateinamen wählen.', 'Please choose a different filename.');
  AddPair('Alle nicht gespeicherten Änderungen an dieser PDF verwerfen und ', 'Discard all unsaved changes to this PDF and ');
  AddPair('%d ausgewählte PDF-Seite(n) entfernen?', 'Remove %d selected PDF page(s)?');
  AddPair('Das Original bleibt unverändert. Dauerhaft wird die Änderung erst mit "Speichern unter ...".', 'The original stays unchanged. Changes become permanent only after Save As.');
  AddPair('Verschlüsseltes PDF – Dokumenteigenschaften anzeigen', 'Encrypted PDF – show document properties');
  AddPair('Zurück / Weiter: Zur vorherigen oder nächsten PDF-Seite.', 'Back / Next: Go to previous or next PDF page.');
  AddPair('- / +: Ansicht verkleinern oder vergrößern.', '- / +: Zoom out or in.');
  AddPair('Durchgehend / Seitenweise: Scrollen oder seitenweise blättern.', 'Continuous / Paged: Scroll or browse page by page.');
  AddPair('F3 / Umschalt+F3: Nächster / vorheriger Treffer.', 'F3 / Shift+F3: Next / previous match.');
  AddPair('Ohne Bearbeitungsmodus: Text mit der Maus auswählen.', 'Outside edit mode: Select text with the mouse.');
  AddPair('Strg+C: Ausgewählten Text kopieren.', 'Ctrl+C: Copy selected text.');
  AddPair('Strg+A: Gesamten PDF-Text auswählen.', 'Ctrl+A: Select all PDF text.');
  AddPair('Deutsch', 'German');
  AddPair('Sprache / Language', 'Language');
  AddPair('Seite', 'Page');
  AddPair('Suchbegriff', 'Search term');
  AddPair('Treffer', 'Matches');
  AddPair('Seitenweise', 'Paged');
  AddPair('Einzelseite', 'Single page');
  AddPair('Beenden', 'Exit');
  AddPair('Kennwort', 'Password');
  AddPair('Passwort', 'Password');
  AddPair('Fehler', 'Error');
  AddPair('Hinweis', 'Notice');
  AddPair('Alle', 'All');
  AddPair('Keine', 'None');
  AddPair('Drucken...', 'Print...');
  AddPair('Breite einpassen', 'Fit width');
  AddPair('Druckeinstellungen', 'Print settings');
  AddPair('Eine oder mehrere PDF-Dateien öffnen (Strg+O)', 'Open one or more PDF files (Ctrl+O)');
  AddPair('Gespeicherte Arbeitsbereiche mit Name und Datum auswählen', 'Select saved workspaces by name and date');
  AddPair('E-Mail-Programm öffnen', 'Open email application');
  AddPair('Portable PDF-Anwendung für Windows 64-Bit', 'Portable PDF application for 64-bit Windows');
  AddPair('PDF-Dateien hier ablegen', 'Drop PDF files here');
  AddPair('PDF-Dateien öffnen', 'Open PDF files');
  AddPair('Datei öffnen', 'Open file');
  AddPair('Dateien öffnen', 'Open files');
  AddPair('Verlauf entfernen', 'Remove history');
  AddPair('Eintrag aus Verlauf entfernen', 'Remove item from history');
  AddPair('Alle Einträge entfernen', 'Remove all entries');
  AddPair('Leeren', 'Clear');
  AddPair('Erneut laden', 'Reload');
  AddPair('Öffnen mit', 'Open with');
  AddPair('Alle schließen', 'Close all');
  AddPair('Aktiven Tab schließen', 'Close active tab');
  AddPair('Alle Tabs schließen', 'Close all tabs');
  AddPair('Neuer Arbeitsbereich', 'New workspace');
  AddPair('Arbeitsbereich speichern', 'Save workspace');
  AddPair('Arbeitsbereich aktualisieren', 'Update workspace');
  AddPair('Arbeitsbereich umbenennen', 'Rename workspace');
  AddPair('Speichern unter', 'Save as');
  AddPair('Dateiname', 'File name');
  AddPair('Dateipfad', 'File path');
  AddPair('Suche', 'Search');
  AddPair('Suchergebnisse', 'Search results');
  AddPair('Keine Treffer', 'No matches');
  AddPair('Vorkommen', 'Occurrences');
  AddPair('Suche abbrechen', 'Cancel search');
  AddPair('Suche läuft ...', 'Searching...');
  AddPair('Fertig', 'Done');
  AddPair('Alle auswählen', 'Select all');
  AddPair('Keine Auswahl', 'No selection');
  AddPair('Warnung', 'Warning');
  AddPair('Information', 'Information');
  AddPair('Originalgröße', 'Actual size');
  AddPair('Ansicht', 'View');
  AddPair('Vollbild', 'Full screen');
  AddPair('Vollbildmodus', 'Full-screen mode');
  AddPair('Seite drehen', 'Rotate page');
  AddPair('Seiten drehen', 'Rotate pages');
  AddPair('Links drehen', 'Rotate left');
  AddPair('Rechts drehen', 'Rotate right');
  AddPair('Markieren', 'Highlight');
  AddPair('Schwärzen', 'Redact');
  AddPair('Anlage hinzufügen', 'Add attachment');
  AddPair('Anlagen extrahieren', 'Extract attachments');
  AddPair('Anlagen öffnen', 'Open attachments');
  AddPair('Anlagen hinzufügen', 'Add attachments');
  AddPair('PDF drucken', 'Print PDF');
  AddPair('PDF öffnen', 'Open PDF');
  AddPair('Die PDF-Datei konnte nicht geöffnet werden.', 'The PDF file could not be opened.');
  AddPair('PDF-Dateien', 'PDF files');
  AddPair('PDF-Dateien (*.pdf)', 'PDF files (*.pdf)');
  AddPair('Ausgewählte PDF-Seiten extrahieren', 'Extract selected PDF pages');
  AddPair('Ein "->" bedeutet Anlage(n) vorhanden', 'A "->" indicates attachment(s) are present');
  AddPair('Farbe ...', 'Color...');
  AddPair('Ein "->" bedeutet Anlage(n) vorhanden', 'A "->" indicates attachment(s) are present');
  AddPair('1-3 oder 5-20 oder...', '1-3 or 5-20 or...');
  AddPair('Markierungswerkzeuge ein- oder ausblenden', 'Show or hide annotation tools');
  AddPair('Werkzeuge ein-/ausblenden', 'Show/hide tools');
  AddPair('Seitenminiaturen / Inhaltsverzeichnis', 'Page thumbnails / table of contents');
  AddPair('Einzelseiten- / Doppelseitenansicht', 'Single-page / two-page view');
  AddPair('Zwischen durchgehender und seitenweiser Anzeige wechseln', 'Switch between continuous and page-by-page display');
  AddPair('Dokumenteigenschaften anzeigen', 'Show document properties');
  AddPair('Markierungsmodus ein- oder ausschalten', 'Toggle annotation mode');
  AddPair('Markierungsform auswählen; Schwärzen verdeckt Text nur optisch', 'Select annotation shape; redaction only visually covers text');
  AddPair('Strichstärke der neuen Markierungen', 'Line width for new annotations');
  AddPair('Farbe der neuen Markierungen auswählen', 'Choose the color for new annotations');
  AddPair('PDF-Kopie unter neuem Namen speichern', 'Save a copy of the PDF under a new name');
  AddPair('Änderungen nicht gespeichert – Speichern unter erforderlich', 'Unsaved changes – Save As required');
  AddPair('Verschlüsseltes PDF – Dokumenteigenschaften anzeigen', 'Encrypted PDF – show document properties');
  AddPair('Strg+F: PDF-Text suchen | F3: nächster Treffer | Umschalt+F3: vorheriger Treffer', 'Ctrl+F: Search PDF text | F3: Next match | Shift+F3: Previous match');
  AddPair('Ein-/Ausblenden der Anlagenliste zur PDF-Datei:', 'Show/hide the list of attachments for this PDF:');
  AddPair('Eine Seite oder einen Bereich eingeben:', 'Enter a page or a range:');
  AddPair('Dreht die PDF-Seite(n) und speichert danach. Vorher wird eine BAK-Datei erstellt', 'Rotates the PDF page(s) and saves afterward. A BAK backup file is created first');
  AddPair('Alle geöffneten PDFs nach dem eingegebenen Text durchsuchen', 'Search all open PDFs for the entered text');
  AddPair('Laufende Suche abbrechen', 'Cancel the current search');
  AddPair('Anlagenfenster schließen', 'Close attachments window');
  AddPair('Vorherige Registerkarte', 'Previous tab');
  AddPair('Naechste Registerkarte', 'Next tab');
  AddPair('Geöffnete PDF-Registerkarten suchen (Strg+Umsch+A)', 'Search open PDF tabs (Ctrl+Shift+A)');
  AddPair('Anzahl geöffneter PDF-Registerkarten', 'Number of open PDF tabs');
  AddPair('FreePDF64-Hauptprogramm öffnen', 'Open the FreePDF64 main application');
  AddPair('Eine oder mehrere PDF-Dateien öffnen (Strg+O)', 'Open one or more PDF files (Ctrl+O)');
  AddPair('Gespeicherte Arbeitsbereiche mit Name und Datum auswählen', 'Select saved workspaces by name and date');
  AddPair('PDF-Datei nicht gefunden.', 'PDF file not found.');
  AddPair('Änderungen speichern?', 'Save changes?');
  AddPair('Änderungen verwerfen?', 'Discard changes?');
  AddPair('Änderungen nicht gespeichert', 'Unsaved changes');
  AddPair('Nur Anlagen aus vertrauenswürdigen PDF-Dateien öffnen.', 'Only open attachments from trusted PDF files.');
  AddPair('Markierungswerkzeuge ein- oder ausblenden', 'Show or hide annotation tools');
  AddPair('Werkzeuge ein-/ausblenden', 'Show/hide tools');
  AddPair('Seitenminiaturen / Inhaltsverzeichnis', 'Page thumbnails / table of contents');
  AddPair('Einzelseiten- / Doppelseitenansicht', 'Single-page / two-page view');
  AddPair('Zwischen durchgehender und seitenweiser Anzeige wechseln', 'Switch between continuous and paged view');
  AddPair('Dokumenteigenschaften anzeigen', 'Show document properties');
  AddPair('Markierungsmodus ein- oder ausschalten', 'Enable or disable annotation mode');
  AddPair('PDF-Kopie unter neuem Namen speichern', 'Save a PDF copy under a new name');
  AddPair('Das Kennwort ist nicht korrekt. Bitte versuchen Sie es erneut.', 'Incorrect password. Please try again.');
  AddPair('Keine weiteren Treffer gefunden.', 'No further matches found.');
  AddPair('Seite %d / %d', 'Page %d / %d');
  AddPair('Seite konnte nicht verschoben werden: ', 'Could not move page: ');
  AddPair('%d Seite(n) gespeichert.', '%d page(s) saved.');
  AddPair('Extrahieren fehlgeschlagen: ', 'Extraction failed: ');
  AddPair('PDF konnte nicht neu geladen werden: ', 'Could not reload PDF: ');
  AddPair('Drehen fehlgeschlagen: ', 'Rotation failed: ');
  AddPair('Mindestens eine Seite muss erhalten bleiben.', 'At least one page must remain.');
  AddPair('Seiten konnten nicht entfernt werden: ', 'Could not remove pages: ');
  AddPair('PDF gespeichert: ', 'PDF saved: ');
  AddPair('Speichern fehlgeschlagen: ', 'Save failed: ');
  AddPair('Die PDF wurde geändert. Vor dem Wechsel speichern?', 'The PDF has changed. Save before switching?');
  AddPair('Die PDF-Seiten konnten nicht gedreht werden:', 'The PDF pages could not be rotated:');
  AddPair('Die Drehung wurde gespeichert, aber die PDF-Anzeige ', 'Rotation was saved, but the PDF view ');
  AddPair('Ein-/Ausblenden der Anlagenliste zur PDF-Datei:', 'Show or hide the PDF attachment list:');
  AddPair('Ein "->" bedeutet Anlage(n) vorhanden', 'An arrow indicates that attachments are present');
  AddPair('Eine Seite oder einen Bereich eingeben:', 'Enter a page number or range:');
  AddPair('Dreht die PDF-Seite(n) und speichert danach. Vorher wird eine BAK-Datei erstellt', 'Rotates PDF pages and saves the result. A BAK backup is created first');
  AddPair('Das Anlagenfenster wurde noch nicht erstellt.', 'The attachments window has not been created yet.');
  AddPair('%d Treffer', '%d matches');
  AddPair('Text: %d Treffer', 'Text: %d matches');
  AddPair('Alle PDFs: %d Treffer', 'All PDFs: %d matches');
  AddPair('Laufende Suche abbrechen', 'Cancel the current search');
  AddPair('Suchbegriff eingeben ...', 'Enter search term...');
  AddPair('%d Treffer – %d von %d Seiten durchsucht', '%d matches – %d of %d pages searched');
  AddPair('Fertig / angehalten: %d Treffer in %d durchsuchten Seiten', 'Finished / stopped: %d matches in %d pages searched');
  AddPair('pdfdetach.exe wurde nicht gefunden.', 'pdfdetach.exe was not found.');
  AddPair('Die Anlage konnte nicht extrahiert werden.', 'The attachment could not be extracted.');
  AddPair('Bitte zuerst eine oder mehrere Anlagen markieren.', 'Select one or more attachments first.');
  AddPair('Datei existiert bereits:', 'File already exists:');
  AddPair('Fehler beim Extrahieren von ', 'Error extracting ');
  AddPair(' markierte Anlage(n) aus der PDF entfernen?', ' selected attachment(s) from the PDF?');
  AddPair('Anlagen konnten nicht entfernt werden. QPDF-Fehlercode ', 'Could not remove attachments. QPDF error code ');
  AddPair('PDF mit entfernten Anlagen gespeichert:', 'PDF saved with attachments removed:');
  AddPair('Die Registrierung des PDF-Viewers ist fehlgeschlagen:', 'Failed to register the PDF viewer:');
  AddPair('Der Windows-Autostart konnte nicht geändert werden:', 'Could not change Windows startup settings:');
  AddPair('Aus Liste entfernen', 'Remove from list');
  AddPair('Dateiordner öffnen', 'Open containing folder');
  AddPair('FreePDF64-Hauptprogramm öffnen', 'Open main FreePDF64 application');
  AddPair('Vorherige Registerkarte', 'Previous tab');
  AddPair('Naechste Registerkarte', 'Next tab');
  AddPair('Geöffnete PDF-Registerkarten suchen (Strg+Umsch+A)', 'Search open PDF tabs (Ctrl+Shift+A)');
  AddPair('Anzahl geöffneter PDF-Registerkarten', 'Number of open PDF tabs');
  AddPair('PDF-Registerkartensuche', 'Search PDF tabs');
  AddPair('Dateiname eingeben ...', 'Enter file name...');
  AddPair('Diese PDF-Datei ist nicht mehr vorhanden:', 'This PDF file no longer exists:');
  AddPair('Der Ordner ist nicht mehr vorhanden:', 'The folder no longer exists:');
  AddPair('Möchten Sie den Verlauf der zuletzt geöffneten PDF-Dateien löschen?', 'Clear the recently opened PDF history?');
  AddPair('FreePDF64.exe wurde im Viewer-Verzeichnis nicht gefunden.', 'FreePDF64.exe was not found in the viewer folder.');
  AddPair('Das FreePDF64-Hauptprogramm konnte nicht gestartet werden.', 'The main FreePDF64 application could not be started.');
  AddPair('Ungespeicherte PDF-Änderungen', 'Unsaved PDF changes');
  AddPair('Änderungen vor dem Schließen speichern?', 'Save changes before closing?');
  AddPair('Geschlossene PDFs wieder öffnen', 'Reopen closed PDFs');
  AddPair('Die PDF-Datei existiert nicht mehr und wurde aus der Liste entfernt:', 'The PDF no longer exists and was removed from the list:');
  AddPair('Der eigenständige PDF-Anzeiger konnte nicht gestartet werden.', 'Could not start the standalone PDF viewer.');
  AddPair('Keine PDF-Datei geöffnet', 'No PDF file open');
  AddPair('Keine PDF geöffnet', 'No PDF open');
  AddPair('PDF wird geladen', 'Loading PDF');
  AddPair('PDF wird geladen...', 'Loading PDF...');
  AddPair('PDF-Datei wird geladen...', 'Loading PDF file...');
  AddPair('PDF-Datei konnte nicht geöffnet werden', 'Could not open PDF file');
  AddPair('Seite konnte nicht geladen werden', 'Could not load page');
  AddPair('Datei nicht gefunden', 'File not found');
  AddPair('Datei wurde nicht gefunden', 'File was not found');
  AddPair('Bitte eine PDF-Datei auswählen.', 'Please select a PDF file.');
  AddPair('Bitte wählen Sie eine PDF-Datei aus.', 'Please select a PDF file.');
  AddPair('Bitte zuerst eine PDF öffnen.', 'Open a PDF first.');
  AddPair('Keine Suchergebnisse', 'No search results');
  AddPair('Keine Suchergebnisse gefunden.', 'No search results found.');
  AddPair('Suche abgeschlossen', 'Search completed');
  AddPair('Suche wird vorbereitet...', 'Preparing search...');
  AddPair('Suchvorgang läuft...', 'Search in progress...');
  AddPair('Suchvorgang abbrechen', 'Cancel search');
  AddPair('Alle Treffer', 'All matches');
  AddPair('Vorheriger Treffer', 'Previous match');
  AddPair('Nächster Treffer', 'Next match');
  AddPair('Vorherige Seite', 'Previous page');
  AddPair('Nächste Seite', 'Next page');
  AddPair('Erste Seite', 'First page');
  AddPair('Letzte Seite', 'Last page');
  AddPair('Seite nach oben', 'Move page up');
  AddPair('Seite nach unten', 'Move page down');
  AddPair('Zoom zurücksetzen', 'Reset zoom');
  AddPair('Zoom vergrößern', 'Zoom in');
  AddPair('Zoom verkleinern', 'Zoom out');
  AddPair('Ansicht zurücksetzen', 'Reset view');
  AddPair('PDF-Ansicht', 'PDF view');
  AddPair('Seitenansicht', 'Page view');
  AddPair('Seitenminiaturen', 'Page thumbnails');
  AddPair('Miniaturansichten', 'Thumbnails');
  AddPair('Dateianhänge', 'File attachments');
  AddPair('PDF-Anhänge', 'PDF attachments');
  AddPair('Anlagen verwalten', 'Manage attachments');
  AddPair('Dateianhang öffnen', 'Open attachment');
  AddPair('Anlage speichern', 'Save attachment');
  AddPair('Anlage löschen', 'Delete attachment');
  AddPair('Anlagen löschen', 'Delete attachments');
  AddPair('Anlage extrahieren', 'Extract attachment');
  AddPair('PDF-Seiten extrahieren', 'Extract PDF pages');
  AddPair('PDF-Seiten löschen', 'Delete PDF pages');
  AddPair('PDF-Seiten drehen', 'Rotate PDF pages');
  AddPair('Seitenbereich', 'Page range');
  AddPair('Seitenbereich auswählen', 'Select page range');
  AddPair('Seitenzahl', 'Page count');
  AddPair('Zoomstufe', 'Zoom level');
  AddPair('Drehwinkel', 'Rotation angle');
  AddPair('Dateigröße', 'File size');
  AddPair('Erstellt am', 'Created on');
  AddPair('Geändert am', 'Modified on');
  AddPair('Zuletzt geöffnet', 'Last opened');
  AddPair('Zuletzt verwendete Dateien', 'Recent files');
  AddPair('Zuletzt verwendete PDFs', 'Recent PDFs');
  AddPair('Verlauf', 'History');
  AddPair('Verlauf leeren', 'Clear history');
  AddPair('Arbeitsbereich auswählen', 'Select workspace');
  AddPair('Gespeicherte Arbeitsbereiche', 'Saved workspaces');
  AddPair('Neuen Arbeitsbereich erstellen', 'Create new workspace');
  AddPair('Arbeitsbereich wurde gespeichert.', 'Workspace saved.');
  AddPair('Arbeitsbereich konnte nicht gespeichert werden.', 'Could not save workspace.');
  AddPair('Arbeitsbereich wurde gelöscht.', 'Workspace deleted.');
  AddPair('Arbeitsbereich konnte nicht geöffnet werden.', 'Could not open workspace.');
  AddPair('Bitte einen Namen eingeben.', 'Please enter a name.');
  AddPair('Bitte einen Arbeitsbereich auswählen.', 'Please select a workspace.');
  AddPair('Name des Arbeitsbereichs', 'Workspace name');
  AddPair('Der Arbeitsbereich existiert bereits.', 'The workspace already exists.');
  AddPair('Wirklich löschen?', 'Really delete?');
  AddPair('Möchten Sie wirklich löschen?', 'Do you really want to delete this?');
  AddPair('Vorgang abgeschlossen.', 'Operation completed.');
  AddPair('Vorgang fehlgeschlagen.', 'Operation failed.');
  AddPair('Vorgang abgebrochen.', 'Operation cancelled.');
  AddPair('Nicht gespeichert', 'Not saved');
  AddPair('Ungespeicherte Änderungen', 'Unsaved changes');
  AddPair('Änderungen speichern', 'Save changes');
  AddPair('Änderungen verwerfen', 'Discard changes');
  AddPair('Erneut versuchen', 'Try again');
  AddPair('Wiederholen', 'Retry');
  AddPair('Anwenden', 'Apply');
  AddPair('Einstellungen', 'Settings');
  AddPair('Allgemein', 'General');
  AddPair('Sprache', 'Language');
  AddPair('Englisch', 'English');
  AddPair('Info', 'About');
  AddPair(' Anlage(n) wurden hinzugefügt:', ' attachment(s) added:');
  AddPair(' · Portable PDF-Anwendung für Windows 64-Bit', ' · Portable PDF application for Windows 64-bit');
  AddPair('" mit dem zugeordneten Windows-Programm öffnen?', '" with its associated Windows application?');
  AddPair('Strg+F: PDF-Text suchen | F3: nächster Treffer | Umschalt+F3: vorheriger Treffer', 'Ctrl+F: Find PDF text | F3: Next match | Shift+F3: Previous match');
  AddPair('Arbeitsbereich', 'Workspace');
  AddPair('Name des Arbeitsbereichs:', 'Workspace name:');
  AddPair('OK', 'OK');
  AddPair('PDF-Textsuche', 'PDF text search');
  AddPair('Suchbegriff:', 'Search term:');
  AddPair('Exit', 'Exit');

  AddPair('Beschreibung', 'Description');
  AddPair('Erweitert', 'Advanced');
  AddPair('Sicherheit', 'Security');
  AddPair('Dateiname:', 'File name:');
  AddPair('Dateigröße:', 'File size:');
  AddPair('Titel:', 'Title:');
  AddPair('Autor:', 'Author:');
  AddPair('Antragsteller:', 'Subject:');
  AddPair('Schlüsselwörter:', 'Keywords:');
  AddPair('Erstellt am:', 'Created on:');
  AddPair('Geändert am:', 'Modified on:');
  AddPair('Ersteller:', 'Application:');
  AddPair('PDF-Produzent:', 'PDF producer:');
  AddPair('PDF-Version:', 'PDF version:');
  AddPair('Standort:', 'Location:');
  AddPair('Anzahl der Seiten:', 'Number of pages:');
  AddPair('Seitengröße:', 'Page size:');
  AddPair('Schnelle Webansicht:', 'Fast web view:');
  AddPair('Verschlüsselt:', 'Encrypted:');
  AddPair('Verschlüsselung:', 'Encryption:');
  AddPair('Drucken erlaubt:', 'Printing allowed:');
  AddPair('Kopieren erlaubt:', 'Copying allowed:');
  AddPair('Ändern erlaubt:', 'Changing allowed:');
  AddPair('Nicht verfügbar', 'Not available');
  AddPair('Nicht verfügbar.', 'Not available.');
  AddPair('Querformat', 'Landscape');
  AddPair('Hochformat', 'Portrait');
  AddPair('40 Bit (PDF-Sicherheitsrevision 2)', '40-bit (PDF security revision 2)');
  AddPair('128 Bit (PDF-Sicherheitsrevision 3)', '128-bit (PDF security revision 3)');
  AddPair('128 Bit (PDF-Sicherheitsrevision 4)', '128-bit (PDF security revision 4)');
  AddPair('256-Bit AES', '256-bit AES');
  AddPair('Seitenbreite', 'Page width');
  AddPair('Benutzerdefiniert', 'Custom');
  AddPair('Keine PDF-Lesezeichen vorhanden', 'No PDF bookmarks available');
  AddPair('PDF-Anlage extrahieren', 'Extract PDF attachment');
  AddPair('Alle Dateien (*.*)|*.*', 'All files (*.*)|*.*');
  AddPair('PDF-Dateien (*.pdf)|*.pdf', 'PDF files (*.pdf)|*.pdf');
  AddPair('PDF ohne die markierten Anlagen speichern', 'Save PDF without selected attachments');
  AddPair('Die Anlage konnte aus Sicherheitsgründen nicht direkt gestartet werden.', 'This attachment cannot be opened directly for security reasons.');
  AddPair('Neuer Name:', 'New name:');
  AddPair('Options', 'Options');
  AddPair('Die Anlage', 'The attachment');
  AddPair('mit dem zugeordneten Windows-Programm öffnen?', 'open with its associated Windows application?');
  AddPair('Bit (Verfahren unbekannt)', 'bit (method unknown)');
  AddPair('Freihand', 'Freehand');
  AddPair('Linie', 'Line');
  AddPair('Rechteck', 'Rectangle');
  AddPair('Ellipse', 'Ellipse');
  AddPair('Die Anlage öffnen?', 'Open the attachment?');
  AddPair(' von ', ' of ');
  AddPair('Verfahren unbekannt', 'method unknown');
  AddPair('Anlage(n)', 'attachment(s)');
  AddPair('E-Mail an FreePDF64@outlook.com', 'Email FreePDF64@outlook.com');
  AddPair('Workspace', 'Workspace');
  AddPair('Berechtigungen', 'Permissions');
  AddPair('Drucken:', 'Printing:');
  AddPair('Hochauflösend drucken:', 'High-resolution printing:');
  AddPair('Modifizieren:', 'Modifying:');
  AddPair('Kopieren von Inhalt:', 'Content copying:');
  AddPair('Kopieren von Inhalt für Barrierefreiheit:', 'Content copying for accessibility:');
  AddPair('Kommentieren:', 'Commenting:');
  AddPair('Formulare ausfüllen:', 'Filling in forms:');
  AddPair('Dokumentzusammenstellung:', 'Document assembly:');
  AddPair('Erlaubt', 'Allowed');
  AddPair('Nicht erlaubt', 'Not allowed');
  AddPair('Verschlüsselt', 'Encrypted');
  AddPair('Verschlüsselung', 'Encryption');
  AddPair('PDF davor einfügen ...', 'Insert PDF before ...');
  AddPair('PDF danach einfügen ...', 'Insert PDF after ...');
  AddPair('PDF-Datei zum Einfügen auswählen', 'Select PDF to insert');
  AddPair('%d PDF-Seite(n) eingefügt.', '%d PDF page(s) inserted.');
  AddPair('PDF konnte nicht eingefügt werden: ', 'Could not insert PDF: ');
end;

procedure InitializePDFLanguage(const IniPath: string);
var Ini: TIniFile; DefaultLanguage: string;
begin
  EnsurePairs;
  FIniPath := IniPath;
  if (GetUserDefaultUILanguage and $03FF) = LANG_GERMAN then
    DefaultLanguage := 'de'
  else
    DefaultLanguage := 'en';
  Ini := TIniFile.Create(IniPath);
  try
    FLanguage := LowerCase(Ini.ReadString('Language', 'Current', DefaultLanguage));
  finally
    Ini.Free;
  end;
  if (FLanguage <> 'de') and (FLanguage <> 'en') then
    FLanguage := DefaultLanguage;
end;

procedure SetPDFLanguage(const ALanguage: string);
var Ini: TIniFile;
begin
  if (ALanguage <> 'de') and (ALanguage <> 'en') then Exit;
  FLanguage := ALanguage;
  if FIniPath = '' then Exit;
  Ini := TIniFile.Create(FIniPath);
  try
    Ini.WriteString('Language', 'Current', FLanguage);
  finally
    Ini.Free;
  end;
end;

function PDFLanguage: string;
begin Result := FLanguage; end;

function Tr(const German: string): string;
var I: Integer;
begin
  EnsurePairs;
  Result := German;
  if FLanguage <> 'en' then
  begin
    I := PairsEN.IndexOf(German);
    if I >= 0 then Result := PairsDE[I];
    Exit;
  end;
  I := PairsDE.IndexOf(German);
  if I >= 0 then
    Result := PairsEN[I]
  else
  begin
    // Auch bereits übersetzte Texte wieder in die jeweils andere Sprache
    // zurückübersetzen, damit wiederholte Sprachwechsel zuverlässig sind.
    I := PairsEN.IndexOf(German);
    if I >= 0 then Result := PairsEN[I];
  end;
end;

procedure TranslatePDFMenu(AMenu: TMenuItem);
var
  I, PairIndex: Integer;
begin
  if AMenu = nil then Exit;
  EnsurePairs;
  if AMenu.Caption <> '-' then
  begin
    // Tag nicht verwenden: Kontextmenues benutzen Tag fuer Aktionen
    // (beispielsweise +90/-90 Grad beim Drehen).
    PairIndex := PairsDE.IndexOf(AMenu.Caption);
    if PairIndex < 0 then
      PairIndex := PairsEN.IndexOf(AMenu.Caption);
    if PairIndex >= 0 then
    begin
      if FLanguage = 'en' then
        AMenu.Caption := PairsEN[PairIndex]
      else
        AMenu.Caption := PairsDE[PairIndex];
    end;
  end;
  for I := 0 to AMenu.Count - 1 do
    TranslatePDFMenu(AMenu.Items[I]);
end;

procedure TranslatePDFControls(AParent: TWinControl);
var I, J, SavedIndex: Integer; C: TControl; Combo: TComboBox; LV: TListView; TV: TTreeView; SavedText: string;
begin
  if AParent = nil then Exit;
  for I := 0 to AParent.ControlCount - 1 do
  begin
    C := AParent.Controls[I];
    if C.Hint <> '' then C.Hint := Tr(C.Hint);
    if C is TLabel then TLabel(C).Caption := Tr(TLabel(C).Caption)
    else if C is TButton then TButton(C).Caption := Tr(TButton(C).Caption)
    else if C is TCheckBox then TCheckBox(C).Caption := Tr(TCheckBox(C).Caption)
    else if C is TRadioButton then TRadioButton(C).Caption := Tr(TRadioButton(C).Caption)
    else if C is TGroupBox then TGroupBox(C).Caption := Tr(TGroupBox(C).Caption)
    else if C is TPanel then TPanel(C).Caption := Tr(TPanel(C).Caption)
    else if C is TStaticText then TStaticText(C).Caption := Tr(TStaticText(C).Caption);
    if C is TComboBox then
    begin
      Combo := TComboBox(C);
      begin
        SavedIndex := Combo.ItemIndex;
        SavedText := Combo.Text;
        for J := 0 to Combo.Items.Count - 1 do
          Combo.Items[J] := Tr(Combo.Items[J]);
        if Combo.Style = csDropDownList then
          Combo.ItemIndex := SavedIndex
        else if SavedText <> '' then
          Combo.Text := Tr(SavedText);
      end;
    end;
    if C is TListView then
    begin
      LV := TListView(C);
      for J := 0 to LV.Columns.Count - 1 do LV.Columns[J].Caption := Tr(LV.Columns[J].Caption);
    end;
    if C is TTreeView then
    begin
      TV := TTreeView(C);
      for J := 0 to TV.Items.Count - 1 do
        TV.Items[J].Text := Tr(TV.Items[J].Text);
    end;
    if C is TWinControl then TranslatePDFControls(TWinControl(C));
  end;
end;

initialization

finalization
  PairsDE.Free;
  PairsEN.Free;

end.

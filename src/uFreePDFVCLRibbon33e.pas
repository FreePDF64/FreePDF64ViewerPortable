unit uFreePDFVCLRibbon33e;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Buttons,
  Vcl.Graphics, Vcl.ImgList, Vcl.VirtualImageList, Winapi.Windows, uPDFLanguage;

type
  TVCLRibbonCommandEvent = procedure(Sender: TObject; CommandId: Integer;
    const Value: string) of object;

  // Paint the icon explicitly, including for disabled commands.  VCL's
  // TSpeedButton disabled-glyph handling is not used for the visible icon.
  TRibbonSpeedButton = class(TSpeedButton)
  private
    FIcon: Vcl.Graphics.TBitmap;
    FOrangeActive: Boolean;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetRibbonIcon(const AFileName: string);
    procedure SetViewModeIcon(AMode: Integer; AColor: TColor);
    procedure SetOrangeActive(Value: Boolean);
  end;

  TFreePDFVCLRibbon = class(TPanel)
  private
    FTabs: TPanel;
    FContent: TPanel;
    FPages: TList;
    FTabPanels: TList;
    FActiveTab: Integer;
    FUpdatingCombos: Boolean;
    FOnCommand: TVCLRibbonCommandEvent;
    FThemeBackground, FThemeText, FThemeAccent: TColor;
    FIconFolder: string;
    FIconImages: TVirtualImageList;
    FCollapseButton: TSpeedButton;
    FBottomDivider: TBevel;
    FCollapsed: Boolean;
    FOnCollapseChanged: TNotifyEvent;
    FTabPreviewCheck: TCheckBox;
    FUpdateAutoCheck: TCheckBox;
    FUpdatingAutoCheck: Boolean;
    FUpdatingTabPreviewCheck: Boolean;
    FPageEdit: TEdit;
    FZoomEdit: TEdit;
    FPageStatusTimer: TTimer;
    FLayoutReady: Boolean;
    FFourKGeometryApplied: Boolean;
    FScrollBack, FScrollForward: TButton;
    FGroupScroll: array[0..6] of Integer;
    procedure ScrollGroups(Sender: TObject);
    procedure UpdateGroupViewport;
    procedure ApplyFourKGeometry;
    procedure PageEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ZoomEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PageStatusTick(Sender: TObject);
    procedure CollapseClick(Sender: TObject);
    procedure TabDoubleClick(Sender: TObject);
    procedure SetCollapsed(Value: Boolean);
    procedure TabClick(Sender: TObject);
    procedure FileTabMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure UpdateFileTabHint;
    procedure CommandClick(Sender: TObject);
    procedure TabPreviewCheckClick(Sender: TObject);
    procedure UpdateAutoCheckClick(Sender: TObject);
    procedure ComboChanged(Sender: TObject);
    procedure FitPageClick(Sender: TObject);
    procedure ShowTab(Index: Integer);
    procedure AddTab(const ACaption: string);
    procedure AddGroup(TabIndex: Integer; const ACaption: string);
    procedure AddCommand(TabIndex, CommandId: Integer; const ACaption: string;
      IsCombo: Boolean);
    procedure BuildRibbon;
    procedure LayoutGroups;
    procedure LoadGlyph(Button: TSpeedButton; CommandId: Integer);
    procedure RefreshCommandIcons;
    function ResolveIconFile(CommandId: Integer; Large, Enabled: Boolean): string;
    function DisplayCaption(CommandId: Integer; const Caption: string): string;
    procedure UpdateTabColors;
    function FindCommand(CommandId: Integer): TControl;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyPalette(Background, TextColor, Accent: TColor);
    procedure SetCommandEnabled(CommandId: Integer; Enabled: Boolean);
    procedure SetCommandOrange(CommandId: Integer; Active: Boolean);
    procedure SetCommandText(CommandId: Integer; const ACaption, AHint: string);
    procedure RefreshLanguage;
    procedure SetTabPreviewChecked(Value: Boolean);
    procedure SetUpdateAutoChecked(Value: Boolean);
    procedure SetComboValue(CommandId: Integer; const Value: string);
    procedure SetComboItems(CommandId: Integer; const Values: array of string);
    procedure SetPageStatus(APage, ACount: Integer);
    procedure SetZoomPercent(APercent: Integer; AEnabled: Boolean);
    procedure SelectTab(Index: Integer);
    function ActiveTabIndex: Integer;
    property OnCommand: TVCLRibbonCommandEvent read FOnCommand write FOnCommand;
    property Collapsed: Boolean read FCollapsed write SetCollapsed;
    property OnCollapseChanged: TNotifyEvent read FOnCollapseChanged write FOnCollapseChanged;
  end;

implementation

{$R RibbonIconsTablerEmbedded.res}

function LoadEmbeddedRibbonBitmap(ABitmap: Vcl.Graphics.TBitmap;
  const AName: string): Boolean;
var
  ResourceName: string;
  ResourceStream: TResourceStream;
  Data: TMemoryStream;
begin
  Result := False;
  ResourceName := UpperCase(ChangeFileExt(ExtractFileName(AName), ''));
  ResourceName := StringReplace(ResourceName, '-', '_NEG_', [rfReplaceAll]);
  if ResourceName = '' then Exit;
  if FindResource(HInstance, PChar(ResourceName), RT_RCDATA) = 0 then Exit;
  ResourceStream := TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
  try
    // RCDATA holds complete BMP files, including the bitmap file header.
    Data := TMemoryStream.Create;
    try
      Data.CopyFrom(ResourceStream, 0);
      Data.Position := 0;
      ABitmap.LoadFromStream(Data);
      ABitmap.TransparentMode := tmFixed;
      ABitmap.TransparentColor := clFuchsia;
      ABitmap.Transparent := True;
      Result := True;
    finally
      Data.Free;
    end;
  finally
    ResourceStream.Free;
  end;
end;


function RibbonGermanText(const S: string): string;
begin
  Result := S;
  // Convert translated UI strings back to their German source keys. This also
  // lets dynamic command captions be refreshed repeatedly without losing state.
  if SameText(PDFLanguage, 'en') then
  begin
    if S = 'File' then Result := 'Datei'
    else if S = 'Start' then Result := 'Start'
    else if S = 'View' then Result := 'Ansicht'
    else if S = 'Edit' then Result := 'Bearbeiten'
    else if S = 'Objects' then Result := 'Objekte'
    else if S = 'Tools' then Result := 'Werkzeuge'
    else if S = 'Help' then Result := 'Hilfe'
    else if S = 'Display' then Result := 'Anzeigen'
    else if S = 'Pages' then Result := 'Seiten'
    else if S = 'Graphics' then Result := 'Bilder'
    else if S = 'Compare' then Result := 'Vergleichen'
    else if S = 'Text' then Result := 'Text'
    else if S = 'Annotations' then Result := 'Anmerkungen'
    else if S = 'Changes' then Result := 'Änderungen'
    else if S = 'Drawing' then Result := 'Zeichnen'
    else if S = 'More drawing tools' then Result := 'Weitere Zeichenwerkzeuge'
    else if S = 'Font' then Result := 'Schrift'
    else if S = 'Watermarks' then Result := 'Wasserzeichen'
    else if S = 'Document' then Result := 'Dokument'
    else if S = 'Measurement' then Result := 'Messung'
    else if S = 'Redaction' then Result := 'Schwärzung'
    else if S = 'Units' then Result := 'Einheiten'
    else if S = 'Tabs' then Result := 'Registerkarten'
    else if S = 'Theme' then Result := 'Design'
    else if S = 'Language' then Result := 'Sprache / Language'
    else if S = 'Information' then Result := 'Information'
    else if S = 'Workspaces' then Result := 'Arbeitsbereiche'
    else if S = 'Search' then Result := 'Suche'
    else if S = 'Save / Export' then Result := 'Speichern / Export'
    else if S = 'Program' then Result := 'Programm'
    else if S = 'Open' then Result := 'Öffnen'
    else if S = 'Save' then Result := 'Speichern'
    else if S = 'Print' then Result := 'Drucken'
    else if S = 'Manage workspaces' then Result := 'Arbeitsbereiche verwalten'
    else if S = 'Save workspace' then Result := 'Arbeitsbereich speichern'
    else if S = 'Search PDF' then Result := 'PDF durchsuchen'
    else if S = 'Search all PDFs' then Result := 'Alle PDFs durchsuchen'
    else if S = 'Thumbnails' then Result := 'Miniaturen'
    else if S = 'Fit page' then Result := 'Seite anpassen'
    else if S = 'Zoom +' then Result := 'Zoom +'
    else if S = 'Zoom -' then Result := 'Zoom -'
    else if S = '100 %' then Result := '100 %'
    else if S = 'Split view' then Result := 'Doppelansicht'
    else if S = 'Single page' then Result := 'Einzelansicht'
    else if S = 'Continuous' then Result := 'Durchgehend'
    else if S = 'Single page scrolling' then Result := 'Seitenweise'
    else if S = 'Hand tool' then Result := 'Hand-Werkzeug'
    else if S = 'Previous page' then Result := 'Vorherige Seite'
    else if S = 'Next page' then Result := 'Nächste Seite'
    else if S = 'Zoom in' then Result := 'Bild vergrößern'
    else if S = 'Zoom out' then Result := 'Bild verkleinern'
    else if S = 'Whole image' then Result := 'Ganzes Bild'
    else if S = 'Rotate right' then Result := 'Bild rechts drehen'
    else if S = 'Rotate left' then Result := 'Bild links drehen'
    else if S = 'Fit width' then Result := 'Bildbreite'
    else if S = 'Original size' then Result := 'Originalgröße'
    else if S = 'Save image' then Result := 'Bild speichern'
    else if S = 'Print image' then Result := 'Bild drucken'
    else if S = 'Prev. TIFF' then Result := 'TIFF zurück'
    else if S = 'Next TIFF' then Result := 'TIFF weiter'
    else if S = 'Visually compare PDFs' then Result := 'PDFs visuell vergleichen'
    else if S = 'Insert text' then Result := 'Text einfügen'
    else if S = 'Highlight text' then Result := 'Text hervorheben'
    else if S = 'Add comment' then Result := 'Kommentar hinzufügen'
    else if S = 'Manage comments' then Result := 'Kommentare verwalten'
    else if S = 'Undo' then Result := 'Rückgängig'
    else if S = 'Redo' then Result := 'Wiederholen'
    else if S = 'Freehand' then Result := 'Freihand'
    else if S = 'Line' then Result := 'Linie'
    else if S = 'Rectangle' then Result := 'Rechteck'
    else if S = 'Ellipse' then Result := 'Ellipse'
    else if S = 'Line width ...' then Result := 'Strichstärke ...'
    else if S = 'Color ...' then Result := 'Farbe ...'
    else if S = 'Redact (visual)' then Result := 'Schwärzen (optisch)'
    else if S = 'Font ...' then Result := 'Schriftart ...'
    else if S = 'Font size ...' then Result := 'Schriftgröße ...'
    else if S = 'Text color ...' then Result := 'Textfarbe ...'
    else if S = 'Insert image' then Result := 'Bild einfügen'
    else if S = 'Add signature' then Result := 'Unterschrift hinzufügen'
    else if S = 'Add hyperlink' then Result := 'Hyperlink hinzufügen'
    else if S = 'Manage hyperlinks' then Result := 'Hyperlinks verwalten ...'
    else if S = 'Text watermark' then Result := 'Textwasserzeichen'
    else if S = 'Image watermark' then Result := 'Bildwasserzeichen'
    else if S = 'Document properties' then Result := 'Dokumenteigenschaften'
    else if S = 'PDF attachments' then Result := 'PDF-Anlagen'
    else if S = 'Measure' then Result := 'Messen'
    else if S = 'Redact' then Result := 'Schwärzen'
    else if S = 'Apply redaction permanently ...' then Result := 'Endgültig schwärzen ...'
    else if S = 'Scale ...' then Result := 'Maßstab ...'
    else if S = 'Measurement color ...' then Result := 'Messfarbe ...'
    else if S = 'Measurement report ...' then Result := 'Messbericht ...'
    else if S = 'mm' then Result := 'mm'
    else if S = 'cm' then Result := 'cm'
    else if S = 'Inch' then Result := 'Zoll'
    else if S = 'Show tab previews' then Result := 'Registerkartenvorschau anzeigen'
    else if S = 'Standard' then Result := 'Standard'
    else if S = 'Modern Light' then Result := 'Modern Hell'
    else if S = 'Classic Blue' then Result := 'Klassisch Blau'
    else if S = 'Classic Gray' then Result := 'Klassisch Grau'
    else if S = 'Ice Gray' then Result := 'Eisgrau'
    else if S = 'German' then Result := 'Deutsch'
    else if S = 'English' then Result := 'English'
    else if S = 'Check for updates' then Result := 'Nach Updates suchen ...'
    else if S = 'Check weekly' then Result := 'Wöchentlich prüfen'
    else if S = 'Feature overview' then Result := 'Funktionsübersicht'
    else if S = 'About FreePDF64' then Result := 'Über FreePDF64'
    else if S = 'Home' then Result := 'Home'
    else if S = 'Open PDFs and images ...' then Result := 'PDFs und Bilder öffnen ...'
    else if S = 'Reload PDF (discard changes)' then Result := 'PDF neu laden (Änderungen verwerfen)'
    else if S = 'PDF save as ...' then Result := 'PDF speichern unter ...'
    else if S = 'Save changes directly to the open PDF (Ctrl+S).' then
      Result := 'Änderungen direkt in der geöffneten PDF speichern (Strg+S).'
    else if S = 'Export pages as images ...' then Result := 'Seiten als Bilder exportieren ...'
    else if S = 'Export pages as text ...' then Result := 'Seiten als Text exportieren ...'
    else if S = 'Extract PDF images ...' then Result := 'PDF-Bilder extrahieren ...'
    else if S = 'Merge PDFs ...' then Result := 'PDFs zusammenführen ...'
    else if S = 'Exit' then Result := 'Beenden'
    else if S = 'Enable / disable tab previews' then Result := 'Registerkartenvorschau anzeigen'
    else if S = 'Preview when hovering over a PDF tab' then Result := 'Vorschau beim Überfahren einer PDF-Registerkarte'
    else if S = 'Collapse / expand Ribbon' then Result := 'Ribbon ein-/ausklappen'
    else if S = 'Scroll Ribbon groups left' then Result := 'Ribbon-Gruppen nach links'
    else if S = 'Scroll Ribbon groups right' then Result := 'Ribbon-Gruppen nach rechts'
    else if S = 'Enter page number and press Enter' then Result := 'Seitennummer eingeben und Enter drücken'
    else if S = 'Select zoom mode' then Result := 'Zoommodus auswählen'
    else if S = 'Measurement' then Result := 'Messung'
    else if S = 'Redaction' then Result := 'Schwärzung'
    else if S = 'Switch to single-page view' then Result := 'Zur Einzelansicht wechseln'
    else if S = 'Switch to split view' then Result := 'Zur Doppelansicht wechseln'
    else if S = 'Switch to continuous view' then Result := 'Zur durchgehenden Ansicht wechseln'
    else if S = 'Switch to page-by-page view' then Result := 'Zur seitenweisen Ansicht wechseln'
    else if S = 'Hand tool: off' then Result := 'Hand-Werkzeug ausschalten'
    else if S = 'Move PDF page with the mouse' then Result := 'PDF-Seite mit der Maus verschieben'
    else if S = 'Hand: on' then Result := 'Hand: Ein'
    else if S = 'Page width' then Result := 'Seitenbreite'
    else if S = 'Full page' then Result := 'Ganze Seite'
    else if S = 'Original size (100 %)' then Result := 'Originalgröße (100 %)'
    else if S = 'Custom' then Result := 'Benutzerdefiniert'
    else if S = 'Page %d of %d' then Result := '%d von %d'
    else if S = 'Page – of –' then Result := 'Seite – von –';
  end;
end;

function RibbonText(const German: string): string;
begin
  Result := German;
  if SameText(PDFLanguage, 'en') then
  begin
    // Keep this map centralized so tabs, groups, commands and hints use the
    // same English terminology throughout the Ribbon.
    if German = 'Datei' then Result := 'File'
    else if German = 'Ansicht' then Result := 'View'
    else if German = 'Bearbeiten' then Result := 'Edit'
    else if German = 'Objekte' then Result := 'Objects'
    else if German = 'Werkzeuge' then Result := 'Tools'
    else if German = 'Hilfe' then Result := 'Help'
    else if German = 'Anzeigen' then Result := 'Display'
    else if German = 'Seiten' then Result := 'Pages'
    else if German = 'Bilder' then Result := 'Graphics'
    else if German = 'Vergleichen' then Result := 'Compare'
    else if German = 'Anmerkungen' then Result := 'Annotations'
    else if German = 'Änderungen' then Result := 'Changes'
    else if German = 'Zeichnen' then Result := 'Drawing'
    else if German = 'Weitere Zeichenwerkzeuge' then Result := 'More drawing tools'
    else if German = 'Schrift' then Result := 'Font'
    else if German = 'Wasserzeichen' then Result := 'Watermarks'
    else if German = 'Dokument' then Result := 'Document'
    else if German = 'Prüfen' then Result := 'Redaction'
    else if German = 'Schwärzung' then Result := 'Redaction'
    else if German = 'Messung' then Result := 'Measurement'
    else if German = 'Einheiten' then Result := 'Units'
    else if German = 'Registerkarten' then Result := 'Tabs'
    else if German = 'Design' then Result := 'Theme'
    else if German = 'Sprache / Language' then Result := 'Language'
    else if German = 'Nach Updates suchen ...' then Result := 'Check for updates'
    else if German = 'Wöchentlich prüfen' then Result := 'Check weekly'
    else if German = 'Information' then Result := 'Information'
    else if German = 'Arbeitsbereiche' then Result := 'Workspaces'
    else if German = 'Suche' then Result := 'Search'
    else if German = 'Speichern / Export' then Result := 'Save / Export'
    else if German = 'Programm' then Result := 'Program'
    else if German = 'Öffnen' then Result := 'Open'
    else if German = 'Speichern' then Result := 'Save'
    else if German = 'Drucken' then Result := 'Print'
    else if German = 'Arbeitsbereiche verwalten' then Result := 'Manage workspaces'
    else if German = 'Arbeitsbereich speichern' then Result := 'Save workspace'
    else if German = 'PDF durchsuchen' then Result := 'Search PDF'
    else if German = 'Alle PDFs durchsuchen' then Result := 'Search all PDFs'
    else if German = 'Miniaturen' then Result := 'Thumbnails'
    else if German = 'Seite anpassen' then Result := 'Fit page'
    else if German = 'Doppelansicht' then Result := 'Split view'
    else if German = 'Einzelansicht' then Result := 'Single page'
    else if German = 'Seitenweise' then Result := 'Single page scrolling'
    else if German = 'Durchgehend' then Result := 'Continuous'
    else if German = 'Hand-Werkzeug' then Result := 'Hand tool'
    else if German = 'Vorherige Seite' then Result := 'Previous page'
    else if German = 'Nächste Seite' then Result := 'Next page'
    else if German = 'Bild vergrößern' then Result := 'Zoom in'
    else if German = 'Bild verkleinern' then Result := 'Zoom out'
    else if German = 'Ganzes Bild' then Result := 'Whole image'
    else if German = 'Bild rechts drehen' then Result := 'Rotate right'
    else if German = 'Bild links drehen' then Result := 'Rotate left'
    else if German = 'Bildbreite' then Result := 'Fit width'
    else if German = 'Originalgröße' then Result := 'Original size'
    else if German = 'Bild speichern' then Result := 'Save image'
    else if German = 'Bild drucken' then Result := 'Print image'
    else if German = 'TIFF zurück' then Result := 'Prev. TIFF'
    else if German = 'TIFF weiter' then Result := 'Next TIFF'
    else if German = 'PDFs visuell vergleichen' then Result := 'Visually compare PDFs'
    else if German = 'Text einfügen' then Result := 'Insert text'
    else if German = 'Text hervorheben' then Result := 'Highlight text'
    else if German = 'Kommentar hinzufügen' then Result := 'Add comment'
    else if German = 'Kommentare verwalten' then Result := 'Manage comments'
    else if German = 'Rückgängig' then Result := 'Undo'
    else if German = 'Wiederholen' then Result := 'Redo'
    else if German = 'Freihand' then Result := 'Freehand'
    else if German = 'Linie' then Result := 'Line'
    else if German = 'Rechteck' then Result := 'Rectangle'
    else if German = 'Ellipse' then Result := 'Ellipse'
    else if German = 'Strichstärke ...' then Result := 'Line width ...'
    else if German = 'Farbe ...' then Result := 'Color ...'
    else if German = 'Schwärzen (optisch)' then Result := 'Redact (visual)'
    else if German = 'Schriftart ...' then Result := 'Font ...'
    else if German = 'Schriftgröße ...' then Result := 'Font size ...'
    else if German = 'Textfarbe ...' then Result := 'Text color ...'
    else if German = 'Bild einfügen' then Result := 'Insert image'
    else if German = 'Unterschrift hinzufügen' then Result := 'Add signature'
    else if German = 'Hyperlink hinzufügen' then Result := 'Add hyperlink'
    else if German = 'Hyperlinks verwalten ...' then Result := 'Manage hyperlinks'
    else if German = 'Textwasserzeichen' then Result := 'Text watermark'
    else if German = 'Bildwasserzeichen' then Result := 'Image watermark'
    else if German = 'Dokumenteigenschaften' then Result := 'Document properties'
    else if German = 'PDF-Anlagen' then Result := 'PDF attachments'
    else if German = 'Messen' then Result := 'Measure'
    else if German = 'Schwärzen' then Result := 'Redact'
    else if German = 'Endgültig schwärzen ...' then Result := 'Apply redaction permanently ...'
    else if German = 'Maßstab ...' then Result := 'Scale ...'
    else if German = 'Messfarbe ...' then Result := 'Measurement color ...'
    else if German = 'Messbericht ...' then Result := 'Measurement report ...'
    else if German = 'Zoll' then Result := 'Inch'
    else if German = 'Registerkartenvorschau anzeigen' then Result := 'Show tab previews'
    else if German = 'Vorschau beim Überfahren einer PDF-Registerkarte' then Result := 'Preview when hovering over a PDF tab'
    else if German = 'Standard' then Result := 'Standard'
    else if German = 'Modern Hell' then Result := 'Modern Light'
    else if German = 'Klassisch Blau' then Result := 'Classic Blue'
    else if German = 'Klassisch Grau' then Result := 'Classic Gray'
    else if German = 'Eisgrau' then Result := 'Ice Gray'
    else if German = 'Deutsch' then Result := 'German'
    else if German = 'English' then Result := 'English'
    else if German = 'Funktionsübersicht' then Result := 'Feature overview'
    else if German = 'Über FreePDF64' then Result := 'About FreePDF64'
    else if German = 'PDFs und Bilder öffnen ...' then Result := 'Open PDFs and images ...'
    else if German = 'PDF neu laden (Änderungen verwerfen)' then Result := 'Reload PDF (discard changes)'
    else if German = 'PDF speichern unter ...' then Result := 'PDF save as ...'
    else if German = 'Änderungen direkt in der geöffneten PDF speichern (Strg+S).' then
      Result := 'Save changes directly to the open PDF (Ctrl+S).'
    else if German = 'Seiten als Bilder exportieren ...' then Result := 'Export pages as images ...'
    else if German = 'Seiten als Text exportieren ...' then Result := 'Export pages as text ...'
    else if German = 'PDF-Bilder extrahieren ...' then Result := 'Extract PDF images ...'
    else if German = 'PDFs zusammenführen ...' then Result := 'Merge PDFs ...'
    else if German = 'Beenden' then Result := 'Exit'
    else if German = 'Home' then Result := 'Home'
    else if German = 'Zur Einzelansicht wechseln' then Result := 'Switch to single-page view'
    else if German = 'Zur Doppelansicht wechseln' then Result := 'Switch to split view'
    else if German = 'Zur durchgehenden Ansicht wechseln' then Result := 'Switch to continuous view'
    else if German = 'Zur seitenweisen Ansicht wechseln' then Result := 'Switch to page-by-page view'
    else if German = 'Hand-Werkzeug ausschalten' then Result := 'Turn off hand tool'
    else if German = 'PDF-Seite mit der Maus verschieben' then Result := 'Move PDF page with the mouse'
    else if German = 'Hand: Ein' then Result := 'Hand: On'
    else if German = 'Zoommodus auswählen' then Result := 'Select zoom mode'
    else if German = 'Seitennummer eingeben und Enter drücken' then Result := 'Enter page number and press Enter'
    else if German = 'Ribbon ein-/ausklappen' then Result := 'Collapse / expand Ribbon'
    else if German = 'Ribbon-Gruppen nach links' then Result := 'Scroll Ribbon groups left'
    else if German = 'Ribbon-Gruppen nach rechts' then Result := 'Scroll Ribbon groups right'
    else if German = 'Seitenbreite' then Result := 'Page width'
    else if German = 'Ganze Seite' then Result := 'Full page'
    else if German = 'Originalgröße (100 %)' then Result := 'Original size (100 %)'
    else if German = 'Benutzerdefiniert' then Result := 'Custom';
  end;
end;

constructor TRibbonSpeedButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIcon := Vcl.Graphics.TBitmap.Create;
end;

destructor TRibbonSpeedButton.Destroy;
begin
  FIcon.Free;
  inherited Destroy;
end;

procedure TRibbonSpeedButton.SetRibbonIcon(const AFileName: string);
begin
  FIcon.SetSize(0, 0);
  if LoadEmbeddedRibbonBitmap(FIcon, AFileName) or
    ((AFileName <> '') and FileExists(AFileName)) then
  begin
    if FIcon.Empty then FIcon.LoadFromFile(AFileName);
    FIcon.TransparentMode := tmFixed;
    FIcon.TransparentColor := clFuchsia;
    FIcon.Transparent := True;
  end;
  Invalidate;
end;

// Draw the four PDF view-mode states as crisp monochrome page diagrams.
// These glyphs are generated in memory: no external RibbonIconsTabler folder
// and no additional resource-build step are required.
procedure TRibbonSpeedButton.SetViewModeIcon(AMode: Integer; AColor: TColor);
var
  B: Vcl.Graphics.TBitmap;
  Ink: TColor;
  procedure PageRect(X1, Y1, X2, Y2: Integer);
  begin
    B.Canvas.Rectangle(X1, Y1, X2, Y2);
  end;
begin
  B := FIcon;
  B.PixelFormat := pf24bit;
  B.SetSize(24, 24);
  B.Canvas.Brush.Color := clFuchsia;
  B.Canvas.FillRect(Rect(0, 0, 24, 24));
  Ink := AColor;
  if not Enabled then Ink := clGrayText;
  B.Canvas.Pen.Color := Ink;
  B.Canvas.Pen.Width := 2;
  B.Canvas.Brush.Style := bsClear;
  case AMode of
    1: begin // one PDF page
      PageRect(7, 3, 18, 21);
    end;
    2: begin // two PDF pages side by side
      PageRect(2, 4, 12, 20);
      PageRect(13, 4, 23, 20);
    end;
    3: begin // page-by-page: one sheet with page boundaries
      PageRect(5, 3, 20, 21);
      B.Canvas.MoveTo(9, 8); B.Canvas.LineTo(16, 8);
      B.Canvas.MoveTo(9, 12); B.Canvas.LineTo(16, 12);
    end;
    4: begin // continuous: three distinct sheets stacked vertically
      PageRect(5, 2, 20, 8);
      PageRect(5, 9, 20, 15);
      PageRect(5, 16, 20, 22);
    end;
  end;
  B.Canvas.Brush.Style := bsSolid;
  B.TransparentMode := tmFixed;
  B.TransparentColor := clFuchsia;
  B.Transparent := True;
  Invalidate;
end;

procedure TRibbonSpeedButton.SetOrangeActive(Value: Boolean);
begin
  if FOrangeActive = Value then Exit;
  FOrangeActive := Value;
  Invalidate;
end;

procedure TRibbonSpeedButton.Paint;
var
  X, Y, IconW, IconH, MaxIcon, AvailableH, PPI: Integer;
begin
  inherited Paint;
  if FOrangeActive and Enabled then
  begin
    Canvas.Pen.Color := RGB(240, 129, 20);
    Canvas.Pen.Width := 2;
    Canvas.Brush.Style := bsClear;
    Canvas.RoundRect(1, 1, Width - 1, Height - 1, 6, 6);
    Canvas.Brush.Style := bsSolid;
  end;
  if (FIcon = nil) or FIcon.Empty then Exit;

  // The ribbon uses its original 32/24 pixel icon dimensions at every
  // monitor DPI.  In particular, do not multiply bitmap dimensions by
  // CurrentPPI: VCL has already scaled the button and its text layout.
  // Scaling the icon again caused the 4K icons to overlap the captions.
  PPI := 96;
  if Parent <> nil then PPI := Parent.CurrentPPI;
  if Layout = blGlyphTop then
  begin
    MaxIcon := 32;
    if PPI >= 192 then MaxIcon := 48;
  end
  else
  begin
    MaxIcon := 24;
    if PPI >= 192 then MaxIcon := 36;
  end;
  IconW := FIcon.Width;
  IconH := FIcon.Height;
  if PPI >= 192 then
  begin
    IconW := MulDiv(IconW, 3, 2);
    IconH := MulDiv(IconH, 3, 2);
  end;
  if (IconW > MaxIcon) or (IconH > MaxIcon) then
  begin
    if IconW >= IconH then
    begin
      IconH := Max(1, MulDiv(IconH, MaxIcon, IconW));
      IconW := MaxIcon;
    end
    else
    begin
      IconW := Max(1, MulDiv(IconW, MaxIcon, IconH));
      IconH := MaxIcon;
    end;
  end;
  if Layout = blGlyphTop then
    AvailableH := Max(1, Height div 2 - 8)
  else
    AvailableH := Max(1, Height - 4);
  if IconH > AvailableH then
  begin
    IconW := Max(1, MulDiv(IconW, AvailableH, IconH));
    IconH := AvailableH;
  end;

  if Layout = blGlyphTop then
  begin
    X := (Width - IconW) div 2;
    Y := Max(2, Min(7, Margin));
  end
  else
  begin
    X := Max(2, Min(7, Margin));
    Y := (Height - IconH) div 2;
  end;
  Winapi.Windows.TransparentBlt(Canvas.Handle, X, Y, IconW, IconH,
    FIcon.Canvas.Handle, 0, 0, FIcon.Width, FIcon.Height,
    ColorToRGB(clFuchsia));
end;

constructor TFreePDFVCLRibbon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Align := alTop;
  Height := 149;
  DoubleBuffered := True;
  FPages := TList.Create;
  FTabPanels := TList.Create;
  FIconImages := TVirtualImageList.Create(Self);
  FIconFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'RibbonIconsTabler' + PathDelim;
  FTabs := TPanel.Create(Self);
  FTabs.Parent := Self;
  FTabs.Align := alTop;
  FTabs.Height := 32;
  // Clicking the unused tab-strip area toggles the Ribbon, just like the arrow.
  // Child tab panels retain their own click handlers.
  FTabs.OnClick := CollapseClick;
  FCollapseButton := TSpeedButton.Create(Self);
  FCollapseButton.Parent := FTabs;
  FCollapseButton.Caption := '^';
  FCollapseButton.Hint := RibbonText('Ribbon ein-/ausklappen');
  FCollapseButton.ShowHint := True;
  FCollapseButton.Flat := True;
  FCollapseButton.Align := alRight;
  FCollapseButton.Width := 32;
  FCollapseButton.OnClick := CollapseClick;
  FTabs.BevelOuter := bvNone;
  FTabs.DoubleBuffered := True;
  // Fine horizontal boundary between Ribbon and document/start page.
  FBottomDivider := TBevel.Create(Self);
  FBottomDivider.Parent := Self;
  FBottomDivider.Align := alBottom;
  FBottomDivider.Shape := bsBottomLine;
  FBottomDivider.Height := 2;
  FContent := TPanel.Create(Self);
  FContent.Parent := Self;
  FContent.Align := alClient;
  FContent.BevelOuter := bvNone;
  FContent.DoubleBuffered := True;
  FScrollBack := TButton.Create(Self);
  FScrollBack.Parent := FContent;
  FScrollBack.Caption := '<';
  FScrollBack.Hint := RibbonText('Ribbon-Gruppen nach links');
  FScrollBack.ShowHint := True;
  FScrollBack.OnClick := ScrollGroups;
  FScrollForward := TButton.Create(Self);
  FScrollForward.Parent := FContent;
  FScrollForward.Caption := '>';
  FScrollForward.Hint := RibbonText('Ribbon-Gruppen nach rechts');
  FScrollForward.ShowHint := True;
  FScrollForward.OnClick := ScrollGroups;
  FillChar(FGroupScroll, SizeOf(FGroupScroll), 0);
  BuildRibbon;
  LayoutGroups;
  // Datei links, danach Start/Ansicht/Bearbeiten/Objekte/Werkzeuge/Hilfe.
  // Die internen Registerkartenindizes bleiben unverändert.
  if FTabPanels.Count = 7 then
  begin
    TPanel(FTabPanels[6]).Left := 4;
    TPanel(FTabPanels[0]).Left := TPanel(FTabPanels[6]).Left + TPanel(FTabPanels[6]).Width + 2;
    TPanel(FTabPanels[1]).Left := TPanel(FTabPanels[0]).Left + TPanel(FTabPanels[0]).Width + 2;
    TPanel(FTabPanels[2]).Left := TPanel(FTabPanels[1]).Left + TPanel(FTabPanels[1]).Width + 2;
    TPanel(FTabPanels[3]).Left := TPanel(FTabPanels[2]).Left + TPanel(FTabPanels[2]).Width + 2;
    TPanel(FTabPanels[4]).Left := TPanel(FTabPanels[3]).Left + TPanel(FTabPanels[3]).Width + 2;
    TPanel(FTabPanels[5]).Left := TPanel(FTabPanels[4]).Left + TPanel(FTabPanels[4]).Width + 2;
  end;
  ApplyPalette(clWhite, clWindowText, TColor($00F1E8E1));
  ShowTab(0);
  FCollapseButton.BringToFront;
  FPageStatusTimer := TTimer.Create(Self);
  FPageStatusTimer.Interval := 500;
  FPageStatusTimer.OnTimer := PageStatusTick;
  FLayoutReady := True;
  UpdateGroupViewport;
end;


// The original ribbon geometry is defined at 96 DPI. On a 4K monitor
// Windows scales the VCL fonts but not every dynamically created control's
// coordinates. Scale only the bounds, once, after the ribbon has a parent.
// Do not change Font.Size: this preserves the native Segoe UI 8/9 pt sizes.
procedure TFreePDFVCLRibbon.ApplyFourKGeometry;
var
  PPI, I, J, K, CompactPercent: Integer;
  Page, Group: TWinControl;
  C: TControl;
  function GroupCaption(AGroup: TWinControl): string;
  var N: Integer;
  begin
    Result := '';
    for N := 0 to AGroup.ControlCount - 1 do
      if (AGroup.Controls[N] is TLabel) and
        (TLabel(AGroup.Controls[N]).Align = alBottom) then
        Exit(TLabel(AGroup.Controls[N]).Caption);
  end;
  procedure ScaleBounds(AControl: TControl);
  begin
    // Preserve horizontal DPI geometry, but use a shorter vertical
    // scale at 4K. The font size itself is never changed.
    AControl.SetBounds(MulDiv(AControl.Left, PPI, 96),
      MulDiv(AControl.Top, 175, 100),
      MulDiv(AControl.Width, PPI, 96),
      MulDiv(AControl.Height, 175, 100));
  end;
begin
  if FFourKGeometryApplied or not FLayoutReady or (Parent = nil) then Exit;
  PPI := Parent.CurrentPPI;
  // Keep the confirmed WQHD/125% layout exactly as before.
  if PPI < 192 then Exit;
  FFourKGeometryApplied := True;
  DisableAlign;
  try
    FTabs.DisableAlign;
    try
      FTabs.Height := MulDiv(FTabs.Height, 175, 100);
      FCollapseButton.Width := MulDiv(FCollapseButton.Width, PPI, 96);
      for I := 0 to FTabPanels.Count - 1 do
        ScaleBounds(TControl(FTabPanels[I]));
    finally
      FTabs.EnableAlign;
    end;
    for I := 0 to FPages.Count - 1 do
    begin
      Page := TWinControl(FPages[I]);
      for J := 0 to Page.ControlCount - 1 do
        if Page.Controls[J] is TPanel then
        begin
          Group := TWinControl(Page.Controls[J]);
          for K := 0 to Group.ControlCount - 1 do
          begin
            C := Group.Controls[K];
            if not (C is TBevel) then ScaleBounds(C);
          end;
          ScaleBounds(Group);
          // Only the requested groups become narrower at 4K.
          // Keep the existing vertical layout, icon sizes and font sizes.
          CompactPercent := 100;
          if I = 1 then
          begin
            if GroupCaption(Group) = 'Anzeigen' then CompactPercent := 88
            else if GroupCaption(Group) = 'Bilder' then CompactPercent := 82;
          end
          else if I = 6 then
          begin
            if GroupCaption(Group) = 'Speichern / Export' then CompactPercent := 95
            else if GroupCaption(Group) = 'Programm' then CompactPercent := 94;
          end;
          if CompactPercent <> 100 then
          begin
            Group.Width := MulDiv(Group.Width, CompactPercent, 100);
            for K := 0 to Group.ControlCount - 1 do
            begin
              C := Group.Controls[K];
              if (C is TBevel) or ((C is TLabel) and
                (TLabel(C).Align = alBottom)) then Continue;
              C.SetBounds(MulDiv(C.Left, CompactPercent, 100), C.Top,
                MulDiv(C.Width, CompactPercent, 100), C.Height);
            end;
          end;
          // Compact 4K groups without moving or shrinking command controls.
          // The bottom-aligned group caption uses the reclaimed space.
          // The 96-DPI group is 5 px shorter for WQHD; its 4K
          // scaled height already matches the previously tested geometry.
        end;
    end;
    if FCollapsed then
      Height := FTabs.Height
    else
      Height := MulDiv(148, 175, 100);
  finally
    EnableAlign;
  end;
  // Reassign icons after the parent and its final DPI are established.
  RefreshCommandIcons;
  UpdateGroupViewport;
end;

procedure TFreePDFVCLRibbon.Resize;
begin
  inherited Resize;
  ApplyFourKGeometry;
  UpdateGroupViewport;
end;

destructor TFreePDFVCLRibbon.Destroy;
begin
  FTabPanels.Free;
  FPages.Free;
  inherited;
end;

procedure TFreePDFVCLRibbon.AddTab(const ACaption: string);
var
  Page, TabPanel: TPanel;
  TabText: TLabel;
  W, X: Integer;
begin
  Page := TPanel.Create(Self);
  Page.Parent := FContent;
  Page.Align := alClient;
  Page.BevelOuter := bvNone;
  Page.DoubleBuffered := True;
  Page.Visible := False;
  FPages.Add(Page);

  // Do not access Self.Canvas before the ribbon has a Parent.
  // Canvas access would create the window handle during construction.
  W := Max(64, Length(RibbonText(ACaption)) * 7 + 18);
  X := 4;
  if FTabPanels.Count > 0 then
    with TPanel(FTabPanels[FTabPanels.Count - 1]) do
      X := Left + Width + 2;
  TabPanel := TPanel.Create(Self);
  TabPanel.Parent := FTabs;
  TabPanel.BevelOuter := bvNone;
  TabPanel.SetBounds(X, 2, W, 30);
  TabPanel.Tag := FPages.Count - 1;
  TabPanel.Cursor := crHandPoint;
  TabPanel.OnClick := TabClick;
  TabPanel.OnDblClick := TabDoubleClick;
  TabText := TLabel.Create(Self);
  TabText.Parent := TabPanel;
  TabText.Align := alClient;
  TabText.Alignment := taCenter;
  TabText.Layout := tlCenter;
  TabText.Transparent := True;
  // Match the command and dropdown typography in the VCL ribbon.
  TabText.Font.Name := 'Segoe UI';
  TabText.Font.Size := 8;
  TabText.Caption := RibbonText(ACaption);
  TabText.Tag := TabPanel.Tag;
  TabText.Cursor := crHandPoint;
  TabText.OnClick := TabClick;
  TabText.OnDblClick := TabDoubleClick;
  FTabPanels.Add(TabPanel);
  if TabPanel.Tag = 6 then
  begin
    TabPanel.OnMouseUp := FileTabMouseUp;
    TabText.OnMouseUp := FileTabMouseUp;
    UpdateFileTabHint;
  end;
end;

procedure TFreePDFVCLRibbon.AddGroup(TabIndex: Integer; const ACaption: string);
var
  Page, Group: TPanel;
  TitleLabel: TLabel;
begin
  Page := TPanel(FPages[TabIndex]);
  Group := TPanel.Create(Self);
  Group.Parent := Page;
  Group.BevelOuter := bvNone;
  Group.SetBounds(4, 3, 74, 110);
  // A subtle vertical separator at the right edge of each command group.
  with TBevel.Create(Self) do
  begin
    Parent := Group;
    Align := alRight;
    Width := 2;
    Shape := bsRightLine;
  end;
  Group.Tag := 0; // command count
  Group.DoubleBuffered := True;
  TitleLabel := TLabel.Create(Self);
  TitleLabel.Parent := Group;
  TitleLabel.Align := alBottom;
  TitleLabel.Height := 15;
  TitleLabel.Font.Name := 'Segoe UI';
  TitleLabel.Font.Size := 7;
  TitleLabel.Alignment := taCenter;
  TitleLabel.Layout := tlCenter;
  TitleLabel.Caption := RibbonText(ACaption);
  TitleLabel.Transparent := True;
end;

function RibbonCompactGroup(TabIndex: Integer; const GroupName: string): Boolean;
begin
  Result := ((TabIndex = 1) and (GroupName = 'Anzeigen')) or
    ((TabIndex = 2) and ((GroupName = 'Weitere Zeichenwerkzeuge') or
                         (GroupName = 'Schrift'))) or
    ((TabIndex = 1) and ((GroupName = 'Bilder') or (GroupName = 'Seiten') or (GroupName = 'Anzeigen'))) or
    (TabIndex = 6) or
    ((TabIndex = 5) and (GroupName = 'Updates'));
end;

function RibbonGroupTitle(Group: TPanel): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Group.ControlCount - 1 do
    if Group.Controls[I] is TLabel then
      if TLabel(Group.Controls[I]).Align = alBottom then
        Exit(RibbonGermanText(TLabel(Group.Controls[I]).Caption));
end;

function TFreePDFVCLRibbon.DisplayCaption(CommandId: Integer;
  const Caption: string): string;
begin
  Result := RibbonText(Caption);
  if SameText(PDFLanguage, 'en') then
  begin
    case CommandId of
      107: Result := 'Open' + #13#10 + 'workspaces';
      108: Result := 'Manage' + #13#10 + 'workspaces';
      196: Result := 'Save' + #13#10 + 'workspace';
      110: Result := 'Search' + #13#10 + 'PDF';
      111: Result := 'Search all' + #13#10 + 'PDFs';
      119: Result := 'Split' + #13#10 + 'view';
      129: Result := 'Undo'; 130: Result := 'Redo';
      178: Result := 'Scale'; 179: Result := 'Measure color'; 180: Result := 'Measure report';
      120: Result := 'Compare PDFs' + #13#10 + 'visually';
      123: Result := 'Insert' + #13#10 + 'text';
      124: Result := 'Highlight' + #13#10 + 'text';
      126: Result := 'Add' + #13#10 + 'comment';
      127: Result := 'Manage' + #13#10 + 'comments';
      133: Result := 'Insert' + #13#10 + 'image';
      134: Result := 'Add' + #13#10 + 'signature';
      135: Result := 'Add' + #13#10 + 'hyperlink';
      177: Result := 'Manage' + #13#10 + 'hyperlinks';
      137: Result := 'Text' + #13#10 + 'watermark';
      138: Result := 'Image' + #13#10 + 'watermark';
      141: Result := 'Document' + #13#10 + 'properties';
      142: Result := 'PDF' + #13#10 + 'attachments';
      143: Result := 'Extract' + #13#10 + 'images';
      194: Result := 'Apply' + #13#10 + 'redaction';
      154: Result := 'Modern' + #13#10 + 'Light';
      155: Result := 'Classic' + #13#10 + 'Gray';
      156: Result := 'Classic' + #13#10 + 'Blue';
      157: Result := 'Ice' + #13#10 + 'Gray';
      149: Result := 'Feature' + #13#10 + 'overview';
      150: Result := 'About' + #13#10 + 'FreePDF64';
      223: Result := 'Check for' + #13#10 + 'updates';
      224: Result := 'Merge' + #13#10 + 'PDFs';
    end;
    Exit;
  end;
  case CommandId of
    107: Result := 'Arbeitsbereiche' + #13#10 + 'öffnen';
    108: Result := 'Arbeitsbereiche' + #13#10 + 'verwalten';
    196: Result := 'Arbeitsbereich' + #13#10 + 'speichern';
    110: Result := 'PDF' + #13#10 + 'durchsuchen';
    111: Result := 'Alle PDFs' + #13#10 + 'durchsuchen';
    119: Result := 'Ansicht' + #13#10 + 'teilen';
    129: Result := 'Rückgängig';
    130: Result := 'Wiederholen';
    178: Result := 'Maßstab';
    179: Result := 'Messfarbe';
    180: Result := 'Messbericht';
    120: Result := 'PDFs visuell' + #13#10 + 'vergleichen';
    123: Result := 'Text' + #13#10 + 'einfügen';
    124: Result := 'Text' + #13#10 + 'hervorheben';
    126: Result := 'Kommentar' + #13#10 + 'hinzufügen';
    127: Result := 'Kommentare' + #13#10 + 'verwalten';
    133: Result := 'Bild' + #13#10 + 'einfügen';
    134: Result := 'Unterschrift' + #13#10 + 'hinzufügen';
    135: Result := 'Hyperlink' + #13#10 + 'hinzufügen';
    177: Result := 'Hyperlinks' + #13#10 + 'verwalten';
    137: Result := 'Text-' + #13#10 + 'wasserzeichen';
    138: Result := 'Bild-' + #13#10 + 'wasserzeichen';
    141: Result := 'Dokument-' + #13#10 + 'eigenschaften';
    142: Result := 'PDF-' + #13#10 + 'Anlagen';
    143: Result := 'Bilder' + #13#10 + 'extrahieren';
    194: Result := 'Endgültig' + #13#10 + 'schwärzen';
    154: Result := 'Modern' + #13#10 + 'Hell';
    155: Result := 'Klassisch' + #13#10 + 'Grau';
    156: Result := 'Klassisch' + #13#10 + 'Blau';
    157: Result := 'Eisgrau';
    149: Result := 'Funktions-' + #13#10 + 'übersicht';
    150: Result := 'Über' + #13#10 + 'FreePDF64';
    223: Result := 'Nach Updates' + #13#10 + 'suchen';
    224: Result := 'PDFs' + #13#10 + 'zusammenführen';
  end;
end;

function TFreePDFVCLRibbon.ResolveIconFile(CommandId: Integer;
  Large, Enabled: Boolean): string;
var
  SizeCode, ColorCode, Folder, Candidate: string;
  Depth: Integer;
begin
  // Look for the actual icon directory, including common Delphi output
  // directories (Win64\Debug, Win64\Release) when run from the IDE.
  // Reuse existing embedded Tabler glyphs for the new PDF view controls.
  case CommandId of
    214: CommandId := 207; // original size
    215: CommandId := 119; // split view
    216: CommandId := 114; // page list
    217: CommandId := 145; // temporary fallback for hand tool
    218: CommandId := 210; // previous page arrow, embedded Tabler icon
    219: CommandId := 211; // next page arrow, embedded Tabler icon
    220: CommandId := 104; // save-as uses existing embedded save glyph
    224: CommandId := 120; // use embedded PDF comparison glyph as fallback
  end;
  SizeCode := '_S';
  if Large then SizeCode := '_L';
  ColorCode := '';
  if not Enabled then ColorCode := '_D'
  else if (GetRValue(ColorToRGB(FThemeBackground)) * 299 +
           GetGValue(ColorToRGB(FThemeBackground)) * 587 +
           GetBValue(ColorToRGB(FThemeBackground)) * 114) < 128000 then
    ColorCode := '_W';
  // Embedded icons are the primary source; no external folder is required.
  Candidate := 'cmd' + IntToStr(CommandId) + SizeCode + ColorCode + '.bmp';
  if FindResource(HInstance, PChar(StringReplace(UpperCase(ChangeFileExt(Candidate, '')), '-', '_NEG_', [rfReplaceAll])), RT_RCDATA) <> 0 then
    Exit(Candidate);
  if Large then
  begin
    Candidate := 'cmd' + IntToStr(CommandId) + '_S' + ColorCode + '.bmp';
    if FindResource(HInstance, PChar(StringReplace(UpperCase(ChangeFileExt(Candidate, '')), '-', '_NEG_', [rfReplaceAll])), RT_RCDATA) <> 0 then
      Exit(Candidate);
  end;
  if ColorCode <> '' then
  begin
    Candidate := 'cmd' + IntToStr(CommandId) + SizeCode + '.bmp';
    if FindResource(HInstance, PChar(StringReplace(UpperCase(ChangeFileExt(Candidate, '')), '-', '_NEG_', [rfReplaceAll])), RT_RCDATA) <> 0 then
      Exit(Candidate);
  end;
  Folder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := '';
  for Depth := 0 to 4 do
  begin
    Candidate := Folder + 'RibbonIconsTabler' + PathDelim + 'cmd' +
      IntToStr(CommandId) + SizeCode + ColorCode + '.bmp';
    if FileExists(Candidate) then Exit(Candidate);
    // A missing large bitmap must not make the symbol disappear.
    if Large then
    begin
      Candidate := Folder + 'RibbonIconsTabler' + PathDelim + 'cmd' +
        IntToStr(CommandId) + '_S' + ColorCode + '.bmp';
      if FileExists(Candidate) then Exit(Candidate);
    end;
    // Fall back to the normal monochrome file only when a color variant
    // is absent, never to a different command's symbol.
    if ColorCode <> '' then
    begin
      Candidate := Folder + 'RibbonIconsTabler' + PathDelim + 'cmd' +
        IntToStr(CommandId) + SizeCode + '.bmp';
      if FileExists(Candidate) then Exit(Candidate);
    end;
    Folder := ExtractFileDir(ExcludeTrailingPathDelimiter(Folder));
    if Folder = '' then Break;
    Folder := IncludeTrailingPathDelimiter(Folder);
  end;
end;

procedure TFreePDFVCLRibbon.LoadGlyph(Button: TSpeedButton; CommandId: Integer);
var
  Filename: string;
  IconId: Integer;
begin
  IconId := CommandId;
  // The icon represents the NEXT available view mode, not the current mode.
  // The actual 215/216 icons are drawn by SetViewModeIcon below.
  // The resource icon is used only as the transparent text-layout placeholder.
  Filename := ResolveIconFile(IconId, Button.Layout = blGlyphTop,
    Button.Enabled);
  if Button is TRibbonSpeedButton then
  begin
    // Always use the dedicated icon renderer, including at 250% DPI.
    // The native glyph is a transparent placeholder for VCL text layout.
    // At 4K reserve the width of the larger, custom-painted compact icon.
    TRibbonSpeedButton(Button).SetRibbonIcon(Filename);
    // Keep the icon and the action synchronized, including after tab changes.
    // 215 toggles single/two-page, 216 toggles paged/continuous scrolling.
    if CommandId = 215 then
    begin
      if Button.Caption = 'Einzelansicht' then
        TRibbonSpeedButton(Button).SetViewModeIcon(1, Button.Font.Color)
      else
        TRibbonSpeedButton(Button).SetViewModeIcon(2, Button.Font.Color);
    end
    else if CommandId = 216 then
    begin
      if Button.Caption = 'Durchgehend' then
        TRibbonSpeedButton(Button).SetViewModeIcon(4, Button.Font.Color)
      else
        TRibbonSpeedButton(Button).SetViewModeIcon(3, Button.Font.Color);
    end;
    if Filename <> '' then
    begin
      if not LoadEmbeddedRibbonBitmap(Button.Glyph, Filename) then
        Button.Glyph.LoadFromFile(Filename);
      if FFourKGeometryApplied and (Button.Layout = blGlyphLeft) then
        Button.Glyph.SetSize(44, 36);
      Button.Glyph.Canvas.Brush.Color := clFuchsia;
      Button.Glyph.Canvas.FillRect(Rect(0, 0, Button.Glyph.Width,
        Button.Glyph.Height));
      Button.Glyph.TransparentColor := clFuchsia;
      Button.Glyph.Transparent := True;
      Button.NumGlyphs := 1;
    end
    else
      Button.Glyph := nil;
  end;
end;

// Crisp 16x16 fit-page glyph, drawn at native size instead of shrinking a
// detailed bitmap. Rebuilt only when the ribbon palette is refreshed.
procedure DrawFitPageIcon(ABitmap: Vcl.Graphics.TBitmap; ABackground: TColor);
var
  Ink: TColor;
  Brightness: Integer;
begin
  Brightness := GetRValue(ColorToRGB(ABackground)) * 299 +
    GetGValue(ColorToRGB(ABackground)) * 587 +
    GetBValue(ColorToRGB(ABackground)) * 114;
  if Brightness < 128000 then Ink := clWhite else Ink := clBlack;
  ABitmap.PixelFormat := pf24bit;
  ABitmap.SetSize(16, 16);
  ABitmap.Canvas.Brush.Color := clFuchsia;
  ABitmap.Canvas.FillRect(Rect(0, 0, 16, 16));
  ABitmap.Canvas.Pen.Color := Ink;
  ABitmap.Canvas.Pen.Width := 1;
  // Four simple corner brackets surrounding a page; no tiny arrowheads.
  with ABitmap.Canvas do
  begin
    MoveTo(2, 6); LineTo(2, 2); LineTo(6, 2);
    MoveTo(10, 2); LineTo(14, 2); LineTo(14, 6);
    MoveTo(2, 10); LineTo(2, 14); LineTo(6, 14);
    MoveTo(10, 14); LineTo(14, 14); LineTo(14, 10);
    // A centered page outline makes the action recognizable at 100% DPI.
    Rectangle(6, 5, 11, 12);
  end;
  ABitmap.TransparentMode := tmFixed;
  ABitmap.TransparentColor := clFuchsia;
  ABitmap.Transparent := True;
end;

procedure TFreePDFVCLRibbon.RefreshCommandIcons;
var
  I, J, K: Integer;
  Page, Group: TPanel;
  C: TControl;
  IconFile: string;
begin
  // Refresh only on actual palette changes or command-state changes.
  for I := 0 to FPages.Count - 1 do
  begin
    Page := TPanel(FPages[I]);
    for J := 0 to Page.ControlCount - 1 do
      if Page.Controls[J] is TPanel then
      begin
        Group := TPanel(Page.Controls[J]);
        for K := 0 to Group.ControlCount - 1 do
        begin
          C := Group.Controls[K];
          if C is TSpeedButton then
            LoadGlyph(TSpeedButton(C), C.Tag)
          else if C is TImage then
          begin
            IconFile := ResolveIconFile(C.Tag, False, C.Enabled);
            if C.Tag = 115 then
              DrawFitPageIcon(TImage(C).Picture.Bitmap, FThemeBackground)
            else if IconFile <> '' then
            begin
              if not LoadEmbeddedRibbonBitmap(TImage(C).Picture.Bitmap, IconFile) then
                TImage(C).Picture.Bitmap.LoadFromFile(IconFile);
              TImage(C).Picture.Bitmap.TransparentMode := tmFixed;
              TImage(C).Picture.Bitmap.TransparentColor := clFuchsia;
              TImage(C).Picture.Bitmap.Transparent := True;
            end;
          end;
        end;
      end;
  end;
end;

procedure TFreePDFVCLRibbon.AddCommand(TabIndex, CommandId: Integer;
  const ACaption: string; IsCombo: Boolean);
var
  Page, Group: TPanel;
  I, Col, RowIndex, ButtonWidth, CellWidth, LeftPos, TopPos: Integer;
  Button: TSpeedButton;
  Combo: TComboBox;
  LabelControl: TLabel;
  IconControl: TImage;
  IconFile: string;
  Compact: Boolean;
  GroupName: string;
begin
  Page := TPanel(FPages[TabIndex]);
  Group := nil;
  for I := Page.ControlCount - 1 downto 0 do
    if Page.Controls[I] is TPanel then
    begin
      Group := TPanel(Page.Controls[I]);
      Break;
    end;
  if Group = nil then Exit;
  GroupName := RibbonGroupTitle(Group);
  Compact := RibbonCompactGroup(TabIndex, GroupName);
  if Compact then
  begin
    if (TabIndex = 1) and (GroupName = 'Seiten') then
    begin
      Col := 0;
      RowIndex := Group.Tag;
      CellWidth := 195;
      LeftPos := 6;
    end
    else if (TabIndex = 1) and (GroupName = 'Anzeigen') then
    begin
      // Compact 4-column layout. Keep the existing three-row rhythm,
      // but eliminate the oversized 60+ px gaps between commands.
      case CommandId of
        116: begin Col := 1; RowIndex := 0; end;
        117: begin Col := 1; RowIndex := 1; end;
        214: begin Col := 2; RowIndex := 0; end;
        215: begin Col := 2; RowIndex := 1; end;
        216: begin Col := 2; RowIndex := 2; end;
        217: begin Col := 3; RowIndex := 0; end;
      else
        begin Col := 0; RowIndex := Group.Tag; end;
      end;
      case Col of
        0: begin LeftPos := 6; CellWidth := 150; end;
        1: begin LeftPos := 158; CellWidth := 140; end;
        2: begin LeftPos := 300; CellWidth := 148; end;
      else
        begin LeftPos := 450; CellWidth := 145; end;
      end;
    end
    else
    begin
      Col := Group.Tag div 3;
      RowIndex := Group.Tag mod 3;
      if TabIndex = 6 then
      begin
        if GroupName = 'Datei' then CellWidth := 315
        else if GroupName = 'Speichern / Export' then CellWidth := 252
        else if GroupName = 'Programm' then CellWidth := 135
        else CellWidth := 165;
      end
      else if (TabIndex = 5) and (GroupName = 'Updates') then CellWidth := 160
      else if (TabIndex = 1) and (GroupName = 'Bilder') then CellWidth := 146
      else if (TabIndex = 1) and (GroupName = 'Anzeigen') then CellWidth := 205
      else if (TabIndex = 2) and (GroupName = 'Schrift') then CellWidth := 245
      else CellWidth := 238;
      LeftPos := 6 + Col * CellWidth;
    end;
    TopPos := 4 + RowIndex * 30;
    ButtonWidth := CellWidth - 8;
  end
  else
  begin
    ButtonWidth := 69;
    case CommandId of
      107,108,196: ButtonWidth := 105;
      110,111: ButtonWidth := 85;
      119,120: ButtonWidth := 95;
      129,130: ButtonWidth := 100;
      178,179,180: ButtonWidth := 96;
      123: ButtonWidth := 72;
      124: ButtonWidth := 100;
      126,127: ButtonWidth := 83;
      133,134,135,177: ButtonWidth := 83;
      137,138: ButtonWidth := 102;
      141: ButtonWidth := 115;
      142,143: ButtonWidth := 77;
      153,154,155,156: ButtonWidth := 64;
      157: ButtonWidth := 105;
      159,160: ButtonWidth := 72;
      149: ButtonWidth := 111;
      150: ButtonWidth := 84;
      223: ButtonWidth := 105;
      194: ButtonWidth := 94;
    end;
    // Leave a 2-pixel gap between adjacent large buttons.
    // The previous -7 offset overlapped the preceding button by 2 pixels,
    // so the hover rectangle of "Apply redaction" covered "Redact".
    LeftPos := Group.Width - 3;
    if Group.Tag = 0 then LeftPos := 5;
    TopPos := 4;
  end;
  if (TabIndex = 1) and (GroupName = 'Anzeigen') and (CommandId = 217) then
  begin
    // Editable zoom percentage in the third row, directly below Zoom -.
    FZoomEdit := TEdit.Create(Self);
    FZoomEdit.Parent := Group;
    FZoomEdit.Tag := 221;
    FZoomEdit.Font.Name := 'Segoe UI';
    FZoomEdit.Font.Size := 8;
    FZoomEdit.SetBounds(158, 64, 132, 25);
    FZoomEdit.Text := '100 %';
    FZoomEdit.Enabled := False;
    FZoomEdit.ShowHint := True;
    if SameText(PDFLanguage, 'en') then
      FZoomEdit.Hint := 'Enter zoom percentage and press Enter'
    else
      FZoomEdit.Hint := 'Zoom in % eingeben und Enter drücken';
    FZoomEdit.OnKeyDown := ZoomEditKeyDown;
    // Preserve the Hand Tool button, located in the fourth column.
    Button := TRibbonSpeedButton.Create(Self);
    Button.Parent := Group;
    Button.Tag := CommandId;
    Button.Hint := RibbonText(ACaption);
    Button.ShowHint := True;
    Button.Flat := True;
    Button.Font.Name := 'Segoe UI';
    Button.Font.Size := 8;
    Button.Caption := RibbonText(ACaption);
    Button.Layout := blGlyphLeft;
    Button.Margin := 3;
    Button.Spacing := 4;
    Button.SetBounds(LeftPos, TopPos, ButtonWidth, 29);
    Button.OnClick := CommandClick;
    LoadGlyph(Button, CommandId);
  end
  else if (TabIndex = 1) and (GroupName = 'Seiten') and (CommandId = 212) then
  begin
    FPageEdit := TEdit.Create(Self);
    FPageEdit.Parent := Group;
    FPageEdit.Tag := 212;
    FPageEdit.Font.Name := 'Segoe UI';
    FPageEdit.Font.Size := 9;
    FPageEdit.SetBounds(LeftPos + 4, TopPos + 1, 174, 27);
    FPageEdit.Text := 'Seite – von –';
    FPageEdit.Enabled := False;
    FPageEdit.Hint := RibbonText('Seitennummer eingeben und Enter drücken');
    FPageEdit.ShowHint := True;
    FPageEdit.OnKeyDown := PageEditKeyDown;
  end
  else if IsCombo then
  begin
    // A compact combo uses the same 8 pt typography as the command buttons.
    // Its Tabler icon occupies the leftmost 18 pixels, without moving the row.
    IconFile := ResolveIconFile(CommandId, False, True);
    if (IconFile <> '') or (CommandId = 115) then
    begin
      IconControl := TImage.Create(Self);
      IconControl.Parent := Group;
      IconControl.Tag := CommandId;
      IconControl.SetBounds(LeftPos + 2, TopPos + 5, 16, 16);
      if CommandId = 115 then
        DrawFitPageIcon(IconControl.Picture.Bitmap, FThemeBackground)
      else if not LoadEmbeddedRibbonBitmap(IconControl.Picture.Bitmap, IconFile) then
        IconControl.Picture.Bitmap.LoadFromFile(IconFile);
      IconControl.Picture.Bitmap.TransparentColor := clFuchsia;
      IconControl.Picture.Bitmap.TransparentMode := tmFixed;
      IconControl.Picture.Bitmap.Transparent := True;
      IconControl.Transparent := True;
      IconControl.Stretch := False;
      IconControl.ShowHint := True;
      IconControl.Hint := ACaption;
      if CommandId = 115 then
      begin
        IconControl.Cursor := crHandPoint;
        IconControl.OnClick := FitPageClick;
      end;
    end;
    LabelControl := TLabel.Create(Self);
    LabelControl.Parent := Group;
    LabelControl.Tag := CommandId;
    if CommandId = 115 then LabelControl.Caption := RibbonText('Seite anpassen')
    else LabelControl.Caption := RibbonText(ACaption);
    LabelControl.Font.Name := 'Segoe UI';
    LabelControl.Font.Size := 8;
    LabelControl.Alignment := taLeftJustify;
    LabelControl.Layout := tlCenter;
    LabelControl.AutoSize := False;
    if CommandId = 115 then
      LabelControl.SetBounds(LeftPos + 21, TopPos, 104, 26)
    else
      LabelControl.SetBounds(LeftPos + 21, TopPos, 71, 26);
    if CommandId = 115 then
    begin
      LabelControl.Cursor := crHandPoint;
      LabelControl.OnClick := FitPageClick;
    end;
    LabelControl.Transparent := True;
    Combo := TComboBox.Create(Self);
    Combo.Parent := Group;
    Combo.Tag := CommandId;
    Combo.Style := csDropDownList;
    Combo.Font.Name := 'Segoe UI';
    Combo.Font.Size := 8;
    if CommandId = 115 then Combo.Hint := RibbonText('Zoommodus auswählen')
    else Combo.Hint := RibbonText(ACaption);
    Combo.ShowHint := True;
    if CommandId = 115 then
      // Zoom mode is independent from the fit-page action.
      // Place it in the third row, directly below Seite anpassen.
      Combo.SetBounds(6, 64, 140, 25)
    else
      Combo.SetBounds(LeftPos + 92, TopPos, Max(60, ButtonWidth - 96), 26);
    Combo.OnChange := ComboChanged;
  end
  else
  begin
    Button := TRibbonSpeedButton.Create(Self);
    Button.Parent := Group;
    Button.Tag := CommandId;
    if (CommandId = 104) and (TabIndex = 0) then
      Button.Hint := RibbonText('Änderungen direkt in der geöffneten PDF speichern (Strg+S).')
    else if CommandId = 223 then
      if SameText(PDFLanguage, 'en') then Button.Hint := 'Check for updates now'
      else Button.Hint := 'Jetzt nach Updates suchen'
    else
      Button.Hint := RibbonText(ACaption);
    Button.ShowHint := True;
    Button.Flat := True;
    // Tab headings keep their inherited font.
    Button.Font.Name := 'Segoe UI';
    Button.Font.Size := 8;
    // The update command is always available, even when no PDF is open.
    // Give it the active theme text color instead of inheriting a gray state.
    if CommandId = 223 then
    begin
      Button.Enabled := True;
      if (GetRValue(ColorToRGB(FThemeBackground)) * 299 +
          GetGValue(ColorToRGB(FThemeBackground)) * 587 +
          GetBValue(ColorToRGB(FThemeBackground)) * 114) >= 128000 then
        Button.Font.Color := clBlack
      else
        Button.Font.Color := clWhite;
      Button.ParentFont := False;
    end;
    // The entire row is one button:
    // icon, caption, hover highlight and click target stay together.
    if Compact then
    begin
      Button.Caption := RibbonText(ACaption);
      Button.Layout := blGlyphLeft;
      Button.Margin := 3;
      Button.Spacing := 4;
      Button.SetBounds(LeftPos, TopPos, ButtonWidth, 29);
    end
    else
    begin
      Button.Caption := DisplayCaption(CommandId, ACaption);
      Button.Layout := blGlyphTop;
      Button.Margin := 7;
      Button.Spacing := 5;
      Button.SetBounds(LeftPos, TopPos, ButtonWidth, 87);
    end;
    Button.OnClick := CommandClick;
    LoadGlyph(Button, CommandId);
  end;
  Group.Tag := Group.Tag + 1;
  if Compact then
  begin
    if (TabIndex = 1) and (GroupName = 'Anzeigen') then
      Group.Width := 600
    else
      Group.Width := Max(80, (Col + 1) * CellWidth + 6);
  end
  else
    Group.Width := LeftPos + ButtonWidth + 5;
end;

procedure TFreePDFVCLRibbon.LayoutGroups;
var
  TabIndex, I, X: Integer;
  Page: TPanel;
begin
  for TabIndex := 0 to FPages.Count - 1 do
  begin
    Page := TPanel(FPages[TabIndex]);
    X := 4;
    for I := 0 to Page.ControlCount - 1 do
      if Page.Controls[I] is TPanel then
      begin
        Page.Controls[I].Left := X;
        Inc(X, Page.Controls[I].Width + 3);
      end;
  end;
end;

procedure TFreePDFVCLRibbon.UpdateGroupViewport;
var
  Page: TPanel;
  I, TotalWidth, ViewWidth, MaxOffset, Offset, X, ArrowWidth: Integer;
  NeedsScroll: Boolean;
begin
  // During Create the ribbon has no parent window yet.  Calling
  // BringToFront on the scroll buttons at that stage can force VCL to
  // create their parent handles and raise EInvalidOperation
  // ("Control has no parent window").  The first Resize after
  // parenting will perform the viewport layout.
  if (Parent = nil) or not FLayoutReady or (FContent = nil) or
    (FActiveTab < 0) or (FActiveTab >= FPages.Count) then Exit;
  Page := TPanel(FPages[FActiveTab]);
  TotalWidth := 4;
  for I := 0 to Page.ControlCount - 1 do
    if Page.Controls[I] is TPanel then
      Inc(TotalWidth, Page.Controls[I].Width + 3);
  NeedsScroll := TotalWidth > FContent.ClientWidth;
  ArrowWidth := 30;
  if FFourKGeometryApplied then ArrowWidth := 48;
  // Windowed buttons remain above the windowed page panels.
  FScrollBack.Visible := NeedsScroll and not FCollapsed;
  FScrollForward.Visible := NeedsScroll and not FCollapsed;
  ViewWidth := FContent.ClientWidth;
  if NeedsScroll then Dec(ViewWidth, ArrowWidth * 2);
  ViewWidth := Max(1, ViewWidth);
  MaxOffset := Max(0, TotalWidth - ViewWidth);
  Offset := EnsureRange(FGroupScroll[FActiveTab], 0, MaxOffset);
  FGroupScroll[FActiveTab] := Offset;
  X := 4 - Offset;
  for I := 0 to Page.ControlCount - 1 do
    if Page.Controls[I] is TPanel then
    begin
      Page.Controls[I].Left := X;
      Inc(X, Page.Controls[I].Width + 3);
    end;
  if NeedsScroll then
  begin
    FScrollBack.SetBounds(FContent.ClientWidth - ArrowWidth * 2, 0,
      ArrowWidth, FContent.ClientHeight);
    FScrollForward.SetBounds(FContent.ClientWidth - ArrowWidth, 0,
      ArrowWidth, FContent.ClientHeight);
    FScrollBack.Enabled := Offset > 0;
    FScrollForward.Enabled := Offset < MaxOffset;
    FScrollBack.BringToFront;
    FScrollForward.BringToFront;
  end;
end;

procedure TFreePDFVCLRibbon.ScrollGroups(Sender: TObject);
var
  Delta: Integer;
begin
  if (FActiveTab < 0) or (FActiveTab > 6) then Exit;
  Delta := 180;
  if FFourKGeometryApplied then Delta := 360;
  if Sender = FScrollBack then Delta := -Delta;
  FGroupScroll[FActiveTab] := Max(0, FGroupScroll[FActiveTab] + Delta);
  UpdateGroupViewport;
end;

procedure TFreePDFVCLRibbon.UpdateFileTabHint;
var
  TabPanel: TPanel;
  HintText: string;
begin
  if FTabPanels.Count < 7 then Exit;
  TabPanel := TPanel(FTabPanels[6]);
  if RibbonText('Datei') = 'File' then
    HintText := 'Left: File menu / Right: Home'
  else
    HintText := 'Links: Datei-Menü / Rechts: Home';
  TabPanel.Hint := HintText;
  TabPanel.ShowHint := True;
  if (TabPanel.ControlCount > 0) and (TabPanel.Controls[0] is TLabel) then
  begin
    TLabel(TabPanel.Controls[0]).Hint := HintText;
    TLabel(TabPanel.Controls[0]).ShowHint := True;
  end;
end;

procedure TFreePDFVCLRibbon.FileTabMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbRight then Exit;
  if Assigned(FOnCommand) then
    FOnCommand(Self, 167, '');
end;

procedure TFreePDFVCLRibbon.TabClick(Sender: TObject);
begin
  if FCollapsed then Collapsed := False;
  ShowTab(TControl(Sender).Tag);
end;

procedure TFreePDFVCLRibbon.ShowTab(Index: Integer);
var I: Integer;
begin
  if (Index < 0) or (Index >= FPages.Count) then Exit;
  for I := 0 to FPages.Count - 1 do
    TPanel(FPages[I]).Visible := I = Index;
  FActiveTab := Index;
  UpdateTabColors;
  UpdateGroupViewport;
end;

procedure TFreePDFVCLRibbon.UpdateTabColors;
var I: Integer; P: TPanel; L: TLabel;
begin
  for I := 0 to FTabPanels.Count - 1 do
  begin
    P := TPanel(FTabPanels[I]);
    if I = FActiveTab then P.Color := FThemeBackground
    else P.Color := FThemeAccent;
    L := TLabel(P.Controls[0]);
    L.Font.Color := FThemeText;
    L.Font.Style := [];
    if I = FActiveTab then L.Font.Style := [fsBold];
  end;
end;

procedure TFreePDFVCLRibbon.CommandClick(Sender: TObject);
var
  C: TControl;
begin
  if Sender is TLabel then
  begin
    C := FindCommand(TLabel(Sender).Tag);
    if (C <> nil) and not C.Enabled then Exit;
  end;
  if Assigned(FOnCommand) then
    FOnCommand(Self, TControl(Sender).Tag, '');
end;

procedure TFreePDFVCLRibbon.TabPreviewCheckClick(Sender: TObject);
begin
  if FUpdatingTabPreviewCheck then Exit;
  if Assigned(FOnCommand) then
    FOnCommand(Self, 197, '');
end;

procedure TFreePDFVCLRibbon.SetTabPreviewChecked(Value: Boolean);
begin
  if FTabPreviewCheck = nil then Exit;
  FUpdatingTabPreviewCheck := True;
  try
    FTabPreviewCheck.Checked := Value;
  finally
    FUpdatingTabPreviewCheck := False;
  end;
end;

procedure TFreePDFVCLRibbon.UpdateAutoCheckClick(Sender: TObject);
begin
  if FUpdatingAutoCheck then Exit;
  if Assigned(FOnCommand) then FOnCommand(Self, 222, '');
end;

procedure TFreePDFVCLRibbon.SetUpdateAutoChecked(Value: Boolean);
begin
  if FUpdateAutoCheck = nil then Exit;
  FUpdatingAutoCheck := True;
  try
    FUpdateAutoCheck.Checked := Value;
  finally
    FUpdatingAutoCheck := False;
  end;
end;

procedure TFreePDFVCLRibbon.FitPageClick(Sender: TObject);
begin
  if (Sender is TControl) and not TControl(Sender).Enabled then Exit;
  // Clicking the icon or label applies fit-page, without changing
  // the currently selected combobox value until the document updates.
  if Assigned(FOnCommand) then
    FOnCommand(Self, 115, 'Ganze Seite');
end;

procedure TFreePDFVCLRibbon.ComboChanged(Sender: TObject);
begin
  if FUpdatingCombos then Exit;
  if Assigned(FOnCommand) then
    FOnCommand(Self, TControl(Sender).Tag, RibbonGermanText(TComboBox(Sender).Text));
end;

function TFreePDFVCLRibbon.FindCommand(CommandId: Integer): TControl;
var I, J, K: Integer; Page, Group: TPanel; C: TControl;
begin
  Result := nil;
  for I := 0 to FPages.Count - 1 do
  begin
    Page := TPanel(FPages[I]);
    for J := 0 to Page.ControlCount - 1 do
      if Page.Controls[J] is TPanel then
      begin
        Group := TPanel(Page.Controls[J]);
        for K := 0 to Group.ControlCount - 1 do
        begin
          C := Group.Controls[K];
          if ((C is TSpeedButton) or (C is TComboBox)) and
             (C.Tag = CommandId) then Exit(C);
        end;
      end;
  end;
end;

procedure TFreePDFVCLRibbon.ApplyPalette(Background, TextColor, Accent: TColor);
var I, J, K: Integer; Page, Group: TPanel;
begin
  if (FThemeBackground = Background) and (FThemeText = TextColor) and
     (FThemeAccent = Accent) then Exit;
  FThemeBackground := Background;
  FThemeText := TextColor;
  FThemeAccent := Accent;
  Color := Background;
  FTabs.Color := Accent;
  FCollapseButton.Font.Color := TextColor;
  FContent.Color := Background;
  for I := 0 to FPages.Count - 1 do
  begin
    Page := TPanel(FPages[I]);
    Page.Color := Background;
    for J := 0 to Page.ControlCount - 1 do
      if Page.Controls[J] is TPanel then
      begin
        Group := TPanel(Page.Controls[J]);
        Group.Color := Background;
        for K := 0 to Group.ControlCount - 1 do
        begin
          if Group.Controls[K] is TLabel then
            TLabel(Group.Controls[K]).Font.Color := TextColor;
          if Group.Controls[K] is TCheckBox then
            TCheckBox(Group.Controls[K]).Font.Color := TextColor;
          if Group.Controls[K] is TSpeedButton then
            begin
              TSpeedButton(Group.Controls[K]).Font.Color := TextColor;
              if TSpeedButton(Group.Controls[K]).Tag = 223 then
              begin
                // Always render the clickable update command with a clear,
                // high-contrast caption (not the disabled-looking gray).
                if (GetRValue(ColorToRGB(Background)) * 299 +
                    GetGValue(ColorToRGB(Background)) * 587 +
                    GetBValue(ColorToRGB(Background)) * 114) >= 128000 then
                  TSpeedButton(Group.Controls[K]).Font.Color := clBlack
                else
                  TSpeedButton(Group.Controls[K]).Font.Color := clWhite;
              end;
            end;
        end;
      end;
  end;
  UpdateTabColors;
  RefreshCommandIcons;
end;

procedure TFreePDFVCLRibbon.SetCommandText(CommandId: Integer; const ACaption, AHint: string);
var
  C: TControl;
begin
  C := FindCommand(CommandId);
  if C is TSpeedButton then
  begin
    TSpeedButton(C).Caption := RibbonText(ACaption);
    TSpeedButton(C).Hint := RibbonText(AHint);
    if (CommandId = 215) or (CommandId = 216) then
      LoadGlyph(TSpeedButton(C), CommandId);
  end;
end;

procedure TFreePDFVCLRibbon.RefreshLanguage;
var
  I, J, K, W: Integer;
  P, G, TP: TPanel;
  L: TLabel;
  C: TControl;
  German: string;
begin
  for I := 0 to FTabPanels.Count - 1 do
  begin
    TP := TPanel(FTabPanels[I]);
    if TP.ControlCount > 0 then
    begin
      L := TLabel(TP.Controls[0]);
      German := RibbonGermanText(L.Caption);
      L.Caption := RibbonText(German);
      W := Max(64, Length(L.Caption) * 7 + 18);
      TP.Width := W;
    end;
  end;
  UpdateFileTabHint;
  // Reposition tab headers after translated captions have changed widths.
  W := 4;
  if FTabPanels.Count = 7 then
  begin
    for I := 0 to 6 do
    begin
      case I of
        0: TP := TPanel(FTabPanels[6]); // File
        1: TP := TPanel(FTabPanels[0]); // Start
        2: TP := TPanel(FTabPanels[1]); // View
        3: TP := TPanel(FTabPanels[2]); // Edit
        4: TP := TPanel(FTabPanels[3]); // Objects
        5: TP := TPanel(FTabPanels[4]); // Tools
      else
        TP := TPanel(FTabPanels[5]); // Help
      end;
      TP.Left := W;
      Inc(W, TP.Width + 2);
    end;
  end;
  for I := 0 to FPages.Count - 1 do
  begin
    P := TPanel(FPages[I]);
    for J := 0 to P.ControlCount - 1 do
      if P.Controls[J] is TPanel then
      begin
        G := TPanel(P.Controls[J]);
        for K := 0 to G.ControlCount - 1 do
        begin
          C := G.Controls[K];
          if C is TLabel then
          begin
            L := TLabel(C);
            if L.Align = alBottom then
              L.Caption := RibbonText(RibbonGermanText(L.Caption))
            else if L.Tag <> 0 then
            begin
              German := RibbonGermanText(L.Caption);
              if L.Tag = 115 then German := 'Seite anpassen';
              L.Caption := RibbonText(German);
            end;
          end
          else if C is TSpeedButton then
          begin
            German := RibbonGermanText(TSpeedButton(C).Caption);
            if TSpeedButton(C).Tag = 215 then
            begin
              if (German = 'Einzelansicht') or (German = 'Doppelansicht') then
                TSpeedButton(C).Caption := RibbonText(German);
            end
            else if TSpeedButton(C).Tag = 216 then
              TSpeedButton(C).Caption := RibbonText(German)
            else if TSpeedButton(C).Tag = 217 then
              TSpeedButton(C).Caption := RibbonText(German)
            else if RibbonCompactGroup(I, RibbonGroupTitle(G)) then
              TSpeedButton(C).Caption := RibbonText(German)
            else
              TSpeedButton(C).Caption := DisplayCaption(TSpeedButton(C).Tag, German);
            if TSpeedButton(C).Tag = 223 then
            begin
              TSpeedButton(C).Enabled := True;
              if (GetRValue(ColorToRGB(FThemeBackground)) * 299 +
          GetGValue(ColorToRGB(FThemeBackground)) * 587 +
          GetBValue(ColorToRGB(FThemeBackground)) * 114) >= 128000 then
        TSpeedButton(C).Font.Color := clBlack
      else
        TSpeedButton(C).Font.Color := clWhite;
              if SameText(PDFLanguage, 'en') then
                TSpeedButton(C).Hint := 'Check for updates now'
              else TSpeedButton(C).Hint := 'Jetzt nach Updates suchen';
            end
            else
              TSpeedButton(C).Hint := RibbonText(RibbonGermanText(TSpeedButton(C).Hint));
          end
          else if C is TComboBox then
          begin
            if TComboBox(C).Tag = 115 then
            begin
              TComboBox(C).Hint := RibbonText('Zoommodus auswählen');
              for W := 0 to TComboBox(C).Items.Count - 1 do
                TComboBox(C).Items[W] := RibbonText(RibbonGermanText(TComboBox(C).Items[W]));
            end;
          end;
        end;
      end;
  end;
  if FUpdateAutoCheck <> nil then
  begin
    if SameText(PDFLanguage, 'en') then
    begin
      FUpdateAutoCheck.Caption := 'Check weekly';
      FUpdateAutoCheck.Hint := 'Automatically check for updates every week';
    end
    else
    begin
      FUpdateAutoCheck.Caption := 'Wöchentlich prüfen';
      FUpdateAutoCheck.Hint := 'Automatisch einmal pro Woche nach Updates suchen';
    end;
  end;
  if FTabPreviewCheck <> nil then
  begin
    FTabPreviewCheck.Caption := RibbonText('Registerkartenvorschau anzeigen');
    FTabPreviewCheck.Hint := RibbonText('Vorschau beim Überfahren einer PDF-Registerkarte');
  end;
  FCollapseButton.Hint := RibbonText('Ribbon ein-/ausklappen');
  FScrollBack.Hint := RibbonText('Ribbon-Gruppen nach links');
  FScrollForward.Hint := RibbonText('Ribbon-Gruppen nach rechts');
  if FPageEdit <> nil then
  begin
    FPageEdit.Hint := RibbonText('Seitennummer eingeben und Enter drücken');
    if not FPageEdit.Focused then
      if SameText(PDFLanguage, 'en') then FPageEdit.Text := 'Page – of –'
      else FPageEdit.Text := 'Seite – von –';
  end;
  UpdateGroupViewport;
end;

procedure TFreePDFVCLRibbon.SetCommandOrange(CommandId: Integer; Active: Boolean);
var
  I, J, K: Integer;
  Page, Group: TPanel;
  C: TControl;
begin
  for I := 0 to FPages.Count - 1 do
  begin
    Page := TPanel(FPages[I]);
    for J := 0 to Page.ControlCount - 1 do
      if Page.Controls[J] is TPanel then
      begin
        Group := TPanel(Page.Controls[J]);
        for K := 0 to Group.ControlCount - 1 do
        begin
          C := Group.Controls[K];
          if (C.Tag = CommandId) and (C is TRibbonSpeedButton) then
            TRibbonSpeedButton(C).SetOrangeActive(Active);
        end;
      end;
  end;
end;

procedure TFreePDFVCLRibbon.SetCommandEnabled(CommandId: Integer; Enabled: Boolean);
var
  I, J, K: Integer;
  Page, Group: TPanel;
  C: TControl;
begin
  // The Start and Datei tabs can contain the same command ID.
  // Update every occurrence, not only the first one found.
  for I := 0 to FPages.Count - 1 do
  begin
    Page := TPanel(FPages[I]);
    for J := 0 to Page.ControlCount - 1 do
      if Page.Controls[J] is TPanel then
      begin
        Group := TPanel(Page.Controls[J]);
        for K := 0 to Group.ControlCount - 1 do
        begin
          C := Group.Controls[K];
          if ((C is TSpeedButton) or (C is TComboBox) or
              ((CommandId = 115) and ((C is TLabel) or (C is TImage)))) and
             (C.Tag = CommandId) then
          begin
            if C.Enabled <> Enabled then
            begin
              C.Enabled := Enabled;
              if C is TSpeedButton then
                LoadGlyph(TSpeedButton(C), CommandId)
              else if C is TImage then
              begin
                // Recolor the standalone combo icon without reloading
                // every button on every status update.
                RefreshCommandIcons;
              end;
            end;
          end;
        end;
      end;
  end;
end;

procedure TFreePDFVCLRibbon.SetComboValue(CommandId: Integer; const Value: string);
var C: TControl; Combo: TComboBox;
begin
  C := FindCommand(CommandId);
  if not (C is TComboBox) then Exit;
  Combo := TComboBox(C);
  FUpdatingCombos := True;
  try
    Combo.ItemIndex := Combo.Items.IndexOf(Value);
    if (CommandId = 115) and (Combo.ItemIndex < 0) and
       SameText(Value, 'Seite anpassen') then
      Combo.ItemIndex := Combo.Items.IndexOf('Ganze Seite');
  finally
    FUpdatingCombos := False;
  end;
end;

procedure TFreePDFVCLRibbon.SetComboItems(CommandId: Integer;
  const Values: array of string);
var C: TControl; Combo: TComboBox; I: Integer;
begin
  C := FindCommand(CommandId);
  if not (C is TComboBox) then Exit;
  Combo := TComboBox(C);
  FUpdatingCombos := True;
  Combo.Items.BeginUpdate;
  try
    Combo.Items.Clear;
    for I := Low(Values) to High(Values) do Combo.Items.Add(Values[I]);
  finally
    Combo.Items.EndUpdate;
    FUpdatingCombos := False;
  end;
end;

procedure TFreePDFVCLRibbon.SelectTab(Index: Integer);
begin
  ShowTab(Index);
end;

function TFreePDFVCLRibbon.ActiveTabIndex: Integer;
begin
  Result := FActiveTab;
end;


procedure TFreePDFVCLRibbon.SetCollapsed(Value: Boolean);
begin
  if FCollapsed = Value then Exit;
  FCollapsed := Value;
  FContent.Visible := not Value;
  if Value then Height := FTabs.Height
  else if FFourKGeometryApplied and (Parent <> nil) then
    Height := MulDiv(155, 175, 100)
  else Height := 149;
  if FCollapseButton <> nil then
    if Value then FCollapseButton.Caption := 'v'
    else FCollapseButton.Caption := '^';
  UpdateGroupViewport;
  if Assigned(FOnCollapseChanged) then FOnCollapseChanged(Self);
end;

procedure TFreePDFVCLRibbon.CollapseClick(Sender: TObject);
begin
  Collapsed := not Collapsed;
end;

procedure TFreePDFVCLRibbon.TabDoubleClick(Sender: TObject);
begin
  Collapsed := not Collapsed;
end;

procedure TFreePDFVCLRibbon.PageStatusTick(Sender: TObject);
begin
  if Visible and (not Collapsed) and Assigned(FOnCommand) then
    FOnCommand(Self, 213, '');
end;

procedure TFreePDFVCLRibbon.SetZoomPercent(APercent: Integer; AEnabled: Boolean);
var
  S: string;
begin
  if FZoomEdit = nil then Exit;
  FZoomEdit.Enabled := AEnabled;
  if not AEnabled then S := '–'
  else S := IntToStr(APercent) + ' %';
  // Do not overwrite the user's input while the edit is focused.
  if not FZoomEdit.Focused and (FZoomEdit.Text <> S) then
    FZoomEdit.Text := S;
end;

procedure TFreePDFVCLRibbon.ZoomEditKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  S: string;
  N: Integer;
begin
  if Key = VK_RETURN then
  begin
    S := Trim(FZoomEdit.Text);
    S := StringReplace(S, '%', '', [rfReplaceAll]);
    S := Trim(S);
    if TryStrToInt(S, N) and (N >= 8) and (N <= 1000) and
       Assigned(FOnCommand) then
      FOnCommand(Self, 221, IntToStr(N));
    // Clear focus so the next status tick reflects the actual PDF zoom.
    if FPageEdit <> nil then FPageEdit.SetFocus;
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    if FPageEdit <> nil then FPageEdit.SetFocus;
    Key := 0;
  end;
end;

procedure TFreePDFVCLRibbon.PageEditKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  N: Integer;
  S: string;
begin
  if Key = VK_RETURN then
  begin
    S := Trim(FPageEdit.Text);
    if Pos(' ', S) > 0 then S := Copy(S, 1, Pos(' ', S) - 1);
    if TryStrToInt(S, N) and (N > 0) and Assigned(FOnCommand) then
      FOnCommand(Self, 212, IntToStr(N));
    Key := 0;
  end;
end;

procedure TFreePDFVCLRibbon.SetPageStatus(APage, ACount: Integer);
var
  S: string;
begin
  if FPageEdit = nil then Exit;
  FPageEdit.Enabled := ACount > 0;
  if (APage > 0) and (ACount > 0) then
    if SameText(PDFLanguage, 'en') then S := Format('%d of %d', [APage, ACount])
    else S := Format('%d von %d', [APage, ACount])
  else if SameText(PDFLanguage, 'en') then S := 'Page – of –'
  else S := 'Seite – von –';
  if not FPageEdit.Focused then
    if FPageEdit.Text <> S then FPageEdit.Text := S;
end;

procedure TFreePDFVCLRibbon.BuildRibbon;
begin
  AddTab('Start');
  AddGroup(0, 'Datei');
  AddCommand(0, 103, 'Öffnen', false);
  AddCommand(0, 104, 'Speichern', false);
  AddCommand(0, 105, 'Drucken', false);
  AddGroup(0, 'Arbeitsbereiche');
  AddCommand(0, 108, 'Arbeitsbereiche verwalten', false);
  AddCommand(0, 196, 'Arbeitsbereich speichern', false);
  AddGroup(0, 'Suche');
  AddCommand(0, 110, 'PDF durchsuchen', false);
  AddCommand(0, 111, 'Alle PDFs durchsuchen', false);
  AddTab('Ansicht');
  AddGroup(1, 'Anzeigen');
  AddCommand(1, 114, 'Miniaturen', false);
  AddCommand(1, 115, 'Seite anpassen', true);
  AddCommand(1, 116, 'Zoom +', false);
  AddCommand(1, 117, 'Zoom -', false);
  AddCommand(1, 214, '100 %', false);
  AddCommand(1, 215, 'Doppelansicht', false);
  AddCommand(1, 216, 'Seitenweise', false);
  AddCommand(1, 217, 'Hand-Werkzeug', false);
  AddGroup(1, 'Seiten');
  AddCommand(1, 210, 'Vorherige Seite', false);
  AddCommand(1, 211, 'Nächste Seite', false);
  AddCommand(1, 212, 'Seite – von –', false);
  AddGroup(1, 'Bilder');
  // Three coherent columns, top-to-bottom: Zoom, rotation, output.
  // Keeping each related pair vertically adjacent avoids accidental clicks.
  AddCommand(1, 202, 'Bild vergrößern', false);
  AddCommand(1, 201, 'Bild verkleinern', false);
  AddCommand(1, 205, 'Ganzes Bild', false);
  AddCommand(1, 204, 'Bild rechts drehen', false);
  AddCommand(1, 203, 'Bild links drehen', false);
  AddCommand(1, 206, 'Bildbreite', false);
  AddCommand(1, 208, 'Bild speichern', false);
  AddCommand(1, 209, 'Bild drucken', false);
  AddCommand(1, 207, 'Originalgröße', false);
  AddCommand(1, 218, 'TIFF zurück', false);
  AddCommand(1, 219, 'TIFF weiter', false);
  AddGroup(1, 'Vergleichen');
  AddCommand(1, 119, 'Ansicht teilen', false);
  AddCommand(1, 120, 'PDFs visuell vergleichen', false);
  AddTab('Bearbeiten');
  AddGroup(2, 'Text');
  AddCommand(2, 123, 'Text einfügen', false);
  AddCommand(2, 124, 'Text hervorheben', false);
  AddGroup(2, 'Anmerkungen');
  AddCommand(2, 126, 'Kommentar hinzufügen', false);
  AddCommand(2, 127, 'Kommentare verwalten', false);
  AddGroup(2, 'Änderungen');
  AddCommand(2, 129, 'Rückgängig', false);
  AddCommand(2, 130, 'Wiederholen', false);
  AddGroup(2, 'Zeichnen');
  AddCommand(2, 168, 'Freihand', false);
  AddCommand(2, 169, 'Linie', false);
  AddCommand(2, 170, 'Rechteck', false);
  AddCommand(2, 171, 'Ellipse', false);
  AddGroup(2, 'Weitere Zeichenwerkzeuge');
  AddCommand(2, 172, 'Strichstärke ...', true);
  AddCommand(2, 173, 'Farbe ...', false);
  AddCommand(2, 184, 'Schwärzen (optisch)', false);
  AddGroup(2, 'Schrift');
  AddCommand(2, 174, 'Schriftart ...', true);
  AddCommand(2, 175, 'Schriftgröße ...', true);
  AddCommand(2, 176, 'Textfarbe ...', false);
  AddTab('Objekte');
  AddGroup(3, 'Objekte');
  AddCommand(3, 133, 'Bild einfügen', false);
  AddCommand(3, 134, 'Unterschrift hinzufügen', false);
  AddCommand(3, 135, 'Hyperlink hinzufügen', false);
  AddCommand(3, 177, 'Hyperlinks verwalten ...', false);
  AddGroup(3, 'Wasserzeichen');
  AddCommand(3, 137, 'Textwasserzeichen', false);
  AddCommand(3, 138, 'Bildwasserzeichen', false);
  AddTab('Werkzeuge');
  AddGroup(4, 'Dokument');
  AddCommand(4, 141, 'Dokumenteigenschaften', false);
  AddCommand(4, 142, 'PDF-Anlagen', false);
  AddGroup(4, 'Messung');
  AddCommand(4, 145, 'Messen', false);
  AddCommand(4, 178, 'Maßstab ...', false);
  AddCommand(4, 179, 'Messfarbe ...', false);
  AddCommand(4, 180, 'Messbericht ...', false);
  AddGroup(4, 'Schwärzung');
  AddCommand(4, 146, 'Schwärzen', false);
  AddCommand(4, 194, 'Endgültig schwärzen ...', false);
  AddGroup(4, 'Einheiten');
  AddCommand(4, 181, 'mm', false);
  AddCommand(4, 182, 'cm', false);
  AddCommand(4, 183, 'Zoll', false);
  AddGroup(4, 'Registerkarten');
  // Keep the original tab-hover preview and its existing INI setting.
  // This is independent of the page thumbnails in Ansicht.
  FTabPreviewCheck := TCheckBox.Create(Self);
  FTabPreviewCheck.Parent := TWinControl(TPanel(FPages[4]).Controls[
    TPanel(FPages[4]).ControlCount - 1]);
  FTabPreviewCheck.Tag := 197;
  FTabPreviewCheck.Caption := RibbonText('Registerkartenvorschau anzeigen');
  FTabPreviewCheck.Font.Name := 'Segoe UI';
  FTabPreviewCheck.Font.Size := 8;
  FTabPreviewCheck.SetBounds(9, 12, 222, 28);
  FTabPreviewCheck.OnClick := TabPreviewCheckClick;
  FTabPreviewCheck.Hint := RibbonText('Vorschau beim Überfahren einer PDF-Registerkarte');
  TPanel(FTabPreviewCheck.Parent).Width := 243;
  AddTab('Hilfe');
  AddGroup(5, 'Design');
  AddCommand(5, 153, 'Standard', false);
  AddCommand(5, 154, 'Modern Hell', false);
  AddCommand(5, 156, 'Klassisch Blau', false);
  AddCommand(5, 155, 'Klassisch Grau', false);
  AddCommand(5, 157, 'Eisgrau', false);
  AddGroup(5, 'Sprache / Language');
  AddCommand(5, 159, 'Deutsch', false);
  AddCommand(5, 160, 'English', false);
  AddGroup(5, 'Updates');
  AddCommand(5, 223, 'Nach Updates suchen ...', false);
  // Reuse the existing INI-backed weekly update setting.
  FUpdateAutoCheck := TCheckBox.Create(Self);
  FUpdateAutoCheck.Parent := TWinControl(TPanel(FPages[5]).Controls[
    TPanel(FPages[5]).ControlCount - 1]);
  FUpdateAutoCheck.Tag := 222;
  FUpdateAutoCheck.Caption := RibbonText('Wöchentlich prüfen');
  FUpdateAutoCheck.Font.Name := 'Segoe UI';
  FUpdateAutoCheck.Font.Size := 8;
  FUpdateAutoCheck.SetBounds(9, 41, 146, 29);
  if SameText(PDFLanguage, 'en') then
    FUpdateAutoCheck.Hint := 'Automatically check for updates every week'
  else
    FUpdateAutoCheck.Hint := 'Automatisch einmal pro Woche nach Updates suchen';
  FUpdateAutoCheck.ShowHint := True;
  FUpdateAutoCheck.OnClick := UpdateAutoCheckClick;
  TPanel(FUpdateAutoCheck.Parent).Width := 166;
  AddGroup(5, 'Information');
  AddCommand(5, 149, 'Funktionsübersicht', false);
  AddCommand(5, 150, 'Über FreePDF64', false);
  // Datei ist eine normale Registerkarte, kein separates Popup-Fenster.
  AddTab('Datei');
  AddGroup(6, 'Datei');
  AddCommand(6, 167, 'Home', false);
  AddCommand(6, 103, 'PDFs und Bilder öffnen ...', false);
  AddCommand(6, 163, 'PDF neu laden (Änderungen verwerfen)', false);
  AddGroup(6, 'Speichern / Export');
  AddCommand(6, 220, 'PDF speichern unter ...', false);
  AddCommand(6, -191, 'Seiten als Bilder exportieren ...', false);
  AddCommand(6, -192, 'Seiten als Text exportieren ...', false);
  AddCommand(6, 143, 'PDF-Bilder extrahieren ...', false);
  AddCommand(6, 224, 'PDFs zusammenführen ...', false);
  AddGroup(6, 'Programm');
  AddCommand(6, 165, 'Beenden', false);
  // Export command states are synchronized with the active PDF tab.
end;

end.


unit uFreePDF64PDFiumCore;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.SyncObjs, System.Math,
  System.Generics.Collections, Vcl.Graphics;

type
  EPDFiumViewer = class(Exception);
  EPDFiumPasswordRequired = class(EPDFiumViewer);
  // FPDF_FORMFILLINFO, Version 1: erster Eintrag ist die Version,
  // danach folgen Callback-Pointer. Reservierter Platz ist nullinitialisiert.
  TPDFFormFillInfo = record
    Version: Integer;
    Callbacks: array[0..63] of Pointer;
  end;
  // PDFium V8: IPDF_JSPLATFORM Version 2 (Win64, natuerliches Alignment).
  TPDFJSPlatform = record
    Version: Integer;
    AppAlert: Pointer;
    AppBeep: Pointer;
    AppResponse: Pointer;
    DocGetFilePath: Pointer;
    DocMail: Pointer;
    DocPrint: Pointer;
    DocSubmitForm: Pointer;
    DocGotoPage: Pointer;
    FieldBrowse: Pointer;
    FormFillInfo: Pointer;
    Isolate: Pointer;
    V8EmbedderSlot: Cardinal;
  end;
  // Die ersten Felder entsprechen PDFiums FPDF_FORMFILLINFO Version 2.
  PPDFJSFormInfo = ^TPDFJSFormInfo;
  TPDFJSFormInfo = record
    Version: Integer;
    Release: Pointer;
    Invalidate: Pointer;
    OutputSelectedRect: Pointer;
    SetCursor: Pointer;
    SetTimer: Pointer;
    KillTimer: Pointer;
    GetLocalTime: Pointer;
    OnChange: Pointer;
    GetPage: Pointer;
    GetCurrentPage: Pointer;
    GetRotation: Pointer;
    ExecuteNamedAction: Pointer;
    SetTextFieldFocus: Pointer;
    DoURIAction: Pointer;
    DoGoToAction: Pointer;
    JSPlatform: Pointer;
    Reserved: array[0..31] of Pointer;
    // Private Daten hinter dem von PDFium verwendeten Strukturteil.
    CurrentDoc: Pointer;
    CurrentPage: Pointer;
    CurrentPageIndex: Integer;
  end;
  TPDFInkPoint = packed record
    X, Y: Single;
  end;
  TPDFInkRect = packed record
    Left, Bottom, Right, Top: Single;
  end;
  TPDFQuadPoints = packed record
    X1, Y1, X2, Y2, X3, Y3, X4, Y4: Single;
  end;
  TPDFTextMatch = record
    PageIndex: Integer;
    CharIndex: Integer;
    CharCount: Integer;
  end;
  TPDFLinkTarget = record
    URI: string;
    PageIndex: Integer; // -1 bei externem Link
  end;
  TPDFInkStroke = class(TList<TPDFInkPoint>)
  public
    LineWidth: Single; // Strichstaerke in PDF-Punkten
    StrokeColor: TColor; // individuelle Farbe der Markierung
    IsCover: Boolean; // nur optische Abdeckung, keine sichere Schwärzung
  end;
  TPDFBookmarkItem = class
  public
    Title: string;
    PageIndex: Integer;
    Children: TObjectList<TPDFBookmarkItem>;
    constructor Create;
    destructor Destroy; override;
  end;
  TPDFInsertedTextAction = record
    PageIndex: Integer; // physical page index
    Obj: Pointer;
    ObjectIndex: Integer; // Index im aktuellen Seitenobjektbestand
    Inserted: Boolean;
    IsHighlight: Boolean;
    IsArea: Boolean;
    AnnotIndex: Integer;
    StartChar, CharCount: Integer;
    AreaX1, AreaY1, AreaX2, AreaY2: Double;
    MarkColor: TColor;
  end;
  TPDFNote = record
    PageIndex: Integer;
    AnnotIndex: Integer;
    Bounds: TPDFInkRect;
    Contents: string;
  end;
  TPDFNoteAction = record
    PageIndex: Integer;
    NoteIndex: Integer;
    BeforeNote, AfterNote: TPDFNote;
    BeforeExists, AfterExists: Boolean;
  end;
  TFreePDF64PDFiumCore = class
  private
    FDocument: Pointer;
    FSearchTerm: string;
    FSearchCache: TArray<TPDFTextMatch>;
    FSearchCacheValid: Boolean;
    FFileName: string;
    FPageCount: Integer;
    FStrokes: TObjectList<TPDFInkStroke>;
    FStrokePages: TList<Integer>;
    FModified: Boolean;
    FPageOrder: TArray<Integer>;
    FOrderChanged: Boolean;
    FTextActions: TList<TPDFInsertedTextAction>;
    FTextActionPos: Integer;
    FReplayingHighlight: Boolean;
    FNoteActions: TList<TPDFNoteAction>;
    FNoteActionPos: Integer;
    function ApplyNoteState(const N: TPDFNote; AExists: Boolean; AIndex: Integer): Boolean;
    procedure RecordNoteAction(const A: TPDFNoteAction);
    procedure ClearTextActions;
    function ChangeTextAction(AUndo: Boolean; out APageIndex: Integer): Boolean;
    function IsAlabamaInteractionTest(APageIndex: Integer): Boolean;
    function PhysicalPage(AIndex: Integer): Integer;
    function VisiblePage(APhysical: Integer): Integer;
    procedure WriteOrderedPDF(const AInput, AOutput: string);
    procedure InvalidateSearchCache;
  public
    constructor Create;
    destructor Destroy; override;
    procedure OpenFile(const AFileName: string; const APassword: AnsiString = '');
    procedure CloseFile;
    procedure TakeDocumentFrom(ASource: TFreePDF64PDFiumCore);
    procedure RenderPage(APageIndex: Integer; ABitmap: TBitmap;
      AWidth, AHeight: Integer; ARotation: Integer = 0);
    procedure AddStroke(APageIndex: Integer; APoints: TPDFInkStroke);
    function HighlightText(APageIndex, AStartChar, ACharCount: Integer; AColor: TColor): Boolean;
    function HighlightArea(APageIndex: Integer; AX1, AY1, AX2, AY2: Double; AColor: TColor): Boolean;
    procedure InsertText(APageIndex: Integer; AX, AY: Double;
      const AText: string; AFontSize: Double; AColor: TColor; const AFontName: string = 'Arial');
    function UndoInsertedText(out APageIndex: Integer): Boolean;
    function RedoInsertedText(out APageIndex: Integer): Boolean;
    function CanUndoInsertedText: Boolean;
    function CanRedoInsertedText: Boolean;
    function GetNotes(APageIndex: Integer): TArray<TPDFNote>;
    function AddNote(APageIndex: Integer; AX, AY: Double; const AText: string): Boolean;
    function ChangeNote(const ANote: TPDFNote; const AText: string;
      AX, AY: Double; AMove: Boolean): Boolean;
    function DeleteNote(const ANote: TPDFNote): Boolean;
    function UndoNote(out APageIndex: Integer): Boolean;
    function RedoNote(out APageIndex: Integer): Boolean;
    function CanUndoNote: Boolean;
    function CanRedoNote: Boolean;
    procedure SaveAs(const AFileName: string);
    procedure ExportPages(const AVisiblePages: TArray<Integer>; const ATargetFile: string);
    procedure DeletePages(const APageIndices: TArray<Integer>);
    procedure ImportPDFPages(const AFileName: string; AVisibleIndex: Integer);
    procedure MovePage(AIndex, ANewIndex: Integer);
    function SourcePageIndex(AIndex: Integer): Integer;
    procedure RotateInMemory(AFirstPage, ALastPage, AAngle: Integer);
    procedure RotatePages(AFirstPage, ALastPage, AAngle: Integer; const ATargetFile: string);
    function PagePointToDevice(APageIndex, AWidth, AHeight: Integer;
      AX, AY: Double; out X, Y: Integer): Boolean;
    function DevicePointToPage(APageIndex, AWidth, AHeight, X, Y: Integer;
      out AX, AY: Double): Boolean;
    property Modified: Boolean read FModified;
    property Strokes: TObjectList<TPDFInkStroke> read FStrokes;
    property StrokePages: TList<Integer> read FStrokePages;
    function LinkAtPoint(APageIndex, AWidth, AHeight, X, Y: Integer;
      out ATarget: TPDFLinkTarget): Boolean;
    function PageSize(APageIndex: Integer; out AWidth, AHeight: Single): Boolean;
    function FindTextPage(const AText: string; AStartPage: Integer): Integer;
    function FindAllTextMatches(const AText: string): TArray<TPDFTextMatch>;
    function FindTextMatchesOnPage(const AText: string; APage: Integer): TArray<TPDFTextMatch>;
    function MatchCharRects(APage, ACharIndex, ACharCount: Integer): TArray<TPDFInkRect>;
    function TextCharAt(APage: Integer; AX, AY: Double): Integer;
    function TextCharCount(APage: Integer): Integer;
    function TextRange(APage, AStart, ACount: Integer): string;
    function FindTextMatch(const AText: string; AStartPage, AStartChar,
      ADirection: Integer; out APage, ACharIndex, ACharCount: Integer): Boolean;
    function MetaText(const AKey: AnsiString): string;
    procedure ReadBookmarks(AItems: TObjectList<TPDFBookmarkItem>);
    function FormType: Integer;
    function HasDocumentJavaScript: Boolean;
    function FormWidgetCount: Integer;
    function FindAdjacentFormWidget(AFromPage, AFromIndex, ADirection: Integer;
      out APage, AIndex: Integer): Boolean;
    function FormWidgetDeviceRect(APageIndex, AWidgetIndex, AWidth,
      AHeight: Integer; out ARect: TRect): Boolean;
    function FormWidgetAtPoint(APageIndex, AWidth, AHeight, X, Y: Integer;
      out AWidgetIndex: Integer): Boolean;
    function FormWidgetOptions(APageIndex, AWidgetIndex: Integer; AItems: TStrings): Boolean;
    function FormWidgetFieldInfo(APageIndex, AWidgetIndex: Integer;
      out AFieldType, AFieldFlags: Integer): Boolean;
    function FormWidgetFontSize(APageIndex, AWidgetIndex: Integer;
      out AFontSize: Single): Boolean;
    function FormWidgetReadOnly(APageIndex, AWidgetIndex: Integer): Boolean;
    function FormWidgetRequired(APageIndex, AWidgetIndex: Integer): Boolean;
    function CountEmptyRequiredFields: Integer;
    function ListEmptyRequiredFields(ADetails: TStrings): Integer;
    function FormWidgetLikelyMultiline(APageIndex, AWidgetIndex: Integer): Boolean;
    function EditFormWidgetText(APageIndex, AWidgetIndex: Integer;
      var AValue: string): Boolean;
    function ToggleFormWidgetChoice(APageIndex, AWidgetIndex: Integer): Boolean;
    function SetFormWidgetSelectedIndices(APageIndex, AWidgetIndex: Integer;
      const AIndices: TArray<Integer>): Boolean;
    function SetFormWidgetText(APageIndex, AWidgetIndex: Integer;
      const AValue: string): Boolean;
    procedure DrawFormTextPreview(APageIndex: Integer; ABitmap: TBitmap;
      AWidth, AHeight, ARotation: Integer);
    function PDFVersion: string;
    function SecurityRevision: Integer;
    function SecurityPermissions: UInt64;
    property FileName: string read FFileName;
    property PageCount: Integer read FPageCount;
  end;

implementation

type
  PPDFFileWrite = ^TPDFFileWrite;
  TPDFWriteBlock = function(AWriter: PPDFFileWrite; AData: Pointer;
    ASize: Cardinal): Integer; cdecl;
  TPDFFileWrite = record
    Version: Integer;
    WriteBlock: TPDFWriteBlock;
  end;
  POutputWriter = ^TOutputWriter;
  TOutputWriter = record
    Base: TPDFFileWrite;
    Stream: TFileStream;
  end;

function JSGetPage(Info, Doc: Pointer; Index: Integer): Pointer; cdecl;
begin
  Result := nil;
  if (Info <> nil) and (Doc = PPDFJSFormInfo(Info)^.CurrentDoc) and
     (Index = PPDFJSFormInfo(Info)^.CurrentPageIndex) then
    Result := PPDFJSFormInfo(Info)^.CurrentPage;
end;

function JSGetCurrentPage(Info, Doc: Pointer): Pointer; cdecl;
begin
  Result := nil;
  if (Info <> nil) and (Doc = PPDFJSFormInfo(Info)^.CurrentDoc) then
    Result := PPDFJSFormInfo(Info)^.CurrentPage;
end;

function JSGetRotation(Info, Page: Pointer): Integer; cdecl;
begin
  Result := 0;
end;

procedure JSInvalidate(Info, Page: Pointer; L, T, R, B: Double); cdecl;
begin
end;

procedure JSSetCursor(Info: Pointer; CursorType: Integer); cdecl;
begin
end;

function JSSetTimer(Info: Pointer; Delay: Integer; TimerCallback: Pointer): Integer; cdecl;
begin
  Result := 0;
end;

procedure JSKillTimer(Info: Pointer; TimerID: Integer); cdecl;
begin
end;

procedure JSNamedAction(Info: Pointer; Action: PAnsiChar); cdecl;
begin
end;

procedure JSBeep(JS: Pointer; BeepType: Integer); cdecl;
begin
end;

function JSAlert(JS, Msg, Title: Pointer; ButtonType, IconType: Integer): Integer; cdecl;
begin
  Result := 1;
end;

function PDFWriteBlock(AWriter: PPDFFileWrite; AData: Pointer;
  ASize: Cardinal): Integer; cdecl;
begin
  try
    Result := Integer(POutputWriter(AWriter).Stream.Write(AData^, ASize) = Integer(ASize));
  except
    Result := 0;
  end;
end;

function FPDFBookmark_GetFirstChild(Doc, Bookmark: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFBookmark_GetNextSibling(Doc, Bookmark: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFBookmark_GetTitle(Bookmark, Buffer: Pointer; BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDFBookmark_GetDest(Doc, Bookmark: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFBookmark_GetAction(Bookmark: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFAction_GetType(Action: Pointer): Cardinal; stdcall; external 'pdfium.dll';
function FPDFLink_GetLinkAtPoint(Page: Pointer; X, Y: Double): Pointer; stdcall; external 'pdfium.dll';
function FPDFLink_LoadWebLinks(TextPage: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFLink_CountWebLinks(LinkPage: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFLink_GetURL(LinkPage: Pointer; LinkIndex: Integer;
  Buffer: PWideChar; BufLen: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDFLink_CountRects(LinkPage: Pointer; LinkIndex: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDFLink_GetRect(LinkPage: Pointer; LinkIndex, RectIndex: Integer;
  var Left, Top, Right, Bottom: Double): Integer; stdcall; external 'pdfium.dll';
procedure FPDFLink_CloseWebLinks(LinkPage: Pointer); stdcall; external 'pdfium.dll';
function FPDFText_GetUnicode(TextPage: Pointer; Index: Integer): Cardinal; stdcall; external 'pdfium.dll';
function FPDFLink_GetAction(Link: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFLink_GetDest(Doc, Link: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFAction_GetURIPath(Doc, Action, Buffer: Pointer; BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDFAction_GetDest(Doc, Action: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFDest_GetDestPageIndex(Doc, Dest: Pointer): Integer; stdcall; external 'pdfium.dll';

// PDFium public/fpdf_edit.h: echte Textobjekte im Seiteninhalt.
function FPDFText_LoadStandardFont(Document: Pointer; Font: PAnsiChar): Pointer; stdcall; external 'pdfium.dll';
function FPDFText_LoadFont(Document: Pointer; Data: PByte; Size: Cardinal; FontType: Integer; CID: Integer): Pointer; stdcall; external 'pdfium.dll';
function FPDFPageObj_CreateTextObj(Document, Font: Pointer; FontSize: Single): Pointer; stdcall; external 'pdfium.dll';
function FPDFText_SetText(TextObject: Pointer; Text: PWideChar): Integer; stdcall; external 'pdfium.dll';
function FPDFPageObj_SetFillColor(PageObject: Pointer; R, G, B, A: Cardinal): Integer; stdcall; external 'pdfium.dll';
procedure FPDFPageObj_Transform(PageObject: Pointer; A, B, C, D, E, F: Double); stdcall; external 'pdfium.dll';
procedure FPDFPage_InsertObject(Page, PageObject: Pointer); stdcall; external 'pdfium.dll';
function FPDFPage_RemoveObject(Page, PageObject: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFPage_CountObjects(Page: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFPage_GetObject(Page: Pointer; Index: Integer): Pointer; stdcall; external 'pdfium.dll';
function FPDFPage_GenerateContent(Page: Pointer): Integer; stdcall; external 'pdfium.dll';
procedure FPDFPageObj_Destroy(PageObject: Pointer); stdcall; external 'pdfium.dll';
procedure FPDF_InitLibrary; stdcall; external 'pdfium.dll';
procedure FPDF_DestroyLibrary; stdcall; external 'pdfium.dll';
function FPDF_LoadDocument(FileName, Password: PAnsiChar): Pointer; stdcall; external 'pdfium.dll';
function FPDF_GetLastError: Cardinal; stdcall; external 'pdfium.dll';
function FPDF_GetSecurityHandlerRevision(Doc: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDF_GetDocPermissions(Doc: Pointer): NativeUInt; stdcall; external 'pdfium.dll';
procedure FPDF_CloseDocument(Doc: Pointer); stdcall; external 'pdfium.dll';
function FPDF_GetPageCount(Doc: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDF_ImportPages(DestDoc, SrcDoc: Pointer; PageRange: PAnsiChar; Index: Integer): Integer; stdcall; external 'pdfium.dll';
// AcroForm-Erkennung (PDFium public/fpdf_formfill.h / fpdf_annot.h).
function FPDF_GetFormType(Doc: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFDoc_GetJavaScriptActionCount(Doc: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFPage_GetAnnotCount(Page: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFPage_GetAnnot(Page: Pointer; Index: Integer): Pointer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetSubtype(Annot: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetFlags(Annot: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetLinkedAnnot(Annot: Pointer; Key: PAnsiChar): Pointer; stdcall; external 'pdfium.dll';
// PDFium fpdf_formfill.h: Formfeldtyp direkt abfragen (kein /AS-Raten).
function FPDFAnnot_GetFormFieldType(FormHandle, Annot: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_IsChecked(FormHandle, Annot: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetFormFieldName(FormHandle, Annot: Pointer; Buffer: Pointer; BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetFormFieldValue(FormHandle, Annot: Pointer; Buffer: Pointer; BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetFormFieldFlags(FormHandle, Annot: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetFormFieldExportValue(FormHandle, Annot: Pointer;
  Buffer: Pointer; BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDFDOC_InitFormFillEnvironment(Doc: Pointer;
  FormInfo: Pointer): Pointer; stdcall; external 'pdfium.dll';
procedure FORM_DoDocumentJSAction(FormHandle: Pointer); stdcall; external 'pdfium.dll';
procedure FORM_DoDocumentOpenAction(FormHandle: Pointer); stdcall; external 'pdfium.dll';
procedure FPDFDOC_ExitFormFillEnvironment(FormHandle: Pointer); stdcall; external 'pdfium.dll';
// PDFium-native Formularhervorhebung (fpdf_formfill.h).
procedure FPDF_SetFormFieldHighlightColor(FormHandle: Pointer;
  FieldType: Integer; Color: Cardinal); stdcall; external 'pdfium.dll';
procedure FPDF_SetFormFieldHighlightAlpha(FormHandle: Pointer;
  Alpha: Byte); stdcall; external 'pdfium.dll';
procedure FPDF_FFLDraw(FormHandle, Bitmap, Page: Pointer;
  StartX, StartY, SizeX, SizeY, Rotate, Flags: Integer);
  stdcall; external 'pdfium.dll';
procedure FORM_OnAfterLoadPage(Page, FormHandle: Pointer); stdcall; external 'pdfium.dll';
procedure FORM_OnBeforeClosePage(Page, FormHandle: Pointer); stdcall; external 'pdfium.dll';
function FORM_OnLButtonDown(FormHandle, Page: Pointer; Modifier: Integer;
  PageX, PageY: Double): Integer; stdcall; external 'pdfium.dll';
function FORM_OnLButtonUp(FormHandle, Page: Pointer; Modifier: Integer;
  PageX, PageY: Double): Integer; stdcall; external 'pdfium.dll';
// FormFill-API: Eingaben ueber die Formularengine statt direkt /V schreiben.
function FORM_SetFocusedAnnot(FormHandle, Annot: Pointer): Integer; stdcall; external 'pdfium.dll';
function FORM_SelectAllText(FormHandle, Page: Pointer): Integer; stdcall; external 'pdfium.dll';
procedure FORM_ReplaceSelection(FormHandle, Page: Pointer; Value: PWideChar); stdcall; external 'pdfium.dll';
function FORM_ForceToKillFocus(FormHandle: Pointer): Integer; stdcall; external 'pdfium.dll';
function FORM_SetIndexSelected(FormHandle, Page: Pointer; Index: Integer;
  Selected: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetOptionCount(FormHandle, Annot: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetOptionLabel(FormHandle, Annot: Pointer; Index: Integer;
  Buffer: Pointer; BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetRect(Annot: Pointer; var Rect: TPDFInkRect): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_GetStringValue(Annot: Pointer; Key: PAnsiChar; Buffer: Pointer; BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDFAnnot_SetStringValue(Annot: Pointer; Key: PAnsiChar; Value: PWideChar): Integer; stdcall; external 'pdfium.dll';
function FPDF_GetFileVersion(Doc: Pointer; var FileVersion: Integer): Integer;
  stdcall; external 'pdfium.dll';
function FPDF_GetFileSize(Doc: Pointer): NativeUInt; stdcall; external 'pdfium.dll';
function FPDF_GetMetaText(Doc: Pointer; Tag: PAnsiChar; Buffer: Pointer;
  BufLen: Cardinal): Cardinal; stdcall; external 'pdfium.dll';
function FPDF_LoadPage(Doc: Pointer; Index: Integer): Pointer; stdcall; external 'pdfium.dll';
procedure FPDF_ClosePage(Page: Pointer); stdcall; external 'pdfium.dll';
procedure FPDFPage_Delete(Doc: Pointer; PageIndex: Integer); stdcall; external 'pdfium.dll';
function FPDFPage_GetRotation(Page: Pointer): Integer; stdcall; external 'pdfium.dll';
procedure FPDFPage_SetRotation(Page: Pointer; Rotate: Integer); stdcall; external 'pdfium.dll';
function FPDF_DeviceToPage(Page: Pointer; StartX, StartY, SizeX, SizeY, Rotate,
  DeviceX, DeviceY: Integer; var PageX, PageY: Double): Integer; stdcall; external 'pdfium.dll';
function FPDF_PageToDevice(Page: Pointer; StartX, StartY, SizeX, SizeY,
  Rotate: Integer; PageX, PageY: Double; var DeviceX, DeviceY: Integer): Integer;
  stdcall; external 'pdfium.dll';
function FPDFPage_CreateAnnot(Page: Pointer; Subtype: Integer): Pointer; stdcall; external 'pdfium.dll';
procedure FPDFPage_CloseAnnot(Annot: Pointer); stdcall; external 'pdfium.dll';
function FPDFAnnot_AddInkStroke(Annot: Pointer; Points: Pointer; Count: NativeUInt): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_AppendAttachmentPoints(Annot: Pointer; const Quad: TPDFQuadPoints): Integer; stdcall; external 'pdfium.dll';
function FPDFPage_RemoveAnnot(Page: Pointer; Index: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_SetColor(Annot: Pointer; ColorType: Integer; R, G, B, A: Cardinal): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_SetBorder(Annot: Pointer; HR, VR, BW: Single): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_SetRect(Annot: Pointer; const R: TPDFInkRect): Integer; stdcall; external 'pdfium.dll';
function FPDFAnnot_SetFlags(Annot: Pointer; Flags: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDF_SaveAsCopy(Doc: Pointer; Writer: PPDFFileWrite; Flags: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDFText_LoadPage(Page: Pointer): Pointer; stdcall; external 'pdfium.dll';
procedure FPDFText_ClosePage(TextPage: Pointer); stdcall; external 'pdfium.dll';
function FPDFText_CountChars(TextPage: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFText_GetText(TextPage: Pointer; StartIndex, Count: Integer;
  ResultBuffer: PWideChar): Integer; stdcall; external 'pdfium.dll';
function FPDFText_FindStart(TextPage: Pointer; FindWhat: PWideChar;
  Flags: Cardinal; StartIndex: Integer): Pointer; stdcall; external 'pdfium.dll';
function FPDFText_FindNext(Handle: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFText_FindPrev(Handle: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFText_GetSchResultIndex(Handle: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDFText_GetSchCount(Handle: Pointer): Integer; stdcall; external 'pdfium.dll';
procedure FPDFText_FindClose(Handle: Pointer); stdcall; external 'pdfium.dll';
function FPDFText_GetCharBox(TextPage: Pointer; Index: Integer; var Left, Right, Bottom, Top: Double): Integer; stdcall; external 'pdfium.dll';
function FPDFText_GetCharIndexAtPos(TextPage: Pointer; X, Y, XTolerance, YTolerance: Double): Integer; stdcall; external 'pdfium.dll';
function FPDFText_CountRects(TextPage: Pointer; StartIndex, Count: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDFText_GetRect(TextPage: Pointer; RectIndex: Integer; var Left, Top, Right, Bottom: Double): Integer; stdcall; external 'pdfium.dll';
function FPDF_GetPageWidthF(Page: Pointer): Single; stdcall; external 'pdfium.dll';
function FPDF_GetPageHeightF(Page: Pointer): Single; stdcall; external 'pdfium.dll';
function FPDFBitmap_Create(Width, Height, Alpha: Integer): Pointer; stdcall; external 'pdfium.dll';
procedure FPDFBitmap_Destroy(Bitmap: Pointer); stdcall; external 'pdfium.dll';
function FPDFBitmap_GetBuffer(Bitmap: Pointer): Pointer; stdcall; external 'pdfium.dll';
function FPDFBitmap_GetStride(Bitmap: Pointer): Integer; stdcall; external 'pdfium.dll';
procedure FPDFBitmap_FillRect(Bitmap: Pointer; Left, Top, Width, Height: Integer; Color: Cardinal); stdcall; external 'pdfium.dll';
procedure FPDF_RenderPageBitmap(Bitmap, Page: Pointer; StartX, StartY, SizeX, SizeY, Rotate, Flags: Integer); stdcall; external 'pdfium.dll';

// Kompatibilitaet: aktuelle V8-Builds verlangen Version 2;
// aeltere PDFium-Builds koennen weiterhin Version 1 erwarten.
function InitCompatibleForm(Doc: Pointer; var Info: TPDFFormFillInfo): Pointer;
begin
  Info.Version := 2;
  Result := FPDFDOC_InitFormFillEnvironment(Doc, @Info);
  if Result = nil then
  begin
    Info.Version := 1;
    Result := FPDFDOC_InitFormFillEnvironment(Doc, @Info);
  end;
end;

type
  PPixelRow = ^TPixelRow;
  TPixelRow = array[0..65535] of Cardinal;

var
  LibraryUsers: Integer = 0;

function TFreePDF64PDFiumCore.MetaText(const AKey: AnsiString): string;
var
  N: Cardinal;
  Buffer: TArray<WideChar>;
begin
  Result := '';
  if FDocument = nil then Exit;
  N := FPDF_GetMetaText(FDocument, PAnsiChar(AKey), nil, 0);
  if (N < 2) or (N > 65536) then Exit;
  SetLength(Buffer, (N div 2) + 1);
  if FPDF_GetMetaText(FDocument, PAnsiChar(AKey), @Buffer[0], N) > 0 then
    Result := string(PWideChar(@Buffer[0]));
end;

function TFreePDF64PDFiumCore.SecurityRevision: Integer;
begin
  Result := -1;
  if FDocument <> nil then
    Result := FPDF_GetSecurityHandlerRevision(FDocument);
end;

function TFreePDF64PDFiumCore.SecurityPermissions: UInt64;
begin
  Result := 0;
  if FDocument <> nil then
    Result := UInt64(FPDF_GetDocPermissions(FDocument));
end;

function TFreePDF64PDFiumCore.FormType: Integer;
begin
  Result := 0; // FORMTYPE_NONE
  if FDocument <> nil then
    Result := FPDF_GetFormType(FDocument);
end;

function TFreePDF64PDFiumCore.HasDocumentJavaScript: Boolean;
begin
  // Nur dokumentweite JavaScript-Aktionen; keine vollstaendige Acrobat-API-Pruefung.
  Result := (FDocument <> nil) and
    (FPDFDoc_GetJavaScriptActionCount(FDocument) > 0);
end;

function TFreePDF64PDFiumCore.FormWidgetCount: Integer;
const
  FPDF_ANNOT_WIDGET = 20;
var
  Page, Annot: Pointer;
  I, J: Integer;
begin
  Result := 0;
  if FDocument = nil then Exit;
  // Nur auf ausdruecklichen Aufruf (Dokumenteigenschaften) durchlaufen.
  for I := 0 to FPageCount - 1 do
  begin
    Page := FPDF_LoadPage(FDocument, PhysicalPage(I));
    if Page = nil then Continue;
    try
      for J := 0 to FPDFPage_GetAnnotCount(Page) - 1 do
      begin
        Annot := FPDFPage_GetAnnot(Page, J);
        if Annot = nil then Continue;
        try
          if FPDFAnnot_GetSubtype(Annot) = FPDF_ANNOT_WIDGET then
            Inc(Result);
        finally
          FPDFPage_CloseAnnot(Annot);
        end;
      end;
    finally
      FPDF_ClosePage(Page);
    end;
  end;
end;

// Schritt 2: Widgets per PDF-Seitenkoordinaten sicher lokalisieren.
// Noch KEINE Aenderung von Formularwerten; dafuer ist die FormFill-Umgebung noetig.
function TFreePDF64PDFiumCore.FindAdjacentFormWidget(
  AFromPage, AFromIndex, ADirection: Integer;
  out APage, AIndex: Integer): Boolean;
var
  P, I, StartPage, Step, N: Integer;
  Page, Annot: Pointer;
begin
  Result := False;
  APage := -1;
  AIndex := -1;
  if (FDocument = nil) or (FPageCount <= 0) then Exit;
  if ADirection < 0 then Step := -1 else Step := 1;
  StartPage := AFromPage;
  if (StartPage < 0) or (StartPage >= FPageCount) then StartPage := 0;
  // Maximal ein kompletter Umlauf durch alle Seiten.
  for N := 0 to FPageCount - 1 do
  begin
    P := (StartPage + N * Step + FPageCount * 2) mod FPageCount;
    Page := FPDF_LoadPage(FDocument, PhysicalPage(P));
    if Page = nil then Continue;
    try
      if Step > 0 then
      begin
        if N = 0 then I := AFromIndex + 1 else I := 0;
        if I < 0 then I := 0;
        while I < FPDFPage_GetAnnotCount(Page) do
        begin
          Annot := FPDFPage_GetAnnot(Page, I);
          if Annot <> nil then
          try
            if (FPDFAnnot_GetSubtype(Annot) = 20) and
               (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) = 0) and
                (((FPDFAnnot_GetFlags(Annot) and 2) = 0) or
                 (IsAlabamaInteractionTest(P) and
                  (I <> FPDFPage_GetAnnotCount(Page) - 1)))) then
            begin
              APage := P;
              AIndex := I;
              Exit(True);
            end;
          finally
            FPDFPage_CloseAnnot(Annot);
          end;
          Inc(I);
        end;
      end
      else
      begin
        if (N = 0) and (AFromIndex >= 0) then I := AFromIndex - 1
        else I := FPDFPage_GetAnnotCount(Page) - 1;
        if I >= FPDFPage_GetAnnotCount(Page) then
          I := FPDFPage_GetAnnotCount(Page) - 1;
        while I >= 0 do
        begin
          Annot := FPDFPage_GetAnnot(Page, I);
          if Annot <> nil then
          try
            if (FPDFAnnot_GetSubtype(Annot) = 20) and
               (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) = 0) and
                (((FPDFAnnot_GetFlags(Annot) and 2) = 0) or
                 (IsAlabamaInteractionTest(P) and
                  (I <> FPDFPage_GetAnnotCount(Page) - 1)))) then
            begin
              APage := P;
              AIndex := I;
              Exit(True);
            end;
          finally
            FPDFPage_CloseAnnot(Annot);
          end;
          Dec(I);
        end;
      end;
    finally
      FPDF_ClosePage(Page);
    end;
  end;
end;

function TFreePDF64PDFiumCore.FormWidgetDeviceRect(APageIndex,
  AWidgetIndex, AWidth, AHeight: Integer; out ARect: TRect): Boolean;
var
  Page, Annot: Pointer;
  R: TPDFInkRect;
  X1, Y1, X2, Y2: Integer;
begin
  Result := False;
  ARect := Rect(0, 0, 0, 0);
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) or (AWidth <= 0) or (AHeight <= 0) then Exit;
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then Exit;
  try
    if (AWidgetIndex < 0) or
       (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
    Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
    if Annot = nil then Exit;
    try
      if (FPDFAnnot_GetSubtype(Annot) <> 20) or
         (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) <> 0) or
              (((FPDFAnnot_GetFlags(Annot) and 2) <> 0) and
               not IsAlabamaInteractionTest(APageIndex))) or
         (FPDFAnnot_GetRect(Annot, R) = 0) then Exit;
      if (FPDF_PageToDevice(Page, 0, 0, AWidth, AHeight, 0,
        R.Left, R.Top, X1, Y1) = 0) or
         (FPDF_PageToDevice(Page, 0, 0, AWidth, AHeight, 0,
        R.Right, R.Bottom, X2, Y2) = 0) then Exit;
      ARect := Rect(Min(X1, X2), Min(Y1, Y2),
        Max(X1, X2), Max(Y1, Y2));
      Result := (ARect.Right > ARect.Left) and
        (ARect.Bottom > ARect.Top);
    finally
      FPDFPage_CloseAnnot(Annot);
    end;
  finally
    FPDF_ClosePage(Page);
  end;
end;

function TFreePDF64PDFiumCore.FormWidgetAtPoint(APageIndex, AWidth, AHeight,
  X, Y: Integer; out AWidgetIndex: Integer): Boolean;
const
  FPDF_ANNOT_WIDGET = 20;
var
  Page, Annot: Pointer;
  PX, PY: Double;
  R: TPDFInkRect;
  I: Integer;
begin
  Result := False;
  AWidgetIndex := -1;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) or (AWidth <= 0) or (AHeight <= 0) then Exit;
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then Exit;
  try
    if FPDF_DeviceToPage(Page, 0, 0, AWidth, AHeight, 0,
      X, Y, PX, PY) = 0 then Exit;
    for I := FPDFPage_GetAnnotCount(Page) - 1 downto 0 do
    begin
      Annot := FPDFPage_GetAnnot(Page, I);
      if Annot = nil then Continue;
      try
        if (FPDFAnnot_GetSubtype(Annot) = FPDF_ANNOT_WIDGET) and
           (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) = 0) and
                (((FPDFAnnot_GetFlags(Annot) and 2) = 0) or
                 (IsAlabamaInteractionTest(APageIndex) and
                  (I <> FPDFPage_GetAnnotCount(Page) - 1)))) and
           (FPDFAnnot_GetRect(Annot, R) <> 0) and
           (PX >= Min(R.Left, R.Right)) and
           (PX <= Max(R.Left, R.Right)) and
           (PY >= Min(R.Bottom, R.Top)) and
           (PY <= Max(R.Bottom, R.Top)) then
        begin
          AWidgetIndex := I;
          Result := True;
          Exit;
        end;
      finally
        FPDFPage_CloseAnnot(Annot);
      end;
    end;
  finally
    FPDF_ClosePage(Page);
  end;
end;

function TFreePDF64PDFiumCore.FormWidgetFieldInfo(APageIndex,
  AWidgetIndex: Integer; out AFieldType, AFieldFlags: Integer): Boolean;
var
  FormInfo: TPDFFormFillInfo;
  FormHandle, Page, Annot: Pointer;
begin
  Result := False;
  AFieldType := 0;
  AFieldFlags := 0;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  FillChar(FormInfo, SizeOf(FormInfo), 0);
  FormInfo.Version := 1;
  FormHandle := InitCompatibleForm(FDocument, FormInfo);
  if FormHandle = nil then Exit;
  try
    Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
    if Page = nil then Exit;
    FORM_OnAfterLoadPage(Page, FormHandle);
    try
      if (AWidgetIndex < 0) or
         (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
      Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
      if Annot = nil then Exit;
      try
        if FPDFAnnot_GetSubtype(Annot) <> 20 then Exit;
        AFieldType := FPDFAnnot_GetFormFieldType(FormHandle, Annot);
        if AFieldType = 0 then Exit; // unbekannt: bisheriges Verhalten
        AFieldFlags := FPDFAnnot_GetFormFieldFlags(FormHandle, Annot);
        Result := True;
      finally
        FPDFPage_CloseAnnot(Annot);
      end;
    finally
      FORM_OnBeforeClosePage(Page, FormHandle);
      FPDF_ClosePage(Page);
    end;
  finally
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
  end;
end;

// PDFium liest die effektive Schriftgroesse des Formularfeldes aus dessen
// Default-Appearance. Dynamisch gebunden fuer aeltere PDFium-DLLs.
function TFreePDF64PDFiumCore.FormWidgetFontSize(APageIndex,
  AWidgetIndex: Integer; out AFontSize: Single): Boolean;
type
  TGetAnnotFontSize = function(FormHandle, Annot: Pointer;
    FontSize: PSingle): Integer; stdcall;
var
  Lib: HMODULE;
  GetFontSize: TGetAnnotFontSize;
  FormInfo: TPDFFormFillInfo;
  FormHandle, Page, Annot: Pointer;
begin
  Result := False;
  AFontSize := 0;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  Lib := GetModuleHandle('pdfium.dll');
  if Lib = 0 then Exit;
  GetFontSize := TGetAnnotFontSize(GetProcAddress(Lib, 'FPDFAnnot_GetFontSize'));
  if not Assigned(GetFontSize) then Exit;
  FillChar(FormInfo, SizeOf(FormInfo), 0);
  FormInfo.Version := 1;
  FormHandle := InitCompatibleForm(FDocument, FormInfo);
  if FormHandle = nil then Exit;
  try
    Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
    if Page = nil then Exit;
    FORM_OnAfterLoadPage(Page, FormHandle);
    try
      if (AWidgetIndex < 0) or
         (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
      Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
      if Annot = nil then Exit;
      try
        if FPDFAnnot_GetSubtype(Annot) <> 20 then Exit;
        Result := (GetFontSize(FormHandle, Annot, @AFontSize) <> 0) and
          (AFontSize > 0) and (AFontSize <= 144);
      finally
        FPDFPage_CloseAnnot(Annot);
      end;
    finally
      FORM_OnBeforeClosePage(Page, FormHandle);
      FPDF_ClosePage(Page);
    end;
  finally
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
  end;
end;

function TFreePDF64PDFiumCore.FormWidgetReadOnly(APageIndex,
  AWidgetIndex: Integer): Boolean;
var
  FieldType, FieldFlags: Integer;
begin
  // PDF AcroForm /Ff Bit 1: ReadOnly (Maske 1).
  Result := FormWidgetFieldInfo(APageIndex, AWidgetIndex,
    FieldType, FieldFlags) and ((FieldFlags and 1) <> 0);
end;

function TFreePDF64PDFiumCore.FormWidgetRequired(APageIndex,
  AWidgetIndex: Integer): Boolean;
var
  FieldType, FieldFlags: Integer;
begin
  // PDF AcroForm /Ff Bit 2: Required (Maske 2).
  Result := FormWidgetFieldInfo(APageIndex, AWidgetIndex,
    FieldType, FieldFlags) and ((FieldFlags and 2) <> 0);
end;

function TFreePDF64PDFiumCore.CountEmptyRequiredFields: Integer;
begin
  Result := ListEmptyRequiredFields(nil);
end;

function TFreePDF64PDFiumCore.ListEmptyRequiredFields(
  ADetails: TStrings): Integer;
var
  PageIndex, WidgetIndex, Count, FieldType, FieldFlags: Integer;
  Page, Annot, FormHandle: Pointer;
  FormInfo: TPDFFormFillInfo;
  FieldName, FieldValue, GroupKey: string;
  SeenGroups, CheckedGroups, RadioDescriptions: TStringList;
  FieldDescription: string;

  function ReadFormString(A: Pointer; AName: Boolean): string;
  var
    Needed: Cardinal;
    Buffer: TArray<WideChar>;
  begin
    Result := '';
    if AName then
      Needed := FPDFAnnot_GetFormFieldName(FormHandle, A, nil, 0)
    else
      Needed := FPDFAnnot_GetFormFieldValue(FormHandle, A, nil, 0);
    if (Needed < 2) or (Needed > 1048576) or
       ((Needed mod 2) <> 0) then Exit;
    SetLength(Buffer, (Needed div 2) + 1);
    FillChar(Buffer[0], Length(Buffer) * SizeOf(WideChar), 0);
    if AName then
    begin
      if FPDFAnnot_GetFormFieldName(FormHandle, A,
        @Buffer[0], Needed) <> Needed then Exit;
    end
    else if FPDFAnnot_GetFormFieldValue(FormHandle, A,
      @Buffer[0], Needed) <> Needed then Exit;
    Result := string(PWideChar(@Buffer[0]));
  end;

begin
  Result := 0;
  if ADetails <> nil then ADetails.Clear;
  if FDocument = nil then Exit;
  SeenGroups := TStringList.Create;
  CheckedGroups := TStringList.Create;
  RadioDescriptions := TStringList.Create;
  try
    SeenGroups.CaseSensitive := True;
    CheckedGroups.CaseSensitive := True;
    // Radio-Gruppen muessen erst komplett untersucht werden:
    // ein spaeteres Widget kann die Auswahl enthalten.
    for PageIndex := 0 to FPageCount - 1 do
    begin
      FillChar(FormInfo, SizeOf(FormInfo), 0);
      FormInfo.Version := 1;
      FormHandle := InitCompatibleForm(FDocument, FormInfo);
      if FormHandle = nil then Continue;
      try
        Page := FPDF_LoadPage(FDocument, PhysicalPage(PageIndex));
        if Page = nil then Continue;
        try
          FORM_OnAfterLoadPage(Page, FormHandle);
          try
            Count := FPDFPage_GetAnnotCount(Page);
            for WidgetIndex := 0 to Count - 1 do
            begin
              Annot := FPDFPage_GetAnnot(Page, WidgetIndex);
              if Annot = nil then Continue;
              try
                if FPDFAnnot_GetSubtype(Annot) <> 20 then Continue;
                FieldType := FPDFAnnot_GetFormFieldType(FormHandle, Annot);
                FieldFlags := FPDFAnnot_GetFormFieldFlags(FormHandle, Annot);
                if (FieldFlags and 2) = 0 then Continue;
                if (FieldType <> 2) and (FieldType <> 3) and
                   (FieldType <> 4) and (FieldType <> 5) and
                   (FieldType <> 6) then Continue;
                FieldName := ReadFormString(Annot, True);
                if FieldName <> '' then
                  GroupKey := FieldName
                else
                  GroupKey := Format('#%d:%d', [PageIndex, WidgetIndex]);
                if FieldName = '' then
                  FieldDescription := Format('Seite %d, Feld %d',
                    [PageIndex + 1, WidgetIndex + 1])
                else
                  FieldDescription := Format('Seite %d: %s',
                    [PageIndex + 1, FieldName]);
                if FieldType = 3 then
                begin
                  // Alle Widgets eines Radio-Felds zaehlen nur einmal.
                  GroupKey := 'R:' + GroupKey;
                  if SeenGroups.IndexOf(GroupKey) < 0 then
                  begin
                    SeenGroups.Add(GroupKey);
                    RadioDescriptions.Values[GroupKey] :=
                      FieldDescription + ' (Radio-Gruppe)';
                  end;
                  if FPDFAnnot_IsChecked(FormHandle, Annot) <> 0 then
                    if CheckedGroups.IndexOf(GroupKey) < 0 then
                      CheckedGroups.Add(GroupKey);
                end
                else if FieldType = 2 then
                begin
                  GroupKey := 'C:' + GroupKey;
                  if SeenGroups.IndexOf(GroupKey) < 0 then
                  begin
                    SeenGroups.Add(GroupKey);
                    if FPDFAnnot_IsChecked(FormHandle, Annot) = 0 then
                    begin
                      Inc(Result);
                      if ADetails <> nil then
                        ADetails.Add(FieldDescription + ' (Checkbox)');
                    end;
                  end;
                end
                else
                begin
                  GroupKey := 'T:' + GroupKey;
                  if SeenGroups.IndexOf(GroupKey) >= 0 then Continue;
                  SeenGroups.Add(GroupKey);
                  FieldValue := ReadFormString(Annot, False);
                  if (Trim(FieldValue) = '') or
                     SameText(Trim(FieldValue), 'Off') then
                  begin
                    Inc(Result);
                    if ADetails <> nil then
                      ADetails.Add(FieldDescription + ' (Text/Auswahl)');
                  end;
                end;
              finally
                FPDFPage_CloseAnnot(Annot);
              end;
            end;
          finally
            FORM_OnBeforeClosePage(Page, FormHandle);
          end;
        finally
          FPDF_ClosePage(Page);
        end;
      finally
        FPDFDOC_ExitFormFillEnvironment(FormHandle);
      end;
    end;
    for WidgetIndex := 0 to SeenGroups.Count - 1 do
      if (Copy(SeenGroups[WidgetIndex], 1, 2) = 'R:') and
         (CheckedGroups.IndexOf(SeenGroups[WidgetIndex]) < 0) then
      begin
        Inc(Result);
        if ADetails <> nil then
          ADetails.Add(RadioDescriptions.Values[SeenGroups[WidgetIndex]]);
      end;
  finally
    RadioDescriptions.Free;
    CheckedGroups.Free;
    SeenGroups.Free;
  end;
end;

function TFreePDF64PDFiumCore.FormWidgetLikelyMultiline(APageIndex,
  AWidgetIndex: Integer): Boolean;
var
  Page, Annot: Pointer;
  R: TPDFInkRect;
  W, H: Double;
  FieldType, FieldFlags: Integer;
begin
  Result := False;
  // PDFium: Textfeld = 6, Multiline-Flag = Bit 13 (4096).
  // Nur bei unbekanntem Feldtyp die bisherige Geometrie verwenden.
  if FormWidgetFieldInfo(APageIndex, AWidgetIndex, FieldType, FieldFlags) then
  begin
    Result := (FieldType = 6) and ((FieldFlags and 4096) <> 0);
    Exit;
  end;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then Exit;
  try
    if (AWidgetIndex < 0) or
       (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
    Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
    if Annot = nil then Exit;
    try
      if (FPDFAnnot_GetSubtype(Annot) <> 20) or
         (FPDFAnnot_GetRect(Annot, R) = 0) then Exit;
      W := Abs(R.Right - R.Left);
      H := Abs(R.Top - R.Bottom);
      // Vorlaeufige Layout-Heuristik: keine PDFium-Feldflag-Abfrage.
      // Breite, flache Widgets erhalten einen einzeiligen Editor.
      Result := (W > 0) and (H > 0) and (H / W > 0.12);
    finally
      FPDFPage_CloseAnnot(Annot);
    end;
  finally
    FPDF_ClosePage(Page);
  end;
end;

function TFreePDF64PDFiumCore.FormWidgetOptions(APageIndex,
  AWidgetIndex: Integer; AItems: TStrings): Boolean;
var
  Page, Annot, FormHandle: Pointer;
  FormInfo: TPDFFormFillInfo;
  I, Count: Integer;
  Needed: Cardinal;
  Buf: TArray<WideChar>;
begin
  Result := False;
  AItems.Clear;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  FillChar(FormInfo, SizeOf(FormInfo), 0);
  FormInfo.Version := 1;
  FormHandle := InitCompatibleForm(FDocument, FormInfo);
  if FormHandle = nil then Exit;
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then
  begin
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
    Exit;
  end;
  FORM_OnAfterLoadPage(Page, FormHandle);
  try
    if (AWidgetIndex < 0) or
       (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
    Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
    if Annot = nil then Exit;
    try
      if FPDFAnnot_GetSubtype(Annot) <> 20 then Exit;
      // Ohne FormFill-Handle kann PDFium bei einigen Versionen keine
      // Optionen liefern. Dann bleibt der bisherige Textdialog aktiv.
      Count := FPDFAnnot_GetOptionCount(FormHandle, Annot);
      if (Count <= 0) or (Count > 1000) then Exit;
      for I := 0 to Count - 1 do
      begin
        Needed := FPDFAnnot_GetOptionLabel(FormHandle, Annot, I, nil, 0);
        if (Needed < 2) or (Needed > 8192) or (Needed mod 2 <> 0) then Exit;
        SetLength(Buf, (Needed div 2) + 1);
        FillChar(Buf[0], Length(Buf) * SizeOf(WideChar), 0);
        if FPDFAnnot_GetOptionLabel(FormHandle, Annot, I, @Buf[0], Needed) = 0 then Exit;
        AItems.Add(string(PWideChar(@Buf[0])));
      end;
      Result := AItems.Count > 0;
    finally
      FPDFPage_CloseAnnot(Annot);
    end;
  finally
    FORM_OnBeforeClosePage(Page, FormHandle);
    FPDF_ClosePage(Page);
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
  end;
end;

function TFreePDF64PDFiumCore.EditFormWidgetText(APageIndex,
  AWidgetIndex: Integer; var AValue: string): Boolean;
var
  Page, Annot, FormHandle: Pointer;
  FormInfo: TPDFFormFillInfo;
  Needed: Cardinal;
  Buffer: TArray<WideChar>;
begin
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  FillChar(FormInfo, SizeOf(FormInfo), 0);
  FormInfo.Version := 1;
  FormHandle := InitCompatibleForm(FDocument, FormInfo);
  if FormHandle = nil then Exit;
  try
    Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
    if Page = nil then Exit;
    try
      FORM_OnAfterLoadPage(Page, FormHandle);
      try
        if (AWidgetIndex < 0) or
           (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
        Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
        if Annot = nil then Exit;
        try
          if (FPDFAnnot_GetSubtype(Annot) <> 20) or
             (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) <> 0) or
              (((FPDFAnnot_GetFlags(Annot) and 2) <> 0) and
               not IsAlabamaInteractionTest(APageIndex))) then Exit;
          // PDFium liefert auch geerbte /V-Werte des uebergeordneten Feldes.
          Needed := FPDFAnnot_GetFormFieldValue(FormHandle, Annot, nil, 0);
          if (Needed < 2) or (Needed > 1048576) or
             ((Needed mod 2) <> 0) then Exit;
          SetLength(Buffer, (Needed div 2) + 1);
          FillChar(Buffer[0], Length(Buffer) * SizeOf(WideChar), 0);
          if FPDFAnnot_GetFormFieldValue(FormHandle, Annot,
             @Buffer[0], Needed) <> Needed then Exit;
          AValue := string(PWideChar(@Buffer[0]));
          Result := True;
        finally
          FPDFPage_CloseAnnot(Annot);
        end;
      finally
        FORM_OnBeforeClosePage(Page, FormHandle);
      end;
    finally
      FPDF_ClosePage(Page);
    end;
  finally
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
  end;
end;

function TFreePDF64PDFiumCore.SetFormWidgetText(APageIndex,
  AWidgetIndex: Integer; const AValue: string): Boolean;
var
  Page, Annot, FormHandle: Pointer;
  FormInfo: TPDFFormFillInfo;
  JSInfo: TPDFJSFormInfo;
  JSPlatform: TPDFJSPlatform;
  JSEnabled: Boolean;
  FieldType, I, Count, MatchedIndex: Integer;
  Needed: Cardinal;
  Buffer: TArray<WideChar>;
  LabelText: string;
  FocusOK, ChangeOK: Boolean;
  Diag: TStringList;
  BeforeWages, BeforeTotal, AfterWages, AfterTotal: UnicodeString;
  BeforeOtherPage2, AfterOtherPage2, BeforeOtherPage1, AfterOtherPage1: UnicodeString;
  BeforeFirstName, AfterFirstName: UnicodeString;
  BeforeTotalFound, AfterTotalFound: Boolean;
  BeforeOtherPage2Found, AfterOtherPage2Found: Boolean;
  BeforeOtherPage1Found, AfterOtherPage1Found: Boolean;
  BeforeFirstNameFound, AfterFirstNameFound: Boolean;
  procedure LogStep(const S: string);
  var
    LogPath: string;
  begin
    if Diag = nil then Exit;
    Diag.Add(S);
    try
      LogPath := ChangeFileExt(FFileName, '.Alabama_Text_Berechnung_Patch17.log');
      try
      except
        LogPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
          'Alabama_Text_Berechnung_Patch17.log';
      end;
    except
      // Diagnose darf die Formularverarbeitung nicht beeinflussen.
    end;
  end;
  function FieldValueByNameOnPage(const AName: string;
    APhysicalPage: Integer; out AFound: Boolean): UnicodeString;
  var
    K: Integer;
    W, SearchPage: Pointer;
    NLen, VLen: Cardinal;
    Buf: TArray<WideChar>;
    OwnPage: Boolean;
  begin
    Result := '';
    AFound := False;
    SearchPage := Page;
    OwnPage := APhysicalPage <> PhysicalPage(APageIndex);
    if OwnPage then
    begin
      SearchPage := FPDF_LoadPage(FDocument, APhysicalPage);
      if SearchPage = nil then Exit;
      FORM_OnAfterLoadPage(SearchPage, FormHandle);
    end;
    try
      for K := 0 to FPDFPage_GetAnnotCount(SearchPage) - 1 do
      begin
        W := FPDFPage_GetAnnot(SearchPage, K);
        if W = nil then Continue;
        try
          if FPDFAnnot_GetSubtype(W) <> 20 then Continue;
          NLen := FPDFAnnot_GetFormFieldName(FormHandle, W, nil, 0);
          if (NLen < 2) or (NLen > 8192) or ((NLen mod 2) <> 0) then Continue;
          SetLength(Buf, NLen div 2 + 1);
          FillChar(Buf[0], Length(Buf) * SizeOf(WideChar), 0);
          if FPDFAnnot_GetFormFieldName(FormHandle, W, @Buf[0], NLen) <> NLen then Continue;
          if not SameText(string(PWideChar(@Buf[0])), AName) then Continue;
          AFound := True;
          VLen := FPDFAnnot_GetFormFieldValue(FormHandle, W, nil, 0);
          if (VLen < 2) or (VLen > 65536) or ((VLen mod 2) <> 0) then Exit;
          SetLength(Buf, VLen div 2 + 1);
          FillChar(Buf[0], Length(Buf) * SizeOf(WideChar), 0);
          if FPDFAnnot_GetFormFieldValue(FormHandle, W, @Buf[0], VLen) = VLen then
            Result := UnicodeString(PWideChar(@Buf[0]));
          Exit;
        finally
          FPDFPage_CloseAnnot(W);
        end;
      end;
    finally
      if OwnPage then
      begin
        FORM_OnBeforeClosePage(SearchPage, FormHandle);
        FPDF_ClosePage(SearchPage);
      end;
    end;
  end;
  procedure CaptureCalculationState(const AStage: string;
    out ABus, ATotal, AOther2, AOther1, AFirst: UnicodeString;
    out ATotalFound, AOther2Found, AOther1Found, AFirstFound: Boolean);
  var
    FoundBus: Boolean;
  begin
    ABus := FieldValueByNameOnPage('BUSINC', PhysicalPage(1), FoundBus);
    AOther2 := FieldValueByNameOnPage('TOTOTHERINCPG2', PhysicalPage(1), AOther2Found);
    AOther1 := FieldValueByNameOnPage('TOTOTHERINC', PhysicalPage(0), AOther1Found);
    ATotal := FieldValueByNameOnPage('TOTALINC', PhysicalPage(0), ATotalFound);
    AFirst := FieldValueByNameOnPage('FIRSTNAME', PhysicalPage(0), AFirstFound);
    LogStep(AStage + ': BUSINC vorhanden=' + BoolToStr(FoundBus, True) +
      ' Laenge=' + IntToStr(Length(ABus)) +
      '; TOTOTHERINCPG2 vorhanden=' + BoolToStr(AOther2Found, True) +
      ' Laenge=' + IntToStr(Length(AOther2)) +
      '; TOTOTHERINC vorhanden=' + BoolToStr(AOther1Found, True) +
      ' Laenge=' + IntToStr(Length(AOther1)) +
      '; TOTALINC vorhanden=' + BoolToStr(ATotalFound, True) +
      ' Laenge=' + IntToStr(Length(ATotal)) +
      '; FIRSTNAME vorhanden=' + BoolToStr(AFirstFound, True) +
      ' Laenge=' + IntToStr(Length(AFirst)));
  end;
begin
  Diag := nil;
  if False then
  begin
    Diag := TStringList.Create;
    LogStep('Alabama Patch 17 - Dokument-JavaScript vor Feld-Commit');
    LogStep('Seite: ' + IntToStr(APageIndex + 1));
    LogStep('Widget-Index: ' + IntToStr(AWidgetIndex));
    LogStep('Keine Feldinhalte werden protokolliert');
  end;
  try
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  FillChar(FormInfo, SizeOf(FormInfo), 0);
  FormInfo.Version := 1;
  // JavaScript-Plattform nur fuer den Commit der Formularaenderung aktivieren.
  // Alle Pointer bleiben bis zum ExitFormFillEnvironment gueltig.
  FillChar(JSInfo, SizeOf(JSInfo), 0);
  FillChar(JSPlatform, SizeOf(JSPlatform), 0);
  JSInfo.Version := 2;
  JSInfo.Invalidate := @JSInvalidate;
  JSInfo.SetCursor := @JSSetCursor;
  JSInfo.SetTimer := @JSSetTimer;
  JSInfo.KillTimer := @JSKillTimer;
  JSInfo.GetPage := @JSGetPage;
  JSInfo.GetCurrentPage := @JSGetCurrentPage;
  JSInfo.GetRotation := @JSGetRotation;
  JSInfo.ExecuteNamedAction := @JSNamedAction;
  JSInfo.CurrentDoc := FDocument;
  JSInfo.CurrentPageIndex := PhysicalPage(APageIndex);
  JSPlatform.Version := 2;
  JSPlatform.AppAlert := @JSAlert;
  JSPlatform.AppBeep := @JSBeep;
  JSPlatform.FormFillInfo := @JSInfo;
  JSInfo.JSPlatform := @JSPlatform;
  FormHandle := FPDFDOC_InitFormFillEnvironment(FDocument, @JSInfo);
  JSEnabled := FormHandle <> nil;
  LogStep('V8-Formularumgebung: ' + BoolToStr(JSEnabled, True));
  if not JSEnabled then
    FormHandle := InitCompatibleForm(FDocument, FormInfo);
  if FormHandle = nil then Exit;
  try
    // Dokument-JavaScript fuer allgemeine Textfeld-Aktionen registrieren.
    // DocumentOpen wird hier absichtlich nicht erneut ausgefuehrt.
    // Bestehende PDF-spezifische Sichtbarkeitsregeln bleiben erhalten.
    if JSEnabled then
    begin
      LogStep('Patch17: vor FORM_DoDocumentJSAction');
      FORM_DoDocumentJSAction(FormHandle);
      LogStep('Patch17: nach FORM_DoDocumentJSAction');
    end;
    Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
    if Page = nil then Exit;
    if JSEnabled then JSInfo.CurrentPage := Page;
    try
      FORM_OnAfterLoadPage(Page, FormHandle);
      LogStep('FORM_OnAfterLoadPage abgeschlossen');
      if Diag <> nil then
      begin
        CaptureCalculationState('Vorher', BeforeWages, BeforeTotal,
          BeforeOtherPage2, BeforeOtherPage1, BeforeFirstName,
          BeforeTotalFound, BeforeOtherPage2Found, BeforeOtherPage1Found,
          BeforeFirstNameFound);
        LogStep('PDF-Original: FIRSTNAME hat CalculateForm()/nameClean() als /AA/C; /CO enthaelt 3 Felder');
      end;
      try
        if (AWidgetIndex < 0) or
           (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
        Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
        if Annot = nil then Exit;
        try
          if (FPDFAnnot_GetSubtype(Annot) <> 20) or
             (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) <> 0) or
              (((FPDFAnnot_GetFlags(Annot) and 2) <> 0) and
               not IsAlabamaInteractionTest(APageIndex))) then Exit;
          FieldType := FPDFAnnot_GetFormFieldType(FormHandle, Annot);
          LogStep('Formfeldtyp: ' + IntToStr(FieldType));
          if Diag <> nil then
          begin
            Needed := FPDFAnnot_GetFormFieldName(FormHandle, Annot, nil, 0);
            if (Needed >= 2) and (Needed <= 8192) and ((Needed mod 2) = 0) then
            begin
              SetLength(Buffer, Needed div 2 + 1);
              FillChar(Buffer[0], Length(Buffer) * SizeOf(WideChar), 0);
              if FPDFAnnot_GetFormFieldName(FormHandle, Annot, @Buffer[0], Needed) = Needed then
                LogStep('Bearbeitetes Feld: ' + string(PWideChar(@Buffer[0])));
            end;
            LogStep('Feldflags: ' + IntToStr(FPDFAnnot_GetFormFieldFlags(FormHandle, Annot)));
          end;
          if (FieldType <> 4) and (FieldType <> 5) and (FieldType <> 6) then Exit;
          // Schreibschutz muss auch im Core erzwungen werden.
          if (FPDFAnnot_GetFormFieldFlags(FormHandle, Annot) and 1) <> 0 then Exit;

          // Dropdown: den Optionsindex an PDFium uebergeben. Das setzt
          // den Feldwert und die Darstellung, nicht nur ein Widget-/V.
          MatchedIndex := -1;
          if (FieldType = 4) or (FieldType = 5) then
          begin
            Count := FPDFAnnot_GetOptionCount(FormHandle, Annot);
            if (Count <= 0) or (Count > 10000) then Exit;
            for I := 0 to Count - 1 do
            begin
              Needed := FPDFAnnot_GetOptionLabel(FormHandle, Annot, I, nil, 0);
              if (Needed < 2) or (Needed > 65536) or
                 ((Needed mod 2) <> 0) then Continue;
              SetLength(Buffer, (Needed div 2) + 1);
              FillChar(Buffer[0], Length(Buffer) * SizeOf(WideChar), 0);
              if FPDFAnnot_GetOptionLabel(FormHandle, Annot, I,
                @Buffer[0], Needed) <> Needed then Continue;
              LabelText := string(PWideChar(@Buffer[0]));
              if LabelText = AValue then
              begin
                MatchedIndex := I;
                Break;
              end;
            end;
            if MatchedIndex < 0 then Exit;
          end;

          LogStep('Vor FORM_SetFocusedAnnot');
          FocusOK := FORM_SetFocusedAnnot(FormHandle, Annot) <> 0;
          LogStep('FORM_SetFocusedAnnot: ' + BoolToStr(FocusOK, True));
          if not FocusOK then Exit;
          ChangeOK := False;
          try
            if (FieldType = 4) or (FieldType = 5) then
              ChangeOK := FORM_SetIndexSelected(FormHandle, Page,
                MatchedIndex, 1) <> 0
            else if FORM_SelectAllText(FormHandle, Page) <> 0 then
            begin
              LogStep('Vor FORM_ReplaceSelection');
              FORM_ReplaceSelection(FormHandle, Page, PWideChar(AValue));
              LogStep('FORM_ReplaceSelection abgeschlossen');
              ChangeOK := True;
            end;
          finally
            // Commit und Appearance-Neugenerierung bei Fokusverlust.
            LogStep('Vor FORM_ForceToKillFocus');
            if FORM_ForceToKillFocus(FormHandle) = 0 then
              ChangeOK := False;
          end;
          LogStep('Commit-Ergebnis: ' + BoolToStr(ChangeOK, True));
          if Diag <> nil then
          begin
            CaptureCalculationState('Nachher', AfterWages, AfterTotal,
              AfterOtherPage2, AfterOtherPage1, AfterFirstName,
              AfterTotalFound, AfterOtherPage2Found, AfterOtherPage1Found,
              AfterFirstNameFound);
            LogStep('BUSINC geaendert: ' + BoolToStr(BeforeWages <> AfterWages, True));
            LogStep('TOTOTHERINCPG2 geaendert: ' + BoolToStr(BeforeOtherPage2 <> AfterOtherPage2, True));
            LogStep('TOTOTHERINC geaendert: ' + BoolToStr(BeforeOtherPage1 <> AfterOtherPage1, True));
            LogStep('TOTALINC geaendert: ' + BoolToStr(BeforeTotal <> AfterTotal, True));
            LogStep('FIRSTNAME geaendert: ' + BoolToStr(BeforeFirstName <> AfterFirstName, True));
          end;
          Result := ChangeOK;
          if Result then FModified := True;
        finally
          FPDFPage_CloseAnnot(Annot);
        end;
      finally
        FORM_OnBeforeClosePage(Page, FormHandle);
      end;
    finally
      FPDF_ClosePage(Page);
    end;
  finally
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
    LogStep('Formularumgebung freigegeben');
  end;
  finally
    Diag.Free;
  end;
end;

function TFreePDF64PDFiumCore.SetFormWidgetSelectedIndices(APageIndex,
  AWidgetIndex: Integer; const AIndices: TArray<Integer>): Boolean;
var
  Page, Annot, FormHandle: Pointer;
  FormInfo: TPDFFormFillInfo;
  I, J, Count, Flags: Integer;
  Selected, FocusOK, ChangeOK: Boolean;
begin
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) or (Length(AIndices) = 0) then Exit;
  FillChar(FormInfo, SizeOf(FormInfo), 0);
  FormInfo.Version := 1;
  FormHandle := InitCompatibleForm(FDocument, FormInfo);
  if FormHandle = nil then Exit;
  try
    Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
    if Page = nil then Exit;
    try
      FORM_OnAfterLoadPage(Page, FormHandle);
      try
        if (AWidgetIndex < 0) or
           (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then Exit;
        Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
        if Annot = nil then Exit;
        try
          if (FPDFAnnot_GetSubtype(Annot) <> 20) or
             (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) <> 0) or
              (((FPDFAnnot_GetFlags(Annot) and 2) <> 0) and
               not IsAlabamaInteractionTest(APageIndex))) or
             (FPDFAnnot_GetFormFieldType(FormHandle, Annot) <> 5) then Exit;
          Flags := FPDFAnnot_GetFormFieldFlags(FormHandle, Annot);
          if (Flags and 1) <> 0 then Exit;
          if ((Flags and $200000) = 0) and (Length(AIndices) > 1) then Exit;
          Count := FPDFAnnot_GetOptionCount(FormHandle, Annot);
          if (Count <= 0) or (Count > 10000) then Exit;
          for I := 0 to High(AIndices) do
            if (AIndices[I] < 0) or (AIndices[I] >= Count) then Exit;
          FocusOK := FORM_SetFocusedAnnot(FormHandle, Annot) <> 0;
          if not FocusOK then Exit;
          ChangeOK := True;
          try
            // PDFium aktualisiert /V, /I und die Widget-Appearance.
            // Erst alle Optionen abwählen, dann die gewünschten setzen.
            for I := 0 to Count - 1 do
              FORM_SetIndexSelected(FormHandle, Page, I, 0);
            for I := 0 to High(AIndices) do
            begin
              Selected := True;
              for J := 0 to I - 1 do
                if AIndices[J] = AIndices[I] then Selected := False;
              if Selected and (FORM_SetIndexSelected(FormHandle, Page,
                AIndices[I], 1) = 0) then ChangeOK := False;
            end;
          finally
            if FORM_ForceToKillFocus(FormHandle) = 0 then ChangeOK := False;
          end;
          Result := ChangeOK;
          if Result then FModified := True;
        finally
          FPDFPage_CloseAnnot(Annot);
        end;
      finally
        FORM_OnBeforeClosePage(Page, FormHandle);
      end;
    finally
      FPDF_ClosePage(Page);
    end;
  finally
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
  end;
end;

function TFreePDF64PDFiumCore.ToggleFormWidgetChoice(APageIndex,
  AWidgetIndex: Integer): Boolean;
var
  Page, Annot, FormHandle: Pointer;
  FormInfo: TPDFFormFillInfo;
  JSInfo: TPDFJSFormInfo;
  JSPlatform: TPDFJSPlatform;
  JSEnabled: Boolean;
  R: TPDFInkRect;
  FieldType: Integer;
  X, Y: Double;
  DownOK, UpOK: Integer;
  WasChecked, NowChecked: Boolean;
  OriginalClickFlags: Integer;
  ClickAnnot: Pointer;
  Diag: TStringList;
  DiagName: string;
  NameLength: Cardinal;
  NameBuffer: TArray<WideChar>;
  BeforeFirstName, BeforeTotalInc, BeforeTaxDue: UnicodeString;
  AfterFirstName, AfterTotalInc, AfterTaxDue: UnicodeString;
  BeforeWidgetValues, AfterWidgetValues: TArray<UnicodeString>;
  BeforeWidgetNames, AfterWidgetNames: TArray<string>;
  ChangedWidgetCount, WidgetCompareIndex: Integer;
  procedure FlushDiag;
  var
    LPath: string;
  begin
    if Diag = nil then Exit;
    try
      LPath := ChangeFileExt(FFileName, '.Alabama_Berechnung_Patch11.log');
      try
      except
        LPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
          'Alabama_Berechnung_Patch11.log';
      end;
    except
      // Logging must never interrupt form interaction.
    end;
  end;
  function ReadPageFieldValue(const AName: string): UnicodeString;
  var
    J: Integer;
    A: Pointer;
    N, V: Cardinal;
    Buf: TArray<WideChar>;
    FieldName: string;
  begin
    Result := '';
    for J := 0 to FPDFPage_GetAnnotCount(Page) - 1 do
    begin
      A := FPDFPage_GetAnnot(Page, J);
      if A = nil then Continue;
      try
        if FPDFAnnot_GetSubtype(A) <> 20 then Continue; // PDFium Widget
        N := FPDFAnnot_GetFormFieldName(FormHandle, A, nil, 0);
        if (N < 2) or (N > 8192) or ((N mod 2) <> 0) then Continue;
        SetLength(Buf, N div 2 + 1);
        FillChar(Buf[0], Length(Buf) * SizeOf(WideChar), 0);
        if FPDFAnnot_GetFormFieldName(FormHandle, A, @Buf[0], N) <> N then Continue;
        FieldName := string(PWideChar(@Buf[0]));
        if not SameText(FieldName, AName) then Continue;
        V := FPDFAnnot_GetFormFieldValue(FormHandle, A, nil, 0);
        if (V < 2) or (V > 65536) or ((V mod 2) <> 0) then Exit;
        SetLength(Buf, V div 2 + 1);
        FillChar(Buf[0], Length(Buf) * SizeOf(WideChar), 0);
        if FPDFAnnot_GetFormFieldValue(FormHandle, A, @Buf[0], V) = V then
          Result := UnicodeString(PWideChar(@Buf[0]));
        Exit;
      finally
        FPDFPage_CloseAnnot(A);
      end;
    end;
  end;
  procedure CapturePageWidgetValues(out ANames: TArray<string>;
    out AValues: TArray<UnicodeString>);
  var
    K: Integer;
    W: Pointer;
    NLen, VLen: Cardinal;
    Buffer: TArray<WideChar>;
  begin
    SetLength(ANames, FPDFPage_GetAnnotCount(Page));
    SetLength(AValues, Length(ANames));
    for K := 0 to High(ANames) do
    begin
      W := FPDFPage_GetAnnot(Page, K);
      if W = nil then Continue;
      try
        if FPDFAnnot_GetSubtype(W) <> 20 then Continue;
        NLen := FPDFAnnot_GetFormFieldName(FormHandle, W, nil, 0);
        if (NLen >= 2) and (NLen <= 8192) and ((NLen mod 2) = 0) then
        begin
          SetLength(Buffer, NLen div 2 + 1);
          FillChar(Buffer[0], Length(Buffer) * SizeOf(WideChar), 0);
          if FPDFAnnot_GetFormFieldName(FormHandle, W, @Buffer[0], NLen) = NLen then
            ANames[K] := string(PWideChar(@Buffer[0]));
        end;
        VLen := FPDFAnnot_GetFormFieldValue(FormHandle, W, nil, 0);
        if (VLen >= 2) and (VLen <= 65536) and ((VLen mod 2) = 0) then
        begin
          SetLength(Buffer, VLen div 2 + 1);
          FillChar(Buffer[0], Length(Buffer) * SizeOf(WideChar), 0);
          if FPDFAnnot_GetFormFieldValue(FormHandle, W, @Buffer[0], VLen) = VLen then
            AValues[K] := UnicodeString(PWideChar(@Buffer[0]));
        end;
      finally
        FPDFPage_CloseAnnot(W);
      end;
    end;
  end;
  function SafeReadField(const AName, APhase: string): UnicodeString;
  begin
    Result := '';
    if Diag <> nil then
      Diag.Add(APhase + ' ' + AName + ': Beginn');
    try
      Result := ReadPageFieldValue(AName);
      if Diag <> nil then
        Diag.Add(APhase + ' ' + AName + ': Ende (Laenge=' +
          IntToStr(Length(Result)) + ')');
    except
      on E: Exception do
      begin
        Result := '';
        if Diag <> nil then
          Diag.Add(APhase + ' ' + AName + ': Fehler ' + E.ClassName);
      end;
    end;
  end;
begin
  Result := False;
  Diag := nil;
  if False then
  begin
    Diag := TStringList.Create;
    Diag.Add('Alabama Patch 12 - Feldaktions- und Berechnungsdiagnose');
    Diag.Add('HOF PDF-Aktion (Originaldatei): MultiCB_01(event.target.name,event.target.value)');
    Diag.Add('PDF-AcroForm CO: 3 Eintraege (Originaldatei)');
    Diag.Add('Zeit: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Diag.Add('Seite: ' + IntToStr(APageIndex + 1));
    Diag.Add('Widget-Index: ' + IntToStr(AWidgetIndex));
    Diag.Add('Keine Formularwerte werden protokolliert.');
    FlushDiag; // Datei bereits vor der Formularverarbeitung anlegen
  end;
  try
  OriginalClickFlags := -1;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  FillChar(FormInfo, SizeOf(FormInfo), 0);
  FormInfo.Version := 1;
  // Allgemeine V8-JavaScript-Plattform fuer Checkboxen und Optionsfelder.
  // Die bestehende Behandlung der Formular-Sichtbarkeit bleibt unveraendert.
  // Ohne JSPlatform kann PDFium zwar den Haken setzen, aber keine
  // zugehoerigen JavaScript-Feldaktionen ausfuehren.
  JSEnabled := False;
  FormHandle := nil;
  if True then
  begin
    FillChar(JSInfo, SizeOf(JSInfo), 0);
    FillChar(JSPlatform, SizeOf(JSPlatform), 0);
    JSInfo.Version := 2;
    JSInfo.Invalidate := @JSInvalidate;
    JSInfo.SetCursor := @JSSetCursor;
    JSInfo.SetTimer := @JSSetTimer;
    JSInfo.KillTimer := @JSKillTimer;
    JSInfo.GetPage := @JSGetPage;
    JSInfo.GetCurrentPage := @JSGetCurrentPage;
    JSInfo.GetRotation := @JSGetRotation;
    JSInfo.ExecuteNamedAction := @JSNamedAction;
    JSInfo.CurrentDoc := FDocument;
    JSInfo.CurrentPageIndex := PhysicalPage(APageIndex);
    JSPlatform.Version := 2;
    JSPlatform.AppAlert := @JSAlert;
    JSPlatform.AppBeep := @JSBeep;
    JSPlatform.FormFillInfo := @JSInfo;
    JSInfo.JSPlatform := @JSPlatform;
    FormHandle := FPDFDOC_InitFormFillEnvironment(FDocument, @JSInfo);
    JSEnabled := FormHandle <> nil;
  end;
  if FormHandle = nil then
    FormHandle := InitCompatibleForm(FDocument, FormInfo);
  if Diag <> nil then
  begin
    Diag.Add('JS-Formularumgebung: ' + BoolToStr(JSEnabled, True));
    FlushDiag;
  end;
  if FormHandle = nil then Exit;
  try
    // Patch 18: Dokument-JavaScript auch fuer Checkbox-/Radioaktionen
    // registrieren. Viele Formulare definieren die von MouseUp verwendeten
    // Funktionen (z.B. MultiCB_01) als Dokument-JavaScript.
    // DocumentOpen wird absichtlich NICHT erneut ausgefuehrt.
    if JSEnabled then
    begin
      if Diag <> nil then
      begin
        Diag.Add('Patch18: vor FORM_DoDocumentJSAction (Checkbox)');
        FlushDiag;
      end;
      FORM_DoDocumentJSAction(FormHandle);
      if Diag <> nil then
      begin
        Diag.Add('Patch18: nach FORM_DoDocumentJSAction (Checkbox)');
        FlushDiag;
      end;
    end;
    Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
    if Page = nil then Exit;
    if JSEnabled then JSInfo.CurrentPage := Page;
    try
      // Alabama-Test 07: Dokument-JS/Open-Aktionen hier NICHT erneut
      // ausfuehren. Diese koennen VERCTRL und die versteckten Widgets
      // wieder auf den Adobe-Hinweiszustand setzen. Die V8-Plattform
      // bleibt fuer die eigentliche Formularinteraktion aktiv.
      FORM_OnAfterLoadPage(Page, FormHandle);
      try
        if Diag <> nil then
        begin
          Diag.Add('FORM_OnAfterLoadPage abgeschlossen');
          FlushDiag;
        end;
        // Nur Feld-Aenderungen protokollieren, niemals Formularinhalte.
        BeforeFirstName := '';
        BeforeTotalInc := '';
        BeforeTaxDue := '';
        if Diag <> nil then
        begin
          BeforeFirstName := SafeReadField('FIRSTNAME', 'Vor');
          BeforeTotalInc := SafeReadField('TOTALINC', 'Vor');
          BeforeTaxDue := SafeReadField('TAXDUE', 'Vor');
          Diag.Add('Snapshot aller Widgets vor Klick: Beginn');
          CapturePageWidgetValues(BeforeWidgetNames, BeforeWidgetValues);
          Diag.Add('Snapshot aller Widgets vor Klick: ' + IntToStr(Length(BeforeWidgetValues)));
          FlushDiag;
        end;
        if (AWidgetIndex < 0) or
           (AWidgetIndex >= FPDFPage_GetAnnotCount(Page)) then
        begin
          if Diag <> nil then begin Diag.Add('Abbruch: Widget-Index ungueltig'); FlushDiag; end;
          Exit;
        end;
        Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
        if Annot = nil then
        begin
          if Diag <> nil then begin Diag.Add('Abbruch: Annotation fehlt'); FlushDiag; end;
          Exit;
        end;
        try
          if Diag <> nil then
          begin
            Diag.Add('Annotation Subtyp: ' + IntToStr(FPDFAnnot_GetSubtype(Annot)));
            Diag.Add('Annotation Flags: ' + IntToStr(FPDFAnnot_GetFlags(Annot)));
            Diag.Add('Formfeldtyp: ' + IntToStr(FPDFAnnot_GetFormFieldType(FormHandle, Annot)));
            FlushDiag;
          end;
          if (FPDFAnnot_GetSubtype(Annot) <> 20) or
             (((FPDFAnnot_GetFlags(Annot) and (1 or 32)) <> 0) or
              (((FPDFAnnot_GetFlags(Annot) and 2) <> 0) and
               not IsAlabamaInteractionTest(APageIndex))) or
             (FPDFAnnot_GetRect(Annot, R) = 0) then Exit;
          FieldType := FPDFAnnot_GetFormFieldType(FormHandle, Annot);
          if (FieldType <> 2) and (FieldType <> 3) then
          begin
            if Diag <> nil then begin Diag.Add('Kein Checkbox-/Optionsfeld'); FlushDiag; end;
            Exit;
          end;
          // Schreibschutz muss auch im Core erzwungen werden.
          if (FPDFAnnot_GetFormFieldFlags(FormHandle, Annot) and 1) <> 0 then Exit;
          WasChecked := FPDFAnnot_IsChecked(FormHandle, Annot) <> 0;
          if Diag <> nil then
          begin
            NameLength := FPDFAnnot_GetFormFieldName(FormHandle, Annot, nil, 0);
            DiagName := '';
            if (NameLength >= 2) and (NameLength <= 8192) and
               ((NameLength mod 2) = 0) then
            begin
              SetLength(NameBuffer, NameLength div 2 + 1);
              FillChar(NameBuffer[0], Length(NameBuffer) * SizeOf(WideChar), 0);
              if FPDFAnnot_GetFormFieldName(FormHandle, Annot,
                @NameBuffer[0], NameLength) = NameLength then
                DiagName := string(PWideChar(@NameBuffer[0]));
            end;
            Diag.Add('Feldname: ' + DiagName);
            Diag.Add('Feldtyp: ' + IntToStr(FieldType));
            Diag.Add('Flags vor Klick: ' + IntToStr(FPDFAnnot_GetFlags(Annot)));
            Diag.Add('Checked vor Klick: ' + BoolToStr(WasChecked, True));
          end;
          if IsAlabamaInteractionTest(APageIndex) then
          begin
            OriginalClickFlags := FPDFAnnot_GetFlags(Annot);
            if (OriginalClickFlags and 2) <> 0 then
              FPDFAnnot_SetFlags(Annot, OriginalClickFlags and not 2)
            else
              OriginalClickFlags := -1;
          end;
          X := (R.Left + R.Right) * 0.5;
          Y := (R.Top + R.Bottom) * 0.5;
        finally
          FPDFPage_CloseAnnot(Annot);
        end;
        // 3b.50: PDFium-FormFill fuehrt den Klick aus. Es schreibt
        // /AS als PDF-Namen, synchronisiert das uebergeordnete /V
        // und pflegt die Widget-Appearance. Die bisherige direkte
        // SetStringValue('AS')-Methode erzeugte ungueltige PDF-Strings.
        // KEIN Rueckfall auf den alten Schreibweg bei Fehlern.
        try
          if Diag <> nil then begin Diag.Add('Vor MouseDown'); FlushDiag; end;
          DownOK := FORM_OnLButtonDown(FormHandle, Page, 0, X, Y);
          if Diag <> nil then begin Diag.Add('Vor MouseUp'); FlushDiag; end;
          UpOK := FORM_OnLButtonUp(FormHandle, Page, 0, X, Y);
          // Fokuswechsel kann PDFium-seitige Validate-/Calculate-Aktionen
          // ausloesen; die JS-Umgebung bleibt dabei noch gueltig.
          if Diag <> nil then
          begin
            Diag.Add('MouseDown Ergebnis: ' + IntToStr(DownOK));
            Diag.Add('MouseUp Ergebnis: ' + IntToStr(UpOK));
            FlushDiag;
          end;
          if JSEnabled then
          begin
            if Diag <> nil then
              Diag.Add('KillFocus Ergebnis: ' +
                IntToStr(FORM_ForceToKillFocus(FormHandle)))
            else
              FORM_ForceToKillFocus(FormHandle);
          end;
        finally
          if OriginalClickFlags >= 0 then
          begin
            ClickAnnot := FPDFPage_GetAnnot(Page, AWidgetIndex);
            if ClickAnnot <> nil then
            try
              FPDFAnnot_SetFlags(ClickAnnot, OriginalClickFlags);
            finally
              FPDFPage_CloseAnnot(ClickAnnot);
            end;
          end;
        end;
        // PDFium kann ein Mouse-Up mit 0 quittieren, obwohl der
        // Feldzustand bereits geaendert wurde. Massgeblich ist der
        // tatsaechliche Check-Zustand, nicht der Event-Rueckgabewert.
        Annot := FPDFPage_GetAnnot(Page, AWidgetIndex);
        if Annot = nil then Exit;
        try
          NowChecked := FPDFAnnot_IsChecked(FormHandle, Annot) <> 0;
        finally
          FPDFPage_CloseAnnot(Annot);
        end;
        Result := (NowChecked <> WasChecked) or
          ((FieldType = 3) and WasChecked and NowChecked);
        if Diag <> nil then
        begin
          AfterFirstName := SafeReadField('FIRSTNAME', 'Nach');
          AfterTotalInc := SafeReadField('TOTALINC', 'Nach');
          AfterTaxDue := SafeReadField('TAXDUE', 'Nach');
          Diag.Add('FIRSTNAME geaendert: ' + BoolToStr(BeforeFirstName <> AfterFirstName, True));
          Diag.Add('TOTALINC geaendert: ' + BoolToStr(BeforeTotalInc <> AfterTotalInc, True));
          Diag.Add('TAXDUE geaendert: ' + BoolToStr(BeforeTaxDue <> AfterTaxDue, True));
          Diag.Add('Snapshot aller Widgets nach Klick: Beginn');
          // Die Namen und Werte werden nur im Speicher verglichen.
          // Keine vertraulichen Formularwerte in die Protokolldatei schreiben.
          CapturePageWidgetValues(AfterWidgetNames, AfterWidgetValues);
          ChangedWidgetCount := 0;
          for WidgetCompareIndex := 0 to High(AfterWidgetValues) do
            if (WidgetCompareIndex <= High(BeforeWidgetValues)) and
               (BeforeWidgetValues[WidgetCompareIndex] <> AfterWidgetValues[WidgetCompareIndex]) then
            begin
              Inc(ChangedWidgetCount);
              Diag.Add('Wert geaendert: Widget ' + IntToStr(WidgetCompareIndex) +
                ' (' + AfterWidgetNames[WidgetCompareIndex] + ')');
            end;
          Diag.Add('Geaenderte Widgetwerte gesamt: ' + IntToStr(ChangedWidgetCount));
          Diag.Add('Hinweis: Keine Feldwerte oder Skriptinhalte im Log.');
          Diag.Add('Checked nach Klick: ' + BoolToStr(NowChecked, True));
          Diag.Add('Result: ' + BoolToStr(Result, True));
          FlushDiag;
        end;
        if NowChecked <> WasChecked then FModified := True;
      finally
        FORM_OnBeforeClosePage(Page, FormHandle);
      end;
    finally
      FPDF_ClosePage(Page);
    end;
  finally
    FPDFDOC_ExitFormFillEnvironment(FormHandle);
  end;
  finally
    if Diag <> nil then
    begin
      FlushDiag;
      Diag.Free;
    end;
  end;
end;

function TFreePDF64PDFiumCore.PDFVersion: string;
var V: Integer;
begin
  Result := '';
  V := 0;
  if (FDocument <> nil) and (FPDF_GetFileVersion(FDocument, V) <> 0) then
    Result := Format('%d.%d', [V div 10, V mod 10]);
end;

constructor TPDFBookmarkItem.Create;
begin
  inherited Create;
  PageIndex := -1;
  Children := TObjectList<TPDFBookmarkItem>.Create(True);
end;

destructor TPDFBookmarkItem.Destroy;
begin
  Children.Free;
  inherited;
end;

procedure TFreePDF64PDFiumCore.ReadBookmarks(AItems: TObjectList<TPDFBookmarkItem>);
  procedure AddLevel(AParent: Pointer; AList: TObjectList<TPDFBookmarkItem>; ADepth: Integer);
  var
    B, D, Act: Pointer;
    N: Cardinal;
    Buf: TArray<WideChar>;
    Item: TPDFBookmarkItem;
    Count: Integer;
  begin
    if ADepth > 48 then Exit;
    B := FPDFBookmark_GetFirstChild(FDocument, AParent);
    Count := 0;
    while (B <> nil) and (Count < 20000) do
    begin
      Inc(Count);
      Item := TPDFBookmarkItem.Create;
      N := FPDFBookmark_GetTitle(B, nil, 0);
      if (N >= 2) and (N <= 65536) then
      begin
        SetLength(Buf, N div 2 + 1);
        if FPDFBookmark_GetTitle(B, @Buf[0], N) > 0 then
          Item.Title := string(PWideChar(@Buf[0]));
      end;
      if Item.Title = '' then Item.Title := '(Ohne Titel)';
      D := FPDFBookmark_GetDest(FDocument, B);
      if D = nil then
      begin
        Act := FPDFBookmark_GetAction(B);
        if (Act <> nil) and (FPDFAction_GetType(Act) = 1) then
          D := FPDFAction_GetDest(FDocument, Act);
      end;
      if D <> nil then
        Item.PageIndex := VisiblePage(FPDFDest_GetDestPageIndex(FDocument, D));
      AList.Add(Item);
      AddLevel(B, Item.Children, ADepth + 1);
      B := FPDFBookmark_GetNextSibling(FDocument, B);
    end;
  end;
begin
  AItems.Clear;
  if FDocument <> nil then AddLevel(nil, AItems, 0);
end;

constructor TFreePDF64PDFiumCore.Create;
begin
  inherited Create;
  FStrokes := TObjectList<TPDFInkStroke>.Create(True);
  FStrokePages := TList<Integer>.Create;
  FTextActions := TList<TPDFInsertedTextAction>.Create;
  FNoteActions := TList<TPDFNoteAction>.Create;
  if TInterlocked.Increment(LibraryUsers) = 1 then
    FPDF_InitLibrary;
end;

destructor TFreePDF64PDFiumCore.Destroy;
begin
  CloseFile;
  FNoteActions.Free;
  FTextActions.Free;
  FStrokePages.Free;
  FStrokes.Free;
  TInterlocked.Decrement(LibraryUsers);
  // PDFium bleibt bis zum Prozessende initialisiert, um konkurrierende
  // Create/Destroy-Rennen zwischen Tabs und Lade-Threads zu vermeiden.
  inherited Destroy;
end;

function TFreePDF64PDFiumCore.PhysicalPage(AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= Length(FPageOrder)) then
    raise EPDFiumViewer.Create('Ungültige sichtbare Seitennummer.');
  Result := FPageOrder[AIndex];
end;

function TFreePDF64PDFiumCore.SourcePageIndex(AIndex: Integer): Integer;
begin
  Result := PhysicalPage(AIndex);
end;

function TFreePDF64PDFiumCore.VisiblePage(APhysical: Integer): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to High(FPageOrder) do
    if FPageOrder[I] = APhysical then Exit(I);
end;

procedure TFreePDF64PDFiumCore.WriteOrderedPDF(const AInput, AOutput: string);
var
  QPDF, CmdLine, PageList: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  ExitCode: DWORD;
  I: Integer;
begin
  QPDF := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'qpdf\bin\qpdf.exe';
  if not FileExists(QPDF) then
    raise EPDFiumViewer.Create('QPDF wurde nicht gefunden: ' + QPDF);
  PageList := '';
  for I := 0 to High(FPageOrder) do
  begin
    if PageList <> '' then PageList := PageList + ',';
    PageList := PageList + IntToStr(FPageOrder[I] + 1);
  end;
  CmdLine := '"' + QPDF + '" "' + AInput + '" --pages . ' +
    PageList + ' -- "' + AOutput + '"';
  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);
  SI.cb := SizeOf(SI);
  if not CreateProcess(PChar(QPDF), PChar(CmdLine), nil, nil, False,
    CREATE_NO_WINDOW, nil, PChar(ExtractFilePath(QPDF)), SI, PI) then
    RaiseLastOSError;
  try
    if WaitForSingleObject(PI.hProcess, INFINITE) <> WAIT_OBJECT_0 then
      raise EPDFiumViewer.Create('QPDF wurde unerwartet beendet.');
    ExitCode := 1;
    if not GetExitCodeProcess(PI.hProcess, ExitCode) or (ExitCode > 3) or
       not FileExists(AOutput) then
      raise EPDFiumViewer.CreateFmt('QPDF: Fehler %d beim Speichern.', [ExitCode]);
  finally
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
  end;
end;

procedure TFreePDF64PDFiumCore.InvalidateSearchCache;
begin
  FSearchCacheValid := False;
  FSearchTerm := '';
  SetLength(FSearchCache, 0);
end;

procedure TFreePDF64PDFiumCore.ClearTextActions;
var I: Integer; A: TPDFInsertedTextAction;
begin
  for I := 0 to FTextActions.Count - 1 do
  begin
    A := FTextActions[I];
    if not A.Inserted and not A.IsHighlight and (A.Obj <> nil) then FPDFPageObj_Destroy(A.Obj);
  end;
  FTextActions.Clear;
  FTextActionPos := 0;
end;

function TFreePDF64PDFiumCore.CanUndoInsertedText: Boolean;
begin Result := FTextActionPos > 0; end;

function TFreePDF64PDFiumCore.CanRedoInsertedText: Boolean;
begin Result := FTextActionPos < FTextActions.Count; end;

function TFreePDF64PDFiumCore.ChangeTextAction(AUndo: Boolean;
  out APageIndex: Integer): Boolean;
var A: TPDFInsertedTextAction; P, CurrentObj: Pointer; N: Integer;
begin
  Result := False;
  APageIndex := -1;
  if FDocument = nil then Exit;
  if AUndo then
  begin
    if not CanUndoInsertedText then Exit;
    N := FTextActionPos - 1;
  end
  else
  begin
    if not CanRedoInsertedText then Exit;
    N := FTextActionPos;
  end;
  A := FTextActions[N];
  P := FPDF_LoadPage(FDocument, A.PageIndex);
  if P = nil then raise EPDFiumViewer.Create('PDF-Seite konnte nicht geladen werden.');
  try
    if A.IsHighlight then
    begin
      if AUndo then
      begin
        if (A.AnnotIndex < 0) or (A.AnnotIndex >= FPDFPage_GetAnnotCount(P)) or
           (FPDFPage_RemoveAnnot(P, A.AnnotIndex) = 0) then
          raise EPDFiumViewer.Create('Hervorhebung konnte nicht entfernt werden.');
        A.Inserted := False;
      end
      else
      begin
        // Annotationen werden auf der neu geladenen Seite neu erzeugt.
        // Keine veralteten PDFium-Handles in der Historie behalten.
        A.AnnotIndex := FPDFPage_GetAnnotCount(P);
        FReplayingHighlight := True;
        try
          if A.IsArea then
          begin
            if not HighlightArea(VisiblePage(A.PageIndex), A.AreaX1, A.AreaY1,
              A.AreaX2, A.AreaY2, A.MarkColor) then
              raise EPDFiumViewer.Create('Hervorhebung konnte nicht wiederhergestellt werden.');
          end
          else if not HighlightText(VisiblePage(A.PageIndex), A.StartChar,
            A.CharCount, A.MarkColor) then
            raise EPDFiumViewer.Create('Hervorhebung konnte nicht wiederhergestellt werden.');
        finally
          FReplayingHighlight := False;
        end;
        A.Inserted := True;
      end;
    end
    else if AUndo then
    begin
      // Seiten werden bei jedem Aufruf neu geladen. Der urspruengliche
      // Objektzeiger ist dann nicht mehr der Zeiger dieser Seiteninstanz.
      if (A.ObjectIndex < 0) or
         (A.ObjectIndex >= FPDFPage_CountObjects(P)) then
        raise EPDFiumViewer.Create('Textobjekt-Index ist nicht mehr gueltig.');
      CurrentObj := FPDFPage_GetObject(P, A.ObjectIndex);
      if (CurrentObj = nil) or (FPDFPage_RemoveObject(P, CurrentObj) = 0) then
        raise EPDFiumViewer.Create('Textobjekt konnte nicht entfernt werden.');
      A.Obj := CurrentObj; // Entferntes Objekt gehoert jetzt uns.
      A.Inserted := False;
    end
    else
    begin
      A.ObjectIndex := FPDFPage_CountObjects(P);
      FPDFPage_InsertObject(P, A.Obj);
      A.Obj := nil; // Die Seite besitzt das Objekt wieder.
      A.Inserted := True;
    end;
    FTextActions[N] := A;
    if not A.IsHighlight then
      if FPDFPage_GenerateContent(P) = 0 then
        raise EPDFiumViewer.Create('PDF-Seiteninhalt konnte nicht aktualisiert werden.');
    if AUndo then Dec(FTextActionPos) else Inc(FTextActionPos);
    APageIndex := VisiblePage(A.PageIndex);
    FModified := True;
    InvalidateSearchCache;
    Result := True;
  finally
    FPDF_ClosePage(P);
  end;
end;

function TFreePDF64PDFiumCore.UndoInsertedText(out APageIndex: Integer): Boolean;
begin Result := ChangeTextAction(True, APageIndex); end;

function TFreePDF64PDFiumCore.RedoInsertedText(out APageIndex: Integer): Boolean;
begin Result := ChangeTextAction(False, APageIndex); end;

function TFreePDF64PDFiumCore.IsAlabamaInteractionTest(APageIndex: Integer): Boolean;
var
  N: string;
begin
  N := LowerCase(ExtractFileName(FFileName));
  Result := (FDocument <> nil) and (APageIndex >= 0) and
    (APageIndex < FPageCount) and (PhysicalPage(APageIndex) < 2) and
    ((Pos('25f40abr', N) > 0) or (Pos('alabama_form40', N) > 0));
end;

procedure TFreePDF64PDFiumCore.CloseFile;
begin
  ClearTextActions;
  FNoteActions.Clear;
  FNoteActionPos := 0;
  InvalidateSearchCache;
  if FDocument <> nil then
  begin
    FPDF_CloseDocument(FDocument);
    FDocument := nil;
  end;
  FFileName := '';
  FPageCount := 0;
  SetLength(FPageOrder, 0);
  FOrderChanged := False;
  FStrokes.Clear;
  FStrokePages.Clear;
  FModified := False;
end;

procedure TFreePDF64PDFiumCore.TakeDocumentFrom(ASource: TFreePDF64PDFiumCore);
begin
  if (ASource = nil) or (ASource = Self) then Exit;
  CloseFile;
  ASource.ClearTextActions;
  FDocument := ASource.FDocument;
  ASource.FDocument := nil;
  FFileName := ASource.FFileName;
  FPageCount := ASource.FPageCount;
  FPageOrder := ASource.FPageOrder;
  FOrderChanged := ASource.FOrderChanged;
  ASource.FFileName := '';
  ASource.FPageCount := 0;
  SetLength(ASource.FPageOrder, 0);
  ASource.FOrderChanged := False;
  InvalidateSearchCache;
end;

procedure TFreePDF64PDFiumCore.OpenFile(const AFileName: string; const APassword: AnsiString);
var
  Utf8Name: UTF8String;
  I: Integer;
  TestFormHandle: Pointer;
  TestJSInfo: TPDFJSFormInfo;
  TestPlatform: TPDFJSPlatform;
  Diag: TStringList;
  DiagCount, DiagFlags, DiagTotal: Integer;
  DiagPageHandle, DiagAnnotHandle: Pointer;
  DiagNameLength: Cardinal;
  DiagName: TBytes;
  DiagFieldName: string;
  TestPage, TestAnnot: Pointer;
  TestCount, TestIndex, TestFlags: Integer;

  procedure Snapshot(const Phase: string; AForm: Pointer);
  var
    LocalPage, LocalAnnot: Integer;
  begin
    Diag.Add('=== ' + Phase + ' ===');
    DiagTotal := 0;
    for LocalPage := 0 to Min(1, FPageCount - 1) do
    begin
      DiagPageHandle := FPDF_LoadPage(FDocument, LocalPage);
      if DiagPageHandle = nil then
      begin
        Diag.Add('Seite ' + IntToStr(LocalPage + 1) + ': FPDF_LoadPage fehlgeschlagen');
        Continue;
      end;
      try
        DiagCount := FPDFPage_GetAnnotCount(DiagPageHandle);
        Diag.Add('Seite ' + IntToStr(LocalPage + 1) + ': Annotationen=' + IntToStr(DiagCount));
        for LocalAnnot := 0 to DiagCount - 1 do
        begin
          DiagAnnotHandle := FPDFPage_GetAnnot(DiagPageHandle, LocalAnnot);
          if DiagAnnotHandle = nil then Continue;
          try
            if FPDFAnnot_GetSubtype(DiagAnnotHandle) <> 20 then Continue; // Widget
            Inc(DiagTotal);
            DiagFlags := FPDFAnnot_GetFlags(DiagAnnotHandle);
            DiagFieldName := '';
            if AForm <> nil then
            begin
              DiagNameLength := FPDFAnnot_GetFormFieldName(AForm, DiagAnnotHandle, nil, 0);
              if (DiagNameLength >= 2) and (DiagNameLength <= 8192) then
              begin
                SetLength(DiagName, DiagNameLength);
                if FPDFAnnot_GetFormFieldName(AForm, DiagAnnotHandle,
                  @DiagName[0], DiagNameLength) = DiagNameLength then
                  DiagFieldName := PWideChar(@DiagName[0]);
              end;
            end;
            Diag.Add(Format('S%d A%d Flags=%d Hidden=%s NoView=%s Name=%s',
              [LocalPage + 1, LocalAnnot, DiagFlags,
               BoolToStr((DiagFlags and 2) <> 0, True),
               BoolToStr((DiagFlags and 32) <> 0, True), DiagFieldName]));
          finally
            FPDFPage_CloseAnnot(DiagAnnotHandle);
          end;
        end;
      finally
        FPDF_ClosePage(DiagPageHandle);
      end;
    end;
    Diag.Add('Widget-Gesamtzahl auf Seiten 1-2: ' + IntToStr(DiagTotal));
  end;
begin
  CloseFile;
  if not FileExists(AFileName) then
    raise EPDFiumViewer.Create('PDF-Datei nicht gefunden: ' + AFileName);
  Utf8Name := UTF8Encode(ExpandFileName(AFileName));
  FDocument := FPDF_LoadDocument(PAnsiChar(Utf8Name), PAnsiChar(APassword));
  if FDocument = nil then
  begin
    if FPDF_GetLastError = 4 then // FPDF_ERR_PASSWORD
      raise EPDFiumPasswordRequired.Create('Für diese PDF-Datei ist ein gültiges Kennwort erforderlich.');
    raise EPDFiumViewer.Create('PDFium konnte die PDF-Datei nicht öffnen (PDFium-Fehler ' +
      IntToStr(FPDF_GetLastError) + ').');
  end;
  FFileName := ExpandFileName(AFileName);
  FPageCount := FPDF_GetPageCount(FDocument);
  SetLength(FPageOrder, FPageCount);
  for I := 0 to FPageCount - 1 do FPageOrder[I] := I;
  FOrderChanged := False;
  // Alabama-Test 05: Sichtbarkeit fuer die gesamte Dokument-Sitzung
  // setzen, damit PDFium bei Hit-Tests und Formularereignissen dieselben
  // Flags wie beim Zeichnen sieht. Nur die beiden ersten Seiten.
  if (Pos('25f40abr', LowerCase(ExtractFileName(FFileName))) > 0) or
     (Pos('alabama_form40', LowerCase(ExtractFileName(FFileName))) > 0) then
    for I := 0 to Min(1, FPageCount - 1) do
    begin
      TestPage := FPDF_LoadPage(FDocument, I);
      if TestPage = nil then Continue;
      try
        TestCount := FPDFPage_GetAnnotCount(TestPage);
        for TestIndex := 0 to TestCount - 1 do
        begin
          TestAnnot := FPDFPage_GetAnnot(TestPage, TestIndex);
          if TestAnnot = nil then Continue;
          try
            if FPDFAnnot_GetSubtype(TestAnnot) <> 20 then Continue;
            TestFlags := FPDFAnnot_GetFlags(TestAnnot);
            // Letztes Widget ist VERCTRL; Druckmarkierung davor erhalten.
            if TestIndex = TestCount - 1 then
              FPDFAnnot_SetFlags(TestAnnot, TestFlags or 2)
            else if (TestFlags and 2) <> 0 then
              FPDFAnnot_SetFlags(TestAnnot, TestFlags and not 2);
          finally
            FPDFPage_CloseAnnot(TestAnnot);
          end;
        end;
      finally
        FPDF_ClosePage(TestPage);
      end;
    end;

end;

procedure TFreePDF64PDFiumCore.AddStroke(APageIndex: Integer; APoints: TPDFInkStroke);
begin
  if (APoints = nil) or (APoints.Count < 2) then Exit;
  FStrokes.Add(APoints);
  FStrokePages.Add(PhysicalPage(APageIndex));
  FModified := True;
end;

function TFreePDF64PDFiumCore.HighlightText(APageIndex, AStartChar,
  ACharCount: Integer; AColor: TColor): Boolean;
const
  FPDF_ANNOT_HIGHLIGHT = 9;
  FPDFANNOT_COLORTYPE_Color = 0;
var
  Page, Annot: Pointer;
  Rects: TArray<TPDFInkRect>;
  R, Bounds: TPDFInkRect;
  Quad: TPDFQuadPoints;
  I, AnnotIndex: Integer;
  Action: TPDFInsertedTextAction;
  RGBColor: COLORREF;
begin
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) or (AStartChar < 0) or
     (ACharCount <= 0) then Exit;
  Rects := MatchCharRects(APageIndex, AStartChar, ACharCount);
  if Length(Rects) = 0 then Exit;
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then
    raise EPDFiumViewer.Create('PDF-Seite konnte nicht geladen werden.');
  try
    AnnotIndex := FPDFPage_GetAnnotCount(Page);
    Annot := FPDFPage_CreateAnnot(Page, FPDF_ANNOT_HIGHLIGHT);
    if Annot = nil then
      raise EPDFiumViewer.Create('Textmarkierung konnte nicht erstellt werden.');
    try
      Bounds := Rects[0];
      for I := 0 to High(Rects) do
      begin
        R := Rects[I];
        Bounds.Left := Min(Bounds.Left, R.Left);
        Bounds.Right := Max(Bounds.Right, R.Right);
        Bounds.Bottom := Min(Bounds.Bottom, R.Bottom);
        Bounds.Top := Max(Bounds.Top, R.Top);
        // PDFium: oben links, oben rechts, unten links, unten rechts.
        Quad.X1 := R.Left;  Quad.Y1 := R.Top;
        Quad.X2 := R.Right; Quad.Y2 := R.Top;
        Quad.X3 := R.Left;  Quad.Y3 := R.Bottom;
        Quad.X4 := R.Right; Quad.Y4 := R.Bottom;
        if FPDFAnnot_AppendAttachmentPoints(Annot, Quad) = 0 then
          raise EPDFiumViewer.Create('Textmarkierung: QuadPoints konnten nicht gesetzt werden.');
      end;
      RGBColor := ColorToRGB(AColor);
      if (FPDFAnnot_SetRect(Annot, Bounds) = 0) or
         (FPDFAnnot_SetColor(Annot, FPDFANNOT_COLORTYPE_Color,
           GetRValue(RGBColor), GetGValue(RGBColor), GetBValue(RGBColor), 160) = 0) then
        raise EPDFiumViewer.Create('Textmarkierung: Farbe oder Bereich konnte nicht gesetzt werden.');
      // Auch beim erneuten Oeffnen bzw. Drucken sichtbar halten.
      // PDF_ANNOT_FLAG_PRINT = 4; ohne gesetztes Flag koennen
      // einzelne PDF-Viewer die Markierung unterdruecken.
      if FPDFAnnot_SetFlags(Annot, 4) = 0 then
        raise EPDFiumViewer.Create('Textmarkierung: Annotationsflags konnten nicht gesetzt werden.');
      if not FReplayingHighlight then
      begin
        for I := FTextActions.Count - 1 downto FTextActionPos do
        begin
          Action := FTextActions[I];
          if not Action.Inserted and not Action.IsHighlight and (Action.Obj <> nil) then
            FPDFPageObj_Destroy(Action.Obj);
          FTextActions.Delete(I);
        end;
        Action := Default(TPDFInsertedTextAction);
        Action.PageIndex := PhysicalPage(APageIndex);
        Action.IsHighlight := True;
        Action.IsArea := False;
        Action.AnnotIndex := AnnotIndex;
        Action.StartChar := AStartChar;
        Action.CharCount := ACharCount;
        Action.MarkColor := AColor;
        Action.Inserted := True;
        FTextActions.Add(Action);
        FTextActionPos := FTextActions.Count;
      end;
      Result := True;
      FModified := True;
    except
      // Fehlgeschlagene Annotation aus der Seite entfernen.
      FPDFPage_CloseAnnot(Annot);
      Annot := nil;
      FPDFPage_RemoveAnnot(Page, AnnotIndex);
      raise;
    end;
    if Annot <> nil then FPDFPage_CloseAnnot(Annot);
  finally
    FPDF_ClosePage(Page);
  end;
end;

// Bildbasierte PDFs: halbtransparentes Rechteck als echte PDF-Annotation.
function TFreePDF64PDFiumCore.HighlightArea(APageIndex: Integer;
  AX1, AY1, AX2, AY2: Double; AColor: TColor): Boolean;
const
  FPDF_ANNOT_HIGHLIGHT = 9;
  FPDFANNOT_COLORTYPE_Color = 0;
var
  Page, Annot: Pointer;
  R: TPDFInkRect;
  Quad: TPDFQuadPoints;
  RGBColor: COLORREF;
  AnnotIndex, I: Integer;
  Action: TPDFInsertedTextAction;
begin
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or (APageIndex >= FPageCount) then Exit;
  R.Left := Min(AX1, AX2);
  R.Right := Max(AX1, AX2);
  R.Bottom := Min(AY1, AY2);
  R.Top := Max(AY1, AY2);
  if (R.Right - R.Left < 1) or (R.Top - R.Bottom < 1) then Exit;
  // Exakt den gezogenen Bereich verwenden: keine kuenstliche Vergroesserung.
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then raise EPDFiumViewer.Create('PDF-Seite konnte nicht geladen werden.');
  try
    AnnotIndex := FPDFPage_GetAnnotCount(Page);
    Annot := FPDFPage_CreateAnnot(Page, FPDF_ANNOT_HIGHLIGHT);
    if Annot = nil then raise EPDFiumViewer.Create('Farbmarkierung konnte nicht erstellt werden.');
    try
      // Highlight-Annotation mit QuadPoints statt Square-Annotation:
      // PDFium rendert diese wie die bereits funktionierenden Textmarkierungen.
      Quad.X1 := R.Left;   Quad.Y1 := R.Top;
      Quad.X2 := R.Right;  Quad.Y2 := R.Top;
      Quad.X3 := R.Left;   Quad.Y3 := R.Bottom;
      Quad.X4 := R.Right;  Quad.Y4 := R.Bottom;
      RGBColor := ColorToRGB(AColor);
      if (FPDFAnnot_AppendAttachmentPoints(Annot, Quad) = 0) or
         (FPDFAnnot_SetRect(Annot, R) = 0) or
         (FPDFAnnot_SetColor(Annot, FPDFANNOT_COLORTYPE_Color,
           GetRValue(RGBColor), GetGValue(RGBColor), GetBValue(RGBColor), 160) = 0) or
         (FPDFAnnot_SetFlags(Annot, 4) = 0) then
        raise EPDFiumViewer.Create('Farbmarkierung konnte nicht eingerichtet werden.');
      if not FReplayingHighlight then
      begin
        for I := FTextActions.Count - 1 downto FTextActionPos do
        begin
          Action := FTextActions[I];
          if not Action.Inserted and not Action.IsHighlight and (Action.Obj <> nil) then
            FPDFPageObj_Destroy(Action.Obj);
          FTextActions.Delete(I);
        end;
        Action := Default(TPDFInsertedTextAction);
        Action.PageIndex := PhysicalPage(APageIndex);
        Action.IsHighlight := True;
        Action.IsArea := True;
        Action.AnnotIndex := AnnotIndex;
        Action.AreaX1 := AX1;
        Action.AreaY1 := AY1;
        Action.AreaX2 := AX2;
        Action.AreaY2 := AY2;
        Action.MarkColor := AColor;
        Action.Inserted := True;
        FTextActions.Add(Action);
        FTextActionPos := FTextActions.Count;
      end;
      FModified := True;
      Result := True;
    except
      FPDFPage_CloseAnnot(Annot);
      Annot := nil;
      FPDFPage_RemoveAnnot(Page, AnnotIndex);
      raise;
    end;
    if Annot <> nil then FPDFPage_CloseAnnot(Annot);
  finally
    FPDF_ClosePage(Page);
  end;
end;

function TFreePDF64PDFiumCore.GetNotes(APageIndex: Integer): TArray<TPDFNote>;
var
  P, A: Pointer;
  I, N: Integer;
  Note: TPDFNote;
  Buf: TBytes;
begin
  SetLength(Result, 0);
  if (FDocument = nil) or (APageIndex < 0) or (APageIndex >= FPageCount) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if P = nil then Exit;
  try
    for I := 0 to FPDFPage_GetAnnotCount(P)-1 do
    begin
      A := FPDFPage_GetAnnot(P, I);
      if A = nil then Continue;
      try
        if (FPDFAnnot_GetSubtype(A) <> 1) or
           (FPDFAnnot_GetRect(A, Note.Bounds) = 0) then Continue;
        Note.PageIndex := APageIndex;
        Note.AnnotIndex := I;
        N := FPDFAnnot_GetStringValue(A, 'Contents', nil, 0);
        Note.Contents := '';
        if (N >= 2) and ((N mod 2) = 0) and (N < 1048576) then
        begin
          SetLength(Buf, N);
          if FPDFAnnot_GetStringValue(A, 'Contents', @Buf[0], N) = Cardinal(N) then
            SetString(Note.Contents, PWideChar(@Buf[0]), N div 2 - 1);
        end;
        SetLength(Result, Length(Result)+1);
        Result[High(Result)] := Note;
      finally
        FPDFPage_CloseAnnot(A);
      end;
    end;
  finally
    FPDF_ClosePage(P);
  end;
end;

procedure TFreePDF64PDFiumCore.RecordNoteAction(const A: TPDFNoteAction);
begin
  while FNoteActions.Count > FNoteActionPos do
    FNoteActions.Delete(FNoteActions.Count-1);
  FNoteActions.Add(A);
  Inc(FNoteActionPos);
  FModified := True;
end;

function TFreePDF64PDFiumCore.ApplyNoteState(const N: TPDFNote;
  AExists: Boolean; AIndex: Integer): Boolean;
var
  P, A: Pointer;
  C: Integer;
begin
  Result := False;
  P := FPDF_LoadPage(FDocument, PhysicalPage(N.PageIndex));
  if P = nil then Exit;
  try
    C := FPDFPage_GetAnnotCount(P);
    if AExists then
    begin
      if (AIndex >= 0) and (AIndex < C) then
        A := FPDFPage_GetAnnot(P, AIndex)
      else
        A := FPDFPage_CreateAnnot(P, 1);
      if A = nil then Exit;
      try
        Result := (FPDFAnnot_SetRect(A, N.Bounds) <> 0) and
          (FPDFAnnot_SetStringValue(A, 'Contents', PWideChar(N.Contents)) <> 0);
        FPDFAnnot_SetFlags(A, 4);
      finally
        FPDFPage_CloseAnnot(A);
      end;
    end
    else if (AIndex >= 0) and (AIndex < C) then
      Result := FPDFPage_RemoveAnnot(P, AIndex) <> 0;
  finally
    FPDF_ClosePage(P);
  end;
  if Result then FModified := True;
end;

function TFreePDF64PDFiumCore.AddNote(APageIndex: Integer;
  AX, AY: Double; const AText: string): Boolean;
var
  N: TPDFNote;
  A: TPDFNoteAction;
  P: Pointer;
begin
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or
    (APageIndex >= FPageCount) or (Trim(AText) = '') then Exit;
  N.PageIndex := APageIndex;
  N.Contents := AText;
  N.Bounds.Left := AX;
  N.Bounds.Right := AX + 20;
  N.Bounds.Top := AY;
  N.Bounds.Bottom := AY - 20;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if P = nil then Exit;
  try
    N.AnnotIndex := FPDFPage_GetAnnotCount(P);
  finally
    FPDF_ClosePage(P);
  end;
  Result := ApplyNoteState(N, True, -1);
  if Result then
  begin
    A.PageIndex := APageIndex;
    A.NoteIndex := N.AnnotIndex;
    A.BeforeExists := False;
    A.AfterExists := True;
    A.AfterNote := N;
    RecordNoteAction(A);
  end;
end;

function TFreePDF64PDFiumCore.ChangeNote(const ANote: TPDFNote;
  const AText: string; AX, AY: Double; AMove: Boolean): Boolean;
var
  A: TPDFNoteAction;
  N: TPDFNote;
  W, H: Single;
begin
  N := ANote;
  if AMove then
  begin
    W := ANote.Bounds.Right - ANote.Bounds.Left;
    H := ANote.Bounds.Top - ANote.Bounds.Bottom;
    N.Bounds.Left := AX;
    N.Bounds.Right := AX + W;
    N.Bounds.Top := AY;
    N.Bounds.Bottom := AY - H;
  end
  else N.Contents := AText;
  Result := ApplyNoteState(N, True, ANote.AnnotIndex);
  if Result then
  begin
    A.PageIndex := N.PageIndex;
    A.NoteIndex := N.AnnotIndex;
    A.BeforeExists := True;
    A.AfterExists := True;
    A.BeforeNote := ANote;
    A.AfterNote := N;
    RecordNoteAction(A);
  end;
end;

function TFreePDF64PDFiumCore.DeleteNote(const ANote: TPDFNote): Boolean;
var A: TPDFNoteAction;
begin
  Result := ApplyNoteState(ANote, False, ANote.AnnotIndex);
  if Result then
  begin
    A.PageIndex := ANote.PageIndex;
    A.NoteIndex := ANote.AnnotIndex;
    A.BeforeExists := True;
    A.AfterExists := False;
    A.BeforeNote := ANote;
    RecordNoteAction(A);
  end;
end;

function TFreePDF64PDFiumCore.CanUndoNote: Boolean;
begin Result := FNoteActionPos > 0; end;
function TFreePDF64PDFiumCore.CanRedoNote: Boolean;
begin Result := FNoteActionPos < FNoteActions.Count; end;
function TFreePDF64PDFiumCore.UndoNote(out APageIndex: Integer): Boolean;
var A: TPDFNoteAction;
begin
  Result := False;
  APageIndex := -1;
  if not CanUndoNote then Exit;
  A := FNoteActions[FNoteActionPos-1];
  if A.BeforeExists then
    Result := ApplyNoteState(A.BeforeNote, True,
      IfThen(A.AfterExists, A.NoteIndex, -1))
  else Result := ApplyNoteState(A.AfterNote, False, A.NoteIndex);
  if Result then begin Dec(FNoteActionPos); APageIndex := A.PageIndex; end;
end;
function TFreePDF64PDFiumCore.RedoNote(out APageIndex: Integer): Boolean;
var A: TPDFNoteAction;
begin
  Result := False;
  APageIndex := -1;
  if not CanRedoNote then Exit;
  A := FNoteActions[FNoteActionPos];
  if A.AfterExists then
    Result := ApplyNoteState(A.AfterNote, True,
      IfThen(A.BeforeExists, A.NoteIndex, -1))
  else Result := ApplyNoteState(A.BeforeNote, False, A.NoteIndex);
  if Result then begin Inc(FNoteActionPos); APageIndex := A.PageIndex; end;
end;

function TFreePDF64PDFiumCore.PagePointToDevice(APageIndex, AWidth,
  AHeight: Integer; AX, AY: Double; out X, Y: Integer): Boolean;
var P: Pointer;
begin
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or
     (APageIndex >= FPageCount) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if P = nil then Exit;
  try
    Result := FPDF_PageToDevice(P, 0, 0, AWidth, AHeight, 0,
      AX, AY, X, Y) <> 0;
  finally
    FPDF_ClosePage(P);
  end;
end;

function TFreePDF64PDFiumCore.DevicePointToPage(APageIndex, AWidth, AHeight,
  X, Y: Integer; out AX, AY: Double): Boolean;
var P: Pointer;
begin
  Result := False;
  if (FDocument = nil) or (APageIndex < 0) or (APageIndex >= FPageCount) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if P = nil then Exit;
  try
    Result := FPDF_DeviceToPage(P, 0, 0, AWidth, AHeight, 0,
      X, Y, AX, AY) <> 0;
  finally
    FPDF_ClosePage(P);
  end;
end;

function TFreePDF64PDFiumCore.LinkAtPoint(APageIndex, AWidth, AHeight,
  X, Y: Integer; out ATarget: TPDFLinkTarget): Boolean;
var
  Page, Link, Action, Dest, TP, Web: Pointer;
  I, J, K, Hit, A, B, AtPos, DotPos: Integer;
  L, T, R, Bottom, CL, CR, CB, CT, NL, NR, NB, NT: Double;
  TextURL, Fragment: string;
  C: Cardinal;
  WBuf: array of WideChar;
  PX, PY: Double;
  N: Cardinal;
  Buf: TBytes;
  URL: UTF8String;
begin
  Result := False;
  ATarget.URI := '';
  ATarget.PageIndex := -1;
  if (FDocument = nil) or (APageIndex < 0) or (APageIndex >= FPageCount) or
     (AWidth <= 0) or (AHeight <= 0) then Exit;
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then Exit;
  try
    if FPDF_DeviceToPage(Page, 0, 0, AWidth, AHeight, 0,
      X, Y, PX, PY) = 0 then Exit;
    Link := FPDFLink_GetLinkAtPoint(Page, PX, PY);
    if Link = nil then
    begin
      // Automatisch erkannte URLs sind oft keine PDF-Link-Annotationen.
      TP := FPDFText_LoadPage(Page);
      if TP = nil then Exit;
      try
        Web := FPDFLink_LoadWebLinks(TP);
        if Web <> nil then
        try
          for I := 0 to FPDFLink_CountWebLinks(Web) - 1 do
            for J := 0 to FPDFLink_CountRects(Web, I) - 1 do
              if (FPDFLink_GetRect(Web, I, J, L, T, R, Bottom) <> 0) and
                 (PX >= L) and (PX <= R) and (PY >= Bottom) and (PY <= T) then
              begin
                K := FPDFLink_GetURL(Web, I, nil, 0);
                if (K > 1) and (K < 8192) then
                begin
                  SetLength(WBuf, K);
                  FPDFLink_GetURL(Web, I, @WBuf[0], K);
                  ATarget.URI := PWideChar(@WBuf[0]);
                  // PDFium kann bei Textlinks ein www.-Ziel ohne Schema liefern.
                  if ATarget.URI.StartsWith('www.', True) then
                    ATarget.URI := 'https://' + ATarget.URI
                  else if (Pos('@', ATarget.URI) > 1) and
                          (Pos(':', ATarget.URI) = 0) then
                    ATarget.URI := 'mailto:' + ATarget.URI;
                  Exit(ATarget.URI <> '');
                end;
              end;
        finally
          FPDFLink_CloseWebLinks(Web);
        end;

        // Nur Zeichen derselben Textzeile verwenden. Word-PDFs koennen
        // zusaetzliche Leerzeichen und Steuerzeichen in der Textschicht haben.
        Hit := FPDFText_GetCharIndexAtPos(TP, PX, PY, 3, 3);
        if Hit < 0 then Exit;
        if FPDFText_GetCharBox(TP, Hit, CL, CR, CB, CT) = 0 then Exit;
        A := Hit;
        B := Hit;
        while (A > 0) and (Hit - A < 256) do
        begin
          if FPDFText_GetCharBox(TP, A - 1, NL, NR, NB, NT) = 0 then Break;
          if (Abs((NT + NB) / 2 - (CT + CB) / 2) > (CT - CB) * 0.45) or
             (CL - NR > (CT - CB) * 0.9) then Break;
          C := FPDFText_GetUnicode(TP, A - 1);
          if (C = 10) or (C = 13) then Break;
          Dec(A);
          CL := NL;
        end;
        CL := 0;
        while (B < FPDFText_CountChars(TP) - 1) and (B - Hit < 256) do
        begin
          if FPDFText_GetCharBox(TP, B, CL, CR, CB, CT) = 0 then Break;
          if FPDFText_GetCharBox(TP, B + 1, NL, NR, NB, NT) = 0 then Break;
          if (Abs((NT + NB) / 2 - (CT + CB) / 2) > (CT - CB) * 0.45) or
             (NL - CR > (CT - CB) * 0.9) then Break;
          C := FPDFText_GetUnicode(TP, B + 1);
          if (C = 10) or (C = 13) then Break;
          Inc(B);
        end;
        Fragment := '';
        for K := A to B do
        begin
          C := FPDFText_GetUnicode(TP, K);
          if (C > 32) and (C <= $FFFF) then
            Fragment := Fragment + Char(C);
        end;
        TextURL := Fragment.Trim;
        while (TextURL <> '') and CharInSet(TextURL[Length(TextURL)],
          ['.', ',', ';', ')', '>', '"']) do
          Delete(TextURL, Length(TextURL), 1);
        AtPos := Pos('@', TextURL);
        DotPos := LastDelimiter('.', TextURL);
        if TextURL.StartsWith('mailto:', True) and (AtPos > 8) and
           (DotPos > AtPos + 1) and (DotPos < Length(TextURL)) then
          ATarget.URI := TextURL
        else if (AtPos > 1) and (DotPos > AtPos + 1) and
                (DotPos < Length(TextURL)) and
                (Pos('://', TextURL) = 0) and (Pos(':', TextURL) = 0) then
          ATarget.URI := 'mailto:' + TextURL
        else if TextURL.StartsWith('www.', True) then
          ATarget.URI := 'https://' + TextURL
        else if TextURL.StartsWith('https://', True) or
                TextURL.StartsWith('http://', True) then
          ATarget.URI := TextURL;
        Result := ATarget.URI <> '';
      finally
        FPDFText_ClosePage(TP);
      end;
      Exit;
    end;
    Action := FPDFLink_GetAction(Link);
    if Action <> nil then
    begin
      case FPDFAction_GetType(Action) of
        3: begin // PDFACTION_URI
          N := FPDFAction_GetURIPath(FDocument, Action, nil, 0);
          if (N = 0) or (N > 8192) then Exit;
          SetLength(Buf, N);
          N := FPDFAction_GetURIPath(FDocument, Action, @Buf[0], N);
          if N = 0 then Exit;
          SetString(URL, PAnsiChar(@Buf[0]), N);
          ATarget.URI := string(URL).Trim;
          if (ATarget.URI <> '') and (ATarget.URI[Length(ATarget.URI)] = #0) then
            Delete(ATarget.URI, Length(ATarget.URI), 1);
          if ATarget.URI.StartsWith('www.', True) then
            ATarget.URI := 'https://' + ATarget.URI
          else if (Pos('@', ATarget.URI) > 1) and
                  (Pos(':', ATarget.URI) = 0) then
            ATarget.URI := 'mailto:' + ATarget.URI;
          Result := ATarget.URI <> '';
        end;
        1: begin // PDFACTION_GOTO
          Dest := FPDFAction_GetDest(FDocument, Action);
          if Dest <> nil then
            ATarget.PageIndex := VisiblePage(FPDFDest_GetDestPageIndex(FDocument, Dest));
          Result := (ATarget.PageIndex >= 0) and (ATarget.PageIndex < FPageCount);
        end;
      end;
    end
    else
    begin
      Dest := FPDFLink_GetDest(FDocument, Link);
      if Dest <> nil then
        ATarget.PageIndex := VisiblePage(FPDFDest_GetDestPageIndex(FDocument, Dest));
      Result := (ATarget.PageIndex >= 0) and (ATarget.PageIndex < FPageCount);
    end;
  finally
    FPDF_ClosePage(Page);
  end;
end;

procedure TFreePDF64PDFiumCore.RotatePages(AFirstPage, ALastPage,
  AAngle: Integer; const ATargetFile: string);
var
  I, NewRotation: Integer;
  Page: Pointer;
  W: TOutputWriter;
begin
  if FDocument = nil then
    raise EPDFiumViewer.Create('Es ist keine PDF-Datei geöffnet.');
  if (AFirstPage < 1) or (ALastPage > FPageCount) or
     (AFirstPage > ALastPage) or ((AAngle <> 90) and (AAngle <> 180) and (AAngle <> 270)) then
    raise EPDFiumViewer.Create('Ungültiger Seitenbereich oder Drehwinkel.');
  if SameText(ExpandFileName(ATargetFile), FFileName) then
    raise EPDFiumViewer.Create('Die Ausgabedatei muss von der Quelldatei abweichen.');
  for I := AFirstPage - 1 to ALastPage - 1 do
  begin
    Page := FPDF_LoadPage(FDocument, PhysicalPage(I));
    if Page = nil then
      raise EPDFiumViewer.CreateFmt('Seite %d konnte nicht geladen werden.', [I + 1]);
    try
      NewRotation := (FPDFPage_GetRotation(Page) + (AAngle div 90)) mod 4;
      FPDFPage_SetRotation(Page, NewRotation);
    finally
      FPDF_ClosePage(Page);
    end;
  end;
  FillChar(W, SizeOf(W), 0);
  W.Base.Version := 1;
  W.Base.WriteBlock := PDFWriteBlock;
  W.Stream := TFileStream.Create(ATargetFile, fmCreate);
  try
    if FPDF_SaveAsCopy(FDocument, @W.Base, 0) = 0 then
      raise EPDFiumViewer.Create('Die gedrehte PDF konnte nicht gespeichert werden.');
  finally
    W.Stream.Free;
  end;
end;

procedure TFreePDF64PDFiumCore.RotateInMemory(AFirstPage, ALastPage, AAngle: Integer);
var
  I: Integer;
  Page: Pointer;
begin
  ClearTextActions;
  if (AFirstPage < 1) or (ALastPage > FPageCount) or
     (AFirstPage > ALastPage) or (AAngle <> 90) and (AAngle <> -90) then
    raise EPDFiumViewer.Create('Ungültiger Seitenbereich oder Drehwinkel.');
  for I := AFirstPage - 1 to ALastPage - 1 do
  begin
    Page := FPDF_LoadPage(FDocument, PhysicalPage(I));
    if Page = nil then raise EPDFiumViewer.Create('Seite konnte nicht gedreht werden.');
    try
      FPDFPage_SetRotation(Page, (FPDFPage_GetRotation(Page) +
        Ord(AAngle = 90) + 3 * Ord(AAngle = -90)) mod 4);
    finally
      FPDF_ClosePage(Page);
    end;
  end;
  FModified := True;
  InvalidateSearchCache;
end;

procedure TFreePDF64PDFiumCore.ImportPDFPages(const AFileName: string;
  AVisibleIndex: Integer);
var
  Src: Pointer;
  SourceName: UTF8String;
  I, OldCount, ImportedCount: Integer;
  NewOrder: TArray<Integer>;
begin
  if FDocument = nil then
    raise EPDFiumViewer.Create('Kein PDF-Dokument geöffnet.');
  if (AVisibleIndex < 0) or (AVisibleIndex > FPageCount) then
    raise EPDFiumViewer.Create('Ungültige Einfügeposition.');
  if SameText(ExpandFileName(AFileName), ExpandFileName(FFileName)) then
    raise EPDFiumViewer.Create('Das geöffnete PDF kann nicht in sich selbst eingefügt werden.');
  SourceName := UTF8String(AFileName);
  Src := FPDF_LoadDocument(PAnsiChar(SourceName), nil);
  if Src = nil then
    raise EPDFiumViewer.Create('Die einzufügende PDF konnte nicht geöffnet werden (ggf. kennwortgeschützt).');
  try
    ImportedCount := FPDF_GetPageCount(Src);
    if ImportedCount < 1 then
      raise EPDFiumViewer.Create('Die ausgewählte PDF enthält keine Seiten.');
    OldCount := FPageCount;
    // Physisch hinten anhängen; nur die sichtbare Seitenzuordnung anpassen.
    // Dadurch bleiben vorhandene Annotationen und Seitenindizes unverändert.
    if FPDF_ImportPages(FDocument, Src, nil, OldCount) = 0 then
      raise EPDFiumViewer.Create('PDF-Seiten konnten nicht eingefügt werden.');
    SetLength(NewOrder, OldCount + ImportedCount);
    for I := 0 to AVisibleIndex - 1 do NewOrder[I] := FPageOrder[I];
    for I := 0 to ImportedCount - 1 do
      NewOrder[AVisibleIndex + I] := OldCount + I;
    for I := AVisibleIndex to OldCount - 1 do
      NewOrder[I + ImportedCount] := FPageOrder[I];
    ClearTextActions;
    FPageOrder := NewOrder;
    FPageCount := FPDF_GetPageCount(FDocument);
    FOrderChanged := True;
    FModified := True;
    InvalidateSearchCache;
  finally
    FPDF_CloseDocument(Src);
  end;
end;

procedure TFreePDF64PDFiumCore.MovePage(AIndex, ANewIndex: Integer);
var I, Saved: Integer;
begin
  ClearTextActions;
  if (FDocument = nil) or (AIndex < 0) or (AIndex >= FPageCount) or
     (ANewIndex < 0) or (ANewIndex >= FPageCount) then
    raise EPDFiumViewer.Create('Ungültige Seitenposition.');
  if AIndex = ANewIndex then Exit;
  Saved := FPageOrder[AIndex];
  if AIndex < ANewIndex then
    for I := AIndex to ANewIndex - 1 do FPageOrder[I] := FPageOrder[I + 1]
  else
    for I := AIndex downto ANewIndex + 1 do FPageOrder[I] := FPageOrder[I - 1];
  FPageOrder[ANewIndex] := Saved;
  FOrderChanged := True;
  FModified := True;
  InvalidateSearchCache;
end;

procedure TFreePDF64PDFiumCore.DeletePages(const APageIndices: TArray<Integer>);
var
  I, J, K, CountDeleted, OldCount: Integer;
  Selected: TArray<Boolean>;
  NewOrder: TArray<Integer>;
begin
  ClearTextActions;
  if (FDocument = nil) or (Length(APageIndices) = 0) then Exit;
  OldCount := FPageCount;
  SetLength(Selected, OldCount);
  CountDeleted := 0;
  for I := 0 to High(APageIndices) do
    if (APageIndices[I] >= 0) and (APageIndices[I] < OldCount) and
       not Selected[PhysicalPage(APageIndices[I])] then
    begin
      Selected[PhysicalPage(APageIndices[I])] := True;
      Inc(CountDeleted);
    end;
  if CountDeleted = 0 then Exit;
  if CountDeleted >= OldCount then
    raise EPDFiumViewer.Create('Mindestens eine PDF-Seite muss erhalten bleiben.');
  for I := FStrokePages.Count - 1 downto 0 do
  begin
    if Selected[FStrokePages[I]] then
    begin
      FStrokePages.Delete(I);
      FStrokes.Delete(I);
    end
    else
    begin
      K := 0;
      for J := 0 to FStrokePages[I] - 1 do
        if Selected[J] then Inc(K);
      FStrokePages[I] := FStrokePages[I] - K;
    end;
  end;
  SetLength(NewOrder, OldCount - CountDeleted);
  K := 0;
  for I := 0 to OldCount - 1 do
    if not Selected[FPageOrder[I]] then
    begin
      CountDeleted := 0;
      for J := 0 to FPageOrder[I] - 1 do
        if Selected[J] then Inc(CountDeleted);
      NewOrder[K] := FPageOrder[I] - CountDeleted;
      Inc(K);
    end;
  for I := OldCount - 1 downto 0 do
    if Selected[I] then FPDFPage_Delete(FDocument, I);
  FPageCount := FPDF_GetPageCount(FDocument);
  FPageOrder := NewOrder;
  FOrderChanged := True;
  FModified := True;
  InvalidateSearchCache;
end;

procedure TFreePDF64PDFiumCore.ExportPages(
  const AVisiblePages: TArray<Integer>; const ATargetFile: string);
var
  W: TOutputWriter;
  TempFile, QPDF, CmdLine, Pages: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  ExitCode: DWORD;
  I: Integer;
begin
  if Length(AVisiblePages) = 0 then Exit;
  QPDF := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'qpdf\bin\qpdf.exe';
  if not FileExists(QPDF) then
    raise EPDFiumViewer.Create('QPDF wurde nicht gefunden.');
  TempFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
    'fp64_extract_' + IntToStr(GetCurrentProcessId) + '.pdf';
  Pages := '';
  for I := 0 to High(AVisiblePages) do
  begin
    if Pages <> '' then Pages := Pages + ',';
    Pages := Pages + IntToStr(PhysicalPage(AVisiblePages[I]) + 1);
  end;
  FillChar(W, SizeOf(W), 0);
  W.Base.Version := 1;
  W.Base.WriteBlock := PDFWriteBlock;
  W.Stream := TFileStream.Create(TempFile, fmCreate);
  try
    if FPDF_SaveAsCopy(FDocument, @W.Base, 0) = 0 then
      raise EPDFiumViewer.Create('PDFium konnte die Seiten nicht vorbereiten.');
  finally
    W.Stream.Free;
  end;
  try
    CmdLine := '"' + QPDF + '" --empty --pages "' + TempFile +
      '" ' + Pages + ' -- "' + ATargetFile + '"';
    FillChar(SI, SizeOf(SI), 0);
    FillChar(PI, SizeOf(PI), 0);
    SI.cb := SizeOf(SI);
    if not CreateProcess(PChar(QPDF), PChar(CmdLine), nil, nil, False,
      CREATE_NO_WINDOW, nil, PChar(ExtractFilePath(QPDF)), SI, PI) then
      RaiseLastOSError;
    try
      if WaitForSingleObject(PI.hProcess, INFINITE) <> WAIT_OBJECT_0 then
        raise EPDFiumViewer.Create('QPDF wurde unerwartet beendet.');
      ExitCode := 1;
      if not GetExitCodeProcess(PI.hProcess, ExitCode) or (ExitCode > 3) or
         not FileExists(ATargetFile) then
        raise EPDFiumViewer.CreateFmt('QPDF-Extraktion fehlgeschlagen: %d.', [ExitCode]);
    finally
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;
  finally
    if FileExists(TempFile) then DeleteFile(TempFile);
  end;
end;

procedure TFreePDF64PDFiumCore.InsertText(APageIndex: Integer;
  AX, AY: Double; const AText: string; AFontSize: Double; AColor: TColor; const AFontName: string);
var
  Page, Font, Obj: Pointer;
  C: Cardinal;
  A: TPDFInsertedTextAction;
  I: Integer;
  DC: HDC;
  HFont, OldFont: HGDIOBJ;
  FontSize: DWORD;
  FontBytes: TBytes;
  FontSignature: DWORD;
begin
  if (FDocument = nil) or (APageIndex < 0) or (APageIndex >= FPageCount) then
    raise EPDFiumViewer.Create('Keine gueltige PDF-Seite zum Einfuegen.');
  if (Trim(AText) = '') or (AFontSize < 1) or (AFontSize > 200) then
    raise EPDFiumViewer.Create('Text oder Schriftgroesse ungueltig.');
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then raise EPDFiumViewer.Create('PDF-Seite konnte nicht geladen werden.');
  try
    // Schriftdatei ueber Windows/GDI auslesen. GetFontData liefert die
    // tatsaechlichen TrueType-Bytes, nicht nur einen nicht-portablen Namen.
    DC := CreateCompatibleDC(0);
    if DC = 0 then raise EPDFiumViewer.Create('Schrift konnte nicht geladen werden.');
    try
      HFont := CreateFontW(-MulDiv(12, GetDeviceCaps(DC, LOGPIXELSY), 72),
        0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_TT_ONLY_PRECIS,
        CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
        PWideChar(AFontName));
      if HFont = 0 then raise EPDFiumViewer.Create('Schrift konnte nicht erzeugt werden.');
      try
        OldFont := SelectObject(DC, HFont);
        try
          FontSize := GetFontData(DC, 0, 0, nil, 0);
          if (FontSize = $FFFFFFFF) or (FontSize < 12) or (FontSize > 32 * 1024 * 1024) then
            raise EPDFiumViewer.Create('Diese Schriftart besitzt keine einbettbaren TrueType-Daten.');
          SetLength(FontBytes, FontSize);
          if GetFontData(DC, 0, 0, @FontBytes[0], FontSize) <> FontSize then
            raise EPDFiumViewer.Create('Schriftdaten konnten nicht gelesen werden.');
        finally
          SelectObject(DC, OldFont);
        end;
      finally
        DeleteObject(HFont);
      end;
    finally
      DeleteDC(DC);
    end;
    // TrueType sfnt; OpenType-CFF ('OTTO') ist nicht TrueType.
    Move(FontBytes[0], FontSignature, SizeOf(FontSignature));
    if FontSignature <> $00000100 then
      raise EPDFiumViewer.Create('Nur TrueType-Schriftarten (.ttf) werden unterstuetzt.');
    // CID=True: zusammengesetzte Schrift mit Unicode-Zeichenzuordnung.
    // CID=False verwendet eine einfache 8-Bit-Schrift; Umlaute koennen fehlen.
    Font := FPDFText_LoadFont(FDocument, @FontBytes[0], Length(FontBytes), 2, 1);
    if Font = nil then raise EPDFiumViewer.Create('PDFium konnte die Schrift nicht einbetten.');
    Obj := FPDFPageObj_CreateTextObj(FDocument, Font, AFontSize);
    if Obj = nil then raise EPDFiumViewer.Create('PDFium konnte kein Textobjekt erzeugen.');
    try
      if FPDFText_SetText(Obj, PWideChar(AText)) = 0 then
        raise EPDFiumViewer.Create('PDFium konnte den Text nicht uebernehmen.');
      C := ColorToRGB(AColor);
      if FPDFPageObj_SetFillColor(Obj, GetRValue(C), GetGValue(C), GetBValue(C), 255) = 0 then
        raise EPDFiumViewer.Create('PDFium konnte die Textfarbe nicht setzen.');
      FPDFPageObj_Transform(Obj, 1, 0, 0, 1, AX, AY);
      FPDFPage_InsertObject(Page, Obj);
      Obj := nil; // Eigentum geht an die PDF-Seite ueber.
      if FPDFPage_GenerateContent(Page) = 0 then
        raise EPDFiumViewer.Create('PDFium konnte den Seiteninhalt nicht aktualisieren.');
      // A new edit invalidates the redo branch. Only detached objects are ours.
      for I := FTextActions.Count - 1 downto FTextActionPos do
      begin
        A := FTextActions[I];
        if not A.Inserted and not A.IsHighlight and (A.Obj <> nil) then FPDFPageObj_Destroy(A.Obj);
        FTextActions.Delete(I);
      end;
      A := Default(TPDFInsertedTextAction);
      A.PageIndex := PhysicalPage(APageIndex);
      A.Obj := nil; // Seitenobjekte nie ueber Seiten-Reloads hinweg dereferenzieren.
      A.ObjectIndex := FPDFPage_CountObjects(Page) - 1;
      A.Inserted := True;
      FTextActions.Add(A);
      FTextActionPos := FTextActions.Count;
      FModified := True;
      InvalidateSearchCache;
    finally
      if Obj <> nil then FPDFPageObj_Destroy(Obj);
    end;
  finally
    FPDF_ClosePage(Page);
  end;
end;

procedure TFreePDF64PDFiumCore.SaveAs(const AFileName: string);
var
  I, J, CheckPageIndex, CheckAnnotIndex: Integer;
  OriginalWidgetCount, SavedWidgetCount: Integer;
  SourcePage, SourceAnnot: Pointer;
  SourceWidgetRect, SavedWidgetRect: TPDFInkRect;
  SourceIndex, SavedIndex: Integer;
  NativeSourceForm, NativeSavedForm: Pointer;
  NativeSourceInfo, NativeSavedInfo: TPDFFormFillInfo;
  NativeSourceType, NativeSavedType, NativeOptionIndex, NativeOptionCount: Integer;
  P, A, CheckDoc, CheckPage, CheckAnnot: Pointer;
  CheckName: UTF8String;
  R: TPDFInkRect;
  S: TPDFInkStroke;
  Points: TArray<TPDFInkPoint>;
  W: TOutputWriter;
  Target, Stage: string;
  Header: array[0..4] of AnsiChar;
  Tail: AnsiString;
  TailSize, EofPos, K, XRefPos, DigitStart: Integer;
  XRefOffset: Int64;
  function NativeFieldValue(AForm, An: Pointer): UnicodeString;
  var
    Needed: Cardinal;
    Data: TArray<WideChar>;
  begin
    Result := '';
    Needed := FPDFAnnot_GetFormFieldValue(AForm, An, nil, 0);
    if (Needed = 0) then Exit;
    if (Needed < 2) or (Needed > 1048576) or ((Needed mod 2) <> 0) then
      raise EPDFiumViewer.Create('PDFium meldet eine ungueltige Formularwertlaenge.');
    SetLength(Data, Needed div 2);
    if FPDFAnnot_GetFormFieldValue(AForm, An, @Data[0], Needed) <> Needed then
      raise EPDFiumViewer.Create('PDFium konnte den Formularwert nicht vollstaendig lesen.');
    Result := string(PWideChar(@Data[0]));
  end;
  // M2.9-M2.12: PDFium liefert Namen und Optionsbeschriftungen
  // einschließlich vererbter AcroForm-Eigenschaften direkt.
  function NativeFieldName(AForm, An: Pointer): UnicodeString;
  var
    Needed: Cardinal;
    Data: TArray<WideChar>;
  begin
    Result := '';
    Needed := FPDFAnnot_GetFormFieldName(AForm, An, nil, 0);
    if Needed = 0 then Exit;
    if (Needed < 2) or (Needed > 1048576) or ((Needed mod 2) <> 0) then
      raise EPDFiumViewer.Create('Ungültige PDFium-Feldnamenlänge.');
    SetLength(Data, Needed div 2);
    if FPDFAnnot_GetFormFieldName(AForm, An, @Data[0], Needed) <> Needed then
      raise EPDFiumViewer.Create('PDFium konnte den Feldnamen nicht lesen.');
    Result := string(PWideChar(@Data[0]));
  end;
  function NativeOptionLabel(AForm, An: Pointer; AIndex: Integer): UnicodeString;
  var
    Needed: Cardinal;
    Data: TArray<WideChar>;
  begin
    Result := '';
    Needed := FPDFAnnot_GetOptionLabel(AForm, An, AIndex, nil, 0);
    if Needed = 0 then Exit;
    if (Needed < 2) or (Needed > 1048576) or ((Needed mod 2) <> 0) then
      raise EPDFiumViewer.Create('Ungültige PDFium-Optionslänge.');
    SetLength(Data, Needed div 2);
    if FPDFAnnot_GetOptionLabel(AForm, An, AIndex, @Data[0], Needed) <> Needed then
      raise EPDFiumViewer.Create('PDFium konnte die Optionsbeschriftung nicht lesen.');
    Result := string(PWideChar(@Data[0]));
  end;
  function ReadWidgetValue(An: Pointer; const Key: AnsiString): UnicodeString;
  var
    N: Cardinal;
    Buf: TBytes;
  begin
    Result := '';
    N := FPDFAnnot_GetStringValue(An, PAnsiChar(Key), nil, 0);
    if (N < 2) or ((N mod 2) <> 0) then Exit;
    SetLength(Buf, N);
    if FPDFAnnot_GetStringValue(An, PAnsiChar(Key), @Buf[0], N) <> N then Exit;
    SetString(Result, PWideChar(@Buf[0]), (N div 2) - 1);
  end;
begin
  ClearTextActions;
  if FDocument = nil then Exit;
  // Anzahl der Formular-Widgets vor dem Schreiben als Referenz merken.
  OriginalWidgetCount := FormWidgetCount;
  Target := ExpandFileName(AFileName);
  if SameText(Target, FFileName) then
    raise EPDFiumViewer.Create('Bitte unter einem neuen Dateinamen speichern.');
  for I := 0 to FStrokes.Count - 1 do
  begin
    S := FStrokes[I];
    if S.Count = 0 then Continue;
    SetLength(Points, S.Count);
    for J := 0 to S.Count - 1 do
      Points[J] := S[J];
    P := FPDF_LoadPage(FDocument, FStrokePages[I]);
    if P = nil then raise EPDFiumViewer.Create('Markierungsseite konnte nicht geladen werden.');
    try
      if S.IsCover then
        A := FPDFPage_CreateAnnot(P, 5) // PDF_ANNOT_SQUARE (PDFium: 5; 4 is LINE)
      else
        A := FPDFPage_CreateAnnot(P, 15); // PDF_ANNOT_INK
      if A = nil then raise EPDFiumViewer.Create('PDF-Markierung konnte nicht erzeugt werden.');
      try
        if (not S.IsCover) and (FPDFAnnot_AddInkStroke(A, @Points[0], Length(Points)) < 0) then
          raise EPDFiumViewer.Create('PDF-Markierungsstrich konnte nicht gespeichert werden.');
        FPDFAnnot_SetColor(A, 0,
          GetRValue(ColorToRGB(S.StrokeColor)),
          GetGValue(ColorToRGB(S.StrokeColor)),
          GetBValue(ColorToRGB(S.StrokeColor)), IfThen(S.IsCover, 255, 115));
        if S.IsCover then
          FPDFAnnot_SetColor(A, 1, 0, 0, 0, 255);
        if S.IsCover then
          FPDFAnnot_SetBorder(A, 0, 0, 0)
        else
          FPDFAnnot_SetBorder(A, 0, 0, Max(0.5, S.LineWidth));
        R.Left := S[0].X; R.Right := R.Left;
        R.Bottom := S[0].Y; R.Top := R.Bottom;
        for J := 1 to S.Count - 1 do
        begin
          R.Left := Min(R.Left, S[J].X);
          R.Right := Max(R.Right, S[J].X);
          R.Bottom := Min(R.Bottom, S[J].Y);
          R.Top := Max(R.Top, S[J].Y);
        end;
        if not S.IsCover then
        begin
          R.Left := R.Left - 9; R.Right := R.Right + 9;
          R.Bottom := R.Bottom - 9; R.Top := R.Top + 9;
        end;
        FPDFAnnot_SetRect(A, R);
        FPDFAnnot_SetFlags(A, 4);
      finally
        FPDFPage_CloseAnnot(A);
      end;
    finally
      FPDF_ClosePage(P);
    end;
  end;
  FillChar(W, SizeOf(W), 0);
  W.Base.Version := 1;
  W.Base.WriteBlock := PDFWriteBlock;
  Stage := Target;
  if FOrderChanged then
    Stage := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
      'fp64_order_' + IntToStr(GetCurrentProcessId) + '.pdf';
  W.Stream := TFileStream.Create(Stage, fmCreate);
  try
    if FPDF_SaveAsCopy(FDocument, @W.Base, 0) = 0 then
      raise EPDFiumViewer.Create('PDFium konnte die PDF nicht speichern.');
  finally
    W.Stream.Free;
  end;
  if FOrderChanged then
  begin
    try
      WriteOrderedPDF(Stage, Target);
    finally
      if FileExists(Stage) then DeleteFile(Stage);
    end;
  end;
  // Speichern erst als erfolgreich werten, wenn die Zieldatei
  // tatsaechlich existiert und nicht leer ist. Das gilt auch fuer
  // PDFs mit bearbeiteten Formular-Widgets.
  if not FileExists(Target) then
    raise EPDFiumViewer.Create('Die gespeicherte PDF-Datei wurde nicht gefunden.');
  with TFileStream.Create(Target, fmOpenRead or fmShareDenyNone) do
  try
    if Size < SizeOf(Header) then
      raise EPDFiumViewer.Create('Die gespeicherte PDF-Datei ist zu kurz.');
    if Read(Header, SizeOf(Header)) <> SizeOf(Header) then
      raise EPDFiumViewer.Create('Der PDF-Dateikopf konnte nicht gelesen werden.');
    if (Header[0] <> '%') or (Header[1] <> 'P') or
       (Header[2] <> 'D') or (Header[3] <> 'F') or
       (Header[4] <> '-') then
      raise EPDFiumViewer.Create('Die gespeicherte Datei besitzt keinen PDF-Dateikopf.');
    // PDF-Abschlussmarker auch bei groesseren Dateien pruefen.
    // Ein gueltiger Header allein erkennt abgeschnittene Ausgaben nicht.
    TailSize := Integer(Min(Int64(4096), Size));
    SetLength(Tail, TailSize);
    Position := Size - TailSize;
    if Read(Tail[1], TailSize) <> TailSize then
      raise EPDFiumViewer.Create('Das PDF-Dateiende konnte nicht gelesen werden.');
    // Den LETZTEN %%EOF-Marker suchen; ein alter Marker aus einem
    // inkrementellen Update darf keine abgeschnittene Datei kaschieren.
    EofPos := 0;
    for K := TailSize - 4 downto 1 do
      if Copy(Tail, K, 5) = '%%EOF' then
      begin
        EofPos := K;
        Break;
      end;
    if EofPos = 0 then
      raise EPDFiumViewer.Create('Der PDF-Abschlussmarker fehlt (moeglicherweise unvollstaendig gespeichert).');
    // Nach dem letzten Marker duerfen nur PDF-Whitespace-Zeichen folgen.
    for K := EofPos + 5 to TailSize do
      if not (Tail[K] in [#0, #9, #10, #12, #13, #32]) then
        raise EPDFiumViewer.Create('Unerwartete Daten nach dem PDF-Abschlussmarker.');
    // startxref muss zum letzten Abschlussabschnitt gehoeren.
    // Letztes startxref vor %%EOF suchen, nicht einen aelteren
    // Eintrag aus einem inkrementellen PDF-Update akzeptieren.
    XRefPos := 0;
    for K := EofPos - Length('startxref') downto 1 do
      if Copy(Tail, K, Length('startxref')) = 'startxref' then
      begin
        XRefPos := K;
        Break;
      end;
    if XRefPos = 0 then
      raise EPDFiumViewer.Create('Der PDF-Querverweis am Dateiende fehlt.');
    DigitStart := XRefPos + Length('startxref');
    while (DigitStart < EofPos) and
      (Tail[DigitStart] in [#9, #10, #12, #13, #32]) do
      Inc(DigitStart);
    if (DigitStart >= EofPos) or not (Tail[DigitStart] in ['0'..'9']) then
      raise EPDFiumViewer.Create('Die startxref-Position fehlt.');
    XRefOffset := 0;
    K := DigitStart;
    while (K < EofPos) and (Tail[K] in ['0'..'9']) do
    begin
      // Ueberlauf beim Einlesen der PDF-Dateiposition verhindern.
      if XRefOffset > (High(Int64) - 9) div 10 then
        raise EPDFiumViewer.Create('Die startxref-Position ist ungueltig.');
      XRefOffset := XRefOffset * 10 + Ord(Tail[K]) - Ord('0');
      Inc(K);
    end;
    if (XRefOffset <= 0) or (XRefOffset >= Size) then
      raise EPDFiumViewer.Create('Die startxref-Position liegt ausserhalb der PDF-Datei.');
  finally
    Free;
  end;
  // Die gerade geschriebene PDF zusaetzlich durch PDFium neu einlesen.
  // Dies prueft die Struktur staerker als Header, EOF und startxref allein.
  // Kennwortgeschuetzte Dateien ohne gespeichertes Kennwort koennen hier
  // nicht erneut geoeffnet werden; deren bisherige Strukturpruefung gilt.
  CheckName := UTF8Encode(Target);
  CheckDoc := FPDF_LoadDocument(PAnsiChar(CheckName), nil);
  if CheckDoc = nil then
  begin
    if FPDF_GetLastError <> 4 then // FPDF_ERR_PASSWORD
      raise EPDFiumViewer.Create('Die gespeicherte PDF konnte von PDFium nicht erneut geoeffnet werden.');
  end
  else
  try
    if FPDF_GetPageCount(CheckDoc) <> FPageCount then
      raise EPDFiumViewer.Create('Die gespeicherte PDF enthaelt eine unerwartete Seitenzahl.');
    // Patch 3b.23: Alle Widget-Annotationen nach dem Speichern
    // erneut zaehlen. So wird ein Verlust von Formularfeldern erkannt.
    SavedWidgetCount := 0;
    for CheckPageIndex := 0 to FPDF_GetPageCount(CheckDoc) - 1 do
    begin
      CheckPage := FPDF_LoadPage(CheckDoc, CheckPageIndex);
      if CheckPage = nil then
        raise EPDFiumViewer.Create('Eine gespeicherte PDF-Seite konnte nicht geladen werden.');
      try
        for CheckAnnotIndex := 0 to FPDFPage_GetAnnotCount(CheckPage) - 1 do
        begin
          CheckAnnot := FPDFPage_GetAnnot(CheckPage, CheckAnnotIndex);
          if CheckAnnot = nil then Continue;
          try
            if FPDFAnnot_GetSubtype(CheckAnnot) = 20 then // PDF_ANNOT_WIDGET
              Inc(SavedWidgetCount);
          finally
            FPDFPage_CloseAnnot(CheckAnnot);
          end;
        end;
      finally
        FPDF_ClosePage(CheckPage);
      end;
    end;
    if SavedWidgetCount <> OriginalWidgetCount then
      raise EPDFiumViewer.Create(Format(
        'Die gespeicherte PDF hat eine abweichende Formularfeldanzahl (%d statt %d).',
        [SavedWidgetCount, OriginalWidgetCount]));
    // Patch 3b.31: Auch die Verteilung der Formular-Widgets auf
    // die einzelnen Seiten muss beim Speichern erhalten bleiben.
    // Die Gesamtzahl allein erkennt Verschiebungen zwischen Seiten nicht.
    for CheckPageIndex := 0 to FPDF_GetPageCount(CheckDoc) - 1 do
    begin
      SourcePage := FPDF_LoadPage(FDocument, FPageOrder[CheckPageIndex]);
      CheckPage := FPDF_LoadPage(CheckDoc, CheckPageIndex);
      if (SourcePage = nil) or (CheckPage = nil) then
      begin
        if SourcePage <> nil then FPDF_ClosePage(SourcePage);
        if CheckPage <> nil then FPDF_ClosePage(CheckPage);
        raise EPDFiumViewer.CreateFmt(
          'Formularpruefung: Seite %d konnte nicht geladen werden.',
          [CheckPageIndex + 1]);
      end;
      try
        J := 0;
        for I := 0 to FPDFPage_GetAnnotCount(SourcePage) - 1 do
        begin
          SourceAnnot := FPDFPage_GetAnnot(SourcePage, I);
          if SourceAnnot <> nil then
          try
            if FPDFAnnot_GetSubtype(SourceAnnot) = 20 then Inc(J);
          finally
            FPDFPage_CloseAnnot(SourceAnnot);
          end;
        end;
        CheckAnnotIndex := 0;
        for I := 0 to FPDFPage_GetAnnotCount(CheckPage) - 1 do
        begin
          CheckAnnot := FPDFPage_GetAnnot(CheckPage, I);
          if CheckAnnot <> nil then
          try
            if FPDFAnnot_GetSubtype(CheckAnnot) = 20 then
              Inc(CheckAnnotIndex);
          finally
            FPDFPage_CloseAnnot(CheckAnnot);
          end;
        end;
        if J <> CheckAnnotIndex then
          raise EPDFiumViewer.CreateFmt(
            'Formularpruefung: Auf Seite %d sind %d statt %d Widgets vorhanden.',
            [CheckPageIndex + 1, CheckAnnotIndex, J]);
      finally
        FPDF_ClosePage(SourcePage);
        FPDF_ClosePage(CheckPage);
      end;
    end;
    // Patch 3b.24: Widget-Zustaende der gespeicherten PDF mit dem
    // aktuellen PDFium-Dokument vergleichen (Werte /V und Status /AS).
    // Der Vergleich erfolgt seitenweise in der Annotationsreihenfolge.
    for CheckPageIndex := 0 to FPDF_GetPageCount(CheckDoc) - 1 do
    begin
      SourcePage := FPDF_LoadPage(FDocument, FPageOrder[CheckPageIndex]);
      CheckPage := FPDF_LoadPage(CheckDoc, CheckPageIndex);
      if (SourcePage = nil) or (CheckPage = nil) then
      begin
        if SourcePage <> nil then FPDF_ClosePage(SourcePage);
        if CheckPage <> nil then FPDF_ClosePage(CheckPage);
        raise EPDFiumViewer.Create('Formularvergleich: Seite konnte nicht geladen werden.');
      end;
      try
        SourceIndex := 0;
        SavedIndex := 0;
        while (SourceIndex < FPDFPage_GetAnnotCount(SourcePage)) and
              (SavedIndex < FPDFPage_GetAnnotCount(CheckPage)) do
        begin
          SourceAnnot := FPDFPage_GetAnnot(SourcePage, SourceIndex);
          CheckAnnot := FPDFPage_GetAnnot(CheckPage, SavedIndex);
          try
            if (SourceAnnot = nil) or (CheckAnnot = nil) then
              raise EPDFiumViewer.Create('Formularvergleich: Annotation fehlt.');
            if FPDFAnnot_GetSubtype(SourceAnnot) <> FPDFAnnot_GetSubtype(CheckAnnot) then
              raise EPDFiumViewer.Create('Formularvergleich: Annotationsreihenfolge weicht ab.');
            if FPDFAnnot_GetSubtype(SourceAnnot) = 20 then
            begin
              // 3b.26: Position und Abmessungen der Widgets pruefen.
              // PDFium liefert die Rechtecke in PDF-Punkten. Kleine
              // Rundungsabweichungen bis 0,05 pt werden toleriert.
              if (FPDFAnnot_GetRect(SourceAnnot, SourceWidgetRect) = 0) or
                 (FPDFAnnot_GetRect(CheckAnnot, SavedWidgetRect) = 0) then
                raise EPDFiumViewer.Create(Format(
                  'Formular-Rechteck nicht lesbar (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
              if (Abs(SourceWidgetRect.Left - SavedWidgetRect.Left) > 0.05) or
                 (Abs(SourceWidgetRect.Right - SavedWidgetRect.Right) > 0.05) or
                 (Abs(SourceWidgetRect.Top - SavedWidgetRect.Top) > 0.05) or
                 (Abs(SourceWidgetRect.Bottom - SavedWidgetRect.Bottom) > 0.05) then
                raise EPDFiumViewer.Create(Format(
                  'Formularfeld-Position nach dem Speichern abweichend (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
              // 3b.28: Annotations-Flags (/F) vergleichen. Dazu gehoeren
              // z.B. Sichtbarkeit, Druckbarkeit und Sperrung eines Widgets.
              // Anders als Stringwerte werden diese Flags direkt von
              // PDFium als Bitmaske ausgelesen.
              if FPDFAnnot_GetFlags(SourceAnnot) <> FPDFAnnot_GetFlags(CheckAnnot) then
                raise EPDFiumViewer.Create(Format(
                  'Formularfeld-Flags nach dem Speichern abweichend (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
              // 3b.25: Widget-Identitaet vor dem Wertvergleich pruefen.
              // /T und /FT sind bei Radio-Kindern oft nicht direkt
              // vorhanden; auch leere Werte werden deshalb verglichen.
              if (ReadWidgetValue(SourceAnnot, 'T') <>
                  ReadWidgetValue(CheckAnnot, 'T')) or
                 (ReadWidgetValue(SourceAnnot, 'FT') <>
                  ReadWidgetValue(CheckAnnot, 'FT')) then
                raise EPDFiumViewer.Create(Format(
                  'Formularfeld-Zuordnung nach dem Speichern abweichend (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
              // 3b.27: Auch alternative Feldbezeichnungen vergleichen.
              // /TU = Benutzerbeschriftung (Tooltip), /TM = Mapping-Name.
              // Beide Angaben sind optional und koennen von Formularen
              // fuer die barrierefreie Bedienung bzw. den Datenexport
              // verwendet werden. Leere Werte sind dabei erlaubt.
              if (ReadWidgetValue(SourceAnnot, 'TU') <>
                  ReadWidgetValue(CheckAnnot, 'TU')) or
                 (ReadWidgetValue(SourceAnnot, 'TM') <>
                  ReadWidgetValue(CheckAnnot, 'TM')) then
                raise EPDFiumViewer.Create(Format(
                  'Formularfeld-Metadaten nach dem Speichern abweichend (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
              // 3b.33: Standardwerte und Rich-Text-Inhalte duerfen
              // beim Speichern nicht verloren gehen. Die Pruefung
              // erfasst die direkt am Widget hinterlegten Strings;
              // vererbte AcroForm-Werte werden weiterhin nicht gelesen.
              if (ReadWidgetValue(SourceAnnot, 'DV') <>
                  ReadWidgetValue(CheckAnnot, 'DV')) or
                 (ReadWidgetValue(SourceAnnot, 'RV') <>
                  ReadWidgetValue(CheckAnnot, 'RV')) or
                 (ReadWidgetValue(SourceAnnot, 'DS') <>
                  ReadWidgetValue(CheckAnnot, 'DS')) then
                raise EPDFiumViewer.Create(Format(
                  'Formular-Standardwert oder Rich-Text nach dem Speichern abweichend (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
              // 3b.29: Direkt am Widget hinterlegte Darstellungs- und
              // Eingabevorgaben duerfen beim Speichern nicht verloren gehen.
              // /DA = Standard-Darstellungsanweisung (Schrift/Farbe),
              // /Q = Textausrichtung, /MaxLen = maximale Zeichenanzahl.
              // Vererbte Werte der AcroForm-Eltern sind hier noch nicht
              // enthalten; deren Auswertung folgt separat.
              if (ReadWidgetValue(SourceAnnot, 'DA') <>
                  ReadWidgetValue(CheckAnnot, 'DA')) or
                 (ReadWidgetValue(SourceAnnot, 'Q') <>
                  ReadWidgetValue(CheckAnnot, 'Q')) or
                 (ReadWidgetValue(SourceAnnot, 'MaxLen') <>
                  ReadWidgetValue(CheckAnnot, 'MaxLen')) then
                raise EPDFiumViewer.Create(Format(
                  'Formular-Darstellungsvorgaben nach dem Speichern abweichend (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
              if (ReadWidgetValue(SourceAnnot, 'V') <>
               ReadWidgetValue(CheckAnnot, 'V')) or
                 (ReadWidgetValue(SourceAnnot, 'AS') <>
               ReadWidgetValue(CheckAnnot, 'AS')) then
                raise EPDFiumViewer.Create(Format(
                  'Formularwert nach dem Speichern abweichend (Seite %d, Widget %d).',
                  [CheckPageIndex + 1, SourceIndex + 1]));
            end;
          finally
            if SourceAnnot <> nil then FPDFPage_CloseAnnot(SourceAnnot);
            if CheckAnnot <> nil then FPDFPage_CloseAnnot(CheckAnnot);
          end;
          Inc(SourceIndex);
          Inc(SavedIndex);
        end;
        if (SourceIndex <> FPDFPage_GetAnnotCount(SourcePage)) or
           (SavedIndex <> FPDFPage_GetAnnotCount(CheckPage)) then
          raise EPDFiumViewer.Create('Formularvergleich: Annotationsanzahl abweichend.');
      finally
        FPDF_ClosePage(SourcePage);
        FPDF_ClosePage(CheckPage);
      end;
    end;
    // M2.3: Zusaetzlich die effektiven Feldwerte ueber die native
    // PDFium-Formular-API vergleichen. /V am Widget allein reicht bei
    // vererbten AcroForm-Werten nicht aus. Nur fuer AcroForms aktiv.
    if (FormType = 1) and (OriginalWidgetCount > 0) then
    begin
      FillChar(NativeSourceInfo, SizeOf(NativeSourceInfo), 0);
      FillChar(NativeSavedInfo, SizeOf(NativeSavedInfo), 0);
      NativeSourceInfo.Version := 1;
      NativeSavedInfo.Version := 1;
      NativeSourceForm := InitCompatibleForm(FDocument, NativeSourceInfo);
      if NativeSourceForm = nil then
        raise EPDFiumViewer.Create('PDFium konnte die Formularpruefung nicht starten.');
      try
        NativeSavedForm := InitCompatibleForm(CheckDoc, NativeSavedInfo);
        if NativeSavedForm = nil then
          raise EPDFiumViewer.Create('PDFium konnte die gespeicherte Formularumgebung nicht oeffnen.');
        try
          for CheckPageIndex := 0 to FPageCount - 1 do
          begin
            SourcePage := FPDF_LoadPage(FDocument, FPageOrder[CheckPageIndex]);
            CheckPage := FPDF_LoadPage(CheckDoc, CheckPageIndex);
            if (SourcePage = nil) or (CheckPage = nil) then
            begin
              if SourcePage <> nil then FPDF_ClosePage(SourcePage);
              if CheckPage <> nil then FPDF_ClosePage(CheckPage);
              raise EPDFiumViewer.Create('Native Formularpruefung: Seite nicht lesbar.');
            end;
            try
              FORM_OnAfterLoadPage(SourcePage, NativeSourceForm);
              try
                FORM_OnAfterLoadPage(CheckPage, NativeSavedForm);
                try
                  for CheckAnnotIndex := 0 to FPDFPage_GetAnnotCount(SourcePage) - 1 do
                  begin
                    SourceAnnot := FPDFPage_GetAnnot(SourcePage, CheckAnnotIndex);
                    CheckAnnot := FPDFPage_GetAnnot(CheckPage, CheckAnnotIndex);
                    try
                      if (SourceAnnot = nil) or (CheckAnnot = nil) then
                        raise EPDFiumViewer.Create('Native Formularpruefung: Annotation fehlt.');
                      if FPDFAnnot_GetSubtype(SourceAnnot) <> 20 then Continue;
                      NativeSourceType := FPDFAnnot_GetFormFieldType(NativeSourceForm, SourceAnnot);
                      NativeSavedType := FPDFAnnot_GetFormFieldType(NativeSavedForm, CheckAnnot);
                      if NativeSourceType <> NativeSavedType then
                        raise EPDFiumViewer.CreateFmt(
                          'Formulartyp nach Speichern abweichend (Seite %d, Feld %d).',
                          [CheckPageIndex + 1, CheckAnnotIndex + 1]);
                      // M2.9: Native Feldflags (Pflichtfeld, Schreibschutz,
                      // Mehrzeiligkeit usw.) müssen erhalten bleiben.
                      if FPDFAnnot_GetFormFieldFlags(NativeSourceForm, SourceAnnot) <>
                         FPDFAnnot_GetFormFieldFlags(NativeSavedForm, CheckAnnot) then
                        raise EPDFiumViewer.CreateFmt(
                          'Formular-Feldflags nach Speichern abweichend (Seite %d, Feld %d).',
                          [CheckPageIndex + 1, CheckAnnotIndex + 1]);
                      // M2.10: Effektiven, auch geerbten Feldnamen prüfen.
                      if NativeFieldName(NativeSourceForm, SourceAnnot) <>
                         NativeFieldName(NativeSavedForm, CheckAnnot) then
                        raise EPDFiumViewer.CreateFmt(
                          'Formular-Feldname nach Speichern abweichend (Seite %d, Feld %d).',
                          [CheckPageIndex + 1, CheckAnnotIndex + 1]);
                      // M2.11: Auswahloptionen vollständig mit PDFium prüfen.
                      if NativeSourceType in [5, 6] then
                      begin
                        NativeOptionCount := FPDFAnnot_GetOptionCount(
                          NativeSourceForm, SourceAnnot);
                        if NativeOptionCount <> FPDFAnnot_GetOptionCount(
                          NativeSavedForm, CheckAnnot) then
                          raise EPDFiumViewer.CreateFmt(
                            'Formular-Optionsanzahl nach Speichern abweichend (Seite %d, Feld %d).',
                            [CheckPageIndex + 1, CheckAnnotIndex + 1]);
                        for NativeOptionIndex := 0 to NativeOptionCount - 1 do
                          if NativeOptionLabel(NativeSourceForm, SourceAnnot, NativeOptionIndex) <>
                             NativeOptionLabel(NativeSavedForm, CheckAnnot, NativeOptionIndex) then
                            raise EPDFiumViewer.CreateFmt(
                              'Formular-Option nach Speichern abweichend (Seite %d, Feld %d, Option %d).',
                              [CheckPageIndex + 1, CheckAnnotIndex + 1, NativeOptionIndex + 1]);
                      end;
                      // M2.12: Alle Feldwerte einschließlich Listenfeldern
                      // über die native PDFium-API vergleichen.
                      if NativeSourceType in [4, 5, 6] then
                      begin
                        if NativeFieldValue(NativeSourceForm, SourceAnnot) <>
                           NativeFieldValue(NativeSavedForm, CheckAnnot) then
                          raise EPDFiumViewer.CreateFmt(
                            'Formularwert nach Speichern abweichend (Seite %d, Feld %d).',
                            [CheckPageIndex + 1, CheckAnnotIndex + 1]);
                      end
                      else if NativeSourceType in [2, 3] then
                      begin
                        if FPDFAnnot_IsChecked(NativeSourceForm, SourceAnnot) <>
                           FPDFAnnot_IsChecked(NativeSavedForm, CheckAnnot) then
                          raise EPDFiumViewer.CreateFmt(
                            'Formularauswahl nach Speichern abweichend (Seite %d, Feld %d).',
                            [CheckPageIndex + 1, CheckAnnotIndex + 1]);
                      end;
                    finally
                      if SourceAnnot <> nil then FPDFPage_CloseAnnot(SourceAnnot);
                      if CheckAnnot <> nil then FPDFPage_CloseAnnot(CheckAnnot);
                    end;
                  end;
                finally
                  FORM_OnBeforeClosePage(CheckPage, NativeSavedForm);
                end;
              finally
                FORM_OnBeforeClosePage(SourcePage, NativeSourceForm);
              end;
            finally
              FPDF_ClosePage(SourcePage);
              FPDF_ClosePage(CheckPage);
            end;
          end;
        finally
          FPDFDOC_ExitFormFillEnvironment(NativeSavedForm);
        end;
      finally
        FPDFDOC_ExitFormFillEnvironment(NativeSourceForm);
      end;
    end;
  finally
    FPDF_CloseDocument(CheckDoc);
  end;
  // Der geoeffnete PDFium-Dokumentzustand bleibt bis zum Reload erhalten.
  // Die virtuelle Reihenfolge wird dabei NICHT zurueckgesetzt.
  FModified := False;
  FStrokes.Clear;
  FStrokePages.Clear;
end;

function TFreePDF64PDFiumCore.PageSize(APageIndex: Integer; out AWidth, AHeight: Single): Boolean;
var P: Pointer;
begin
  AWidth := 0;
  AHeight := 0;
  Result := (FDocument <> nil) and (APageIndex >= 0) and (APageIndex < FPageCount);
  if not Result then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if P = nil then Exit(False);
  try
    AWidth := FPDF_GetPageWidthF(P);
    AHeight := FPDF_GetPageHeightF(P);
  finally
    FPDF_ClosePage(P);
  end;
end;

function TFreePDF64PDFiumCore.FindTextPage(const AText: string;
  AStartPage: Integer): Integer;
var
  Offset, Index, Count, N: Integer;
  P, TP: Pointer;
  Buffer: TArray<WideChar>;
  Content: string;
begin
  Result := -1;
  if (FDocument = nil) or (FPageCount <= 0) or (Trim(AText) = '') then Exit;
  for Offset := 0 to FPageCount - 1 do
  begin
    Index := (Max(0, AStartPage) + Offset) mod FPageCount;
    P := FPDF_LoadPage(FDocument, PhysicalPage(Index));
    if P = nil then Continue;
    try
      TP := FPDFText_LoadPage(P);
      if TP = nil then Continue;
      try
        Count := FPDFText_CountChars(TP);
        if Count <= 0 then Continue;
        SetLength(Buffer, Count + 1);
        N := FPDFText_GetText(TP, 0, Count, @Buffer[0]);
        if N <= 0 then Continue;
        Content := string(PWideChar(@Buffer[0]));
        if Pos(UpperCase(AText), UpperCase(Content)) > 0 then
          Exit(Index);
      finally
        FPDFText_ClosePage(TP);
      end;
    finally
      FPDF_ClosePage(P);
    end;
  end;
end;

function TFreePDF64PDFiumCore.MatchCharRects(APage, ACharIndex,
  ACharCount: Integer): TArray<TPDFInkRect>;
var
  P, TP: Pointer;
  I, N: Integer;
  L, R, B, T: Double;
  Box: TPDFInkRect;
begin
  SetLength(Result, 0);
  if (FDocument = nil) or (APage < 0) or (APage >= FPageCount) or
     (ACharIndex < 0) or (ACharCount <= 0) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APage));
  if P = nil then Exit;
  try
    TP := FPDFText_LoadPage(P);
    if TP = nil then Exit;
    try
      // PDFium gruppiert den Treffer nach Textzeilen statt pro Zeichen.
      N := FPDFText_CountRects(TP, ACharIndex, ACharCount);
      for I := 0 to N - 1 do
      begin
        if FPDFText_GetRect(TP, I, L, T, R, B) = 0 then Continue;
        if (R <= L) or (T <= B) then Continue;
        Box.Left := L; Box.Right := R;
        Box.Bottom := B; Box.Top := T;
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Box;
      end;
    finally
      FPDFText_ClosePage(TP);
    end;
  finally
    FPDF_ClosePage(P);
  end;
end;

function TFreePDF64PDFiumCore.TextCharCount(APage: Integer): Integer;
var P, TP: Pointer;
begin
  Result := 0;
  if (FDocument = nil) or (APage < 0) or (APage >= FPageCount) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APage));
  if P = nil then Exit;
  try
    TP := FPDFText_LoadPage(P);
    if TP = nil then Exit;
    try Result := Max(0, FPDFText_CountChars(TP));
    finally FPDFText_ClosePage(TP); end;
  finally FPDF_ClosePage(P); end;
end;

function TFreePDF64PDFiumCore.TextCharAt(APage: Integer; AX, AY: Double): Integer;
var P, TP: Pointer;
begin
  Result := -1;
  if (FDocument = nil) or (APage < 0) or (APage >= FPageCount) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APage));
  if P = nil then Exit;
  try
    TP := FPDFText_LoadPage(P);
    if TP = nil then Exit;
    try Result := FPDFText_GetCharIndexAtPos(TP, AX, AY, 12, 12);
    finally FPDFText_ClosePage(TP); end;
  finally FPDF_ClosePage(P); end;
end;

function TFreePDF64PDFiumCore.TextRange(APage, AStart, ACount: Integer): string;
var P, TP: Pointer; Buf: TArray<WideChar>; N, Total: Integer;
begin
  Result := '';
  if (FDocument = nil) or (APage < 0) or (APage >= FPageCount) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APage));
  if P = nil then Exit;
  try
    TP := FPDFText_LoadPage(P);
    if TP = nil then Exit;
    try
      Total := FPDFText_CountChars(TP);
      AStart := Max(0, Min(AStart, Total));
      ACount := Max(0, Min(ACount, Total - AStart));
      if ACount = 0 then Exit;
      SetLength(Buf, ACount + 1);
      N := FPDFText_GetText(TP, AStart, ACount, @Buf[0]);
      if N > 1 then SetString(Result, PWideChar(@Buf[0]), N - 1);
    finally FPDFText_ClosePage(TP); end;
  finally FPDF_ClosePage(P); end;
end;

function TFreePDF64PDFiumCore.FindTextMatchesOnPage(
  const AText: string; APage: Integer): TArray<TPDFTextMatch>;
var
  Idx, Cnt, N: Integer;
  P, TP, H: Pointer;
  M: TPDFTextMatch;
begin
  SetLength(Result, 0);
  if (FDocument = nil) or (AText = '') or (APage < 0) or
     (APage >= FPageCount) then Exit;
  P := FPDF_LoadPage(FDocument, PhysicalPage(APage));
  if P = nil then Exit;
  try
    TP := FPDFText_LoadPage(P);
    if TP = nil then Exit;
    try
      H := FPDFText_FindStart(TP, PWideChar(AText), 0, 0);
      if H = nil then Exit;
      try
        while FPDFText_FindNext(H) <> 0 do
        begin
          Idx := FPDFText_GetSchResultIndex(H);
          Cnt := FPDFText_GetSchCount(H);
          if (Idx < 0) or (Cnt <= 0) then Continue;
          M.PageIndex := APage;
          M.CharIndex := Idx;
          M.CharCount := Cnt;
          N := Length(Result);
          SetLength(Result, N + 1);
          Result[N] := M;
        end;
      finally FPDFText_FindClose(H); end;
    finally FPDFText_ClosePage(TP); end;
  finally FPDF_ClosePage(P); end;
end;

function TFreePDF64PDFiumCore.FindAllTextMatches(
  const AText: string): TArray<TPDFTextMatch>;
var
  Pg, N, I: Integer;
  PageMatches: TArray<TPDFTextMatch>;
begin
  if FSearchCacheValid and (FSearchTerm = AText) then
    Exit(Copy(FSearchCache));
  SetLength(FSearchCache, 0);
  FSearchCacheValid := False;
  if (FDocument = nil) or (Trim(AText) = '') then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  for Pg := 0 to FPageCount - 1 do
  begin
    PageMatches := FindTextMatchesOnPage(AText, Pg);
    N := Length(FSearchCache);
    SetLength(FSearchCache, N + Length(PageMatches));
    for I := 0 to High(PageMatches) do
      FSearchCache[N + I] := PageMatches[I];
  end;
  FSearchTerm := AText;
  FSearchCacheValid := True;
  Result := Copy(FSearchCache);
end;

function TFreePDF64PDFiumCore.FindTextMatch(const AText: string;
  AStartPage, AStartChar, ADirection: Integer;
  out APage, ACharIndex, ACharCount: Integer): Boolean;
var
  Matches: TArray<TPDFTextMatch>;
  I, Selected: Integer;
begin
  Result := False;
  APage := -1;
  ACharIndex := -1;
  ACharCount := 0;
  Matches := FindAllTextMatches(AText);
  if Length(Matches) = 0 then Exit;
  Selected := -1;
  if ADirection >= 0 then
  begin
    for I := 0 to High(Matches) do
      if (Matches[I].PageIndex > AStartPage) or
         ((Matches[I].PageIndex = AStartPage) and
          (Matches[I].CharIndex >= AStartChar)) then
      begin
        Selected := I;
        Break;
      end;
    if Selected < 0 then Selected := 0;
  end
  else
  begin
    for I := High(Matches) downto 0 do
      if (Matches[I].PageIndex < AStartPage) or
         ((Matches[I].PageIndex = AStartPage) and
          (Matches[I].CharIndex <= AStartChar)) then
      begin
        Selected := I;
        Break;
      end;
    if Selected < 0 then Selected := High(Matches);
  end;
  APage := Matches[Selected].PageIndex;
  ACharIndex := Matches[Selected].CharIndex;
  ACharCount := Matches[Selected].CharCount;
  Result := True;
end;

procedure TFreePDF64PDFiumCore.DrawFormTextPreview(APageIndex: Integer;
  ABitmap: TBitmap; AWidth, AHeight, ARotation: Integer);
var
  Page, Annot: Pointer;
  I, N, J, DX1, DY1, DX2, DY2, Temp: Integer;
  R: TPDFInkRect;
  Buf: TBytes;
  Value: string;
  Box: TRect;
  State, FieldName: string;
  StateLen, NameLen, Pad, MidX, MidY: Integer;
  IsRadio, IsSelected: Boolean;
begin
  if (FDocument = nil) or (ABitmap = nil) or (ARotation <> 0) or
     (APageIndex < 0) or (APageIndex >= FPageCount) then Exit;
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then Exit;
  try
    ABitmap.Canvas.Brush.Style := bsClear;
    ABitmap.Canvas.Font.Name := 'Arial';
    ABitmap.Canvas.Font.Color := clBlack;
    // Zoom- und DPI-abhaengige Textdarstellung aus Patch 3b.7.
    if FPDF_GetPageHeightF(Page) > 0 then
      ABitmap.Canvas.Font.Height := -Max(8,
        Round(11 * AHeight / FPDF_GetPageHeightF(Page)))
    else
      ABitmap.Canvas.Font.Size := 10;
    for I := 0 to FPDFPage_GetAnnotCount(Page) - 1 do
    begin
      Annot := FPDFPage_GetAnnot(Page, I);
      if Annot = nil then Continue;
      try
        if (FPDFAnnot_GetSubtype(Annot) <> 20) or
           (FPDFAnnot_GetRect(Annot, R) = 0) then Continue;
        // Auswahl-Widgets (Checkboxen/Radio-Buttons) besitzen einen
        // Appearance-State /AS. Deren /V ist ein interner Exportwert,
        // KEIN anzuzeigender Text. PDFium rendert das Widget selbst.
        // Dadurch erscheinen 'Off'/'Yes' nicht mehr als Text im Formular.
        // Ohne FPDF_FORMHANDLE ist GetFormFieldType(nil, ...) unzuverlaessig.
        // Schmale/quadratische Widgets sind die Auswahlfelder; breite
        // Widgets (insbesondere ComboBoxen) nicht ueberzeichnen.
        // Nur schmale Widgets mit /AS als Checkbox/Radio zeichnen.
        // Breite Text- und Dropdownfelder muessen zur /V-Textanzeige
        // durchfallen, statt hier vollstaendig uebersprungen zu werden.
        StateLen := 0;
        if Abs(R.Right - R.Left) <= 2.5 * Abs(R.Top - R.Bottom) then
          StateLen := FPDFAnnot_GetStringValue(Annot, 'AS', nil, 0);
        if StateLen > 2 then
        begin
          // Patch 3b.2: Sichtbare Widget-Vorschau auf der Bitmap.
          // Es werden KEINE internen Zustandsnamen als Text ausgegeben.
          // Die Darstellung ist nur eine Viewer-Vorschau, kein /AP-Stream.
          if (StateLen > 1024) or
             (FPDF_PageToDevice(Page, 0, 0, AWidth, AHeight, 0,
                R.Left, R.Top, DX1, DY1) = 0) or
             (FPDF_PageToDevice(Page, 0, 0, AWidth, AHeight, 0,
                R.Right, R.Bottom, DX2, DY2) = 0) then Continue;
          if DX1 > DX2 then begin Temp := DX1; DX1 := DX2; DX2 := Temp; end;
          if DY1 > DY2 then begin Temp := DY1; DY1 := DY2; DY2 := Temp; end;
          Box := Rect(DX1, DY1, DX2, DY2);
          if (Box.Right - Box.Left < 5) or (Box.Bottom - Box.Top < 5) then Continue;
          SetLength(Buf, StateLen);
          if FPDFAnnot_GetStringValue(Annot, 'AS', @Buf[0], StateLen) = 0 then Continue;
          State := PWideChar(@Buf[0]);
          NameLen := FPDFAnnot_GetStringValue(Annot, 'T', nil, 0);
          FieldName := '';
          if (NameLen > 2) and (NameLen <= 1024) then
          begin
            SetLength(Buf, NameLen);
            if FPDFAnnot_GetStringValue(Annot, 'T', @Buf[0], NameLen) > 0 then
              FieldName := PWideChar(@Buf[0]);
          end;
          // Bei Radio-Kids liegt /T meist im Parent, nicht im Widget.
          // Diese Heuristik dient nur der Vorschau; keine FormFill-Logik.
          IsRadio := FieldName = '';
          IsSelected := not SameText(State, 'Off');
          Pad := 1;
          InflateRect(Box, -Pad, -Pad);
          ABitmap.Canvas.Brush.Style := bsSolid;
          ABitmap.Canvas.Brush.Color := clWhite;
          ABitmap.Canvas.Pen.Color := clBlack;
          ABitmap.Canvas.Pen.Width := 1;
          if IsRadio then
            ABitmap.Canvas.Ellipse(Box)
          else
            ABitmap.Canvas.Rectangle(Box);
          if IsSelected then
          begin
            if IsRadio then
            begin
              MidX := (Box.Left + Box.Right) div 2;
              MidY := (Box.Top + Box.Bottom) div 2;
              Pad := (Box.Right - Box.Left) div 5;
              if Pad < 2 then Pad := 2;
              ABitmap.Canvas.Brush.Color := clBlack;
              ABitmap.Canvas.Ellipse(MidX - Pad, MidY - Pad,
                MidX + Pad + 1, MidY + Pad + 1);
            end
            else
            begin
              ABitmap.Canvas.Pen.Width := 2;
              ABitmap.Canvas.MoveTo(Box.Left + (Box.Right - Box.Left) div 5,
                Box.Top + (Box.Bottom - Box.Top) div 2);
              ABitmap.Canvas.LineTo(Box.Left + (Box.Right - Box.Left) div 2,
                Box.Bottom - (Box.Bottom - Box.Top) div 5);
              ABitmap.Canvas.LineTo(Box.Right - (Box.Right - Box.Left) div 6,
                Box.Top + (Box.Bottom - Box.Top) div 5);
              ABitmap.Canvas.Pen.Width := 1;
            end;
          end;
          Continue;
        end;
        N := FPDFAnnot_GetStringValue(Annot, 'V', nil, 0);
        if (N <= 2) or (N > 65536) then Continue;
        SetLength(Buf, N);
        if FPDFAnnot_GetStringValue(Annot, 'V', @Buf[0], N) = 0 then Continue;
        Value := PWideChar(@Buf[0]);
        if Value = '' then Continue;
        if (FPDF_PageToDevice(Page, 0, 0, AWidth, AHeight, 0,
            R.Left, R.Top, DX1, DY1) = 0) or
           (FPDF_PageToDevice(Page, 0, 0, AWidth, AHeight, 0,
            R.Right, R.Bottom, DX2, DY2) = 0) then Continue;
        if DX1 > DX2 then begin Temp := DX1; DX1 := DX2; DX2 := Temp; end;
        if DY1 > DY2 then begin Temp := DY1; DY1 := DY2; DY2 := Temp; end;
        Box := Rect(DX1 + 3, DY1 + 2, DX2 - 2, DY2 - 2);
        if (Box.Right <= Box.Left) or (Box.Bottom <= Box.Top) then Continue;
        // Auswahl-Widgets setzen die Canvas-Brush auf bsSolid (weiss bzw.
        // schwarz fuer den Radio-Punkt). Vor dem Zeichnen eines Text- oder
        // Dropdownwertes muss der Hintergrund wieder transparent sein.
        // Andernfalls wird der Dropdownwert nach einem Radio-Klick als
        // schwarzer Balken uebermalt.
        ABitmap.Canvas.Brush.Style := bsClear;
        SetBkMode(ABitmap.Canvas.Handle, TRANSPARENT);
        ABitmap.Canvas.Font.Color := clBlack;
        // Nur eine temporaere Vorschau; keine echte PDF-Appearance.
        // Einzeilige Formularfelder duerfen bei der Bitmap-Vorschau
        // nicht durch automatischen Zeilenumbruch mehrzeilig werden.
        // Hohe Felder behalten den bisherigen Mehrzeilenumbruch.
        if (Abs(R.Right - R.Left) > 0) and
           (Abs(R.Top - R.Bottom) / Abs(R.Right - R.Left) <= 0.12) then
        begin
          Value := StringReplace(Value, #13, ' ', [rfReplaceAll]);
          Value := StringReplace(Value, #10, ' ', [rfReplaceAll]);
          DrawText(ABitmap.Canvas.Handle, PChar(Value), Length(Value), Box,
            DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or
            DT_END_ELLIPSIS);
        end
        else
        begin
          // Mehrzeilige Werte innerhalb des Formularrechtecks zeichnen.
          // DT_EDITCONTROL verwendet die Texteditor-Zeilenaufteilung;
          // DT_END_ELLIPSIS ist fuer mehrzeilige Felder ungeeignet.
          DrawText(ABitmap.Canvas.Handle, PChar(Value), Length(Value), Box,
            DT_LEFT or DT_TOP or DT_WORDBREAK or DT_EDITCONTROL or
            DT_NOPREFIX);
        end;
      finally
        FPDFPage_CloseAnnot(Annot);
      end;
    end;
  finally
    FPDF_ClosePage(Page);
  end;
end;

procedure TFreePDF64PDFiumCore.RenderPage(APageIndex: Integer; ABitmap: TBitmap;
  AWidth, AHeight: Integer; ARotation: Integer);
var
  Page, PdfBitmap, FormHandle: Pointer;
  FormInfo: TPDFFormFillInfo;
  NativeFormDrawn: Boolean;
  Y, SourceStride: Integer;
  SourceRow: PPixelRow;
  SourceBuffer: NativeUInt;

begin
  if (FDocument = nil) or (APageIndex < 0) or (APageIndex >= FPageCount) then
    raise EPDFiumViewer.Create('Ungültige PDF-Seite.');
  if (ABitmap = nil) or (AWidth < 1) or (AHeight < 1) then
    raise EPDFiumViewer.Create('Ungültige Bitmap-Abmessungen.');
  Page := FPDF_LoadPage(FDocument, PhysicalPage(APageIndex));
  if Page = nil then
    raise EPDFiumViewer.Create('PDF-Seite konnte nicht geladen werden.');
  try
    PdfBitmap := FPDFBitmap_Create(AWidth, AHeight, 1);
    if PdfBitmap = nil then
      raise EPDFiumViewer.Create('PDFium-Bitmap konnte nicht angelegt werden.');
    try
      FPDFBitmap_FillRect(PdfBitmap, 0, 0, AWidth, AHeight, $FFFFFFFF);
      FPDF_RenderPageBitmap(PdfBitmap, Page, 0, 0, AWidth, AHeight,
        ((ARotation mod 4) + 4) mod 4, $01 or $02);
      // Nur AcroForms: PDFium zeichnet die Felder direkt in seine Bitmap.
      // Kein VCL-Paint-Hook, keine Seiten-/Toolbar-Layoutänderung.
      NativeFormDrawn := False;
      if FPDF_GetFormType(FDocument) = 1 then
      begin
        FillChar(FormInfo, SizeOf(FormInfo), 0);
        FormInfo.Version := 1;
        FormHandle := InitCompatibleForm(FDocument, FormInfo);
        if FormHandle <> nil then
        try
          FORM_OnAfterLoadPage(Page, FormHandle);
          try
            // 0 = alle Formularfeldtypen; Farbe 0xRRGGBB.
            FPDF_SetFormFieldHighlightColor(FormHandle, 0, $0095CAFF);
            FPDF_SetFormFieldHighlightAlpha(FormHandle, 90);
            FPDF_FFLDraw(FormHandle, PdfBitmap, Page, 0, 0,
              AWidth, AHeight, ((ARotation mod 4) + 4) mod 4, 0);
            NativeFormDrawn := True;
          finally
            FORM_OnBeforeClosePage(Page, FormHandle);
          end;
        finally
          FPDFDOC_ExitFormFillEnvironment(FormHandle);
        end;
      end;
      ABitmap.PixelFormat := pf32bit;
      ABitmap.SetSize(AWidth, AHeight);
      // PDFium liefert BGRA. Die VCL-ScanLine-Indizierung wird hier
       // direkt verwendet, damit das Bild nicht vertikal gespiegelt wird.
      // Pufferadresse und Stride nur einmal aus PDFium lesen.
      SourceBuffer := NativeUInt(FPDFBitmap_GetBuffer(PdfBitmap));
      SourceStride := FPDFBitmap_GetStride(PdfBitmap);
      for Y := 0 to AHeight - 1 do
      begin
        SourceRow := PPixelRow(SourceBuffer + NativeUInt(Y) * NativeUInt(SourceStride));
        Move(SourceRow^, ABitmap.ScanLine[Y]^, AWidth * 4);
      end;
      // Nur bei fehlender nativer Form-Umgebung alten M2.1-Pfad verwenden.
      if not NativeFormDrawn then
        DrawFormTextPreview(APageIndex, ABitmap, AWidth, AHeight, ARotation);
    finally
      FPDFBitmap_Destroy(PdfBitmap);
    end;
  finally
    FPDF_ClosePage(Page);
  end;
end;

end.

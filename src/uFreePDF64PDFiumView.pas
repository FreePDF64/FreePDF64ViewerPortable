unit uFreePDF64PDFiumView;

interface

uses
  uPDFLanguage,
  Winapi.Windows, Winapi.Messages, Winapi.CommDlg, Winapi.ShellAPI, Winapi.UxTheme, System.SysUtils, System.Classes, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Buttons, Vcl.Graphics, Vcl.Forms, Vcl.Dialogs, uPDFModernDialogs,
  Vcl.Printers, Vcl.Clipbrd, Vcl.ComCtrls, Vcl.Menus, Vcl.AppEvnts, System.IniFiles, System.Generics.Collections, Math,
  System.NetEncoding, System.Character, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, Winapi.GDIPAPI, Winapi.GDIPOBJ, System.Types, uFreePDF64PDFiumCore, uPDFSignatureDialog, uPDFSignatureLibrary;

const
  WM_PDF_FINISH_TEXT = WM_APP + $5A2;

type
  // TWinControl/VCL deklariert diese Events als protected.
  // Kleine Ableitungen machen sie fuer die programmatische Zuweisung zugaenglich.
  // TBitBtn zeichnet die Glyph-Bitmap selbst (auch mit aktivem Windows-Theme).
  TPDFiumSaveButton = class(TBitBtn)
  private
    FHighlighted: Boolean;
    FDesign: Integer;
    procedure BMSetStyle(var Message: TMessage); message BM_SETSTYLE;
    procedure SetHighlighted(const Value: Boolean);
    procedure UpdateSaveGlyph;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetDesign(AValue: Integer);
    property Highlighted: Boolean read FHighlighted write SetHighlighted;
  end;

  // Owner-drawn toolbar button; original Windows rendering for design 0.
  // Speichert das Originalsymbol direkt am Button. Beim Designwechsel
  // wird immer vom Original ausgegangen (keine kumulative Umfaerbung).
  TPDFGlyphOriginal = class(TComponent)
  public
    Original: TBitmap;
    LastDesign: Integer;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  // Farbtreuer Bitmap-Button: zeichnet bei alternativen Designs selbst.
  TPDFThemeBitBtn = class(TBitBtn)
  private
    FDesign: Integer;
    FHover: Boolean;
    procedure BMSetStyle(var Message: TMessage); message BM_SETSTYLE;
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure SetDesign(AValue: Integer);
  end;

  TPDFDesignButton = class(TButton)
  private
    FDesign: Integer;
    FHover: Boolean;
    FAccentOrange: Boolean;
    FAccentCapable: Boolean;
    procedure BMSetStyle(var Message: TMessage); message BM_SETSTYLE;
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure SetDesign(AValue: Integer);
    procedure SetAccentOrange(AValue: Boolean);
  end;

  // Ein einzelnes, DPI-abhaengig gezeichnetes Stift-und-Lineal-Symbol.
  TPDFToolsButton = class(TBitBtn)
  private
    FHighlighted: Boolean;
    FDesign: Integer;
    procedure BMSetStyle(var Message: TMessage); message BM_SETSTYLE;
    procedure SetHighlighted(const Value: Boolean);
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
    procedure UpdateToolsGlyph;
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetDesign(AValue: Integer);
    property Highlighted: Boolean read FHighlighted write SetHighlighted;
  end;

  TPDFiumScrollBox = class(TScrollBox)
  private
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
  public
    property OnMouseWheel;
    property OnKeyDown;
  end;

  TPDFiumOutlineTree = class(TTreeView)
  public
    property OnMouseWheel;
  end;

  // Zugriff auf die von TGraphicControl verwendete Paint-Zeichenflaeche.
  // TImage.Canvas selbst ist die Picture-Bitmap und darf fuer Overlays
  // nicht verwendet werden.
  TPDFGraphicCanvasAccess = class(TGraphicControl)
  public
    property Canvas;
  end;

  TPDFiumImage = class(TImage)
  private
    FAfterPaint: TNotifyEvent;
  protected
    procedure Paint; override;
  public
    property AfterPaint: TNotifyEvent read FAfterPaint write FAfterPaint;
    property OnMouseWheel;
  end;

  TInlineFormEditAccess = class(TCustomEdit);

  TInlineFormEdit = class(TEdit)
  protected
    procedure WndProc(var Message: TMessage); override;
  end;

  TInlineFormMemo = class(TMemo)
  protected
    procedure WndProc(var Message: TMessage); override;
  end;

  TPDFMeasureRect = record
    Page: Integer;
    X1, Y1, X2, Y2: Double;
    Scale: Double;
    UnitIndex: Integer;
  end;

  // Jede Aktion merkt sich Rechteck und ursprüngliche Position.
  TPDFMeasureAction = record
    Rect: TPDFMeasureRect;
    Index: Integer;
    WasDelete: Boolean;
  end;

  TFreePDF64PDFiumView = class(TPanel)
  private
    FCore: TFreePDF64PDFiumCore;
    FDocumentFormType: Integer; // M2.1: einmalig beim Oeffnen ermittelt
    FScroll: TPDFiumScrollBox;
    FOutlinePanel: TPanel;
    FOutlineSplitter: TSplitter;
    FOutlineTree: TPDFiumOutlineTree;
    FThumbScroll: TPDFiumScrollBox;
    FThumbTab, FBookmarksTab, FOutlineClose: TButton;
    FThumbTimer: TTimer;
    FThumbResizeTimer: TTimer;
    FThumbResizePending: Boolean;
    FThumbResizeInProgress: Boolean;
    FThumbLastOutlineWidth: Integer;
    FThumbLastClientWidth: Integer;
    FThumbDeleteRebuildPending: Boolean;
    FThumbNext: Integer;
    FThumbScrollTarget: Integer;
    FThumbClickNavigation: Boolean;
    FThumbImages: TList;
    FThumbSelected: TList<Integer>;
    FThumbAnchor: Integer;
    FThumbDragSource: Integer;
    FThumbDragStart: TPoint;
    FThumbDragging: Boolean;
    FThumbSuppressClick: Boolean;
    FThumbGhost: TForm;
    FThumbDropLine: TShape;
    FThumbDropTarget: Integer;
    FThumbMenu: TPopupMenu;
    FPageContextMenu: TPopupMenu;
    FOutlineMenu: TPopupMenu;
    FSelectionMenu: TPopupMenu;
    FOutlineExpandItem, FOutlineCollapseItem: TMenuItem;
    FInsertBeforeItem, FInsertAfterItem: TMenuItem;
    FOutlineHeader: TPanel;
    FOutlineTitle: TLabel;
    FOutlineButton: TButton;
    FOutlineItems: TObjectList<TPDFBookmarkItem>;
    FImage: TPDFiumImage;
    FOnFirstPagePaint: TNotifyEvent;
    FPages: TList;
    FRendering: Boolean;
    FLoadedPages: array of Boolean;
    FPageWidths, FPageHeights: array of Single;
    FPageSizesValid: array of Boolean;
    FRenderPending: Boolean;
    FZoomRenderPending: Boolean;
    FLastZoomTick: UInt64;
    FLayoutPageLimit: Integer; // VCL-Seitencontrols erst nach der Erstanzeige erstellen
    FPageCacheLimit: Integer;
    FRenderTimer: TTimer;
    FLastScrollPosition: Integer;
    FScrollRenderPending: Boolean;
    FLastScrollTick: UInt64;
    FResizePending: Boolean;
    FLayoutViewportWidth: Integer;
    FLayoutViewportHeight: Integer;
    FLastResizeTick: UInt64;
    FStrokePage: Integer;
    FStrokeRedo: TList<TPDFInkStroke>;
    FStrokeRedoPages: TList<Integer>;
    FBar: TPanel;
    FEditBar: TPanel;
    FEditToggle: TPDFToolsButton;
    FEditVisible: Boolean;
    FToolbarLayoutBusy: Boolean;
    FMergedToolbarWidth: Integer;
    FMergedTrailingControls: array of TControl;
    FPrev, FNext, FMinus, FPlus, FFit, FZoom100Button, FPrint, FHelp: TButton;
    FNavigationSeparator, FZoomSeparator: TBevel;
    FFitSeparator, FPageModeSeparator, FFlowSeparator, FActionSeparator: TBevel;
    FStatus: TLabel;
    FPageTotal: TLabel;
    FZoomStatus: TLabel;
    FInfo: TButton;
    FInfoDialog: TForm;
    FInfoContentScroll: TScrollBox;
    FPageEdit: TEdit;
    FGoPage: TButton;
    FFind: TButton;
    FFindTerm: string;
    FMatchPage, FMatchChar, FMatchCount: Integer;
    FTotalSearchMatches: Integer;
    FSearchTimer: TTimer;
    FSearchPage: Integer;
    FSearchMatches: TArray<TPDFTextMatch>;
    FSearchRunning: Boolean;
    FOnSearchCountChanged: TNotifyEvent;
    FOnPDFPageClick: TNotifyEvent;
    FWheelAccum: Integer;
    FMarker: TButton;
    FQuickSave: TPDFiumSaveButton;
    FSavePopup: TPopupMenu;
    FReloadMenuItem: TMenuItem;
    FLinkMenuItem: TMenuItem;
    FManageLinksMenuItem: TMenuItem;
    FLinkMode: Boolean;
    FLinkMovePending: Boolean;
    FLinkMovePage: Integer;
    FLinkMoveStart: TPoint;
    FLinkMoveEnd: TPoint;
    FWatermarkMenuItem: TMenuItem;
    FImageWatermarkMenuItem: TMenuItem;
    FSignatureMenuItem: TMenuItem;
    FSignatureFile: string;
    FSignatureTemporary: Boolean;
    FSignatureMode: Boolean;
    FSignatureKeyEvents: TApplicationEvents;
    FSignatureWidthMM: Double;
    FSignaturePreviewPage: Integer;
    FSignaturePreviewPoint: TPoint;
    FSignaturePreviewVisible: Boolean;
    FSignaturePreview: TPicture;
    FSignaturePlaced: Boolean;
    FSignatureDragging: Boolean;
    FSignatureResizing: Boolean;
    FSignatureResizeCorner: Integer; // 1=oben links, 2=oben rechts, 3=unten links, 4=unten rechts
    FSignatureDragOrigin: TPoint;
    FSignatureRectOrigin: TRect;
    FSignatureRect: TRect;
    FRequiredFieldsMenuItem: TMenuItem;
    FMoveUpItem, FMoveDownItem, FExtractItem: TMenuItem;
    FShapeSelect: TComboBox;
    FWidthSelect: TComboBox;
    FColorButton: TButton;
    FColorSwatch: TPanel;
    FMarkColor: TColor;
    FHighlightButton: TButton;
    FHighlightMode: Boolean;
    FMeasureRects: TList<TPDFMeasureRect>;
    FMeasureRedo: TList<TPDFMeasureAction>;
    FMeasureUndo: TList<TPDFMeasureAction>;
    FMeasureDirty: Boolean;
    FSaveSuccessSerial: Integer;
    FMeasurePopup: TPopupMenu;
    FMeasureMenuItem, FMeasureScaleMenuItem: TMenuItem;
    FMeasureMode: Boolean;
    FMeasureDragging: Boolean;
    FMeasurePage: Integer;
    FMeasureStart, FMeasureEnd: TPoint;
    FMeasureScale: Double; // real-world millimetres per PDF point
    FMeasureUnit: Integer; // 0 mm, 1 cm, 2 in
    FMeasureButton: TButton;
    FMeasureUnitSelect: TComboBox;
    FMeasureScaleButton: TButton;
    FNoteMode: Boolean;
    FCommentOwnerAuthorized: Boolean;
    FNoteButton: TButton;
    FNotePopup: TPopupMenu;
    FNoteSelected: TPDFNote;
    FNoteMovePending: Boolean;
    FHighlightAreaDragging: Boolean;
    FHighlightAreaPage: Integer;
    FHighlightAreaStartX, FHighlightAreaStartY: Integer;
    FHighlightAreaEndX, FHighlightAreaEndY: Integer;
    FTextInsertSeparator: TBevel;
    FTextInsertButton: TButton;
    FInsertButton: TButton;
    FInsertPopup: TPopupMenu;
    FInsertTextItem, FInsertNoteItem, FInsertLinkItem, FInsertSignatureItem: TMenuItem;
    FInsertImageWatermarkItem, FInsertTextWatermarkItem: TMenuItem;
    FInsertManageLinksItem, FInsertManageCommentsItem: TMenuItem;
    FTextUndoButton, FTextRedoButton: TBitBtn;
    FRedactionFinalizeButton: TPDFDesignButton;
    FRedactionReportOpen: Boolean;
    FUndoRedoGlyphPPI: Integer;
    FTextInsertMode: Boolean;
    FTextInsertColor: TColor;
    FTextInsertSize: Integer;
    FTextFontSelect: TComboBox;
    FTextSizeSelect: TComboBox;
    FTextColorButton: TButton;
    FTextColorSwatch: TPanel;
    FTextEditor: TEdit;
    FTextResizeGrip: TPanel;
    FTextResizing: Boolean;
    FTextResizeStart: TPoint;
    FTextResizeWidth, FTextResizeHeight: Integer;
    FTextEditorPage: Integer;
    FTextEditorX, FTextEditorY: Double;
    FTextEditorImage: TPDFiumImage;
    FTextDragging: Boolean;
    FTextDragStart: TPoint;
    FTextDragLeft, FTextDragTop: Integer;
    FShapeStart: TPoint;
    FMarkMode: Boolean;
    FCurrentStroke: TPDFInkStroke;
    // Nur Vorschau: diese Rechtecke werden NICHT in die PDF geschrieben.
    FRedactionPreviews: TObjectList<TPDFInkStroke>;
    FRedactionPreviewPages: TList<Integer>;
    FRedactionRedo: TObjectList<TPDFInkStroke>;
    FRedactionRedoPages: TList<Integer>;
    FSelecting: Boolean;
    FDraggingPage: Boolean;
    FActiveFormWidgetPage: Integer;
    FActiveFormWidgetIndex: Integer;
    FInlineFormEditor: TCustomEdit;
    FInlineFormPage, FInlineFormIndex: Integer;
    FInlineFormOriginal: string;
    FInlineFormClosing: Boolean;
    FFormFocusFrame: TShape;
    FDragStartScreen: TPoint;
    FDragStartHorz, FDragStartVert: Integer;
    FSelAnchorPage, FSelAnchorChar: Integer;
    FSelFocusPage, FSelFocusChar: Integer;

    FPreviewBitmap: TBitmap;
    FPreviewLastRect: TRect;
    FPreviewLastRectValid: Boolean;
    FPage: Integer;
    FZoom: Double;
    FFitMode: Boolean;
    FViewMode: Integer; // 0 = Seitenbreite, 1 = ganze Seite, 2 = 100 %, 3 = frei
    FTwoPage: Boolean;
    FContinuous: Boolean;
    FFlowSelect: TComboBox;
    FFlowToggleButton: TButton;
    FTwoPageButton: TButton;
    FTwoPageIcon: TImage;
    FViewSelect: TComboBox;
    FInitialRenderDeferred: Boolean;
    FSidebarInitPending: Boolean;
    procedure CommitSignature;
    procedure UpdateTwoPageIcon;
    procedure UpdateThumbDragVisual(const ScreenPos: TPoint);
    procedure EndThumbDragVisual;
    procedure UpdateFormFocusFrame;
    procedure UpdateInlineFormEditorFont;
    procedure BeginInlineFormEdit(APage, AIndex: Integer);
    procedure FinishInlineFormEdit(ACommit: Boolean);
    procedure InlineFormEditorExit(Sender: TObject);
    procedure InlineFormEditorKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure WMFreeInlineEditor(var Msg: TMessage); message WM_APP + 172;
    procedure WMDeferredFormTab(var Msg: TMessage); message WM_APP + 173;
    procedure FinishPreparedOpen;
    function CanModifyComments(AShowWarning: Boolean = True): Boolean;
    function AuthorizeCommentOwner: Boolean;
    procedure NoteButtonClick(Sender: TObject);
    procedure NoteMenuClick(Sender: TObject);
    function NoteScreenRect(Img: TPDFiumImage; const N: TPDFNote;
      out R: TRect): Boolean;
    function NoteAtPoint(Img: TPDFiumImage; X, Y: Integer;
      out N: TPDFNote): Boolean;
    function NoteDialog(var AText: string): Boolean;
    procedure PageImagePainted(Sender: TObject);
    function CachedPageSize(APage: Integer; out AW, AH: Single): Boolean;
    procedure SearchTimerTick(Sender: TObject);
    procedure ToggleEditBar(Sender: TObject);
    procedure ToggleOutline(Sender: TObject);
    procedure OutlineTabClick(Sender: TObject);
    procedure ThumbClick(Sender: TObject);
    procedure ThumbMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ThumbMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ThumbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DeleteSelectedThumbs(Sender: TObject);
    procedure RotateSelectedThumbs(Sender: TObject);
    procedure PageContextRotateClick(Sender: TObject);
    procedure PageContextToolClick(Sender: TObject);
    procedure ManageLinksClick(Sender: TObject);
    procedure TextWatermarkClick(Sender: TObject);
    procedure ImageWatermarkClick(Sender: TObject);
    procedure SignatureClick(Sender: TObject);
    procedure CancelSignature;
    procedure SignatureApplicationMessage(var Msg: TMsg; var Handled: Boolean);
    procedure ReloadPDFClick(Sender: TObject);
    procedure RequiredFieldsReportClick(Sender: TObject);
    procedure RefreshThumbMenuCaptions;
    procedure ThumbMenuPopup(Sender: TObject);
    procedure MoveSelectedThumb(Sender: TObject);
    procedure ExtractSelectedThumbs(Sender: TObject);
    procedure InsertPDFAtThumbnail(Sender: TObject);
    procedure UpdateSaveState;
    procedure ThumbTimerTick(Sender: TObject);
    procedure ThumbAreaResize(Sender: TObject);
    procedure ThumbResizeTimerTick(Sender: TObject);
    procedure ApplyThumbnailLayout;
    procedure OutlineHeaderResize(Sender: TObject);
    procedure BuildThumbnails;
    procedure AppendThumbnailBatch(ACount: Integer);
    procedure UpdateThumbnailSelection;
    procedure ScrollThumbnailToCurrentPage;
    procedure ShowOutlineTab(AThumbnails: Boolean);
    procedure OutlineChange(Sender: TObject; Node: TTreeNode);
    procedure OutlineExpandAll(Sender: TObject);
    procedure OutlineCollapseAll(Sender: TObject);
    procedure OutlineMenuPopup(Sender: TObject);
    procedure PopulateOutline;
    procedure UpdateSecurityIcon;
    procedure LayoutToolbar(Sender: TObject);
    procedure UpdateUndoRedoGlyphs;
    procedure InvalidateAllWatermarkPages;
    procedure InfoClick(Sender: TObject);
    procedure InfoDialogClose(Sender: TObject; var Action: TCloseAction);
    procedure InfoDialogDestroy(Sender: TObject);
    procedure InfoDialogMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure InfoCloseButtonClick(Sender: TObject);
    function RequestPDFPassword(const AFileName: string; out APassword: string;
      AOwnerPermission: Boolean = False): Boolean;
    procedure SearchNext(ADirection: Integer);
    function FindCachedSearchMatch(AStartPage, AStartChar, ADirection: Integer;
      out APage, ACharIndex, ACharCount: Integer): Boolean;
    procedure ShapeSelectChange(Sender: TObject);
    procedure ViewModeChange(Sender: TObject);
    procedure TwoPageClick(Sender: TObject);
    procedure FlowModeChange(Sender: TObject);
    procedure FlowToggleClick(Sender: TObject);
    procedure UpdateVisiblePage;
    function PageImage(AIndex: Integer): TPDFiumImage;
    procedure LayoutAllPages;
    procedure RenderVisiblePages;
    procedure RenderTimerTick(Sender: TObject);
    procedure DrawPageStrokes(APage: Integer);
    procedure DrawSearchHighlight(APage: Integer);
    procedure DrawTextSelection(APage: Integer);
    procedure RefreshSelectedPages;
    function SelectionHit(Sender: TObject; X, Y: Integer): Integer;
    procedure FindClick(Sender: TObject);
    procedure MarkerClick(Sender: TObject);
    procedure LinkMenuClick(Sender: TObject);
    procedure TextInsertClick(Sender: TObject);
    procedure PopupMeasureItem(Sender: TObject; ACanvas: TCanvas; var Width, Height: Integer);
    procedure PopupDrawItem(Sender: TObject; ACanvas: TCanvas; ARect: TRect; Selected: Boolean);
    procedure InsertDropdownClick(Sender: TObject);
    procedure InsertTextMenuClick(Sender: TObject);
    procedure InsertNoteMenuClick(Sender: TObject);
    procedure HighlightClick(Sender: TObject);
    procedure ShowMeasureReport(Sender: TObject);
    procedure RefreshMeasurePages;
    procedure RecordMeasureAction(const ARect: TPDFMeasureRect;
      AIndex: Integer; AWasDelete: Boolean);
    procedure MeasureDropdownClick(Sender: TObject);
    procedure MeasureClick(Sender: TObject);
    procedure MeasureUnitChange(Sender: TObject);
    procedure MeasureScaleClick(Sender: TObject);
    procedure DrawMeasurement(Sender: TObject);
    procedure CancelMeasurement;

    procedure TextUndoClick(Sender: TObject);
    procedure TextRedoClick(Sender: TObject);
    procedure ClearStrokeRedo;
    procedure ClearRedactionRedo;
    procedure RefreshRedactionPage(APage: Integer);
    procedure UpdateTextUndoButtons;
    procedure RefreshTextPage(APageIndex: Integer);
    procedure TextStyleChange(Sender: TObject);
    procedure TextColorClick(Sender: TObject);
    procedure WMFinishTextEditor(var Message: TMessage); message WM_PDF_FINISH_TEXT;
    procedure TextEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TextEditorMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TextEditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TextEditorMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TextResizeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TextResizeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TextResizeMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PositionTextResizeGrip;
    procedure UpdateTextEditorHeight;
    procedure FinishTextEditor(ACommit: Boolean);
    procedure ColorClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveDropdownClick(Sender: TObject);
    procedure ExportPagesAsImages(Sender: TObject);
    function LinkAtImagePoint(Sender: TObject; X, Y: Integer;
      out ATarget: TPDFLinkTarget): Boolean;
    procedure FormOptionDoubleClick(Sender: TObject);
    procedure ImageMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ImageDblClick(Sender: TObject);
    procedure ImageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ImageMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure AppendPoint(X, Y: Integer);
    procedure BuildEllipseStroke(X1, Y1, X2, Y2: Integer);
    procedure UpdateShapeStroke(X, Y: Integer);
    procedure DrawLivePreview;
    procedure DrawStrokes;
    procedure Navigate(Sender: TObject);
    procedure GoToPage(Sender: TObject);
    procedure PageKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OutlineMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ScrollMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ZoomClick(Sender: TObject);
    procedure Zoom100Click(Sender: TObject);
    procedure ZoomByFactor(AFactor: Double);
    procedure FitClick(Sender: TObject);
    procedure PrintClick(Sender: TObject);
    procedure HelpClick(Sender: TObject);
    procedure ResizeView(Sender: TObject);
    procedure PaintPage;
    function GetFirstPageReady: Boolean;
    function GetIsAcroForm: Boolean;
  public
    // Rein lesende Voranalyse der aktuell vorgemerkten Schwaerzungsrechtecke.
    function AnalyzePendingRedactions(out AAnalysis: TPDFRedactionBatchAnalysis): Boolean;
    procedure FinalizeRedactionClick(Sender: TObject);
    procedure SavePDFAs;
    procedure ShowDocumentProperties;
    procedure TogglePageThumbnails;
    procedure SetPageThumbnailsVisible(AVisible: Boolean);
    procedure ApplySavedThumbnailsAfterLoad;
    class procedure SetGlobalThumbnailSplitMode(AEnabled: Boolean); static;
    class function GlobalThumbnailsVisible: Boolean; static;
    procedure ShowCommentOverview;
    procedure ShowCommentOverviewMenuClick(Sender: TObject);
    procedure ShowRequiredFieldsReport;
    procedure FocusAdjacentFormWidget(ADirection: Integer);
    function HasActiveFormWidget: Boolean;
    procedure ActivateFocusedFormChoice;
    procedure ReloadCurrentPDF;
    constructor CreateInParent(AOwner: TComponent; AParent: TWinControl);
    destructor Destroy; override;
    procedure OpenPDF(const AFileName: string);
    procedure OpenPDFPrepared(APrepared: TFreePDF64PDFiumCore);
    procedure RefreshPDFDisplay;
    procedure RefitOnTabActivation;
    procedure RefreshToolbarAfterSplit;
    procedure SetMergedToolbarWidth(AWidth: Integer);
    procedure SetMergedToolbarTrailingControls(const AControls: array of TControl;
      AParent: TWinControl);
    procedure DrawViewModeItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure ApplyButtonDesign(ADesign: Integer);
    procedure ApplyPDFBackgroundDesign(ADesign: Integer);
    property ToolbarPanel: TPanel read FBar;
    property EditToggleButton: TPDFToolsButton read FEditToggle;
    procedure RefreshLanguage;
    procedure SetFullScreenDisplay(AEnabled: Boolean);
    procedure ZoomIn;
    procedure ZoomOut;
    procedure ReleasePDFForExternalChange;
    procedure RotatePages(AFirstPage, ALastPage, AAngle: Integer);
    procedure ShowPage(APage: Integer);
    procedure ToggleMarker;
    procedure PlaceEditButton(AParent: TWinControl; ALeft, ATop, AHeight: Integer);
    procedure ShowSearchDialog;
    procedure SearchText(const AText: string);
    function HasSearchHighlights: Boolean;
    function GlobalPageCount: Integer;
    function GlobalFindOnPage(const ATerm: string; APage: Integer): TArray<TPDFTextMatch>;
    function GlobalExcerpt(APage, AChar, ALength: Integer): string;
    procedure GlobalShowMatch(const ATerm: string; const AMatch: TPDFTextMatch);
    procedure NextSearchMatch(ADirection: Integer);
    procedure SelectAllText;
    function SelectedText: string;
    procedure CopySelectedText;
    procedure SelectionMenuClick(Sender: TObject);
    function ConfirmUnsaved: Boolean;
    function HasUnsavedChanges: Boolean;
    function SaveUnsavedChanges: Boolean;
    property SearchMatchCount: Integer read FTotalSearchMatches;
    property SearchRunning: Boolean read FSearchRunning;
    property OnSearchCountChanged: TNotifyEvent read FOnSearchCountChanged write FOnSearchCountChanged;
    property OnPDFPageClick: TNotifyEvent read FOnPDFPageClick write FOnPDFPageClick;
    property WorkspaceViewMode: Integer read FViewMode;
    property WorkspaceTwoPage: Boolean read FTwoPage;
    property WorkspaceContinuous: Boolean read FContinuous;
    function WorkspaceSidebarVisible: Boolean;
    procedure RestoreWorkspaceLayout(AViewMode: Integer; ATwoPage, AContinuous, ASidebar: Boolean);
    property WorkspaceZoom: Double read FZoom;
    property WorkspaceFitMode: Boolean read FFitMode;
    procedure RestoreWorkspaceView(AZoom: Double; AFit: Boolean; AX, AY: Integer);
    function WorkspaceScrollX: Integer;
    function WorkspaceScrollY: Integer;
    procedure ApplySplitSync(AZoom: Double; ASetZoom: Boolean; AX, AY: Integer; ASetScroll: Boolean);
    // M2.1: gecachter Dokumenttyp, keine Formularsuche beim Rendern.
    // 0 = kein Formular, 1 = AcroForm, 2/3 = XFA.
    property DocumentFormType: Integer read FDocumentFormType;
    property IsAcroForm: Boolean read GetIsAcroForm;
    property PageIndex: Integer read FPage;
    property FirstPageReady: Boolean read GetFirstPageReady;
    property OnFirstPagePaint: TNotifyEvent read FOnFirstPagePaint write FOnFirstPagePaint;
  end;

// Farbkontrast fuer bestehende BitBtn-Glyphen; keine Groessenaenderung.
procedure ApplyPDFGlyphContrast(AButton: TBitBtn; ADesign: Integer);

implementation

function ToolbarHint(const ADeutsch, AEnglish: string): string; forward;

// Designpalette fuer die drei Verwaltungsdialoge einmalig beim Oeffnen.
// Verwendet die bereits global konfigurierte PDF-Dialogpalette.
procedure ApplyManagedDialogPalette(AForm: TForm; AList: TListView;
  ADesign: Integer);
var
  ListBack, ListText: TColor;
  procedure StyleButtons(AParent: TWinControl);
  var
    I: Integer;
    C: TControl;
  begin
    for I := 0 to AParent.ControlCount - 1 do
    begin
      C := AParent.Controls[I];
      if C is TPDFDesignButton then
        TPDFDesignButton(C).SetDesign(ADesign);
      if C is TWinControl then StyleButtons(TWinControl(C));
    end;
  end;
begin
  ApplyPDFDialogDesign(AForm);
  case ADesign of
    1: begin ListBack := RGB(248, 250, 253); ListText := RGB(35, 48, 65); end;
    2: begin ListBack := RGB(65, 70, 79); ListText := clWhite; end;
    3: begin ListBack := clWhite; ListText := clBlack; end;
    4: begin ListBack := RGB(45, 48, 54); ListText := clWhite; end;
    5: begin ListBack := RGB(246, 250, 255); ListText := RGB(24, 55, 88); end;
  else
    begin ListBack := clWindow; ListText := clWindowText; end;
  end;
  if AList <> nil then
  begin
    AList.ParentColor := False;
    AList.Color := ListBack;
    AList.Font.Color := ListText;
  end;
  StyleButtons(AForm);
end;

type
  // Dialogeigene Verwaltung; keine neuen Felder in TFreePDF64PDFiumView.
  TPDFCommentOverview = class(TComponent)
  private
    FView: TFreePDF64PDFiumView;
    FList: TListView;
    FNotes: TArray<TPDFNote>;
    FRowNoteIndex: TArray<Integer>;
    FRowPages: TArray<Integer>;
    procedure Reload;
    function SelectedNote(out N: TPDFNote): Boolean;
    procedure JumpClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; AView: TFreePDF64PDFiumView;
      AList: TListView); reintroduce;
  end;

  // Seitenwechsel direkt im geöffneten Dialog, ohne ShowModal neu zu starten.
  TPDFLinkListNavigator = class(TComponent)
  private
    FView: TFreePDF64PDFiumView;
    FList: TListView;
    procedure JumpToSelected;
    procedure ListClick(Sender: TObject);
    procedure JumpClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; AView: TFreePDF64PDFiumView;
      AList: TListView); reintroduce;
  end;

constructor TPDFCommentOverview.Create(AOwner: TComponent;
  AView: TFreePDF64PDFiumView; AList: TListView);
begin
  inherited Create(AOwner);
  FView := AView;
  FList := AList;
  Reload;
end;

procedure TPDFCommentOverview.Reload;
var
  Page, I, Count: Integer;
  Notes: TArray<TPDFNote>;
  Measurements: TArray<string>;
  Row: Integer;
  Item: TListItem;
  S: string;
begin
  SetLength(FNotes, 0);
  SetLength(FRowNoteIndex, 0);
  SetLength(FRowPages, 0);
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    if (FView = nil) or (FView.FCore = nil) then Exit;
    for Page := 0 to FView.FCore.PageCount - 1 do
    begin
      Notes := FView.FCore.GetNotes(Page);
      for I := 0 to High(Notes) do
      begin
        Count := Length(FNotes);
        SetLength(FNotes, Count + 1);
        FNotes[Count] := Notes[I];
        Row := Length(FRowNoteIndex);
        SetLength(FRowNoteIndex, Row + 1);
        SetLength(FRowPages, Row + 1);
        FRowNoteIndex[Row] := Count;
        FRowPages[Row] := Page;
        Item := FList.Items.Add;
        Item.Caption := IntToStr(Page + 1);
        S := StringReplace(Notes[I].Contents, #13, ' ', [rfReplaceAll]);
        S := StringReplace(S, #10, ' ', [rfReplaceAll]);
        Item.SubItems.Add(S);
      end;
      Measurements := FView.FCore.GetMeasurementComments(Page);
      for I := 0 to High(Measurements) do
      begin
        Row := Length(FRowNoteIndex);
        SetLength(FRowNoteIndex, Row + 1);
        SetLength(FRowPages, Row + 1);
        FRowNoteIndex[Row] := -1;
        FRowPages[Row] := Page;
        Item := FList.Items.Add;
        Item.Caption := IntToStr(Page + 1);
        Item.SubItems.Add(ToolbarHint('Messung: ', 'Measurement: ') + Measurements[I]);
      end;
    end;
  finally
    FList.Items.EndUpdate;
  end;
end;

function TPDFCommentOverview.SelectedNote(out N: TPDFNote): Boolean;
var I: Integer;
begin
  I := FList.ItemIndex;
  Result := (I >= 0) and (I < Length(FRowNoteIndex)) and
    (FRowNoteIndex[I] >= 0) and (FRowNoteIndex[I] < Length(FNotes));
  if Result then N := FNotes[FRowNoteIndex[I]];
end;

procedure TPDFCommentOverview.JumpClick(Sender: TObject);
var N: TPDFNote;
begin
  if SelectedNote(N) then
    FView.ShowPage(N.PageIndex)
  else if (FList.ItemIndex >= 0) and (FList.ItemIndex < Length(FRowPages)) then
    FView.ShowPage(FRowPages[FList.ItemIndex]);
end;

procedure TPDFCommentOverview.EditClick(Sender: TObject);
var N: TPDFNote; S: string;
begin
  if not SelectedNote(N) or not FView.CanModifyComments then Exit;
  S := N.Contents;
  if FView.NoteDialog(S) and FView.FCore.ChangeNote(N, S, 0, 0, False) then
  begin
    FView.RefreshTextPage(N.PageIndex);
    FView.UpdateSaveState;
    Reload;
  end;
end;

procedure TPDFCommentOverview.DeleteClick(Sender: TObject);
var N: TPDFNote;
begin
  if not SelectedNote(N) or not FView.CanModifyComments then Exit;
  if PDFModernMessageDlg(ToolbarHint('Kommentar wirklich löschen?',
      'Delete this comment?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if FView.FCore.DeleteNote(N) then
  begin
    FView.RefreshTextPage(N.PageIndex);
    FView.UpdateSaveState;
    Reload;
  end;
end;

procedure TFreePDF64PDFiumView.ShowCommentOverviewMenuClick(Sender: TObject);
begin
  ShowCommentOverview;
end;

procedure TFreePDF64PDFiumView.ShowCommentOverview;
var
  D: TForm;
  L: TListView;
  Footer: TPanel;
  B: TButton;
  Controller: TPDFCommentOverview;
  P: Integer;
  procedure AddButton(const Caption: string; ALeft: Integer;
    AClick: TNotifyEvent; AClose: Boolean = False);
  begin
    B := TPDFDesignButton.Create(D);
    B.Parent := Footer;
    B.Caption := Caption;
    B.SetBounds(MulDiv(ALeft, P, 96), MulDiv(7, P, 96),
      MulDiv(105, P, 96), MulDiv(30, P, 96));
    if AClose then
    begin
      B.ModalResult := mrCancel;
      B.Cancel := True;
    end
    else B.OnClick := AClick;
  end;
begin
  if FCore = nil then Exit;
  P := Max(96, CurrentPPI);
  D := TForm.CreateNew(Self);
  try
    D.Caption := ToolbarHint('Kommentare verwalten ...', 'Manage comments...');
    D.Position := poOwnerFormCenter;
    D.BorderStyle := bsSizeable;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.ClientWidth := MulDiv(700, P, 96);
    D.ClientHeight := MulDiv(410, P, 96);
    D.Constraints.MinWidth := MulDiv(510, P, 96);
    D.Constraints.MinHeight := MulDiv(290, P, 96);
    D.KeyPreview := True;
    D.Color := Color;
    Footer := TPanel.Create(D);
    Footer.Parent := D;
    Footer.Align := alBottom;
    Footer.Height := MulDiv(47, P, 96);
    Footer.BevelOuter := bvNone;
    Footer.ParentBackground := True;
    L := TListView.Create(D);
    L.Parent := D;
    L.Align := alClient;
    L.ViewStyle := vsReport;
    L.RowSelect := True;
    L.ReadOnly := True;
    L.Columns.Add.Caption := ToolbarHint('Seite', 'Page');
    L.Columns[0].Width := MulDiv(75, P, 96);
    L.Columns.Add.Caption := ToolbarHint('Kommentartext', 'Comment text');
    L.Columns[1].Width := MulDiv(570, P, 96);
    Controller := TPDFCommentOverview.Create(D, Self, L);
    L.OnDblClick := Controller.JumpClick;
    AddButton(ToolbarHint('Anzeigen', 'Go to page'), 8, Controller.JumpClick);
    AddButton(ToolbarHint('Bearbeiten', 'Edit'), 121, Controller.EditClick);
    AddButton(ToolbarHint('Löschen', 'Delete'), 234, Controller.DeleteClick);
    AddButton(ToolbarHint('Schließen', 'Close'), 347, nil, True);
    ApplyManagedDialogPalette(D, L, FEditToggle.FDesign);
    D.ShowModal;
  finally
    D.Free;
  end;
end;

constructor TPDFLinkListNavigator.Create(AOwner: TComponent;
  AView: TFreePDF64PDFiumView; AList: TListView);
begin
  inherited Create(AOwner);
  FView := AView;
  FList := AList;
end;

procedure TPDFLinkListNavigator.JumpToSelected;
var
  Links: TArray<TPDFManagedLink>;
  Index: Integer;
begin
  if (FView = nil) or (FView.FCore = nil) or (FList = nil) then Exit;
  Index := FList.ItemIndex;
  if Index < 0 then Exit;
  Links := FView.FCore.GetManagedLinks;
  if Index >= Length(Links) then Exit;
  FView.ShowPage(Links[Index].PageIndex);
end;

procedure TPDFLinkListNavigator.ListClick(Sender: TObject);
begin
  JumpToSelected;
end;

procedure TPDFLinkListNavigator.JumpClick(Sender: TObject);
begin
  JumpToSelected;
end;

var
  GThumbnailViews: TList<TFreePDF64PDFiumView>;
  GThumbnailsLoaded: Boolean = False;
  GThumbnailsVisible: Boolean = False;
  GThumbnailSplitMode: Boolean = False;

constructor TPDFGlyphOriginal.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Original := TBitmap.Create;
  LastDesign := -1;
end;

destructor TPDFGlyphOriginal.Destroy;
begin
  Original.Free;
  inherited;
end;

procedure ApplyPDFGlyphContrast(AButton: TBitBtn; ADesign: Integer);
var
  Cache: TPDFGlyphOriginal;
  I, X, Y: Integer;
  B: TBitmap;
  C, TargetColor: TColor;
  R, G, Bl: Byte;
  L: Integer;
  TransparentPixel: TColor;
  Mask: array of Byte;
  NX, NY: Integer;
  IsInk: Boolean;
begin
  if (AButton = nil) or AButton.Glyph.Empty then Exit;
  Cache := nil;
  for I := 0 to AButton.ComponentCount - 1 do
    if AButton.Components[I] is TPDFGlyphOriginal then
    begin
      Cache := TPDFGlyphOriginal(AButton.Components[I]);
      Break;
    end;
  if Cache = nil then
  begin
    Cache := TPDFGlyphOriginal.Create(AButton);
    Cache.Original.Assign(AButton.Glyph);
  end;
  // Nur beim tatsaechlichen Designwechsel Bitmapdaten anfassen.
  if Cache.LastDesign = ADesign then Exit;
  if ADesign = 0 then
  begin
    AButton.Glyph.Assign(Cache.Original);
    Cache.LastDesign := ADesign;
    Exit;
  end;
  case ADesign of
    1: TargetColor := RGB(35, 48, 65);       // Modern Hell
    2, 4: TargetColor := RGB(232, 238, 246); // alte dunkle Paletten (nicht im Menue)
    3: TargetColor := RGB(16, 16, 16);       // Windows Klassik
    5: TargetColor := RGB(24, 55, 88);       // Klassisch Blau
  else
    TargetColor := clBlack;
  end;
  B := TBitmap.Create;
  try
    B.Assign(Cache.Original);
    TransparentPixel := ColorToRGB(B.TransparentColor);
    B.PixelFormat := pf24bit;
    // Eine Pixel breite Konturverstaerkung vorbereiten, nur aus der
    // ORIGINAL-Glyphe. Die Maske wird nicht bei jedem Paint berechnet.
    SetLength(Mask, B.Width * B.Height);
    for Y := 0 to B.Height - 1 do
      for X := 0 to B.Width - 1 do
      begin
        C := ColorToRGB(B.Canvas.Pixels[X, Y]);
        R := GetRValue(C);
        G := GetGValue(C);
        Bl := GetBValue(C);
        L := (Integer(R) * 30 + Integer(G) * 59 + Integer(Bl) * 11) div 100;
        IsInk := (not B.Transparent or (C <> TransparentPixel)) and
          (Abs(Integer(R) - Integer(G)) <= 18) and
          (Abs(Integer(G) - Integer(Bl)) <= 18) and (L < 145);
        if IsInk then Mask[Y * B.Width + X] := 1;
      end;
    for Y := 0 to B.Height - 1 do
      for X := 0 to B.Width - 1 do
      begin
        C := ColorToRGB(B.Canvas.Pixels[X, Y]);
        if B.Transparent and (C = TransparentPixel) then Continue;
        R := GetRValue(C);
        G := GetGValue(C);
        Bl := GetBValue(C);
        L := (Integer(R) * 30 + Integer(G) * 59 + Integer(Bl) * 11) div 100;
        // Dunkle Strichsymbole (einschliesslich geglaetteter Kanten)
        // erhalten die zur Palette passende Vordergrundfarbe.
        // Farbige Statussymbole und helle Flaechen bleiben erhalten.
        if (Abs(Integer(R) - Integer(G)) <= 18) and
           (Abs(Integer(G) - Integer(Bl)) <= 18) and (L < 145) then
        begin
          if ADesign in [2, 4] then
            B.Canvas.Pixels[X, Y] := RGB(225 - L div 5, 232 - L div 5, 242 - L div 5)
          else
            B.Canvas.Pixels[X, Y] := TargetColor;
        end;
      end;
    // Dezente 1-Pixel-Verstaerkung: nur bisher transparente Nachbarpixel
    // einer dunklen monochromen Kontur faerben. Farbige Glyphen bleiben
    // unangetastet; Original, Groesse und Layout bleiben erhalten.
    if B.Transparent then
      for Y := 0 to B.Height - 1 do
        for X := 0 to B.Width - 1 do
          if ColorToRGB(B.Canvas.Pixels[X, Y]) = TransparentPixel then
          begin
            IsInk := False;
            for NY := Y - 1 to Y + 1 do
            begin
              if IsInk then Break;
              if (NY < 0) or (NY >= B.Height) then Continue;
              for NX := X - 1 to X + 1 do
              begin
                if (NX < 0) or (NX >= B.Width) or
                   ((Abs(NX-X) + Abs(NY-Y)) <> 1) then Continue;
                if Mask[NY * B.Width + NX] = 1 then
                begin
                  IsInk := True;
                  Break;
                end;
              end;
            end;
            if IsInk then B.Canvas.Pixels[X, Y] := TargetColor;
          end;
    B.Transparent := Cache.Original.Transparent;
    if B.Transparent then
      B.TransparentColor := Cache.Original.TransparentColor;
    AButton.Glyph.Assign(B);
    Cache.LastDesign := ADesign;
  finally
    B.Free;
  end;
end;

procedure TPDFThemeBitBtn.BMSetStyle(var Message: TMessage);
begin
  // VCL/Windows setzt beim Fokuswechsel den Button-Typ per BM_SETSTYLE
  // auf BS_PUSHBUTTON oder BS_DEFPUSHBUTTON zurueck. In alternativen
  // Designs muss BS_OWNERDRAW auch danach erhalten bleiben.
  if FDesign <> 0 then
    Message.WParam := (Message.WParam and not WPARAM($000F)) or WPARAM(BS_OWNERDRAW);
  inherited;
end;

procedure TPDFThemeBitBtn.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if FDesign <> 0 then
    Params.Style := (Params.Style and not $000F) or BS_OWNERDRAW;
end;

procedure TPDFThemeBitBtn.SetDesign(AValue: Integer);
begin
  if FDesign = AValue then Exit; // Keine Neuzeichnung ohne Designwechsel.

  if FDesign <> AValue then
  begin
    FDesign := AValue;
    FHover := False;
    if HandleAllocated then RecreateWnd;
  end;
  Invalidate;
end;

procedure TPDFThemeBitBtn.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FHover := True;
  if FDesign <> 0 then Invalidate;
end;

procedure TPDFThemeBitBtn.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHover := False;
  if FDesign <> 0 then Invalidate;
end;

procedure TPDFThemeBitBtn.CNDrawItem(var Message: TWMDrawItem);
var
  DC: HDC;
  R, GR: TRect;
  Back, Edge, Fore: TColor;
  State: UINT;
  C: TCanvas;
  GX, GY: Integer;
  S: string;
begin
  if FDesign = 0 then
  begin
    inherited;
    Exit;
  end;
  DC := Message.DrawItemStruct^.hDC;
  R := Message.DrawItemStruct^.rcItem;
  State := Message.DrawItemStruct^.itemState;
  case FDesign of
    1: begin Back := RGB(232, 238, 246); Edge := RGB(151, 168, 188); Fore := RGB(35, 48, 65); end;
    3: begin Back := RGB(192, 192, 192); Edge := RGB(128, 128, 128); Fore := clBlack; end;
    5: begin Back := RGB(190, 214, 237); Edge := RGB(93, 139, 185); Fore := RGB(24, 55, 88); end;
  else
    begin Back := clBtnFace; Edge := clBtnShadow; Fore := clWindowText; end;
  end;
  if FHover and Enabled then
    case FDesign of
      1: Back := RGB(213, 226, 242);
      3: Back := RGB(208, 208, 208);
      5: Back := RGB(174, 204, 233);
    end;
  if (State and ODS_SELECTED) <> 0 then
    case FDesign of
      1: Back := RGB(190, 211, 236);
      3: Back := RGB(176, 176, 176);
      5: Back := RGB(155, 190, 225);
    end;
  if not Enabled then Fore := clGrayText;
  C := TCanvas.Create;
  try
    C.Handle := DC;
    C.Brush.Color := Back;
    C.FillRect(R);
    if FDesign = 3 then
    begin
      // Windows Klassik: derselbe 3D-Rahmen wie TPDFDesignButton.
      if (State and ODS_SELECTED) <> 0 then
        DrawEdge(DC, R, BDR_SUNKENOUTER, BF_RECT)
      else
        DrawEdge(DC, R, BDR_RAISEDINNER or BDR_RAISEDOUTER, BF_RECT);
    end
    else
    begin
      C.Pen.Color := Edge;
      C.Rectangle(R.Left, R.Top, R.Right, R.Bottom);
    end;
    S := Caption;
    C.Font.Assign(Font);
    C.Font.Color := Fore;
    C.Brush.Style := bsClear;
    if (Glyph <> nil) and not Glyph.Empty then
    begin
      GX := R.Left + (R.Right - R.Left - Glyph.Width) div 2;
      GY := R.Top + (R.Bottom - R.Top - Glyph.Height) div 2;
      if S <> '' then GX := R.Left + 4;
      C.Draw(GX, GY, Glyph);
    end;
    if S <> '' then
    begin
      GR := R;
      if (Glyph <> nil) and not Glyph.Empty then Inc(GR.Left, Glyph.Width + 6);
      DrawText(DC, PChar(S), Length(S), GR, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    end;
  finally
    C.Handle := 0;
    C.Free;
  end;
  if (State and ODS_FOCUS) <> 0 then
  begin
    InflateRect(R, -3, -3);
    DrawFocusRect(DC, R);
  end;
  Message.Result := 1;
end;

procedure TPDFDesignButton.BMSetStyle(var Message: TMessage);
begin
  // VCL/Windows setzt beim Fokuswechsel den Button-Typ per BM_SETSTYLE
  // auf BS_PUSHBUTTON oder BS_DEFPUSHBUTTON zurueck. In alternativen
  // Designs muss BS_OWNERDRAW auch danach erhalten bleiben.
  if (FDesign <> 0) or FAccentCapable then
    Message.WParam := (Message.WParam and not WPARAM($000F)) or WPARAM(BS_OWNERDRAW);
  inherited;
end;

procedure TPDFDesignButton.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if (FDesign <> 0) or FAccentCapable then
    Params.Style := (Params.Style and not $000F) or BS_OWNERDRAW;
end;

procedure TPDFDesignButton.SetAccentOrange(AValue: Boolean);
begin
  if FAccentOrange = AValue then Exit;
  // Einmalig OwnerDraw aktivieren. Beim Werkzeugwechsel nicht wieder auf
  // Windows-Standardzeichnung umschalten: sonst kann das Orange stehen bleiben.
  if AValue and not FAccentCapable then
  begin
    FAccentCapable := True;
    FAccentOrange := True;
    if HandleAllocated then RecreateWnd;
  end
  else
    FAccentOrange := AValue;
  FHover := False;
  Invalidate;
  if HandleAllocated then RedrawWindow(Handle, nil, 0,
    RDW_INVALIDATE or RDW_ERASE or RDW_UPDATENOW);
  if (Parent <> nil) and Parent.HandleAllocated then
    RedrawWindow(Parent.Handle, nil, 0,
      RDW_INVALIDATE or RDW_ALLCHILDREN or RDW_UPDATENOW);
end;

procedure TPDFDesignButton.SetDesign(AValue: Integer);
begin
  if FDesign = AValue then Exit; // Keine Neuzeichnung ohne Designwechsel.

  // Auch die Schaltflaechen der Miniaturansicht (Seiten/Inhalte/X)
  // verwenden in allen alternativen Designs eine kraeftige Schrift.
  // Standard behaelt die urspruengliche Schriftgestaltung.
  ParentFont := False;
  if AValue <> 0 then
    Font.Style := Font.Style + [fsBold]
  else
    Font.Style := Font.Style - [fsBold];
  FDesign := AValue;
  FHover := False;
  if HandleAllocated then RecreateWnd;
  Invalidate;
end;

procedure TPDFDesignButton.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FHover := True;
  if (FDesign <> 0) or FAccentCapable then Invalidate;
end;

procedure TPDFDesignButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHover := False;
  if (FDesign <> 0) or FAccentCapable then Invalidate;
end;

procedure TPDFDesignButton.CNDrawItem(var Message: TWMDrawItem);
var
  DC: HDC;
  R: TRect;
  Back, Edge, Fore: TColor;
  State: UINT;
  OldFont: HGDIOBJ;
  S: string;
  ChildIndex: Integer;
  IconImage: TImage;
  PaintCanvas: TCanvas;
begin
  if (FDesign = 0) and not FAccentCapable then
  begin
    inherited;
    Exit;
  end;
  DC := Message.DrawItemStruct^.hDC;
  R := Message.DrawItemStruct^.rcItem;
  State := Message.DrawItemStruct^.itemState;
  case FDesign of
    1: begin Back := RGB(232, 238, 246); Edge := RGB(151, 168, 188); Fore := RGB(35, 48, 65); end;
    2: begin Back := RGB(65, 70, 79); Edge := RGB(112, 122, 137); Fore := clWhite; end;
    3: begin Back := RGB(192, 192, 192); Edge := RGB(128, 128, 128); Fore := clBlack; end;
    4: begin Back := RGB(44, 47, 52); Edge := RGB(100, 106, 116); Fore := clWhite; end;
    5: begin Back := RGB(190, 214, 237); Edge := RGB(93, 139, 185); Fore := RGB(24, 55, 88); end;
  else
    begin Back := clBtnFace; Edge := clBtnShadow; Fore := clWindowText; end;
  end;
  // Die Schaltflaeche fuer die endgueltige Schwaerzung bleibt im
  // Vorschau-Modus in jedem Design eindeutig orange hervorgehoben.
  if FAccentOrange then
  begin
    Back := RGB(255, 190, 92);
    Edge := RGB(210, 112, 20);
    Fore := RGB(70, 38, 8);
  end;
  if FHover and Enabled then
    if FAccentOrange then
      Back := RGB(255, 169, 55)
    else
    case FDesign of
      2: Back := RGB(86, 94, 107);
      4: Back := RGB(68, 73, 81);
      5: Back := RGB(183, 212, 243);
    else
      Back := RGB(213, 226, 242);
    end;
  if (State and ODS_SELECTED) <> 0 then
    if FAccentOrange then
      Back := RGB(235, 139, 32)
    else
    case FDesign of
      2, 4: Back := RGB(91, 106, 128);
    else
      Back := RGB(177, 202, 230);
    end;
  if not Enabled then Fore := clGrayText;
  SetBkColor(DC, ColorToRGB(Back));
  SetDCBrushColor(DC, ColorToRGB(Back));
  FillRect(DC, R, GetStockObject(DC_BRUSH));
  if FDesign = 3 then
  begin
    if (State and ODS_SELECTED) <> 0 then
      DrawEdge(DC, R, BDR_SUNKENOUTER, BF_RECT)
    else
      DrawEdge(DC, R, BDR_RAISEDINNER or BDR_RAISEDOUTER, BF_RECT);
  end
  else
  begin
    SetDCBrushColor(DC, ColorToRGB(Edge));
    FrameRect(DC, R, GetStockObject(DC_BRUSH));
  end;
  S := Caption;
  if S <> '' then
  begin
    OldFont := SelectObject(DC, Font.Handle);
    try
      SetBkMode(DC, TRANSPARENT);
      SetTextColor(DC, ColorToRGB(Fore));
      DrawText(DC, PChar(S), Length(S), R, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    finally
      SelectObject(DC, OldFont);
    end;
  end;
  // Untergeordnete PNG-Symbole (z.B. Arbeitsbereiche) im OwnerDraw
  // direkt zeichnen. Sonst uebermalt ein Fokus-/Klick-Redraw das TImage.
  for ChildIndex := 0 to ControlCount - 1 do
    if Controls[ChildIndex] is TImage then
    begin
      IconImage := TImage(Controls[ChildIndex]);
      if (IconImage.Picture.Graphic <> nil) and
         not IconImage.Picture.Graphic.Empty then
      begin
        PaintCanvas := TCanvas.Create;
        try
          PaintCanvas.Handle := DC;
          // Dieselbe Zentrierung wie das TImage im Standard-Design.
          // Insbesondere das Symbol "Seite anpassen" darf im
          // OwnerDraw-Modus nicht links oben statt mittig erscheinen.
          PaintCanvas.Draw(
            IconImage.Left + (IconImage.Width - IconImage.Picture.Graphic.Width) div 2,
            IconImage.Top + (IconImage.Height - IconImage.Picture.Graphic.Height) div 2,
            IconImage.Picture.Graphic);
          PaintCanvas.Handle := 0;
        finally
          PaintCanvas.Free;
        end;
      end;
    end;
  if (State and ODS_FOCUS) <> 0 then
  begin
    InflateRect(R, -3, -3);
    DrawFocusRect(DC, R);
  end;
  Message.Result := 1;
end;

procedure LoadGlobalThumbnails;
var Ini: TIniFile;
begin
  if GThumbnailsLoaded then Exit;
  GThumbnailsLoaded := True;
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    GThumbnailsVisible := Ini.ReadBool('Viewer', 'ThumbnailsVisible', False);
  finally
    Ini.Free;
  end;
end;

procedure SaveGlobalThumbnails;
var Ini: TIniFile;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    Ini.WriteBool('Viewer', 'ThumbnailsVisible', GThumbnailsVisible);
  finally
    Ini.Free;
  end;
end;

function ToolbarHint(const ADeutsch, AEnglish: string): string;
begin
  if SameText(PDFLanguage, 'en') then Result := AEnglish
  else Result := ADeutsch;
end;


// Patch 3b.41: Suchfeld mit eigenem Datenbestand fuer grosse PDF-Optionslisten.
type
  TPDFOptionSearch = class(TEdit)
  private
    FAllOptions: TStringList;
    FOptionList: TListBox;
    FResultLabel: TLabel;
    procedure FilterOptions(Sender: TObject);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(AList: TListBox; AOptions: TStrings;
      AResultLabel: TLabel);
  end;

constructor TPDFOptionSearch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAllOptions := TStringList.Create;
  OnChange := FilterOptions;
end;

destructor TPDFOptionSearch.Destroy;
begin
  FAllOptions.Free;
  inherited Destroy;
end;


procedure SetToolbarPngIcon(AButton: TButton; const ABase64: string);
var
  Data: TBytes;
  Stream: TBytesStream;
  Png: TPngImage;
  Img: TImage;
begin
  Data := TNetEncoding.Base64.DecodeStringToBytes(ABase64);
  Stream := TBytesStream.Create(Data);
  Png := TPngImage.Create;
  try
    Png.LoadFromStream(Stream);
    Img := TImage.Create(AButton);
    Img.Parent := AButton;
    // Die Grafik fuellt die Schaltflaeche als zentriertes Symbol aus.
    // Dadurch bleibt sie auch nach einem DPI-/Toolbar-Realign mittig.
    Img.Align := alClient;
    Img.AlignWithMargins := True;
    Img.Margins.SetBounds(MulDiv(5, AButton.CurrentPPI, 96),
      MulDiv(5, AButton.CurrentPPI, 96),
      MulDiv(5, AButton.CurrentPPI, 96),
      MulDiv(5, AButton.CurrentPPI, 96));
    Img.Center := True;
    Img.Proportional := True;
    Img.Stretch := True;
    Img.Transparent := True;
    Img.Picture.Assign(Png);
    Img.Hint := AButton.Hint;
    Img.ShowHint := True;
    // Klick auf die Grafik muss dieselbe Aktion wie der Button ausloesen.
    Img.OnClick := AButton.OnClick;
    Img.Enabled := True;
    Img.Visible := True;
    AButton.Caption := '';
  finally
    Png.Free;
    Stream.Free;
  end;
end;


procedure TPDFOptionSearch.Setup(AList: TListBox; AOptions: TStrings;
  AResultLabel: TLabel);
begin
  FOptionList := AList;
  FResultLabel := AResultLabel;
  FAllOptions.Assign(AOptions);
  FilterOptions(Self);
end;

procedure TPDFOptionSearch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  // Pfeil ab/auf aus dem Suchfeld steuert die Ergebnisliste.
  if (FOptionList <> nil) and (FOptionList.Count > 0) and
     (Key in [VK_DOWN, VK_UP]) then
  begin
    if Key = VK_DOWN then
      FOptionList.ItemIndex := Min(FOptionList.Count - 1,
        FOptionList.ItemIndex + 1)
    else
      FOptionList.ItemIndex := Max(0, FOptionList.ItemIndex - 1);
    Key := 0;
    Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TPDFOptionSearch.FilterOptions(Sender: TObject);
var
  I: Integer;
  OldValue: string;
begin
  if FOptionList = nil then Exit;
  OldValue := '';
  if FOptionList.ItemIndex >= 0 then
    OldValue := FOptionList.Items[FOptionList.ItemIndex];
  FOptionList.Items.BeginUpdate;
  try
    FOptionList.Items.Clear;
    for I := 0 to FAllOptions.Count - 1 do
      if (Text = '') or (Pos(AnsiLowerCase(Text),
         AnsiLowerCase(FAllOptions[I])) > 0) then
        FOptionList.Items.Add(FAllOptions[I]);
    FOptionList.ItemIndex := FOptionList.Items.IndexOf(OldValue);
    if (FOptionList.ItemIndex < 0) and (FOptionList.Count > 0) then
      FOptionList.ItemIndex := 0;
  finally
    FOptionList.Items.EndUpdate;
  end;
  if FResultLabel <> nil then
  begin
    if FOptionList.Count = 0 then
      FResultLabel.Caption := 'Keine Treffer'
    else
      FResultLabel.Caption := Format('%d von %d Eintraegen',
        [FOptionList.Count, FAllOptions.Count]);
  end;
end;

procedure TPDFiumImage.Paint;
begin
  inherited Paint;
  if Assigned(FAfterPaint) then FAfterPaint(Self);
end;

function TFreePDF64PDFiumView.AuthorizeCommentOwner: Boolean;
var
  Password: string;
  Probe: TFreePDF64PDFiumCore;
  Attempts: Integer;
begin
  Result := False;
  if (FCore = nil) or (FCore.FileName = '') then Exit;
  for Attempts := 1 to 3 do
  begin
    if not RequestPDFPassword(FCore.FileName, Password, True) then Exit;
    Probe := TFreePDF64PDFiumCore.Create;
    try
      try
        Probe.OpenFile(FCore.FileName, UTF8Encode(Password));
        // PDFium reports unrestricted permissions for an owner-authorized
        // document. A user password must not bypass the permission check.
        if (Probe.SecurityRevision >= 0) and
           ((Probe.SecurityPermissions and UInt64(32)) <> 0) and
           ((Probe.SecurityPermissions and UInt64(8)) <> 0) then
        begin
          FCommentOwnerAuthorized := True;
          Result := True;
          Exit;
        end;
      except
        on EPDFiumPasswordRequired do ;
        on EPDFiumViewer do ;
      end;
    finally
      Password := '';
      Probe.Free;
    end;
    PDFModernMessageDlg(ToolbarHint(
      'Das Berechtigungskennwort ist nicht korrekt.',
      'The permissions password is incorrect.'), mtWarning, [mbOK], 0);
  end;
end;

function TFreePDF64PDFiumView.CanModifyComments(AShowWarning: Boolean): Boolean;
begin
  Result := (FCore <> nil) and
    (FCommentOwnerAuthorized or (FCore.SecurityRevision < 0) or
     ((FCore.SecurityPermissions and UInt64(32)) <> 0));
  if not Result and AShowWarning then
    Result := AuthorizeCommentOwner;
end;

procedure TFreePDF64PDFiumView.NoteButtonClick(Sender: TObject);
begin
  if not CanModifyComments then Exit;
  // Vor dem direkten Wechsel vom Text- zum Kommentarmodus das noch
  // sichtbare Texteingabefeld abschliessen und entfernen.
  if (not FNoteMode) and (FTextEditor <> nil) then
    FinishTextEditor(True);
  FNoteMode := not FNoteMode;
  if FNoteMode then
  begin
    if FMeasureMode then
    begin
      FMeasureMode := False;
      CancelMeasurement;
      if FMeasureButton <> nil then FMeasureButton.Font.Style := [];
    end;
    FTextInsertMode := False;
    FHighlightMode := False;
    FTextInsertButton.Caption := Tr('Text einfügen');
    FHighlightButton.Caption := ToolbarHint('Text hervorheben', 'Highlight text');
  end;
  if FNoteMode then
    FNoteButton.Caption := ToolbarHint('Kommentar: EIN', 'Comment: ON')
  else
    FNoteButton.Caption := ToolbarHint('Kommentar', 'Comment');
  UpdateTextUndoButtons;
  LayoutToolbar(nil);
end;

function TFreePDF64PDFiumView.NoteScreenRect(Img: TPDFiumImage;
  const N: TPDFNote; out R: TRect): Boolean;
var
  X1, Y1: Integer;
  X2, Y2: Integer;
  W, H: Integer;
begin
  Result := False;
  if (Img = nil) or (FCore = nil) then Exit;
  if not FCore.PagePointToDevice(Img.Tag, Img.Width, Img.Height,
    N.Bounds.Left, N.Bounds.Top, X1, Y1) then Exit;
  if not FCore.PagePointToDevice(Img.Tag, Img.Width, Img.Height,
    N.Bounds.Right, N.Bounds.Bottom, X2, Y2) then Exit;
  W := MulDiv(20, CurrentPPI, 96);
  H := MulDiv(17, CurrentPPI, 96);
  // Die sichtbare Blase hat eine feste DPI-skalierte Groesse.
  // Ihre Position ist der obere linke Eckpunkt des PDF-Rechtecks.
  R := Rect(Min(X1, X2), Min(Y1, Y2),
    Min(X1, X2) + W, Min(Y1, Y2) + H);
  Result := True;
end;

function TFreePDF64PDFiumView.NoteAtPoint(Img: TPDFiumImage;
  X, Y: Integer; out N: TPDFNote): Boolean;
var
  A: TPDFNote;
  R: TRect;
begin
  Result := False;
  if (Img = nil) or (FCore = nil) then Exit;
  for A in FCore.GetNotes(Img.Tag) do
    if NoteScreenRect(Img, A, R) and PtInRect(R, Point(X, Y)) then
    begin
      N := A;
      Exit(True);
    end;
end;

function TFreePDF64PDFiumView.NoteDialog(var AText: string): Boolean;
var
  D: TForm;
  M: TMemo;
  B: TPDFDesignButton;
  Footer: TPanel;
  P: Integer;
begin
  Result := False;
  D := TForm.CreateNew(Self);
  try
    P := Max(96, CurrentPPI);
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.Caption := ToolbarHint('Kommentar bearbeiten', 'Edit comment');
    D.BorderStyle := bsSizeable;
    D.Position := poScreenCenter;
    D.ClientWidth := MulDiv(430, CurrentPPI, 96);
    D.ClientHeight := MulDiv(270, CurrentPPI, 96);
    D.Constraints.MinWidth := MulDiv(320, CurrentPPI, 96);
    D.Constraints.MinHeight := MulDiv(210, CurrentPPI, 96);
    M := TMemo.Create(D);
    M.Parent := D;
    M.Align := alClient;
    M.ScrollBars := ssVertical;
    M.WordWrap := True;
    M.Lines.Text := AText;
    Footer := TPanel.Create(D);
    begin
      Footer.Parent := D;
      Footer.Align := alBottom;
      Footer.Height := MulDiv(44, CurrentPPI, 96);
      Footer.BevelOuter := bvNone;
      B := TPDFDesignButton.Create(D);
      B.Parent := Footer;
      B.SetBounds(MulDiv(235, CurrentPPI, 96), MulDiv(7, CurrentPPI, 96),
        MulDiv(88, CurrentPPI, 96), MulDiv(29, CurrentPPI, 96));
      B.Caption := 'OK';
      B.ModalResult := mrOk;
      B.Default := True;
      B := TPDFDesignButton.Create(D);
      B.Parent := Footer;
      B.SetBounds(MulDiv(330, CurrentPPI, 96), MulDiv(7, CurrentPPI, 96),
        MulDiv(90, CurrentPPI, 96), MulDiv(29, CurrentPPI, 96));
      B.Caption := ToolbarHint('Abbrechen', 'Cancel');
      B.ModalResult := mrCancel;
    end;
    // Dialogpalette einmalig beim Erzeugen anwenden.
    ApplyManagedDialogPalette(D, nil, FEditToggle.FDesign);
    Footer.ParentColor := False;
    Footer.Color := D.Color;
    M.ParentColor := False;
    case FEditToggle.FDesign of
      1: begin M.Color := RGB(248,250,253); M.Font.Color := RGB(35,48,65); end;
      2: begin M.Color := RGB(65,70,79); M.Font.Color := clWhite; end;
      3: begin M.Color := clWhite; M.Font.Color := clBlack; end;
      4: begin M.Color := RGB(45,48,54); M.Font.Color := clWhite; end;
      5: begin M.Color := RGB(246,250,255); M.Font.Color := RGB(24,55,88); end;
    else begin M.Color := clWindow; M.Font.Color := clWindowText; end;
    end;
    if D.ShowModal = mrOk then
    begin
      AText := M.Lines.Text;
      Result := Trim(AText) <> '';
    end;
  finally
    D.Free;
  end;
end;

procedure TFreePDF64PDFiumView.NoteMenuClick(Sender: TObject);
var
  S: string;
begin
  if not (Sender is TMenuItem) then Exit;
  if not CanModifyComments then Exit;
  case TMenuItem(Sender).Tag of
    1: begin
         S := FNoteSelected.Contents;
         if NoteDialog(S) then
           if FCore.ChangeNote(FNoteSelected, S, 0, 0, False) then
           begin
             RefreshTextPage(FNoteSelected.PageIndex);
             UpdateSaveState;
           end;
       end;
    2: begin
         FNoteMovePending := True;
         Screen.Cursor := crCross;
       end;
    3: if PDFModernMessageDlg(ToolbarHint('Kommentar wirklich löschen?',
           'Delete this comment?'), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
         if FCore.DeleteNote(FNoteSelected) then
         begin
           RefreshTextPage(FNoteSelected.PageIndex);
           UpdateSaveState;
         end;
  end;
end;

procedure TFreePDF64PDFiumView.PageImagePainted(Sender: TObject);
var
  Img: TPDFiumImage;
  R: TRect;
  Overlay: TControlCanvas;
  Note: TPDFNote;
  NoteRect: TRect;
  NX, NY: Integer;
begin
  DrawMeasurement(Sender);
  // Transparente Signaturvorschau auf der PDF-Seite (nicht im PDF gespeichert).
  if FSignatureMode and FSignaturePreviewVisible and
     (Sender is TPDFiumImage) and (FSignaturePreview <> nil) and
     (FSignaturePreview.Graphic <> nil) then
  begin
    Img := TPDFiumImage(Sender);
    // Vor der Platzierung folgt die Signatur der aktuellen Mausposition.
    // Beim Scrollen bleibt der Mauszeiger stehen, aber die PDF-Seite bewegt
    // sich darunter. Daher die Vorschau auch beim Neuzeichnen der Seite
    // anhand der Bildschirm-Mausposition aktualisieren, nicht nur bei MouseMove.
    // Eine bereits platzierte (noch nicht bestätigte) Signatur bleibt dagegen
    // absichtlich an ihrer PDF-Seitenposition verankert.
    if not FSignaturePlaced then
    begin
      var CursorOnPage := Img.ScreenToClient(Mouse.CursorPos);
      if PtInRect(Img.ClientRect, CursorOnPage) then
      begin
        FSignaturePreviewPage := Img.Tag;
        FSignaturePreviewPoint := CursorOnPage;
      end;
    end;
    if Img.Tag = FSignaturePreviewPage then
    begin
      var PW, PH: Single;
      if not FCore.PageSize(Img.Tag, PW, PH) then Exit;
      var PreviewW := Max(1, Round(FSignatureWidthMM * 72 / 25.4 *
        Img.Width / Max(1.0, Double(PW))));
      var PreviewH := Max(1, MulDiv(PreviewW,
        FSignaturePreview.Height, Max(1, FSignaturePreview.Width)));
      if FSignaturePlaced then
        R := FSignatureRect
      else
      begin
        R := Rect(EnsureRange(FSignaturePreviewPoint.X, 0, Max(0, Img.Width - PreviewW)),
          EnsureRange(FSignaturePreviewPoint.Y, 0, Max(0, Img.Height - PreviewH)), 0, 0);
        R.Right := R.Left + PreviewW;
        R.Bottom := R.Top + PreviewH;
      end;
      TPDFGraphicCanvasAccess(Img).Canvas.StretchDraw(R, FSignaturePreview.Graphic);
      TPDFGraphicCanvasAccess(Img).Canvas.Brush.Style := bsClear;
      TPDFGraphicCanvasAccess(Img).Canvas.Pen.Color := RGB(35, 112, 198);
      TPDFGraphicCanvasAccess(Img).Canvas.Pen.Style := psDash;
      TPDFGraphicCanvasAccess(Img).Canvas.Rectangle(R);
      if FSignaturePlaced then
      begin
        TPDFGraphicCanvasAccess(Img).Canvas.Brush.Color := clWhite;
        TPDFGraphicCanvasAccess(Img).Canvas.Brush.Style := bsSolid;
        TPDFGraphicCanvasAccess(Img).Canvas.Pen.Style := psSolid;
        TPDFGraphicCanvasAccess(Img).Canvas.Rectangle(R.Left-4,R.Top-4,R.Left+5,R.Top+5);
        TPDFGraphicCanvasAccess(Img).Canvas.Rectangle(R.Right-4,R.Top-4,R.Right+5,R.Top+5);
        TPDFGraphicCanvasAccess(Img).Canvas.Rectangle(R.Left-4,R.Bottom-4,R.Left+5,R.Bottom+5);
        TPDFGraphicCanvasAccess(Img).Canvas.Rectangle(R.Right-4,R.Bottom-4,R.Right+5,R.Bottom+5);
      end;
      TPDFGraphicCanvasAccess(Img).Canvas.Pen.Style := psSolid;
      TPDFGraphicCanvasAccess(Img).Canvas.Brush.Style := bsSolid;
    end;
  end;
  // Temporärer Auswahlrahmen: nur auf dem Bildschirm, nicht im PDF.
  if FHighlightAreaDragging and (Sender is TPDFiumImage) then
  begin
    Img := TPDFiumImage(Sender);
    if Img.Tag = FHighlightAreaPage then
    begin
      R := Rect(Min(FHighlightAreaStartX, FHighlightAreaEndX),
        Min(FHighlightAreaStartY, FHighlightAreaEndY),
        Max(FHighlightAreaStartX, FHighlightAreaEndX),
        Max(FHighlightAreaStartY, FHighlightAreaEndY));
      // TImage.Canvas zeichnet IN die Picture-Bitmap. Das hinterliess beim
      // Ziehen dauerhafte Linien ("Straehnen"). Stattdessen ausschliesslich
      // auf die temporaere Zeichenflaeche des Controls zeichnen.
      Overlay := TControlCanvas.Create;
      try
        Overlay.Control := Img;
        Overlay.Pen.Style := psSolid;
        Overlay.Pen.Width := 1;
        Overlay.Pen.Color := RGB(35, 112, 198);
        Overlay.Brush.Style := bsClear;
        Overlay.Rectangle(R);
      finally
        Overlay.Free;
      end;
    end;
  end;
  if (Sender is TPDFiumImage) and (FCore <> nil) then
  begin
    Img := TPDFiumImage(Sender);
    for Note in FCore.GetNotes(Img.Tag) do
    begin
      if NoteScreenRect(Img, Note, NoteRect) then
      begin
        NX := NoteRect.Left;
        NY := NoteRect.Top;
        Overlay := TControlCanvas.Create;
        try
          Overlay.Control := Img;
          Overlay.Brush.Color := RGB(255, 228, 38);
          Overlay.Pen.Color := clBlack;
          Overlay.Pen.Width := 1;
          Overlay.RoundRect(NX, NY, NX + MulDiv(20, CurrentPPI, 96), NY + MulDiv(17, CurrentPPI, 96), MulDiv(3, CurrentPPI, 96), MulDiv(3, CurrentPPI, 96));
          Overlay.MoveTo(NX+MulDiv(5, CurrentPPI, 96), NY+MulDiv(5, CurrentPPI, 96));
          Overlay.LineTo(NX+MulDiv(15, CurrentPPI, 96), NY+MulDiv(5, CurrentPPI, 96));
          Overlay.MoveTo(NX+MulDiv(5, CurrentPPI, 96), NY+MulDiv(9, CurrentPPI, 96));
          Overlay.LineTo(NX+MulDiv(15, CurrentPPI, 96), NY+MulDiv(9, CurrentPPI, 96));
          Overlay.MoveTo(NX+MulDiv(5, CurrentPPI, 96), NY+MulDiv(13, CurrentPPI, 96));
          Overlay.LineTo(NX+MulDiv(12, CurrentPPI, 96), NY+MulDiv(13, CurrentPPI, 96));
        finally
          Overlay.Free;
        end;
      end;
    end;
  end;
  if (FCore = nil) or (FPage < 0) or (FPage >= FPages.Count) then Exit;
  if (Sender = FPages[FPage]) and GetFirstPageReady and
     Assigned(FOnFirstPagePaint) then
    FOnFirstPagePaint(Self);
end;


// Kleines, DPI-skaliertes Hinweisfenster fuer lang dauernde PDF-Aktionen.
// Kein ProcessMessages: waehrend der Aktion duerfen keine weiteren
// Benutzerbefehle oder Timer reentrant ausgefuehrt werden.
function ShowPDFBusyNotice(const AText: string): TForm;
var
  Info: TLabel;
  P: Integer;
begin
  Result := TForm.CreateNew(Application);
  try
    Result.BorderStyle := bsNone;
    Result.Position := poScreenCenter;
    Result.Font.Name := 'Segoe UI';
    Result.Font.Size := 11;
    Result.Color := $00F8F1E8;
    Result.Scaled := True;
    P := Result.CurrentPPI;
    Result.ClientWidth := MulDiv(380, P, 96);
    Result.ClientHeight := MulDiv(105, P, 96);
    Info := TLabel.Create(Result);
    Info.Parent := Result;
    Info.AutoSize := False;
    Info.Alignment := taCenter;
    Info.Layout := tlCenter;
    Info.WordWrap := True;
    Info.Font.Style := [fsBold];
    Info.Font.Color := $00C47A20;
    Info.SetBounds(MulDiv(20, P, 96), MulDiv(12, P, 96),
      Result.ClientWidth - MulDiv(40, P, 96), MulDiv(80, P, 96));
    Info.Caption := Tr('Bitte warten ...') + sLineBreak + AText;
    Result.Show;
    Result.Update;
    UpdateWindow(Result.Handle);
  except
    Result.Free;
    raise;
  end;
end;

constructor TPDFiumSaveButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '';
  Layout := blGlyphLeft;
  Margin := -1;
  Spacing := 0;
  UpdateSaveGlyph;
end;

procedure TPDFiumSaveButton.BMSetStyle(var Message: TMessage);
begin
  Message.WParam := (Message.WParam and not WPARAM($000F)) or WPARAM(BS_OWNERDRAW);
  inherited;
end;

procedure TPDFiumSaveButton.SetDesign(AValue: Integer);
begin
  if FDesign = AValue then Exit;
  FDesign := AValue;
  Invalidate;
end;

procedure TPDFiumSaveButton.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := (Params.Style and not $000F) or BS_OWNERDRAW;
end;

procedure TPDFiumSaveButton.CNDrawItem(var Message: TWMDrawItem);
var
  DC: HDC;
  R: TRect;
  Back, Edge: TColor;
  State: UINT;
  Theme: HTHEME;
  ThemeState: Integer;
  GX, GY, ArrowX, ArrowY, ArrowW: Integer;
  ArrowPoints: array[0..2] of TPoint;
  OldPen, OldBrush: HGDIOBJ;
  ArrowColor: TColor;
  C: TCanvas;
begin
  DC := Message.DrawItemStruct^.hDC;
  R := Message.DrawItemStruct^.rcItem;
  State := Message.DrawItemStruct^.itemState;
  // Rahmen und Hintergrund identisch zu TPDFDesignButton (Info/Drucken).
  if FDesign <> 0 then
  begin
    case FDesign of
      1: begin Back := RGB(232, 238, 246); Edge := RGB(151, 168, 188); end;
      2: begin Back := RGB(65, 70, 79); Edge := RGB(112, 122, 137); end;
      3: begin Back := RGB(192, 192, 192); Edge := RGB(128, 128, 128); end;
      4: begin Back := RGB(44, 47, 52); Edge := RGB(100, 106, 116); end;
      5: begin Back := RGB(190, 214, 237); Edge := RGB(93, 139, 185); end;
    else
      begin Back := clBtnFace; Edge := clBtnShadow; end;
    end;
    if (State and ODS_SELECTED) <> 0 then
      case FDesign of
        2, 4: Back := RGB(91, 106, 128);
      else
        Back := RGB(177, 202, 230);
      end;
    if FHighlighted and Enabled then Back := RGB(255, 175, 65);
    SetDCBrushColor(DC, ColorToRGB(Back));
    FillRect(DC, R, GetStockObject(DC_BRUSH));
    if FDesign = 3 then
    begin
      if (State and ODS_SELECTED) <> 0 then
        DrawEdge(DC, R, BDR_SUNKENOUTER, BF_RECT)
      else
        DrawEdge(DC, R, BDR_RAISEDINNER or BDR_RAISEDOUTER, BF_RECT);
    end
    else
    begin
      SetDCBrushColor(DC, ColorToRGB(Edge));
      FrameRect(DC, R, GetStockObject(DC_BRUSH));
    end;
  end
  else
  begin
    // Standarddesign: Windows-Themenrahmen wie bei den Nachbarbuttons.
    Theme := 0;
    if IsThemeActive then Theme := OpenThemeData(Handle, 'BUTTON');
    if Theme <> 0 then
    begin
      try
        if not Enabled then ThemeState := 4
        else if (State and ODS_SELECTED) <> 0 then ThemeState := 3
        else if (State and ODS_HOTLIGHT) <> 0 then ThemeState := 2
        else ThemeState := 1;
        DrawThemeBackground(Theme, DC, 1, ThemeState, R, nil);
      finally
        CloseThemeData(Theme);
      end;
    end
    else
      DrawFrameControl(DC, R, DFC_BUTTON, DFCS_BUTTONPUSH);
    if FHighlighted and Enabled then
    begin
      InflateRect(R, -3, -3);
      SetDCBrushColor(DC, RGB(255, 175, 65));
      FillRect(DC, R, GetStockObject(DC_BRUSH));
    end;
  end;
  R := Message.DrawItemStruct^.rcItem;
  if (Glyph <> nil) and not Glyph.Empty then
  begin
    // Das Diskettensymbol bleibt unveraendert; nur leicht nach links ruecken.
    GX := (R.Left + R.Right - Glyph.Width) div 2 - MulDiv(2, Max(96, CurrentPPI), 96);
    GY := (R.Top + R.Bottom - Glyph.Height) div 2;
    C := TCanvas.Create;
    try
      C.Handle := DC;
      C.Draw(GX, GY, Glyph);
      C.Handle := 0;
    finally
      C.Free;
    end;
  end;
  // Kleiner Dropdown-Pfeil wie bei "Einfuegen" und "Messen".
  // Direkt auf dem Button zeichnen, ohne Glyph oder Buttonbreite zu aendern.
  ArrowW := Max(3, MulDiv(4, Max(96, CurrentPPI), 96));
  ArrowX := R.Right - MulDiv(3, Max(96, CurrentPPI), 96) - ArrowW;
  ArrowY := (R.Top + R.Bottom) div 2 + MulDiv(2, Max(96, CurrentPPI), 96);
  ArrowPoints[0] := Point(ArrowX - ArrowW, ArrowY - ArrowW div 2);
  ArrowPoints[1] := Point(ArrowX + ArrowW, ArrowY - ArrowW div 2);
  ArrowPoints[2] := Point(ArrowX, ArrowY + ArrowW div 2);
  if not Enabled then ArrowColor := clGrayText
  else if FDesign in [2, 4] then ArrowColor := clWhite
  else ArrowColor := clBlack;
  OldPen := SelectObject(DC, GetStockObject(NULL_PEN));
  OldBrush := SelectObject(DC, CreateSolidBrush(ColorToRGB(ArrowColor)));
  try
    Polygon(DC, ArrowPoints, Length(ArrowPoints));
  finally
    DeleteObject(SelectObject(DC, OldBrush));
    SelectObject(DC, OldPen);
  end;
  Message.Result := 1;
end;

procedure TPDFiumSaveButton.SetHighlighted(const Value: Boolean);
begin
  if FHighlighted = Value then Exit;
  FHighlighted := Value;
  UpdateSaveGlyph;
end;

procedure TPDFiumSaveButton.UpdateSaveGlyph;
var
  B: TBitmap;
  Dpi, S, X, Y, LineW: Integer;
  function P(N: Integer): Integer;
  begin
    Result := MulDiv(N, Dpi, 96);
  end;
begin
  Dpi := Max(96, CurrentPPI);
  S := P(28);
  B := TBitmap.Create;
  try
    B.PixelFormat := pf24bit;
    B.SetSize(S, S);
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, S, S));
    B.TransparentColor := clFuchsia;
    B.TransparentMode := tmFixed;
    B.Transparent := True;
    X := P(3);
    Y := P(3);
    LineW := Max(1, P(2));
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := LineW;
    B.Canvas.Brush.Style := bsClear;
    // Dieselbe transparente Konturzeichnung wie bei den anderen Icons.
    B.Canvas.Rectangle(X, Y, X + P(22), Y + P(22));
    B.Canvas.Rectangle(X + P(4), Y + P(2), X + P(17), Y + P(9));
    B.Canvas.MoveTo(X + P(12), Y + P(2));
    B.Canvas.LineTo(X + P(12), Y + P(9));
    B.Canvas.Rectangle(X + P(4), Y + P(13), X + P(18), Y + P(21));
    if FHighlighted then
    begin
      B.Canvas.Brush.Style := bsSolid;
      B.Canvas.Brush.Color := clBlack;
      B.Canvas.Ellipse(P(22), 0, P(28), P(6));
    end;
    Glyph.Assign(B);
    NumGlyphs := 1;
  finally
    B.Free;
  end;
  Invalidate;
end;

procedure TFreePDF64PDFiumView.SetFullScreenDisplay(AEnabled: Boolean);
begin
  // Nur die PDF-Seiten sichtbar lassen; den Bearbeitungszustand bewahren.
  FBar.Visible := not AEnabled;
  FEditBar.Visible := (not AEnabled) and FEditVisible;
end;

procedure TPDFToolsButton.BMSetStyle(var Message: TMessage);
begin
  Message.WParam := (Message.WParam and not WPARAM($000F)) or WPARAM(BS_OWNERDRAW);
  inherited;
end;

procedure TPDFToolsButton.SetDesign(AValue: Integer);
begin
  if FDesign = AValue then Exit;
  FDesign := AValue;
  Invalidate;
end;

procedure TPDFToolsButton.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := (Params.Style and not $000F) or BS_OWNERDRAW;
end;

procedure TPDFToolsButton.CNDrawItem(var Message: TWMDrawItem);
var
  DC: HDC;
  R: TRect;
  Brush: HBRUSH;
  C: TCanvas;
  GX, GY: Integer;
  Theme: HTHEME;
  State: Integer;
begin
  DC := Message.DrawItemStruct^.hDC;
  R := Message.DrawItemStruct^.rcItem;
  if FHighlighted and Enabled then
  begin
    // Orange signalisiert die eingeschalteten Bearbeitungswerkzeuge.
    Brush := CreateSolidBrush(RGB(255, 175, 65));
    try
      FillRect(DC, R, Brush);
    finally
      DeleteObject(Brush);
    end;
    DrawEdge(DC, R, EDGE_RAISED, BF_RECT);

  end
  else if FDesign <> 0 then
  begin
    case FDesign of
      1: Brush := CreateSolidBrush(RGB(232, 238, 246));
      3: Brush := CreateSolidBrush(RGB(192, 192, 192));
      5: Brush := CreateSolidBrush(RGB(190, 214, 237));
    else
      Brush := CreateSolidBrush(GetSysColor(COLOR_BTNFACE));
    end;
    try
      FillRect(DC, R, Brush);
    finally
      DeleteObject(Brush);
    end;
    if FHighlighted or ((Message.DrawItemStruct^.itemState and ODS_SELECTED) <> 0) then
      DrawEdge(DC, R, EDGE_SUNKEN, BF_RECT)
    else
      DrawEdge(DC, R, EDGE_RAISED, BF_RECT);
  end
  else
  begin
    // Windows zeichnet den normalen Button im selben Stil wie die Nachbarbuttons.
    Theme := 0;
    if IsThemeActive then
      Theme := OpenThemeData(Handle, 'BUTTON');
    if Theme <> 0 then
    begin
      try
        if not Enabled then
          State := 4  // PBS_DISABLED
        else if (Message.DrawItemStruct^.itemState and ODS_SELECTED) <> 0 then
          State := 3  // PBS_PRESSED
        else if (Message.DrawItemStruct^.itemState and ODS_HOTLIGHT) <> 0 then
          State := 2  // PBS_HOT
        else
          State := 1; // PBS_NORMAL
        DrawThemeBackground(Theme, DC, 1 {BP_PUSHBUTTON}, State, R, nil);
      finally
        CloseThemeData(Theme);
      end;
    end
    else
    begin
      Brush := CreateSolidBrush(GetSysColor(COLOR_BTNFACE));
      try
        FillRect(DC, R, Brush);
      finally
        DeleteObject(Brush);
      end;
      if (Message.DrawItemStruct^.itemState and ODS_SELECTED) <> 0 then
        DrawEdge(DC, R, EDGE_SUNKEN, BF_RECT)
      else
        DrawEdge(DC, R, EDGE_RAISED, BF_RECT);
    end;
  end;
  // Der blaue Akzentrahmen bleibt in jedem Zustand sichtbar.
  // Statischer Akzentrahmen: keine Timer oder Animation.
  C := TCanvas.Create;
  try
    C.Handle := DC;
      case FDesign of
        3: C.Pen.Color := RGB(25, 80, 145);
        5: C.Pen.Color := RGB(24, 93, 170);
      else
        C.Pen.Color := RGB(35, 105, 205);
      end;
      C.Pen.Width := Max(2, MulDiv(2, CurrentPPI, 96));
      C.Brush.Style := bsClear;
      C.Rectangle(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1);
      C.Handle := 0;
    finally
      C.Free;
    end;
  if (Glyph <> nil) and not Glyph.Empty then
  begin
    GX := (R.Left + R.Right - Glyph.Width) div 2;
    GY := (R.Top + R.Bottom - Glyph.Height) div 2;
    C := TCanvas.Create;
    try
      C.Handle := DC;
      C.Draw(GX, GY, Glyph);
      C.Handle := 0;
    finally
      C.Free;
    end;
  end;
  Message.Result := 1;
end;


procedure TPDFToolsButton.SetHighlighted(const Value: Boolean);
begin
  if FHighlighted = Value then Exit;
  FHighlighted := Value;
  Invalidate;
end;

constructor TPDFToolsButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '';
  Layout := blGlyphLeft;
  Margin := -1;
  Spacing := 0;
  UpdateToolsGlyph;
end;

procedure TPDFToolsButton.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited ChangeScale(M, D, isDpiChange);
  UpdateToolsGlyph;
end;

procedure TPDFToolsButton.UpdateToolsGlyph;
var
  B: TBitmap;
  S: Integer;
  function P(V: Integer): Integer;
  begin
    Result := MulDiv(V - 2, S, 28);
  end;
  procedure Line(X1, Y1, X2, Y2: Integer);
  begin
    B.Canvas.MoveTo(P(X1), P(Y1));
    B.Canvas.LineTo(P(X2), P(Y2));
  end;
begin
  S := MulDiv(28, CurrentPPI, 96);
  if S < 14 then S := 14;
  B := TBitmap.Create;
  try
    B.PixelFormat := pf24bit;
    B.SetSize(S, S);
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, S, S));
    B.TransparentColor := clFuchsia;
    B.Transparent := True;

    // Lineal unten links, mit sichtbaren Teilstrichen.
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := Max(1, MulDiv(2, S, 32));
    B.Canvas.Brush.Color := clWhite;
    B.Canvas.Polygon([Point(P(3), P(22)), Point(P(22), P(22)),
      Point(P(22), P(27)), Point(P(3), P(27))]);
    B.Canvas.Pen.Width := Max(1, MulDiv(1, S, 32));
    Line(7, 22, 7, 25);
    Line(11, 22, 11, 24);
    Line(15, 22, 15, 25);
    Line(19, 22, 19, 24);

    // Ein schraeg auf dem Lineal liegender Stift mit Spitze.
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := Max(1, MulDiv(2, S, 32));
    B.Canvas.Brush.Color := clWhite;
    B.Canvas.Polygon([Point(P(9), P(19)), Point(P(20), P(5)),
      Point(P(25), P(9)), Point(P(14), P(23))]);
    B.Canvas.Brush.Color := clWhite;
    B.Canvas.Polygon([Point(P(9), P(19)), Point(P(14), P(23)),
      Point(P(7), P(26))]);
    B.Canvas.Brush.Color := clBlack;
    B.Canvas.Polygon([Point(P(7), P(26)), Point(P(9), P(23)),
      Point(P(10), P(25))]);
    B.Canvas.Brush.Color := clBlack;
    B.Canvas.Polygon([Point(P(20), P(5)), Point(P(23), P(2)),
      Point(P(28), P(6)), Point(P(25), P(9))]);
    Glyph.Assign(B);
  finally
    B.Free;
  end;
end;

constructor TFreePDF64PDFiumView.CreateInParent(AOwner: TComponent; AParent: TWinControl);
  function Btn(const S: string; X, W: Integer; Handler: TNotifyEvent): TButton;
  begin
    Result := TPDFDesignButton.Create(Self);
    Result.Parent := FBar;
    Result.SetBounds(X, 4, W, 28);
    Result.Caption := S;
    Result.OnClick := Handler;
  end;
  function ArrowButton(UndoDirection: Boolean; X: Integer;
    Handler: TNotifyEvent): TBitBtn;
  begin
    Result := TPDFThemeBitBtn.Create(Self);
    Result.Parent := FEditBar;
    Result.SetBounds(X, 4, 36, 28);
    Result.Caption := '';
    Result.OnClick := Handler;
    Result.Layout := blGlyphTop;
    Result.Margin := 0;
    Result.Spacing := 0;
  end;
begin
  inherited Create(AOwner);
  Parent := AParent; // Vor dem Erzeugen von TPanel, TScrollBox und TEdit
  BevelOuter := bvNone;
  // Application-level ESC handling: the PDF image is not focusable.
  // TApplicationEvents preserves other application message subscribers.
  FSignatureKeyEvents := TApplicationEvents.Create(Self);
  FSignatureKeyEvents.OnMessage := SignatureApplicationMessage;
  FCore := TFreePDF64PDFiumCore.Create;
  FPage := 0;
  FMatchPage := -1;
  FMatchChar := -1;
  FMatchCount := 0;
  FTotalSearchMatches := 0;
  FSearchPage := 0;
  FSearchRunning := False;
  FSearchTimer := TTimer.Create(Self);
  FSearchTimer.Enabled := False;
  FSearchTimer.Interval := 15;
  FSearchTimer.OnTimer := SearchTimerTick;
  FZoom := 1.0;
  FFitMode := True;
  FViewMode := 1;
  FBar := TPanel.Create(Self);
  FBar.Parent := Self;
  FBar.Align := alTop;
  FBar.Height := 36;
  FEditVisible := False;
  FBar.BevelOuter := bvNone;
  FBar.DoubleBuffered := True;
  FEditBar := TPanel.Create(Self);
  FEditBar.Parent := Self;
  FEditBar.Align := alTop;
  FEditBar.Height := 0;
  FEditBar.BevelOuter := bvNone;
  FEditBar.DoubleBuffered := True;
  FEditBar.Visible := False;
  // Die Hauptleiste muss bei alTop oberhalb der Bearbeitungsleiste liegen.
  FBar.BringToFront;
  FEditToggle := TPDFToolsButton.Create(Self);
  FEditToggle.Parent := FBar;
  FEditToggle.SetBounds(8, 4, 34, 28);
  FEditToggle.OnClick := ToggleEditBar;
  FEditToggle.Name := 'PDFEditToggleButton';
  FEditToggle.Hint := ToolbarHint('Werkzeuge ein-/ausblenden – PDF bearbeiten, kommentieren, messen und markieren',
    'Show/hide tools – Edit, comment, measure and highlight PDFs');
  FEditToggle.ShowHint := True;
  FOutlineButton := Btn('☷', 8, 36, ToggleOutline);
  FOutlineButton.Hint := Tr('Seitenminiaturen / Inhaltsverzeichnis');
  FOutlineButton.ShowHint := True;
  FPrev := Btn('◀', 8, 44, Navigate);
  FPrev.Font.Name := 'Segoe UI Symbol';
  FPrev.Hint := Tr('Vorherige Seite');
  FPrev.ShowHint := True;
  FNext := Btn('▶', 84, 44, Navigate);
  FNext.Font.Name := 'Segoe UI Symbol';
  FNext.Hint := Tr('Nächste Seite');
  FNext.ShowHint := True;
  FNavigationSeparator := TBevel.Create(Self);
  FNavigationSeparator.Parent := FBar;
  FNavigationSeparator.Shape := bsLeftLine;
  FNavigationSeparator.SetBounds(0, 0, 2, 22);
  FZoomSeparator := TBevel.Create(Self);
  FZoomSeparator.Parent := FBar;
  FZoomSeparator.Shape := bsLeftLine;
  FZoomSeparator.SetBounds(0, 0, 2, 22);
  FMinus := Btn('+', 387, 34, ZoomClick);
  FPlus := Btn('−', 427, 34, ZoomClick);
  FZoom100Button := Btn('100 %', 460, 58, Zoom100Click);
  FZoom100Button.Hint := 'Originalgröße (100 %)';
  FZoom100Button.ShowHint := True;
  FMinus.Font.Name := 'Segoe UI Symbol';
  FPlus.Font.Name := 'Segoe UI Symbol';
  FMinus.Font.Size := 13;
  FPlus.Font.Size := 13;
  FMinus.Hint := ToolbarHint('Vergrößern', 'Zoom in');
  FPlus.Hint := ToolbarHint('Verkleinern', 'Zoom out');
  FMinus.ShowHint := True;
  FPlus.ShowHint := True;
  // Symbole passend zur Funktion: links Minus, rechts Plus.
  SetToolbarPngIcon(FMinus,
    'iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAABxUlEQVR42rXUP49NURQF8N97M3iG4lGIhMiICZmJAokg00w09D6ATyA6oqAbI0ZFJiHT0KoUVP4UEj6ARCEoiD+RGURDIjFPs25y3Lw770lYycm9Z+991l53371PSzNaxarQK9Zfo062WtzQzlahZjdOYgZb8BmPcQvP+8QPTLIRV3LgC57iIZ5gKfYFdIdV3g7pnRyexVQtbg/Ox/8Am3OuPUjtfA6dKHxrMY51he144m6sproyThRKhWhNVH/HkezXx38m8fuayKvPuIjlJCixKwQHa/ZteI9rNR4wWmSawUu8jrIJjBRfMokfiX2FD3iGo031HcnzBR7lfXttGOprMoJup1P6Kq7wFZ28LxU13YmbOBWFK3iTBBvSkn1RZbqMTyEqMR6SAzX7VrwtOqPdRDwVggvZd6J4L35iOvux+E8n/lATcdkqC/iFY4WvE/KxwjaNb1gcNH3V5HVxP0rOpgwldhRKe7hUNEBrUK03pW49fMS9/P27eBf7Yv5JL/0/8FYsHftxNTfZctrxOg4XMbO1aW0Po3zY27Ainx/mfKuoe79V+avhmgv5XFXz0QbiXu3ZhJUkOpfYrn+Ilv+MPy783zpsZv2zwr56AAAAAElFTkSuQmCC');
  SetToolbarPngIcon(FPlus,
    'iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAABqElEQVR42rXUz4tOYRQH8M+9cwfF4kUNpYREvStWlM1kw94f4E+wIwt2Y2SsaIpmZWdpwcqspswfoBRJIj/SDJItrs156vH03vdexbdO97nPOed7vp3nPE+lG1VmCW1mf42SbFrcYGeVqTmC85jHHD5jDffwbEJ8b5EduBkJX7COVTzBRuwvYzRUeR2kDyJ5AeMi7iiuhH8VuyKv7lO7FEnnMl+N2SL5bMTdnaY6bR7OlMKWsJnMZmMPLkb8sS7ypOQaNqPAEOzDe9wueECTVZrHS7wKZYfiW+InXuMDnuL0pKpNtt4dClrswfMpasfh/x6jOJX4K7bFegMns37m+IE3IWB7jOREpN7cwCccHNjjvXibTUbdRTwOFVfjf2sobmIimmIqLkT8iS7ifFSW43DOZL40ZjPZ3il8w0rf7Us3b4THoeQSDhRx+zOlLa5nxau+Xu+MvrX4iEe4j4d4F/srcSZtzH/vq5g7juNWvGSbeIE7MS0JC8VtrYcoH/oaJvKlIflV1vdJlvzpQBeDfDH1vOkgbotvF35FocsRO/IPUfnP+OPB/w2pnliON0l+3wAAAABJRU5ErkJggg==');
  FFit := Btn('', 467, 38, FitClick);
  FFit.Font.Name := 'Segoe UI Symbol';
  FFit.Font.Size := 12;
  FFit.Hint := Tr('Seite einpassen');
  FFit.ShowHint := True;
  SetToolbarPngIcon(FFit,
    'iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAB00lEQVR42rXVPWtUURAG4Gdvrhuj2IjYiD/ARkRU/CAKiYidpLBSf4FW6r9QbKyt/IBgYS8axcLGwqCFIHYigmIhEoNh98bmXTgek1XQHDjM3jkz78y8Z84sG7R6kdtwEFsLXbkaLGMVW9CtYbOKJbzAtzbKI7iPBbSV40Qc9ibAYhIYVoEHmMFZPBwdnMH8mMp24C3eYecYu/lgaYoyppLt5sg+NiWLR/iMj8lmNmf9ymcqWNqKo0F+D0LBEPtxGftythjd48Jm5LM6AmvXuajS4XrkbORCtthMFJVbD7jBSqXrJ5t+YdMWdsPspgYqg3SYTultAdaFgsWiYyZjcwXHo/+NgTncxi68juHfrmm8wu5gzJVUfMcBPMUnHMOpnL3B3aK6DuewJ99L+IonoeyOtUj/36um4sS/UtEUN7sdH3ARh0LTZHGBF3C+6JTR5R3GJbwPxrBut0ECPctWtFmTWQH3In9EXqvmxZp93AVoWDyQlUp2Va9PZK+s18cl+OhFSZ/O4Ev2THSKF9qNe3m9fLdF0AYvcSNt1YXrqxlCvcKvnO+/KJbD0aAKvoCTeJ5AR9PrqvsRjF4JvIzTeDBm0A8zvW7+YdDf2tC/pg17cT8BBJN+g07ca6EAAAAASUVORK5CYII=');
  FFitSeparator := TBevel.Create(Self);
  FFitSeparator.Parent := FBar;
  FFitSeparator.Shape := bsLeftLine;
  FPageModeSeparator := TBevel.Create(Self);
  FPageModeSeparator.Parent := FBar;
  FPageModeSeparator.Shape := bsLeftLine;
  FFlowSeparator := TBevel.Create(Self);
  FFlowSeparator.Parent := FBar;
  FFlowSeparator.Shape := bsLeftLine;
  FActionSeparator := TBevel.Create(Self);
  FActionSeparator.Parent := FBar;
  FActionSeparator.Shape := bsLeftLine;
  FViewSelect := TComboBox.Create(Self);
  FViewSelect.Parent := FBar;
  FViewSelect.Style := csDropDownList;
  FViewSelect.OnDrawItem := DrawViewModeItem;
  FViewSelect.SetBounds(597, 5, 116, 26);
  FViewSelect.ParentFont := False;
  FViewSelect.Font.Size := 8;
  FViewSelect.Items.Add(Tr('Seitenbreite'));
  FViewSelect.Items.Add(Tr('Ganze Seite'));
  FViewSelect.Items.Add(Tr('Originalgröße (100 %)'));
  FViewSelect.Items.Add(Tr('Benutzerdefiniert'));
  FViewSelect.ItemIndex := 1;
  FViewSelect.OnChange := ViewModeChange;
  FTwoPage := False;
  FTwoPageButton := Btn('', 770, 32, TwoPageClick);
  FTwoPageButton.Font.Name := 'Segoe UI Symbol';
  FTwoPageButton.Font.Size := 13;
  FTwoPageButton.Font.Style := [];
  FTwoPageButton.Hint := ToolbarHint('Einzelseitenansicht: zur Doppelseite wechseln',
    'Single-page view: switch to two-page view');
  FTwoPageButton.ShowHint := True;
  // Grafisches Symbol mit exakt mittiger Position statt fontabhaengigem
  // Unicode-Zeichen (dessen Seitenabstaende je nach Windows-Font variieren).
  FTwoPageIcon := TImage.Create(Self);
  FTwoPageIcon.Parent := FTwoPageButton;
  FTwoPageIcon.SetBounds(4, 2, 24, 24);
  FTwoPageIcon.Transparent := True;
  FTwoPageIcon.Enabled := False; // Mausklick bleibt beim eigentlichen Button.
  UpdateTwoPageIcon;
  FContinuous := True;
  FFlowSelect := TComboBox.Create(Self);
  FFlowSelect.Parent := FBar;
  FFlowSelect.Style := csDropDownList;
  FFlowSelect.Items.Add(Tr('Durchgehend'));
  FFlowSelect.Items.Add(Tr('Seitenweise'));
  FFlowSelect.ItemIndex := 0;
  FFlowSelect.Hint := Tr('Zwischen durchgehender und seitenweiser Anzeige wechseln');
  FFlowSelect.ShowHint := True;
  FFlowSelect.OnChange := FlowModeChange;
  // Die ComboBox bleibt als interne Modusverwaltung erhalten, ist aber
  // nicht mehr Teil der sichtbaren Symbolleiste.
  FFlowSelect.Visible := False;
  FFlowToggleButton := Btn('☷', 860, 32, FlowToggleClick);
  FFlowToggleButton.Font.Name := 'Segoe UI Symbol';
  FFlowToggleButton.Font.Size := 13;
  FFlowToggleButton.Font.Style := [];
  FFlowToggleButton.Hint := ToolbarHint('Durchgehend: zu seitenweiser Anzeige wechseln', 'Continuous view: switch to page-by-page view');
  FFlowToggleButton.ShowHint := True;
  FPrint := Btn('🖨', 1025, 40, PrintClick);
  FPrint.Font.Name := 'Segoe UI Emoji';
  FPrint.Font.Size := 12;
  FPrint.Hint := Tr('Drucken') + ' (Strg+P)';
  FPrint.ShowHint := True;
  FInfo := Btn('ⓘ', 1120, 34, InfoClick);
  FInfo.Hint := Tr('Dokumenteigenschaften anzeigen') + ' (Strg+D)';
  FInfo.ShowHint := True;
  FInfo.Font.Name := 'Segoe UI Symbol';
  FInfo.Font.Size := 12;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := FBar;
  FStatus.AutoSize := False;
  FStatus.SetBounds(160, 11, 42, 18);
  FStatus.Caption := ToolbarHint('Seite:', 'Page:');
  FPageTotal := TLabel.Create(Self);
  FPageTotal.Parent := FBar;
  FPageTotal.AutoSize := False;
  FPageTotal.SetBounds(214, 11, 42, 18);
  FPageTotal.Caption := '/ 0';
  FZoomStatus := TLabel.Create(Self);
  FZoomStatus.Parent := FBar;
  FZoomStatus.AutoSize := False;
  FZoomStatus.SetBounds(460, 11, 55, 18);
  FZoomStatus.Caption := Format('%d%%', [Round(FZoom * 7200 / CurrentPPI)]);
  FMarker := Btn('Markieren: AUS', 766, 116, MarkerClick);
  FMarker.Hint := Tr('Markierungsmodus ein- oder ausschalten');
  FMarker.ShowHint := True;
  FRedactionPreviews := TObjectList<TPDFInkStroke>.Create(True);
  FRedactionPreviewPages := TList<Integer>.Create;
  FRedactionRedo := TObjectList<TPDFInkStroke>.Create(True);
  FRedactionRedoPages := TList<Integer>.Create;
  FShapeSelect := TComboBox.Create(Self);
  FShapeSelect.Parent := FBar;
  FShapeSelect.Style := csDropDownList;
  FShapeSelect.SetBounds(866, 5, 165, 26);
  FShapeSelect.Items.Add(Tr('Freihand'));             // 0
  FShapeSelect.Items.Add(Tr('Linie'));                // 1
  FShapeSelect.Items.Add(Tr('Rechteck'));             // 2
  FShapeSelect.Items.Add(Tr('Ellipse'));              // 3
  FShapeSelect.Items.Add('──────────────');           // 4: Trennlinie
  FShapeSelect.Items.Add(Tr('Schwärzen (optisch)'));  // 5
  if PDFLanguage = 'en' then
    FShapeSelect.Items.Add('Redaction preview')       // 6
  else
    FShapeSelect.Items.Add('Schwärzung (Vorschau)');
  FShapeSelect.Items.Add('──────────────');           // 7: Trennlinie
  if PDFLanguage = 'en' then
    FShapeSelect.Items.Add('Hand Tool')               // 8
  else
    FShapeSelect.Items.Add('Hand-Werkzeug');
  FShapeSelect.OnChange := ShapeSelectChange;
  FShapeSelect.ItemIndex := 0;
  // Der Hint wird passend zum gewählten Werkzeug gesetzt.
  ShapeSelectChange(FShapeSelect);
  FShapeSelect.ShowHint := True;
  FWidthSelect := TComboBox.Create(Self);
  FWidthSelect.Parent := FBar;
  FWidthSelect.Style := csDropDownList;
  FWidthSelect.SetBounds(982, 5, 54, 26);
  FWidthSelect.Items.Add('1 pt');
  FWidthSelect.Items.Add('2 pt');
  FWidthSelect.Items.Add('3 pt');
  FWidthSelect.Items.Add('5 pt');
  FWidthSelect.Items.Add('8 pt');
  FWidthSelect.Items.Add('12 pt');
  FWidthSelect.ItemIndex := 3;
  FWidthSelect.Hint := Tr('Strichstärke der neuen Markierungen');
  FWidthSelect.ShowHint := True;
  FMarkColor := RGB(255, 235, 0);
  FTextInsertColor := clBlack;
  FTextInsertSize := 12;
  FHighlightButton := Btn(ToolbarHint('Text hervorheben', 'Highlight text'), 1179, 125, HighlightClick);
  FHighlightButton.Parent := FEditBar;
  FHighlightButton.Hint := ToolbarHint('Über Text ziehen; Umschalt+Ziehen: Rechteck; Pfeile: Rückgängig/Wiederholen', 'Drag over text; Shift+drag: rectangle; arrows: undo/redo');
  FHighlightButton.ShowHint := True;
  FTextInsertSeparator := TBevel.Create(Self);
  FTextInsertSeparator.Parent := FEditBar;
  FTextInsertSeparator.Shape := bsLeftLine;
  FTextInsertButton := Btn(Tr('Text einfügen'), 1180, 116, TextInsertClick);
  FTextInsertButton.Parent := FEditBar;
  FMeasureRects := TList<TPDFMeasureRect>.Create;
  FMeasureRedo := TList<TPDFMeasureAction>.Create;
  FMeasureUndo := TList<TPDFMeasureAction>.Create;
  FMeasureDirty := False;
  FSaveSuccessSerial := 0;
  FStrokeRedo := TList<TPDFInkStroke>.Create;
  FStrokeRedoPages := TList<Integer>.Create;
  FMeasureScale := 25.4 / 72.0;
  FMeasureUnit := 0;
  FMeasurePage := -1;
  FMeasureButton := Btn(ToolbarHint('Messen', 'Measure') + ' ' + #$25BE,
    1180, 94, MeasureDropdownClick);
  FMeasureButton.Parent := FEditBar;
  FMeasureButton.Hint := ToolbarHint('Messfunktion oder Messbericht auswählen',
    'Choose measurement tool or measurement report');
  FMeasureButton.ShowHint := True;
  FMeasurePopup := TPopupMenu.Create(Self);
  FMeasurePopup.OwnerDraw := True;
  FMeasureMenuItem := TMenuItem.Create(FMeasurePopup);
  FMeasureMenuItem.Caption := ToolbarHint('Messen', 'Measure');
  FMeasureMenuItem.OnClick := MeasureClick;
  FMeasureMenuItem.OnDrawItem := PopupDrawItem;
  FMeasureMenuItem.OnMeasureItem := PopupMeasureItem;
  FMeasurePopup.Items.Add(FMeasureMenuItem);
  FMeasureScaleMenuItem := TMenuItem.Create(FMeasurePopup);
  FMeasureScaleMenuItem.Caption := ToolbarHint('Maßstab ...', 'Scale ...');
  FMeasureScaleMenuItem.OnClick := MeasureScaleClick;
  FMeasureScaleMenuItem.OnDrawItem := PopupDrawItem;
  FMeasureScaleMenuItem.OnMeasureItem := PopupMeasureItem;
  FMeasurePopup.Items.Add(FMeasureScaleMenuItem);
  FMeasurePopup.Items.Add(TMenuItem.Create(FMeasurePopup));
  with FMeasurePopup.Items[FMeasurePopup.Items.Count - 1] do
  begin
    Caption := ToolbarHint('Messbericht ...', 'Measurement report ...');
    OnClick := ShowMeasureReport;
    OnDrawItem := PopupDrawItem;
    OnMeasureItem := PopupMeasureItem;
  end;
  FMeasureUnitSelect := TComboBox.Create(Self);
  FMeasureUnitSelect.Parent := FEditBar;
  FMeasureUnitSelect.Style := csDropDownList;
  FMeasureUnitSelect.Items.Add('mm');
  FMeasureUnitSelect.Items.Add('cm');
  FMeasureUnitSelect.Items.Add('in');
  FMeasureUnitSelect.ItemIndex := 0;
  FMeasureUnitSelect.OnChange := MeasureUnitChange;
  FMeasureScaleButton := Btn(ToolbarHint('Maßstab ...', 'Scale ...'), 1180, 90, MeasureScaleClick);
  FMeasureScaleButton.Parent := FEditBar;
  FMeasureScaleButton.Hint := ToolbarHint('Maßstab eingeben, z. B. 1:50',
    'Enter drawing scale, e.g. 1:50');
  FMeasureScaleButton.ShowHint := True;
  // Die Aktion bleibt bestehen; der Befehl liegt jetzt im Messen-Dropdown.
  FMeasureScaleButton.Visible := False;
  FNoteButton := Btn(ToolbarHint('Kommentar', 'Comment'), 1180, 94, NoteButtonClick);
  FNoteButton.Parent := FEditBar;
  FNoteButton.Hint := ToolbarHint('Textkommentar einfügen', 'Insert text comment');
  FNoteButton.ShowHint := True;
  // Kompaktes Dropdown fuer Text und Kommentare. Die bisherigen Buttons
  // bleiben als interne Aktionsziele bestehen, werden aber nicht angeordnet.
  FInsertButton := Btn(ToolbarHint('Einfügen', 'Insert') + ' ' + #$25BE,
    1180, 94, InsertDropdownClick);
  FInsertButton.Parent := FEditBar;
  FInsertButton.Hint := ToolbarHint('Text oder Kommentar einfügen',
    'Insert text or comment');
  FInsertButton.ShowHint := True;
  FInsertPopup := TPopupMenu.Create(Self);
  FInsertPopup.OwnerDraw := True;
  FInsertTextItem := TMenuItem.Create(FInsertPopup);
  FInsertTextItem.Caption := ToolbarHint('Text einfügen', 'Insert text');
  FInsertTextItem.OnClick := InsertTextMenuClick;
  FInsertTextItem.OnDrawItem := PopupDrawItem;
  FInsertTextItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertTextItem);
  FInsertNoteItem := TMenuItem.Create(FInsertPopup);
  FInsertNoteItem.Caption := ToolbarHint('Kommentar hinzufügen', 'Add comment');
  FInsertNoteItem.OnClick := InsertNoteMenuClick;
  FInsertNoteItem.OnDrawItem := PopupDrawItem;
  FInsertNoteItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertNoteItem);
  // Trennlinie nach Kommentar: weitere Einfuegefunktionen.
  FInsertPopup.Items.Add(TMenuItem.Create(FInsertPopup));
  FInsertPopup.Items[FInsertPopup.Items.Count - 1].Caption := '-';
  FInsertLinkItem := TMenuItem.Create(FInsertPopup);
  FInsertLinkItem.Caption := ToolbarHint('Hyperlink hinzufügen ...', 'Add hyperlink ...');
  FInsertLinkItem.OnClick := LinkMenuClick;
  FInsertLinkItem.OnDrawItem := PopupDrawItem;
  FInsertLinkItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertLinkItem);
  FInsertSignatureItem := TMenuItem.Create(FInsertPopup);
  FInsertSignatureItem.Caption := ToolbarHint('Unterschrift hinzufügen ...', 'Add signature ...');
  FInsertSignatureItem.OnClick := SignatureClick;
  FInsertSignatureItem.OnDrawItem := PopupDrawItem;
  FInsertSignatureItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertSignatureItem);
  FInsertImageWatermarkItem := TMenuItem.Create(FInsertPopup);
  FInsertImageWatermarkItem.Caption := ToolbarHint('Bildwasserzeichen hinzufügen ...', 'Add image watermark ...');
  FInsertImageWatermarkItem.OnClick := ImageWatermarkClick;
  FInsertImageWatermarkItem.OnDrawItem := PopupDrawItem;
  FInsertImageWatermarkItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertImageWatermarkItem);
  FInsertTextWatermarkItem := TMenuItem.Create(FInsertPopup);
  FInsertTextWatermarkItem.Caption := ToolbarHint('Textwasserzeichen hinzufügen ...', 'Add text watermark ...');
  FInsertTextWatermarkItem.OnClick := TextWatermarkClick;
  FInsertTextWatermarkItem.OnDrawItem := PopupDrawItem;
  FInsertTextWatermarkItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertTextWatermarkItem);
  // Verwaltungsfunktionen als eigene Gruppe am Ende von Einfügen.
  FInsertPopup.Items.Add(TMenuItem.Create(FInsertPopup));
  FInsertPopup.Items[FInsertPopup.Items.Count - 1].Caption := '-';
  FInsertManageLinksItem := TMenuItem.Create(FInsertPopup);
  FInsertManageLinksItem.Caption := ToolbarHint('Hyperlinks verwalten ...', 'Manage hyperlinks ...');
  FInsertManageLinksItem.OnClick := ManageLinksClick;
  FInsertManageLinksItem.OnDrawItem := PopupDrawItem;
  FInsertManageLinksItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertManageLinksItem);
  FInsertManageCommentsItem := TMenuItem.Create(FInsertPopup);
  FInsertManageCommentsItem.Caption := ToolbarHint('Kommentare verwalten ...', 'Manage comments ...');
  FInsertManageCommentsItem.OnClick := ShowCommentOverviewMenuClick;
  FInsertManageCommentsItem.OnDrawItem := PopupDrawItem;
  FInsertManageCommentsItem.OnMeasureItem := PopupMeasureItem;
  FInsertPopup.Items.Add(FInsertManageCommentsItem);
  FTextInsertButton.Visible := False;
  FNoteButton.Visible := False;
  FTextInsertButton.Hint := Tr('Textwerkzeug: Auf eine PDF-Seite klicken');
  FTextInsertButton.ShowHint := True;
  FTextUndoButton := ArrowButton(True, 1181, TextUndoClick);
  FTextRedoButton := ArrowButton(False, 1182, TextRedoClick);
  FUndoRedoGlyphPPI := 0;
  UpdateUndoRedoGlyphs;
  FTextUndoButton.Hint := ToolbarHint('Rückgängig', 'Undo');
  FTextRedoButton.Hint := ToolbarHint('Wiederholen', 'Redo');
  FTextUndoButton.ShowHint := True;
  FTextRedoButton.ShowHint := True;
  FRedactionFinalizeButton := TPDFDesignButton.Create(Self);
  FRedactionFinalizeButton.Parent := FBar;
  FRedactionFinalizeButton.Visible := True;
  FRedactionFinalizeButton.Caption := ToolbarHint('Endgültig schwärzen ...', 'Apply secure redaction ...');
  FRedactionFinalizeButton.OnClick := FinalizeRedactionClick;
  FRedactionFinalizeButton.Enabled := False;
  FRedactionFinalizeButton.Hint := ToolbarHint(
    'Erstellt eine neue PDF-Datei und entfernt den Inhalt der vorgemerkten Seiten durch vollständige Rasterisierung.',
    'Creates a new PDF and removes the content of marked pages by fully rasterizing them.');
  FRedactionFinalizeButton.ShowHint := True;
  FRedactionFinalizeButton.SetAccentOrange(
    (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6));
  FTextFontSelect := TComboBox.Create(Self);
  FTextFontSelect.Parent := FEditBar;
  FTextFontSelect.Style := csDropDownList;
  // Windows-Schriftarten statt einer fest kodierten Dreierliste.
  FTextFontSelect.Items.Assign(Screen.Fonts);
  FTextFontSelect.Sorted := True;
  FTextFontSelect.ItemIndex := FTextFontSelect.Items.IndexOf('Arial');
  if (FTextFontSelect.ItemIndex < 0) and (FTextFontSelect.Items.Count > 0) then
    FTextFontSelect.ItemIndex := 0;
  FTextFontSelect.Hint := ToolbarHint('Schriftart für eingefügten Text', 'Font for inserted text');
  FTextFontSelect.ShowHint := True;
  FTextFontSelect.OnChange := TextStyleChange;
  FTextSizeSelect := TComboBox.Create(Self);
  FTextSizeSelect.Parent := FEditBar;
  FTextSizeSelect.Style := csDropDown;
  FTextSizeSelect.Items.CommaText := '8,10,12,14,16,18,20,24,28,32,36,48,72';
  FTextSizeSelect.Text := '12';
  FTextSizeSelect.Hint := ToolbarHint('Schriftgröße in Punkt (1–200)', 'Font size in points (1–200)');
  FTextSizeSelect.ShowHint := True;
  FTextSizeSelect.OnChange := TextStyleChange;
  FTextColorButton := TPDFDesignButton.Create(Self);
  FTextColorButton.Parent := FEditBar;
  FTextColorButton.Caption := ToolbarHint('Textfarbe ...', 'Text color ...');
  FTextColorButton.OnClick := TextColorClick;
  FTextColorSwatch := TPanel.Create(Self);
  FTextColorSwatch.Parent := FEditBar;
  FTextColorSwatch.BevelOuter := bvLowered;
  FTextColorSwatch.ParentBackground := False;
  FTextColorSwatch.Color := FTextInsertColor;
  FTextColorSwatch.Caption := '';

  FColorButton := Btn(Tr('Farbe ...'), 1072, 60, ColorClick);
  FColorSwatch := TPanel.Create(Self);
  FColorSwatch.Parent := FBar;
  FColorSwatch.BevelOuter := bvLowered;
  FColorSwatch.Color := FMarkColor;
  FColorSwatch.Caption := '';
  FColorSwatch.ParentBackground := False;
  FColorSwatch.SetBounds(FColorButton.Left + FColorButton.Width + 5, 8, 22, 20);
  FColorSwatch.Cursor := crHandPoint;
  FColorSwatch.OnClick := ColorClick;
  FColorButton.Hint := Tr('Farbe der neuen Markierungen auswählen');
  FColorButton.ShowHint := True;
  FQuickSave := TPDFiumSaveButton.Create(Self);
  FQuickSave.Parent := FBar;
  FQuickSave.SetBounds(900, 4, 34, 28);
  FQuickSave.OnClick := SaveDropdownClick;
  FSavePopup := TPopupMenu.Create(Self);
  FSavePopup.OwnerDraw := True;
  FSavePopup.Items.Add(TMenuItem.Create(FSavePopup));
  FSavePopup.Items[0].Caption := ToolbarHint('PDF speichern unter ...', 'Save PDF As ...');
  FSavePopup.Items[0].OnClick := SaveClick;
  FSavePopup.Items[0].OnDrawItem := PopupDrawItem;
  FSavePopup.Items[0].OnMeasureItem := PopupMeasureItem;
  FSavePopup.Items.Add(TMenuItem.Create(FSavePopup));
  FSavePopup.Items[1].Caption := ToolbarHint('Seiten als Bilder exportieren ...', 'Export Pages as Images ...');
  FSavePopup.Items[1].OnClick := ExportPagesAsImages;
  FSavePopup.Items[1].OnDrawItem := PopupDrawItem;
  FSavePopup.Items[1].OnMeasureItem := PopupMeasureItem;
  FQuickSave.Hint := ToolbarHint('Speichern unter ... (Strg+S)', 'Save As ... (Ctrl+S)');
  FQuickSave.ShowHint := True;
  FMarker.Visible := False; // Bearbeiten schaltet den Markierungsmodus direkt.
  FShapeSelect.Parent := FEditBar;
  FWidthSelect.Parent := FEditBar;
  FColorButton.Parent := FEditBar;
  FColorSwatch.Parent := FEditBar;
  FPageEdit := TEdit.Create(Self);
  FPageEdit.Parent := FBar;
  FPageEdit.SetBounds(163, 6, MulDiv(32, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
  FPageEdit.AutoSize := False;
  FPageEdit.Alignment := taCenter;
  FPageEdit.Text := '1';
  FPageEdit.OnKeyDown := PageKeyDown;
  FPageEdit.TabStop := True;
  FGoPage := Btn('Gehe zu', 217, 74, GoToPage);
  FGoPage.Visible := False; // Eingabe mit Enter statt separatem Button
  // Die Textsuche befindet sich bereits in der oberen Viewer-Leiste.
  FFind := nil;
  FPages := TList.Create;
  FRenderTimer := TTimer.Create(Self);
  // Kurzer Timer fuer inkrementelles Rendering statt mehrerer
  // synchroner PDFium-Renderaufrufe innerhalb eines Scrollereignisses.
  FRenderTimer.Interval := 20;
  FPageCacheLimit := 8;
  FScrollRenderPending := False;
  FDraggingPage := False;
  FLastScrollTick := 0;
  FRenderTimer.OnTimer := RenderTimerTick;
  FRenderTimer.Enabled := True;
  FOutlineItems := TObjectList<TPDFBookmarkItem>.Create(True);
  FOutlinePanel := TPanel.Create(Self);
  FOutlinePanel.Parent := Self;
  FOutlinePanel.Align := alLeft;
  FOutlinePanel.Width := 210;
  FOutlinePanel.Constraints.MinWidth := 185;
  FOutlinePanel.Constraints.MaxWidth := 700;
  FOutlinePanel.Caption := '';
  FOutlinePanel.Visible := False;
  FOutlineSplitter := TSplitter.Create(Self);
  FOutlineSplitter.Parent := Self;
  FOutlineSplitter.Align := alLeft;
  FOutlineSplitter.Width := 9;
  FOutlineSplitter.Color := clSilver;
  FOutlineSplitter.Beveled := True;
  FOutlineSplitter.MinSize := 185;
  // Die Seitenleiste waehrend des Ziehens live vergroessern/verkleinern.
  // Die Miniatur-Layouts werden separat zeitlich gebuendelt aktualisiert.
  FOutlineSplitter.ResizeStyle := rsUpdate;
  FOutlineSplitter.Cursor := crHSplit;
  FOutlineSplitter.Visible := False;
  FOutlineHeader := TPanel.Create(Self);
  FOutlineHeader.Parent := FOutlinePanel;
  FOutlineHeader.Align := alTop;
  FOutlineHeader.Height := 74;
  FOutlineHeader.BevelOuter := bvNone;
  FOutlineHeader.OnResize := OutlineHeaderResize;
  FOutlineTitle := TLabel.Create(Self);
  FOutlineTitle.Parent := FOutlineHeader;
  FOutlineTitle.Caption := '';
  FOutlineTitle.Visible := False; // Die Tabs benennen die Inhalte bereits.
  FOutlineTitle.SetBounds(12, 8, 200, 22);
  FOutlineTitle.Font.Style := [fsBold];
  FOutlineClose := TPDFDesignButton.Create(Self);
  FOutlineClose.Parent := FOutlineHeader;
  FOutlineClose.Caption := 'X';
  FOutlineClose.SetBounds(170, 5, 28, 25);
  FOutlineClose.Anchors := [akTop, akRight];
  FOutlineClose.OnClick := ToggleOutline;
  FThumbTab := TPDFDesignButton.Create(Self);
  FThumbTab.Parent := FOutlineHeader;
  FThumbTab.Caption := Tr('Seiten');
  FThumbTab.Tag := 1;
  FThumbTab.SetBounds(8, 40, 91, 28);
  FThumbTab.OnClick := OutlineTabClick;
  FBookmarksTab := TPDFDesignButton.Create(Self);
  FBookmarksTab.Parent := FOutlineHeader;
  FBookmarksTab.Caption := Tr('Inhalte');
  FBookmarksTab.Tag := 0;
  FBookmarksTab.SetBounds(105, 40, 91, 28);
  FBookmarksTab.OnClick := OutlineTabClick;
  OutlineHeaderResize(nil);
  FOutlineTree := TPDFiumOutlineTree.Create(Self);
  FOutlineTree.Parent := FOutlinePanel;
  FOutlineTree.Align := alClient;
  FOutlineTree.ReadOnly := True;
  FOutlineTree.HideSelection := False;
  FOutlineTree.OnChange := OutlineChange;
  FOutlineMenu := TPopupMenu.Create(Self);
  FOutlineMenu.OnPopup := OutlineMenuPopup;
  FOutlineExpandItem := TMenuItem.Create(FOutlineMenu);
  FOutlineExpandItem.OnClick := OutlineExpandAll;
  FOutlineMenu.Items.Add(FOutlineExpandItem);
  FOutlineCollapseItem := TMenuItem.Create(FOutlineMenu);
  FOutlineCollapseItem.OnClick := OutlineCollapseAll;
  FOutlineMenu.Items.Add(FOutlineCollapseItem);
  FOutlineTree.PopupMenu := FOutlineMenu;
  OutlineMenuPopup(nil);
  FOutlineTree.OnMouseWheel := OutlineMouseWheel;
  FThumbScroll := TPDFiumScrollBox.Create(Self);
  FThumbScroll.Parent := FOutlinePanel;
  FThumbScroll.Align := alClient;
  FThumbScroll.VertScrollBar.Tracking := True;
  FThumbScroll.Color := clWhite;
  FThumbScroll.TabStop := True;
  FThumbScroll.OnKeyDown := PageKeyDown;
  FThumbScroll.OnResize := ThumbAreaResize;
  FThumbScroll.OnMouseWheel := OutlineMouseWheel;
  FThumbScroll.OnMouseMove := ThumbMouseMove;
  FThumbScroll.OnMouseUp := ThumbMouseUp;
  FThumbImages := TList.Create;
  FThumbSelected := TList<Integer>.Create;
  FThumbAnchor := -1;
  FThumbDragSource := -1;
  FThumbDragging := False;
  FThumbSuppressClick := False;
  FThumbMenu := TPopupMenu.Create(Self);
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  with FThumbMenu.Items[FThumbMenu.Items.Count - 1] do
  begin
    Caption := Tr('Ausgewählte Seite(n) löschen');
    OnClick := DeleteSelectedThumbs;
  end;
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  with FThumbMenu.Items[FThumbMenu.Items.Count - 1] do
  begin
    Caption := ToolbarHint('Ausgewählte Seite(n) 90° nach rechts drehen', 'Rotate selected page(s) 90° right');
    Tag := 90;
    OnClick := RotateSelectedThumbs;
  end;
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  with FThumbMenu.Items[FThumbMenu.Items.Count - 1] do
  begin
    Caption := ToolbarHint('Ausgewählte Seite(n) 90° nach links drehen', 'Rotate selected page(s) 90° left');
    Tag := -90;
    OnClick := RotateSelectedThumbs;
  end;
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FMoveUpItem := TMenuItem.Create(FThumbMenu);
  FMoveUpItem.Caption := Tr('↑ Seite nach oben');
  FMoveUpItem.Tag := -1;
  FMoveUpItem.OnClick := MoveSelectedThumb;
  FThumbMenu.Items.Add(FMoveUpItem);
  FMoveDownItem := TMenuItem.Create(FThumbMenu);
  FMoveDownItem.Caption := Tr('↓ Seite nach unten');
  FMoveDownItem.Tag := 1;
  FMoveDownItem.OnClick := MoveSelectedThumb;
  FThumbMenu.Items.Add(FMoveDownItem);
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FExtractItem := TMenuItem.Create(FThumbMenu);
  FExtractItem.Caption := Tr('Seite(n) extrahieren ...');
  FExtractItem.OnClick := ExtractSelectedThumbs;
  FThumbMenu.Items.Add(FExtractItem);
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FInsertBeforeItem := TMenuItem.Create(FThumbMenu);
  FInsertBeforeItem.OnClick := InsertPDFAtThumbnail;
  FInsertBeforeItem.Tag := 0;
  FThumbMenu.Items.Add(FInsertBeforeItem);
  FInsertAfterItem := TMenuItem.Create(FThumbMenu);
  FInsertAfterItem.OnClick := InsertPDFAtThumbnail;
  FInsertAfterItem.Tag := 1;
  FThumbMenu.Items.Add(FInsertAfterItem);
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FLinkMenuItem := TMenuItem.Create(FThumbMenu);
  FLinkMenuItem.Caption := ToolbarHint('Hyperlink hinzufügen ...', 'Add hyperlink ...');
  FLinkMenuItem.OnClick := LinkMenuClick;
  FThumbMenu.Items.Add(FLinkMenuItem);
  FSignatureMenuItem := TMenuItem.Create(FThumbMenu);
  FSignatureMenuItem.Caption := ToolbarHint('Unterschrift hinzufügen ...', 'Add signature ...');
  FSignatureMenuItem.OnClick := SignatureClick;
  FThumbMenu.Items.Add(FSignatureMenuItem);
  FImageWatermarkMenuItem := TMenuItem.Create(FThumbMenu);
  FImageWatermarkMenuItem.Caption := Tr('Bildwasserzeichen hinzufügen ...');
  FImageWatermarkMenuItem.OnClick := ImageWatermarkClick;
  FThumbMenu.Items.Add(FImageWatermarkMenuItem);
  FWatermarkMenuItem := TMenuItem.Create(FThumbMenu);
  FWatermarkMenuItem.Caption := Tr('Textwasserzeichen hinzufügen ...');
  FWatermarkMenuItem.OnClick := TextWatermarkClick;
  FThumbMenu.Items.Add(FWatermarkMenuItem);
  // Verwaltungsfunktionen als eigener Abschnitt nach den Wasserzeichen.
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FManageLinksMenuItem := TMenuItem.Create(FThumbMenu);
  FManageLinksMenuItem.Caption := ToolbarHint('Hyperlinks verwalten ...', 'Manage hyperlinks ...');
  FManageLinksMenuItem.OnClick := ManageLinksClick;
  FThumbMenu.Items.Add(FManageLinksMenuItem);
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  with FThumbMenu.Items[FThumbMenu.Items.Count - 1] do
  begin
    Caption := ToolbarHint('Kommentare verwalten ...', 'Manage comments ...');
    OnClick := ShowCommentOverviewMenuClick;
  end;

  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  // 3b.57: Vollstaendigen Pflichtfeldbericht auch ohne Speichern aufrufen.
  FRequiredFieldsMenuItem := TMenuItem.Create(FThumbMenu);
  FRequiredFieldsMenuItem.Caption := Tr('Pflichtfelder prüfen ...') + ' (F7)';
  FRequiredFieldsMenuItem.OnClick := RequiredFieldsReportClick;
  FThumbMenu.Items.Add(FRequiredFieldsMenuItem);
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FReloadMenuItem := TMenuItem.Create(FThumbMenu);
  FReloadMenuItem.Caption := Tr('Änderungen zurücksetzen (letzter Speicherstand)') + ' (Ctrl+Shift+R)';
  FReloadMenuItem.OnClick := ReloadPDFClick;
  FThumbMenu.Items.Add(FReloadMenuItem);
  FThumbMenu.Items.Add(TMenuItem.Create(FThumbMenu));
  FThumbMenu.Items[FThumbMenu.Items.Count - 1].Caption := '-';
  FThumbMenu.OnPopup := ThumbMenuPopup;
  FPageContextMenu := TPopupMenu.Create(Self);
  FPageContextMenu.AutoPopup := False;
  FThumbTimer := TTimer.Create(Self);
  FThumbTimer.Enabled := False;
  FThumbTimer.Interval := 35;
  FThumbTimer.OnTimer := ThumbTimerTick;
  // Maximal ca. 28 Layout-Aktualisierungen pro Sekunde waehrend des Ziehens.
  // Bereits gerenderte Miniatur-Bitmaps werden dabei nur skaliert, nicht
  // erneut aus PDFium gerendert.
  FThumbResizeTimer := TTimer.Create(Self);
  FThumbResizeTimer.Enabled := False;
  FThumbResizeTimer.Interval := 35;
  FThumbResizeTimer.OnTimer := ThumbResizeTimerTick;
  FThumbResizePending := False;
  FThumbLastOutlineWidth := -1;
  FThumbLastClientWidth := -1;
  FThumbResizeInProgress := False;
  FThumbDeleteRebuildPending := False;
  ShowOutlineTab(True);
  FScroll := TPDFiumScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.Color := clBtnShadow;
  // Gepufferte Darstellung vermeidet sichtbares Hintergrund-Aufblitzen
  // beim interaktiven Vergroessern und Verkleinern des Viewer-Fensters.
  FScroll.ParentDoubleBuffered := False;
  FScroll.DoubleBuffered := True;
  FScroll.OnResize := ResizeView;
  FScroll.TabStop := True;
  FScroll.OnMouseWheel := ScrollMouseWheel;
  FScroll.OnKeyDown := PageKeyDown;
  FImage := TPDFiumImage.Create(Self);
  FImage.AfterPaint := PageImagePainted;
  FImage.Parent := FScroll;
  FImage.AutoSize := False;
  FImage.Stretch := False;
  FImage.Proportional := False;
  FImage.OnMouseDown := ImageMouseDown;
  FImage.OnDblClick := ImageDblClick;
  FImage.OnMouseMove := ImageMouseMove;
  FImage.OnMouseUp := ImageMouseUp;
  FImage.OnMouseWheel := ScrollMouseWheel;
  FImage.Tag := 0;
  FPages.Add(FImage);
  FBar.OnResize := LayoutToolbar;
  FEditBar.OnResize := LayoutToolbar;
  LayoutToolbar(nil);
  // Apply the persisted language after every toolbar control has been created.
  // The main form's startup refresh can run before this viewer exists.
  RefreshLanguage;
  UpdateTextUndoButtons;
  LoadGlobalThumbnails;
  if GThumbnailViews = nil then
    GThumbnailViews := TList<TFreePDF64PDFiumView>.Create;
  GThumbnailViews.Add(Self);
  SetPageThumbnailsVisible(GThumbnailsVisible and not GThumbnailSplitMode);
end;

destructor TFreePDF64PDFiumView.Destroy;
begin
  CancelSignature;
  if FThumbDeleteRebuildPending and (FThumbScroll <> nil) and
     FThumbScroll.HandleAllocated then
    SendMessage(FThumbScroll.Handle, WM_SETREDRAW, 1, 0);
  if GThumbnailViews <> nil then GThumbnailViews.Remove(Self);
  if FTextEditor <> nil then
  begin
    FTextEditor.OnKeyDown := nil;
    FreeAndNil(FTextEditor);
  end;
  EndThumbDragVisual;
  if (FThumbScroll <> nil) and (GetCapture = FThumbScroll.Handle) then ReleaseCapture;
  if Assigned(FInfoDialog) then
  begin
    FInfoDialog.OnDestroy := nil;
    FreeAndNil(FInfoDialog);
  end;
  if Assigned(FSearchTimer) then FSearchTimer.Enabled := False;
  if Assigned(FRenderTimer) then FRenderTimer.Enabled := False;
  FreeAndNil(FFormFocusFrame);
  FPreviewBitmap.Free;
  FCurrentStroke.Free;
  FRedactionRedo.Free;
  FRedactionRedoPages.Free;
  FRedactionPreviews.Free;
  FRedactionPreviewPages.Free;
  ClearStrokeRedo;
  FStrokeRedo.Free;
  FStrokeRedoPages.Free;
  FMeasureRedo.Free;
  FMeasureUndo.Free;
  FMeasureRects.Free;
  FPages.Free;
  if Assigned(FThumbTimer) then FThumbTimer.Enabled := False;
  if Assigned(FThumbResizeTimer) then FThumbResizeTimer.Enabled := False;
  FThumbSelected.Free;
  FThumbImages.Free;
  FOutlineItems.Free;
  FCore.Free;
  inherited;
end;

procedure TFreePDF64PDFiumView.RotatePages(AFirstPage, ALastPage,
  AAngle: Integer);
var
  I: Integer;
  OldPage: Integer;
begin
  // Drehen erfolgt ausschliesslich im PDFium-Dokument im Speicher.
  // Weder temporaere PDFs noch QPDF oder ein erneutes Oeffnen sind noetig.
  if (AFirstPage < 1) or (ALastPage > FCore.PageCount) or
     (AFirstPage > ALastPage) or
     ((AAngle <> 90) and (AAngle <> -90) and
      (AAngle <> 180) and (AAngle <> 270)) then
    raise EPDFiumViewer.Create('Ungueltiger Seitenbereich oder Drehwinkel.');
  OldPage := FPage;
  FRenderTimer.Enabled := False;
  FThumbTimer.Enabled := False;
  try
    // PDFium akzeptiert im aktuellen In-Memory-Pfad +/-90 Grad.
    // 180/270 Grad werden in 90-Grad-Schritten ausgefuehrt.
    if AAngle = 180 then
    begin
      FCore.RotateInMemory(AFirstPage, ALastPage, 90);
      FCore.RotateInMemory(AFirstPage, ALastPage, 90);
    end
    else if AAngle = 270 then
      FCore.RotateInMemory(AFirstPage, ALastPage, -90)
    else
      FCore.RotateInMemory(AFirstPage, ALastPage, AAngle);
    for I := AFirstPage - 1 to ALastPage - 1 do
    begin
      if I < Length(FPageSizesValid) then FPageSizesValid[I] := False;
      if I < Length(FLoadedPages) then FLoadedPages[I] := False;
      if I < FPages.Count then PageImage(I).Picture.Assign(nil);
      if I < FThumbImages.Count then
        TImage(FThumbImages[I]).Picture.Assign(nil);
    end;
    FPage := OldPage;
    FResizePending := False;
    PaintPage;
    UpdateThumbnailSelection;
    UpdateSaveState;
    FRenderPending := True;
  finally
    FRenderTimer.Enabled := True;
    FThumbTimer.Enabled := FThumbScroll.Visible and (FCore.PageCount > 0);
  end;
end;

procedure TFreePDF64PDFiumView.ReleasePDFForExternalChange;
begin
  FCommentOwnerAuthorized := False;
  // QPDF muss die Originaldatei unter Windows ersetzen koennen.
  // Daher vorher das PDFium-Dokumenthandle freigeben.
  FCore.CloseFile;
  FDocumentFormType := 0;
  UpdateSecurityIcon;
end;

function TFreePDF64PDFiumView.RequestPDFPassword(const AFileName: string;
  out APassword: string; AOwnerPermission: Boolean): Boolean;
var
  Dialog: TForm;
  ViewerWindow: TCustomForm;
  Prompt, PasswordHint: TLabel;
  Entry: TEdit;
  OKButton, CancelButton: TButton;
  Dpi, Margin, Gap, TextWidth, Y, ButtonY: Integer;
  R: TRect;

  function Px(const Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Dpi, 96);
  end;

  function WrappedHeight(const AText: string): Integer;
  begin
    R := Rect(0, 0, TextWidth, 0);
    Dialog.Canvas.Font.Assign(Dialog.Font);
    DrawText(Dialog.Canvas.Handle, PChar(AText), Length(AText), R,
      DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
    Result := Max(Px(20), R.Bottom - R.Top + Px(5));
  end;

begin
  APassword := '';
  ViewerWindow := GetParentForm(Self);
  if ViewerWindow <> nil then
    Dialog := TForm.CreateNew(ViewerWindow)
  else
    Dialog := TForm.CreateNew(nil);
  try
    if AOwnerPermission then
      Dialog.Caption := ToolbarHint('PDF-Berechtigungskennwort', 'PDF permissions password')
    else
      Dialog.Caption := Tr('FreePDF64-Viewer – PDF-Kennwort');
    Dialog.BorderStyle := bsDialog;
    if ViewerWindow <> nil then
    begin
      Dialog.PopupMode := pmExplicit;
      Dialog.PopupParent := ViewerWindow;
      Dialog.Position := poOwnerFormCenter;
    end
    else
      Dialog.Position := poScreenCenter;

    // Alle Abmessungen einmal anhand der Monitor-DPI skalieren.
    // Scaled=False verhindert eine zweite VCL-Skalierung bei 4K/150–200 %.
    Dialog.Scaled := False;
    Dialog.Font.Name := 'Segoe UI';
    Dialog.Font.Size := 9;
    if ViewerWindow <> nil then
      Dpi := ViewerWindow.CurrentPPI
    else
      Dpi := Screen.PixelsPerInch;
    if Dpi < 96 then Dpi := 96;
    Margin := Px(20);
    Gap := Px(12);
    Dialog.ClientWidth := Px(500);
    TextWidth := Dialog.ClientWidth - 2 * Margin;
    Y := Px(18);

    Prompt := TLabel.Create(Dialog);
    Prompt.Parent := Dialog;
    Prompt.ParentFont := True;
    Prompt.AutoSize := False;
    Prompt.WordWrap := True;
    if AOwnerPermission then
      Prompt.Caption := ToolbarHint(
        'Die Kommentarbearbeitung ist für diese PDF eingeschränkt:',
        'Comment editing is restricted for this PDF:') + sLineBreak +
        ExtractFileName(AFileName)
    else
      Prompt.Caption := Tr('Diese PDF-Datei ist kennwortgeschützt:') + sLineBreak +
        ExtractFileName(AFileName);
    Prompt.SetBounds(Margin, Y, TextWidth, WrappedHeight(Prompt.Caption));
    Inc(Y, Prompt.Height + Gap);

    PasswordHint := TLabel.Create(Dialog);
    PasswordHint.Parent := Dialog;
    PasswordHint.ParentFont := True;
    PasswordHint.AutoSize := False;
    PasswordHint.WordWrap := True;
    if AOwnerPermission then
      PasswordHint.Caption := ToolbarHint(
        'Bitte geben Sie das Eigentümerkennwort ein:',
        'Enter the owner password:')
    else
      PasswordHint.Caption := Tr('Bitte geben Sie das Kennwort zum Öffnen ein:');
    PasswordHint.SetBounds(Margin, Y, TextWidth,
      WrappedHeight(PasswordHint.Caption));
    Inc(Y, PasswordHint.Height + Px(7));

    Entry := TEdit.Create(Dialog);
    Entry.Parent := Dialog;
    Entry.ParentFont := True;
    Entry.SetBounds(Margin, Y, TextWidth, Px(28));
    Entry.PasswordChar := '*';
    Entry.TabOrder := 0;

    ButtonY := Entry.Top + Entry.Height + Px(17);
    OKButton := TButton.Create(Dialog);
    OKButton.Parent := Dialog;
    OKButton.ParentFont := True;
    if AOwnerPermission then
      OKButton.Caption := 'OK'
    else
      OKButton.Caption := Tr('Öffnen');
    OKButton.SetBounds(Dialog.ClientWidth - Margin - Px(202), ButtonY,
      Px(94), Px(34));
    OKButton.ModalResult := mrOk;
    OKButton.Default := True;
    OKButton.TabOrder := 2;

    CancelButton := TButton.Create(Dialog);
    CancelButton.Parent := Dialog;
    CancelButton.ParentFont := True;
    CancelButton.Caption := Tr('Abbrechen');
    CancelButton.SetBounds(Dialog.ClientWidth - Margin - Px(100), ButtonY,
      Px(100), Px(34));
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    CancelButton.TabOrder := 3;

    Dialog.ClientHeight := ButtonY + Px(34) + Margin;
    Dialog.ActiveControl := Entry;
    Result := Dialog.ShowModal = mrOk;
    if Result then APassword := Entry.Text;
    Entry.Clear;
  finally
    Dialog.Free;
  end;
end;

function TFreePDF64PDFiumView.CachedPageSize(APage: Integer;
  out AW, AH: Single): Boolean;
begin
  AW := 0;
  AH := 0;
  Result := (APage >= 0) and (APage < FCore.PageCount);
  if not Result then Exit;
  if Length(FPageSizesValid) <> FCore.PageCount then
  begin
    SetLength(FPageSizesValid, FCore.PageCount);
    SetLength(FPageWidths, FCore.PageCount);
    SetLength(FPageHeights, FCore.PageCount);
  end;
  if not FPageSizesValid[APage] then
  begin
    // Keine geschaetzten Seitenmasse fuer das Hauptfenster verwenden:
    // Landschafts- und Hochformat koennen innerhalb einer PDF wechseln.
    // Dank FLayoutPageLimit werden nur die aktuell aufgebauten Seiten
    // vermessen; alle weiteren folgen in kleinen Timer-Batches.
    Result := FCore.PageSize(APage, FPageWidths[APage], FPageHeights[APage]);
    if not Result then Exit;
    FPageSizesValid[APage] := True;
  end;
  AW := FPageWidths[APage];
  AH := FPageHeights[APage];
end;

procedure TFreePDF64PDFiumView.OpenPDF(const AFileName: string);
var
  Password: string;
  Attempts: Integer;
begin
  if not ConfirmUnsaved then Exit;
  try
    SetLength(FPageSizesValid, 0);
    FCore.OpenFile(AFileName);
  except
    on EPDFiumPasswordRequired do
    begin
      Attempts := 0;
      repeat
        if not RequestPDFPassword(AFileName, Password) then
          Abort;
        try
          FCore.OpenFile(AFileName, UTF8Encode(Password));
          Break;
        except
          on EPDFiumPasswordRequired do
          begin
            Inc(Attempts);
            if Attempts >= 5 then
              raise EPDFiumViewer.Create('Zu viele falsche Kennworteingaben.');
            PDFModernMessageDlg(Tr('Das Kennwort ist nicht korrekt. Bitte versuchen Sie es erneut.'),
              mtWarning, [mbOK], 0);
          end;
        end;
      until False;
    end;
  end;
  FinishPreparedOpen;

end;

procedure TFreePDF64PDFiumView.OpenPDFPrepared(APrepared: TFreePDF64PDFiumCore);
begin
  if APrepared = nil then
    raise EPDFiumViewer.Create('Kein vorbereitetes PDF-Dokument vorhanden.');
  if not ConfirmUnsaved then Abort;
  SetLength(FPageSizesValid, 0);
  FCore.TakeDocumentFrom(APrepared);
  FinishPreparedOpen;
end;

function TFreePDF64PDFiumView.GetIsAcroForm: Boolean;
begin
  Result := FDocumentFormType = 1;
end;

procedure TFreePDF64PDFiumView.FinishPreparedOpen;
begin
  CancelMeasurement;
  FMeasureRects.Clear;
  FMeasureUndo.Clear;
  FMeasureRedo.Clear;
  FMeasureDirty := False;
  ClearStrokeRedo;
  FRedactionPreviews.Clear;
  FRedactionPreviewPages.Clear;
  ClearRedactionRedo;
  FCommentOwnerAuthorized := False;
  // M2.1: nur einmal pro erfolgreich geoeffnetem Dokument abfragen.
  // Kein Widget-Scan, keine Aenderung an Render-/Zoom-/Scrollpfaden.
  FDocumentFormType := FCore.FormType;
  // Kompatibilitaetshinweis nur einmal beim Oeffnen, ohne Eingriff in Formulare.
  if (FDocumentFormType in [2, 3]) or FCore.HasDocumentJavaScript then
    PDFModernMessageDlg(ToolbarHint(
      'WICHTIGER HINWEIS ZUR FORMULAR-KOMPATIBILITÄT' + sLineBreak + sLineBreak +
      'Dieses PDF enthält Dokument-JavaScript oder ein XFA-Formular. ' +
      'Einige Funktionen benötigen möglicherweise Adobe Acrobat Reader ' +
      'und werden in FreePDF64-Viewer Portable nicht vollständig unterstützt.' +
      sLineBreak + sLineBreak +
      'Bitte prüfen Sie automatische Berechnungen, abhängige Felder ' +
      'und das gespeicherte Ergebnis vor der weiteren Verwendung.' +
      sLineBreak + sLineBreak +
      'Dieser Hinweis ist eine Vorsichtsmaßnahme und bedeutet nicht, ' +
      'dass das Formular fehlerhaft ist.',
      'IMPORTANT FORM COMPATIBILITY NOTICE' + sLineBreak + sLineBreak +
      'This PDF contains document JavaScript or an XFA form. ' +
      'Some functions may require Adobe Acrobat Reader and may not ' +
      'be fully supported by FreePDF64-Viewer Portable.' +
      sLineBreak + sLineBreak +
      'Please verify automatic calculations, dependent fields, and ' +
      'the saved result before further use.' + sLineBreak + sLineBreak +
      'This notice is a precaution, not a finding that the form is invalid.'),
      mtWarning, [mbOK], 0);

  UpdateSaveState;
  FSelecting := False;
  FSelAnchorPage := -1;
  FSelFocusPage := -1;
  FThumbSelected.Clear;
  FThumbAnchor := -1;
  UpdateSecurityIcon;
  FFindTerm := '';
  FMatchPage := -1;
  FMatchChar := -1;
  FMatchCount := 0;
  FPage := 0;
  // Nur die erste Seite synchron anordnen; restliche Controls im Timer.
  FLayoutPageLimit := Min(1, FCore.PageCount);
  FWheelAccum := 0;
  FFitMode := True;
  FViewMode := 1;
  FViewSelect.ItemIndex := 1;
  // Nur das Layout vorbereiten; der vorhandene Render-Timer beginnt
  // erst in einem spaeteren Nachrichten-Durchlauf mit dem ersten Bild.
  FInitialRenderDeferred := True;

  PaintPage;

  // Erst die PDF-Seite anzeigen, dann die Seitenleiste aufbauen.
  FSidebarInitPending := True;
  FThumbTimer.Enabled := False;
  FThumbImages.Clear;
  while FThumbScroll.ControlCount > 0 do
    FThumbScroll.Controls[0].Free;
end;

procedure TFreePDF64PDFiumView.RefitOnTabActivation;
begin
  if (FCore = nil) or (FCore.PageCount = 0) or FRendering or
     (FScroll.ClientWidth <= 100) or (FScroll.ClientHeight <= 100) then Exit;

  // Inaktive PDF-Tabs koennen beim Maximieren ihre alte Layoutgroesse
  // behalten. Erst nach dem Align des aktivierten Tabs vergleichen.
  // Kein Re-Layout bei unveraendertem Viewport.
  if (FLayoutViewportWidth <> FScroll.ClientWidth) or
     (FLayoutViewportHeight <> FScroll.ClientHeight) then
  begin
    FResizePending := False;
    LayoutAllPages;
  end;
end;

procedure TFreePDF64PDFiumView.DrawViewModeItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  C: TComboBox;
  R: TRect;
begin
  C := TComboBox(Control);
  // Bei einem neu erzeugten ComboBox-Handle nach dem Splitwechsel
  // kann Windows fuer das geschlossene Auswahlfeld Index = -1 liefern.
  // Die tatsaechliche Auswahl dann fuer die Anzeige verwenden.
  if (Index < 0) and (C.ItemIndex >= 0) and
     (C.ItemIndex < C.Items.Count) then
    Index := C.ItemIndex;
  C.Canvas.Brush.Color := C.Color;
  C.Canvas.FillRect(ARect);
  if (Index >= 0) and (Index < C.Items.Count) then
  begin
    C.Canvas.Font.Assign(C.Font);
    C.Canvas.Font.Color := C.Font.Color;
    R := ARect;
    Inc(R.Left, 5);
    DrawText(C.Canvas.Handle, PChar(C.Items[Index]), -1, R,
      DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_NOPREFIX);
  end;
end;

procedure TFreePDF64PDFiumView.ApplyButtonDesign(ADesign: Integer);
var
  BackColor, TextColor, FieldColor: TColor;
  procedure Walk(AParent: TWinControl);
  var
    I: Integer;
    C: TControl;
  begin
    for I := 0 to AParent.ControlCount - 1 do
    begin
      C := AParent.Controls[I];
      if C is TPDFDesignButton then
        begin
        TPDFDesignButton(C).ParentFont := False;
        if (ADesign <> 0) and (C.Parent <> FEditBar) then
          TPDFDesignButton(C).Font.Style := [fsBold]
        else
          TPDFDesignButton(C).Font.Style := [];
        TPDFDesignButton(C).SetDesign(ADesign);
      end
      else if C is TPDFiumSaveButton then
        TPDFiumSaveButton(C).SetDesign(ADesign)
      else if C is TPDFToolsButton then
        TPDFToolsButton(C).SetDesign(ADesign)
      else if C is TPDFThemeBitBtn then
      begin
        TPDFThemeBitBtn(C).Font.Style := [fsBold];
        ApplyPDFGlyphContrast(TPDFThemeBitBtn(C), ADesign);
        TPDFThemeBitBtn(C).SetDesign(ADesign);
      end
      else if C is TBitBtn then
        ApplyPDFGlyphContrast(TBitBtn(C), ADesign);
      if C is TWinControl then
        Walk(TWinControl(C));
    end;
  end;
begin
  // Nicht nur die OwnerDraw-Buttons: auch die Container und die
  // Beschriftungen muessen die aktive Designpalette erhalten.
  case ADesign of
    1: begin BackColor := RGB(225, 232, 241); TextColor := RGB(35, 48, 65); FieldColor := RGB(245, 247, 250); end;
    2: begin BackColor := RGB(54, 58, 65); TextColor := clWhite; FieldColor := RGB(65, 70, 79); end;
    3: begin BackColor := RGB(192, 192, 192); TextColor := clBlack; FieldColor := RGB(192, 192, 192); end;
    4: begin BackColor := RGB(34, 36, 40); TextColor := clWhite; FieldColor := RGB(45, 48, 54); end;
    5: begin BackColor := RGB(190, 214, 237); TextColor := RGB(24, 55, 88); FieldColor := RGB(205, 225, 245); end;
  else
    begin BackColor := clBtnFace; TextColor := clWindowText; FieldColor := clWindow; end;
  end;
  FBar.ParentColor := False;
  FBar.ParentBackground := False;
  FBar.Color := BackColor;
  if ADesign <> 0 then FBar.Font.Style := [fsBold]
  else FBar.Font.Style := [];
  FEditBar.ParentColor := False;
  FEditBar.ParentBackground := False;
  FEditBar.Color := BackColor;
  // Die Bearbeitungsleiste besitzt besonders kompakte Steuerelemente.
  // Fett gesetzte Schriften werden in Nicht-Standard-Designs abgeschnitten.
  FEditBar.Font.Style := [];
  FStatus.ParentFont := False;
  FPageTotal.ParentFont := False;
  FZoomStatus.ParentFont := False;
  FStatus.Font.Color := TextColor;
  FPageTotal.Font.Color := TextColor;
  FZoomStatus.Font.Color := TextColor;
  if ADesign <> 0 then
  begin
    FStatus.Font.Style := [fsBold];
    FPageTotal.Font.Style := [fsBold];
    FZoomStatus.Font.Style := [fsBold];
  end
  else
  begin
    FStatus.Font.Style := [];
    FPageTotal.Font.Style := [];
    FZoomStatus.Font.Style := [];
  end;
  // Undurchsichtiger Labelhintergrund verhindert hellen Text auf
  // einem vom Windows-Theme hell gezeichneten Toolbar-Hintergrund.
  FStatus.Transparent := False;
  FPageTotal.Transparent := False;
  FZoomStatus.Transparent := False;
  FStatus.Color := BackColor;
  FPageTotal.Color := BackColor;
  FZoomStatus.Color := BackColor;
  // Kopfbereich der Miniaturansicht an die Designpalette anpassen.
  if FOutlineHeader <> nil then
  begin
    FOutlineHeader.ParentColor := False;
    FOutlineHeader.ParentBackground := False;
    FOutlineHeader.Color := BackColor;
    FOutlineHeader.Invalidate;
  end;
  if FOutlineTitle <> nil then
  begin
    FOutlineTitle.Font.Color := TextColor;
    if ADesign <> 0 then FOutlineTitle.Font.Style := [fsBold]
    else FOutlineTitle.Font.Style := [];
  end;
  // Einmalig bei der Designanwendung auch die nativen Eingabefelder
  // setzen. Diese werden von Walk absichtlich nicht neu aufgebaut.
  if FPageEdit <> nil then
  begin
    FPageEdit.ParentFont := False;
    FPageEdit.Color := FieldColor;
    FPageEdit.Font.Color := TextColor;
    if ADesign <> 0 then FPageEdit.Font.Style := [fsBold]
    else FPageEdit.Font.Style := [];
  end;
  if FViewSelect <> nil then
  begin
    FViewSelect.ParentFont := False;
    // Die native csDropDownList zeichnet ihre geschlossene Flaeche
    // selbst und ignoriert dabei teilweise Color. OwnerDraw vermeidet
    // diesen weissen Hintergrund ohne Arbeit beim Tabwechsel.
    if ADesign = 0 then FViewSelect.Style := csDropDownList
    else FViewSelect.Style := csOwnerDrawFixed;
    FViewSelect.Color := FieldColor;
    FViewSelect.Font.Color := TextColor;
    if ADesign <> 0 then FViewSelect.Font.Style := [fsBold]
    else FViewSelect.Font.Style := [];
    // OwnerDraw verwendet sonst die alte Standard-Zeilenhoehe. Bei 4K
    // wird die fette Schrift dadurch im geschlossenen Feld abgeschnitten.
    if ADesign <> 0 then
    begin
      FViewSelect.Canvas.Font.Assign(FViewSelect.Font);
      FViewSelect.ItemHeight := FViewSelect.Canvas.TextHeight('Ag') +
        MulDiv(6, FViewSelect.CurrentPPI, 96);
    end;
  end;
  // Schrift der Miniatur-Registerkarten nach einem Designwechsel angleichen.
  if (FOutlineHeader <> nil) and (FThumbTab <> nil) and
     (FBookmarksTab <> nil) and (FOutlineClose <> nil) then
    OutlineHeaderResize(nil);
  if FFlowSelect <> nil then
  begin
    FFlowSelect.ParentFont := False;
    if ADesign = 0 then FFlowSelect.Style := csDropDownList
    else FFlowSelect.Style := csOwnerDrawFixed;
    FFlowSelect.OnDrawItem := DrawViewModeItem;
    FFlowSelect.Color := FieldColor;
    FFlowSelect.Font.Color := TextColor;
    if ADesign <> 0 then FFlowSelect.Font.Style := [fsBold]
    else FFlowSelect.Font.Style := [];
  end;
  if FShapeSelect <> nil then
  begin
    FShapeSelect.ParentFont := False;
    if ADesign = 0 then FShapeSelect.Style := csDropDownList
    else FShapeSelect.Style := csOwnerDrawFixed;
    FShapeSelect.OnDrawItem := DrawViewModeItem;
    FShapeSelect.Color := FieldColor;
    FShapeSelect.Font.Color := TextColor;
    if ADesign <> 0 then FShapeSelect.Font.Style := [fsBold]
    else FShapeSelect.Font.Style := [];
    if ADesign <> 0 then
    begin
      FShapeSelect.Canvas.Font.Assign(FShapeSelect.Font);
      FShapeSelect.ItemHeight := FShapeSelect.Canvas.TextHeight('Ag') +
        MulDiv(6, FShapeSelect.CurrentPPI, 96);
    end;
  end;
  if FWidthSelect <> nil then
  begin
    FWidthSelect.ParentFont := False;
    if ADesign = 0 then FWidthSelect.Style := csDropDownList
    else FWidthSelect.Style := csOwnerDrawFixed;
    FWidthSelect.OnDrawItem := DrawViewModeItem;
    FWidthSelect.Color := FieldColor;
    FWidthSelect.Font.Color := TextColor;
    if ADesign <> 0 then FWidthSelect.Font.Style := [fsBold]
    else FWidthSelect.Font.Style := [];
    if ADesign <> 0 then
    begin
      FWidthSelect.Canvas.Font.Assign(FWidthSelect.Font);
      FWidthSelect.ItemHeight := FWidthSelect.Canvas.TextHeight('Ag') +
        MulDiv(6, FWidthSelect.CurrentPPI, 96);
    end;
  end;
  if FTextFontSelect <> nil then
  begin
    FTextFontSelect.ParentFont := False;
    if ADesign = 0 then FTextFontSelect.Style := csDropDownList
    else FTextFontSelect.Style := csOwnerDrawFixed;
    FTextFontSelect.OnDrawItem := DrawViewModeItem;
    FTextFontSelect.Color := FieldColor;
    FTextFontSelect.Font.Color := TextColor;
    if ADesign <> 0 then FTextFontSelect.Font.Style := [fsBold]
    else FTextFontSelect.Font.Style := [];
    if ADesign <> 0 then
    begin
      FTextFontSelect.Canvas.Font.Assign(FTextFontSelect.Font);
      FTextFontSelect.ItemHeight := FTextFontSelect.Canvas.TextHeight('Ag') +
        MulDiv(6, FTextFontSelect.CurrentPPI, 96);
    end;
  end;
  if FTextSizeSelect <> nil then
  begin
    FTextSizeSelect.ParentFont := False;
    FTextSizeSelect.Color := FieldColor;
    FTextSizeSelect.Font.Color := TextColor;
    if ADesign <> 0 then FTextSizeSelect.Font.Style := [fsBold]
    else FTextSizeSelect.Font.Style := [];
  end;
  Walk(Self);
  // Einfuegen und Messen: Fett nur bei aktivem Werkzeugmodus.
  if FInsertButton <> nil then
  begin
    FInsertButton.ParentFont := False;
    if FTextInsertMode or FNoteMode then
      FInsertButton.Font.Style := [fsBold]
    else
      FInsertButton.Font.Style := [];
  end;
  if FMeasureButton <> nil then
  begin
    FMeasureButton.ParentFont := False;
    if FMeasureMode then
      FMeasureButton.Font.Style := [fsBold]
    else
      FMeasureButton.Font.Style := [];
  end;
  // Der Werkzeuge-Button kann in die gemeinsame Browser-Symbolleiste
  // umgehaengt sein und liegt dann ausserhalb von Self/Walk(Self).
  // Nur beim echten Designwechsel direkt mit der Palette versorgen.
  if FEditToggle <> nil then
    FEditToggle.SetDesign(ADesign);
  FBar.Invalidate;
  FEditBar.Invalidate;
end;

procedure TFreePDF64PDFiumView.ApplyPDFBackgroundDesign(ADesign: Integer);
begin
  if FScroll = nil then Exit;
  // Nur Modern Hell und Klassisch Blau erhalten einen farbigen
  // PDF-Umgebungshintergrund. Die PDF-Seiten bleiben unveraendert.
  case ADesign of
    1: FScroll.Color := RGB(229, 236, 246); // Modern Hell
    5: FScroll.Color := RGB(220, 234, 247); // Klassisch Blau
  else
    FScroll.Color := clBtnShadow;
  end;
  FScroll.Invalidate;
end;

procedure TFreePDF64PDFiumView.RefreshPDFDisplay;
begin

  // Nach dem Einbetten in ein TabSheet sind die Clientmasse erst spaeter gueltig.
  if (FCore.PageCount = 0) or (FScroll.ClientWidth < 50) or
     (FScroll.ClientHeight < 50) then Exit;
  FResizePending := False;
  PaintPage;
  FScroll.Invalidate;

end;

procedure TFreePDF64PDFiumView.FindClick(Sender: TObject);
var
  Term: string;
  Dialog: TForm;
  Prompt: TLabel;
  Entry: TEdit;
  OKButton, CancelButton: TButton;
  Margin, Gap, ButtonY, TextWidth: Integer;

  function Px(V: Integer): Integer;
  begin
    Result := MulDiv(V, CurrentPPI, 96);
  end;

begin
  // Eigenes Suchdialogfenster verwenden, damit auch die Standardbuttons
  // unabhaengig von der Windows-/VCL-Dialogs Sprache uebersetzt werden.
  Margin := Px(16);
  Gap := Px(8);
  TextWidth := Px(440);
  Dialog := TForm.Create(nil);
  try
    Dialog.Caption := Tr('PDF-Textsuche');
    Dialog.BorderStyle := bsDialog;
    Dialog.Position := poMainFormCenter;
    Dialog.BorderIcons := [biSystemMenu];
    Dialog.ClientWidth := TextWidth + Margin * 2;
    Dialog.ClientHeight := Px(132);
    Dialog.Font.Assign(Font);

    Prompt := TLabel.Create(Dialog);
    Prompt.Parent := Dialog;
    Prompt.ParentFont := True;
    Prompt.Caption := Tr('Suchbegriff:');
    Prompt.SetBounds(Margin, Margin, TextWidth, Px(20));

    Entry := TEdit.Create(Dialog);
    Entry.Parent := Dialog;
    Entry.ParentFont := True;
    Entry.Text := FFindTerm;
    Entry.SetBounds(Margin, Prompt.Top + Prompt.Height + Gap,
      TextWidth, Px(28));

    Entry.TabOrder := 0;

    ButtonY := Entry.Top + Entry.Height + Px(16);
    CancelButton := TButton.Create(Dialog);
    CancelButton.Parent := Dialog;
    CancelButton.ParentFont := True;
    CancelButton.Caption := Tr('Abbrechen');
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    CancelButton.SetBounds(Dialog.ClientWidth - Margin - Px(100),
      ButtonY, Px(100), Px(34));
    CancelButton.TabOrder := 2;

    OKButton := TButton.Create(Dialog);
    OKButton.Parent := Dialog;
    OKButton.ParentFont := True;
    OKButton.Caption := Tr('OK');
    OKButton.ModalResult := mrOk;
    OKButton.Default := True;
    OKButton.SetBounds(CancelButton.Left - Gap - Px(98),
      ButtonY, Px(98), Px(34));
    OKButton.TabOrder := 1;

    Dialog.ClientHeight := ButtonY + Px(34) + Margin;
    ApplyPDFDialogDesign(Dialog);
    Dialog.ActiveControl := Entry;
    Entry.SelectAll;
    case Dialog.ShowModal of
      mrOk:
        begin
          Term := Trim(Entry.Text);
          SearchText(Term);
        end;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TFreePDF64PDFiumView.ShowSearchDialog;
begin
  FindClick(Self);
end;

procedure TFreePDF64PDFiumView.SearchTimerTick(Sender: TObject);
var
  PageMatches: TArray<TPDFTextMatch>;
  I, N, Pg: Integer;
begin
  if not FSearchRunning then Exit;
  if FSearchPage >= FCore.PageCount then
  begin
    FSearchRunning := False;
    FSearchTimer.Enabled := False;
    if Assigned(FOnSearchCountChanged) then FOnSearchCountChanged(Self);
    Exit;
  end;
  Pg := FSearchPage;
  Inc(FSearchPage);
  // PDFium bleibt ausschliesslich im UI-Thread: keine konkurrierenden
  // Dokumentzugriffe. Pro Tick nur eine Seite, daher kein 800-Seiten-Block.
  PageMatches := FCore.FindTextMatchesOnPage(FFindTerm, Pg);
  N := Length(FSearchMatches);
  SetLength(FSearchMatches, N + Length(PageMatches));
  for I := 0 to High(PageMatches) do
    FSearchMatches[N + I] := PageMatches[I];
  FTotalSearchMatches := Length(FSearchMatches);
  if Assigned(FOnSearchCountChanged) then FOnSearchCountChanged(Self);
  if (N = 0) and (Length(PageMatches) > 0) then SearchNext(1);
end;

function TFreePDF64PDFiumView.HasSearchHighlights: Boolean;
begin
  Result := (FFindTerm <> '') or FSearchRunning or (Length(FSearchMatches) > 0);
end;

procedure TFreePDF64PDFiumView.SearchText(const AText: string);
var Term: string; PageIndex: Integer;
begin
  Term := Trim(AText);
  FSearchTimer.Enabled := False;
  FSearchRunning := False;
  SetLength(FSearchMatches, 0);
  FSearchPage := 0;
  if Term = '' then
  begin
    FSearchTimer.Enabled := False;
    FSearchRunning := False;
    SetLength(FSearchMatches, 0);
    FFindTerm := '';
    FMatchPage := -1;
    FMatchChar := -1;
    FMatchCount := 0;
    FTotalSearchMatches := 0;
    if Assigned(FOnSearchCountChanged) then FOnSearchCountChanged(Self);
    if FCore.PageCount > 0 then
      for PageIndex := 0 to High(FLoadedPages) do
        if FLoadedPages[PageIndex] then
        begin
          FCore.RenderPage(PageIndex, PageImage(PageIndex).Picture.Bitmap,
            PageImage(PageIndex).Width, PageImage(PageIndex).Height);
          DrawPageStrokes(PageIndex);
          PageImage(PageIndex).Invalidate;
        end;
    if FCore.PageCount > 0 then UpdateVisiblePage;
    Exit;
  end;
  if FCore.PageCount = 0 then Exit;
  FMatchPage := -1;
  FMatchChar := -1;
  FMatchCount := 0;
  FFindTerm := Term;
  FTotalSearchMatches := 0;
  if Assigned(FOnSearchCountChanged) then FOnSearchCountChanged(Self);
  FSearchRunning := True;
  if Assigned(FOnSearchCountChanged) then FOnSearchCountChanged(Self);
  FSearchTimer.Enabled := True;
end;

function TFreePDF64PDFiumView.GlobalPageCount: Integer;
begin
  Result := FCore.PageCount;
end;

function TFreePDF64PDFiumView.GlobalFindOnPage(const ATerm: string;
  APage: Integer): TArray<TPDFTextMatch>;
begin
  Result := FCore.FindTextMatchesOnPage(ATerm, APage);
end;

function TFreePDF64PDFiumView.GlobalExcerpt(APage, AChar, ALength: Integer): string;
var
  StartAt: Integer;
begin
  StartAt := Max(0, AChar - 35);
  Result := FCore.TextRange(APage, StartAt, Min(110, ALength + 70));
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

procedure TFreePDF64PDFiumView.GlobalShowMatch(const ATerm: string;
  const AMatch: TPDFTextMatch);
var
  I: Integer;
begin
  FSearchTimer.Enabled := False;
  FSearchRunning := False;
  FFindTerm := ATerm;
  SetLength(FSearchMatches, 1);
  FSearchMatches[0] := AMatch;
  FMatchPage := AMatch.PageIndex;
  FMatchChar := AMatch.CharIndex;
  FMatchCount := AMatch.CharCount;
  ShowPage(AMatch.PageIndex);
  for I := 0 to High(FLoadedPages) do
    if FLoadedPages[I] and (Abs(I - AMatch.PageIndex) <= 2) then
    begin
      FCore.RenderPage(I, PageImage(I).Picture.Bitmap,
        PageImage(I).Width, PageImage(I).Height);
      DrawPageStrokes(I);
      DrawSearchHighlight(I);
      PageImage(I).Invalidate;
    end;
end;

procedure TFreePDF64PDFiumView.NextSearchMatch(ADirection: Integer);
begin
  SearchNext(ADirection);
end;

function TFreePDF64PDFiumView.FindCachedSearchMatch(
  AStartPage, AStartChar, ADirection: Integer;
  out APage, ACharIndex, ACharCount: Integer): Boolean;
var
  I, Selected: Integer;
begin
  Result := False;
  Selected := -1;
  if Length(FSearchMatches) = 0 then Exit;
  if ADirection >= 0 then
  begin
    for I := 0 to High(FSearchMatches) do
      if (FSearchMatches[I].PageIndex > AStartPage) or
         ((FSearchMatches[I].PageIndex = AStartPage) and
          (FSearchMatches[I].CharIndex >= AStartChar)) then
      begin Selected := I; Break; end;
    if Selected < 0 then Selected := 0;
  end
  else
  begin
    for I := High(FSearchMatches) downto 0 do
      if (FSearchMatches[I].PageIndex < AStartPage) or
         ((FSearchMatches[I].PageIndex = AStartPage) and
          (FSearchMatches[I].CharIndex <= AStartChar)) then
      begin Selected := I; Break; end;
    if Selected < 0 then Selected := High(FSearchMatches);
  end;
  APage := FSearchMatches[Selected].PageIndex;
  ACharIndex := FSearchMatches[Selected].CharIndex;
  ACharCount := FSearchMatches[Selected].CharCount;
  Result := True;
end;

procedure TFreePDF64PDFiumView.SearchNext(ADirection: Integer);
var Pg, Idx, Cnt, StartPg, StartChar, OldPage: Integer;
begin
  if (FFindTerm = '') or (FCore.PageCount = 0) then Exit;
  if FMatchPage < 0 then
  begin
    StartPg := FPage;
    if ADirection > 0 then StartChar := 0 else StartChar := MaxInt;
  end
  else
  begin
    StartPg := FMatchPage;
    if ADirection > 0 then StartChar := FMatchChar + Max(1, FMatchCount)
    else StartChar := FMatchChar - 1;
  end;
  if FindCachedSearchMatch(StartPg, StartChar, ADirection,
    Pg, Idx, Cnt) then
  begin
    OldPage := FMatchPage;
    FMatchPage := Pg;
    FMatchChar := Idx;
    FMatchCount := Cnt;
    // F3 darf nicht alle bereits geladenen PDF-Seiten erneut rendern.
    // Nur auf der bisherigen und der neuen Trefferseite aendert sich
    // die Hervorhebung des aktiven Treffers.
    if (OldPage >= 0) and (OldPage <= High(FLoadedPages)) and
       FLoadedPages[OldPage] and (PageImage(OldPage) <> nil) then
    begin
      FCore.RenderPage(OldPage, PageImage(OldPage).Picture.Bitmap,
        PageImage(OldPage).Width, PageImage(OldPage).Height);
      DrawPageStrokes(OldPage);
      DrawSearchHighlight(OldPage);
      PageImage(OldPage).Invalidate;
    end;
    if (Pg <> OldPage) and (Pg >= 0) and (Pg <= High(FLoadedPages)) and
       FLoadedPages[Pg] and (PageImage(Pg) <> nil) then
    begin
      FCore.RenderPage(Pg, PageImage(Pg).Picture.Bitmap,
        PageImage(Pg).Width, PageImage(Pg).Height);
      DrawPageStrokes(Pg);
      DrawSearchHighlight(Pg);
      PageImage(Pg).Invalidate;
    end;
    ShowPage(Pg);
    UpdateVisiblePage;
  end
  else
    PDFModernMessageDlg(Tr('Keine weiteren Treffer gefunden.'), mtInformation, [mbOK], 0);
end;

procedure TFreePDF64PDFiumView.ShowPage(APage: Integer);
var
  Img: TPDFiumImage;
  TargetY: Integer;
begin
  if (FCore = nil) or (APage < 0) or (APage >= FCore.PageCount) then Exit;

  if (FInlineFormEditor <> nil) and
     (FInlineFormPage <> APage) then FinishInlineFormEdit(True);

  // Die Zielseite VOR dem Layout setzen (wichtig fuer "Ganze Seite").
  FPage := APage;
  if FContinuous and (APage >= FLayoutPageLimit) then
  begin
    FLayoutPageLimit := Min(FCore.PageCount, APage + 1);
    LayoutAllPages;
  end
  else if not FContinuous then
    LayoutAllPages;

  if FContinuous then
  begin
    Img := PageImage(APage);
    if Img <> nil then
    begin
      // Img.Top ist bei einer gescrollten TScrollBox relativ zum
      // sichtbaren Ursprung. Die Dokumentposition ist die Summe aus
      // aktueller Scrollposition und der Bildschirmposition des Controls.
      // KEIN ScrollInView vor der Berechnung: es veraendert beide Werte.
      // Nach LayoutAllPages sind die Control-Koordinaten bei
      // Scrollposition 0 angelegt worden. Img.Top ist deshalb bereits
      // die absolute Dokumentposition und bleibt auch beim Scrollen
      // die korrekte Zielkoordinate.
      // TScrollBox verschiebt Child.Top beim Scrollen. Deshalb ist
      // Img.Top allein KEINE Dokumentposition: den aktuellen
      // Scrolloffset addieren. Das gilt auch beim Miniaturklick.
      TargetY := FScroll.VertScrollBar.Position +
        FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0))).Y - 8;
      FScroll.VertScrollBar.Position := Max(0, TargetY);
    end;
  end
  else
    FScroll.VertScrollBar.Position := 0;

  FPage := APage;
  FLastScrollPosition := FScroll.VertScrollBar.Position;
  FRenderPending := True;
  // Nicht durch UpdateVisiblePage sofort wieder die alte Seite bestimmen.
  // Die naechste regulaere Scroll-/Renderaktualisierung uebernimmt dies.
  if not FPageEdit.Focused then
    FPageEdit.Text := IntToStr(FPage + 1);
  FPrev.Enabled := FPage > 0;
  FNext.Enabled := FPage < FCore.PageCount - 1;
  FPageTotal.Caption := Format('/ %d', [FCore.PageCount]);
  // Jeder Navigationsklick setzt das Ziel neu, auch wenn bereits ein
  // aelterer asynchroner Miniatursprung vorgemerkt ist.
  if not FThumbClickNavigation then
    FThumbScrollTarget := APage;
  UpdateThumbnailSelection;
  // Zielminiatur sofort bereitstellen, auch wenn der Hintergrundaufbau
  // erst bei den ersten Seiten angekommen ist.
  if (not FThumbClickNavigation) and
     (FThumbScroll <> nil) and FThumbScroll.Visible and
     (FOutlinePanel <> nil) and FOutlinePanel.Visible then
  begin
    FThumbScrollTarget := APage;
    // Miniaturaufbau in Timer-Batches statt bis zur Zielseite
    // synchron hunderte Controls zu erzeugen.
    if FThumbNext > APage then
      ScrollThumbnailToCurrentPage;
    FThumbTimer.Enabled := True;
  end;
  RenderVisiblePages;
end;

procedure TFreePDF64PDFiumView.Navigate(Sender: TObject);
begin
  if Sender = FPrev then ShowPage(FPage - 1)
  else ShowPage(FPage + 1);
end;

procedure TFreePDF64PDFiumView.GoToPage(Sender: TObject);
var N: Integer;
begin
  if TryStrToInt(Trim(FPageEdit.Text), N) then ShowPage(N - 1)
  else FPageEdit.Text := IntToStr(FPage + 1);
end;

procedure TFreePDF64PDFiumView.PageKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if FRedactionReportOpen then Exit;
  // Schwärzungsvorschau: Die letzte Vormerkung einzeln entfernen.
  // Entf ist bewusst nur im Vorschauwerkzeug aktiv, damit die normale
  // PDF-Bearbeitung und deren Rückgängig-Funktion unverändert bleiben.
  if (Key = VK_DELETE) and (FShapeSelect <> nil) and
     (FShapeSelect.ItemIndex = 6) and (FRedactionPreviews <> nil) and
     (FRedactionPreviews.Count > 0) then
  begin
    FRedactionPreviews.Delete(FRedactionPreviews.Count - 1);
    FRedactionPreviewPages.Delete(FRedactionPreviewPages.Count - 1);
    ClearRedactionRedo;
    UpdateTextUndoButtons;
    RenderVisiblePages;
    Key := 0;
    Exit;
  end;
  if (Key = VK_ESCAPE) and (FRedactionPreviews <> nil) and
     (FRedactionPreviews.Count > 0) then
  begin
    FRedactionPreviews.Clear;
    FRedactionPreviewPages.Clear;
    ClearRedactionRedo;
    UpdateTextUndoButtons;
    RenderVisiblePages;
    Key := 0;
    Exit;
  end;
  if (Key = VK_ESCAPE) and FSignatureMode then
  begin
    CancelSignature;
    Key := 0;
    Exit;
  end;
  if (Key = VK_ESCAPE) and FMeasureMode then
  begin
    FMeasureMode := False;
    CancelMeasurement;
    FMeasureButton.Font.Style := [];
    Key := 0;
    Exit;
  end;
  // ESC beendet zuerst den aktiven Hyperlink-Einfuegemodus.
  if (Key = VK_ESCAPE) and FLinkMode then
  begin
    FLinkMode := False;
    Screen.Cursor := crDefault;
    if FImage <> nil then FImage.Cursor := crDefault;
    Key := 0;
    Exit;
  end;
  // ESC hebt die Mehrfachmarkierung der Miniaturseiten auf.
  if (Key = VK_ESCAPE) and (FThumbSelected.Count > 0) then
  begin
    FThumbSelected.Clear;
    FThumbAnchor := -1;
    UpdateThumbnailSelection;
    Key := 0;
    Exit;
  end;
  // ESC entfernt nur die temporaere Textauswahl im PDF.
  if (Key = VK_ESCAPE) and (FSelAnchorPage >= 0) and
     (FSelFocusPage >= 0) then
  begin
    FSelecting := False;
    FSelAnchorPage := -1;
    FSelFocusPage := -1;
    FSelAnchorChar := -1;
    FSelFocusChar := -1;
    RefreshSelectedPages;
    Key := 0;
    Exit;
  end;
  if (Key = VK_TAB) and HasActiveFormWidget then
  begin
    Key := 0;
    if ssShift in Shift then FocusAdjacentFormWidget(-1)
    else FocusAdjacentFormWidget(1);
    Exit;
  end;
  if (Key = VK_SPACE) and HasActiveFormWidget then
  begin
    Key := 0;
    ActivateFocusedFormChoice;
    Exit;
  end;
  // Textauswahl kopieren, ohne bestehende Tastaturfunktionen zu ersetzen.
  if (Key = Ord('C')) and (ssCtrl in Shift) and
     not (ssAlt in Shift) and (FSelAnchorPage >= 0) and
     (FSelFocusPage >= 0) then
  begin
    CopySelectedText;
    Key := 0;
    Exit;
  end;
  case Key of
    VK_F7: begin
      RequiredFieldsReportClick(nil);
      Key := 0;
    end;
    Ord('R'): if (ssCtrl in Shift) and (ssShift in Shift) then
      begin
        ReloadPDFClick(nil);
        Key := 0;
      end;
    VK_F3: begin
      if ssShift in Shift then SearchNext(-1) else SearchNext(1);
      Key := 0;
    end;
    VK_RETURN: begin GoToPage(nil); Key := 0; end;
    VK_NEXT: begin ShowPage(FPage + 1); Key := 0; end;
    VK_PRIOR: begin ShowPage(FPage - 1); Key := 0; end;
    VK_HOME: if ssCtrl in Shift then
      begin ShowPage(0); Key := 0; end;
    VK_END: if ssCtrl in Shift then
      begin ShowPage(FCore.PageCount - 1); Key := 0; end;
  end;
end;

procedure TFreePDF64PDFiumView.OutlineMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  Step, P: Integer;
begin
  // Das Mausrad innerhalb der Seitenleiste darf nicht die PDF-Seite scrollen.
  Handled := True;
  if (FOutlinePanel = nil) or not FOutlinePanel.Visible then Exit;
  if FOutlineTree.Visible then
  begin
    // TTreeView besitzt eine eigene vertikale Scrollverwaltung.
    if WheelDelta < 0 then
      FOutlineTree.Perform(WM_VSCROLL, SB_LINEDOWN, 0)
    else
      FOutlineTree.Perform(WM_VSCROLL, SB_LINEUP, 0);
  end
  else if FThumbScroll.Visible then
  begin
    Step := Max(32, FThumbScroll.ClientHeight div 7);
    P := FThumbScroll.VertScrollBar.Position;
    if WheelDelta < 0 then
      FThumbScroll.VertScrollBar.Position := P + Step
    else
      FThumbScroll.VertScrollBar.Position := Max(0, P - Step);
  end;
end;

procedure TFreePDF64PDFiumView.ScrollMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var Step, P: Integer;
begin
  Handled := True;
  if FCore.PageCount = 0 then Exit;
  if ssCtrl in Shift then
  begin
    if WheelDelta > 0 then
      ZoomByFactor(1.10)
    else
      ZoomByFactor(1 / 1.10);
    Exit;
  end;
  if not FContinuous then
  begin
    if WheelDelta < 0 then ShowPage(Min(FCore.PageCount - 1,
      FPage + IfThen(FTwoPage, 2, 1)))
    else ShowPage(Max(0, FPage - IfThen(FTwoPage, 2, 1)));
    Exit;
  end;
  Step := Max(32, FScroll.ClientHeight div 7);
  P := FScroll.VertScrollBar.Position;
  if WheelDelta < 0 then
    FScroll.VertScrollBar.Position := P + Step
  else
    FScroll.VertScrollBar.Position := Max(0, P - Step);
  // Rendern zeitversetzt im bestehenden Timer statt synchron bei jedem
  // Mausrad-Impuls: verhindert sichtbares Flackern beim Scrollen.
  FLastScrollPosition := FScroll.VertScrollBar.Position;
  FScrollRenderPending := True;
  FLastScrollTick := GetTickCount64;
  UpdateVisiblePage;
  FRenderPending := True;
end;

function TFreePDF64PDFiumView.WorkspaceScrollX: Integer;
begin
  Result := FScroll.HorzScrollBar.Position;
end;

function TFreePDF64PDFiumView.WorkspaceScrollY: Integer;
begin
  Result := FScroll.VertScrollBar.Position;
end;

procedure TFreePDF64PDFiumView.ApplySplitSync(AZoom: Double; ASetZoom: Boolean;
  AX, AY: Integer; ASetScroll: Boolean);
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  if ASetZoom and (Abs(FZoom - AZoom) > 0.0001) then
    RestoreWorkspaceView(AZoom, False, WorkspaceScrollX, WorkspaceScrollY);
  if ASetScroll then
  begin
    FScroll.HorzScrollBar.Position := Max(0, AX);
    FScroll.VertScrollBar.Position := Max(0, AY);
    FLastScrollPosition := FScroll.VertScrollBar.Position;
    FScrollRenderPending := True;
    FLastScrollTick := GetTickCount64;
    FRenderPending := True;
  end;
end;

procedure TFreePDF64PDFiumView.RestoreWorkspaceView(AZoom: Double; AFit: Boolean; AX, AY: Integer);
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  if not AFit then
  begin
    FFitMode := False;
    FViewMode := 3;
    FViewSelect.ItemIndex := 3;
    FZoom := Max(8.0 * CurrentPPI / 7200.0,
                 Min(1000.0 * CurrentPPI / 7200.0, AZoom));
    FZoomStatus.Caption := Format('%d%%', [Round(FZoom * 7200 / CurrentPPI)]);
    PaintPage;
  end;
  FScroll.HorzScrollBar.Position := Max(0, AX);
  FScroll.VertScrollBar.Position := Max(0, AY);
  FLastScrollPosition := FScroll.VertScrollBar.Position;
  FScrollRenderPending := True;
  FLastScrollTick := GetTickCount64;
  FRenderPending := True;
end;

function TFreePDF64PDFiumView.WorkspaceSidebarVisible: Boolean;
begin
  Result := FOutlinePanel.Visible;
end;

procedure TFreePDF64PDFiumView.RestoreWorkspaceLayout(
  AViewMode: Integer; ATwoPage, AContinuous, ASidebar: Boolean);
begin
  AViewMode := EnsureRange(AViewMode, 0, 3);
  if FTwoPage <> ATwoPage then TwoPageClick(nil);
  if FContinuous <> AContinuous then
  begin
    FFlowSelect.ItemIndex := Ord(not AContinuous);
    FlowModeChange(nil);
  end;
  if FViewMode <> AViewMode then
  begin
    FViewSelect.ItemIndex := AViewMode;
    ViewModeChange(nil);
  end;
  // Die globale Miniatur-Einstellung bereits vor dem Layout beachten.
  // Sonst erscheint die Seitenleiste beim Laden eines Arbeitsbereichs kurz.
  LoadGlobalThumbnails;
  ASidebar := ASidebar and GThumbnailsVisible and not GThumbnailSplitMode;
  if FOutlinePanel.Visible <> ASidebar then ToggleOutline(nil);
end;

procedure TFreePDF64PDFiumView.ZoomByFactor(AFactor: Double);
var
  Img: TPDFiumImage;
  AnchorPage: Integer;
  OldImageY, OldImageH, NewImageY, NewImageH: Integer;
  AnchorScreenY, NewScrollPos, MaxScrollPos: Integer;
  AnchorRatio: Double;
  P: TPoint;
begin
  FinishInlineFormEdit(True);
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;

  // Den Punkt in der aktuell sichtbaren Seite merken, der in der Mitte des
  // Viewports liegt. Nach dem Zoomen wird derselbe Punkt wieder an dieselbe
  // Bildschirmposition gesetzt, damit die Ansicht nicht zu anderen Seiten
  // springt.
  AnchorPage := EnsureRange(FPage, 0, FCore.PageCount - 1);
  Img := PageImage(AnchorPage);
  AnchorScreenY := FScroll.ClientHeight div 2;
  OldImageY := 0;
  OldImageH := 0;
  AnchorRatio := 0.5;

  if (Img <> nil) and (Img.Height > 0) then
  begin
    P := FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
    OldImageY := P.Y;
    OldImageH := Img.Height;
    AnchorRatio := (AnchorScreenY - OldImageY) / OldImageH;
    if AnchorRatio < 0 then AnchorRatio := 0;
    if AnchorRatio > 1 then AnchorRatio := 1;
  end;

  FFitMode := False;
  FViewMode := 3;
  FViewSelect.ItemIndex := 3;
  FZoom := Max(8.0 * CurrentPPI / 7200.0,
               Min(1000.0 * CurrentPPI / 7200.0, FZoom * AFactor));
  // Alte Bitmap als skalierte Vorschau zeigen. PDFium erst rendern,
  // wenn fuer 220 ms kein weiterer Zoomschritt eingetroffen ist.
  FZoomRenderPending := True;
  FLastZoomTick := GetTickCount64;
  PaintPage;

  // LayoutAllPages hat die Bildgroessen neu berechnet. Scrolloffset anhand
  // desselben relativen Punktes der gleichen PDF-Seite korrigieren.
  Img := PageImage(AnchorPage);
  if (Img <> nil) and (Img.Height > 0) then
  begin
    P := FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
    NewImageY := P.Y;
    NewImageH := Img.Height;
    NewScrollPos := FScroll.VertScrollBar.Position + NewImageY +
      Round(AnchorRatio * NewImageH) - AnchorScreenY;
    MaxScrollPos := Max(0, FScroll.VertScrollBar.Range - FScroll.ClientHeight);
    FScroll.VertScrollBar.Position := EnsureRange(NewScrollPos, 0, MaxScrollPos);
  end;

  FLastScrollPosition := FScroll.VertScrollBar.Position;
  UpdateVisiblePage;
  // 3b.63: Bildgroesse hat sich geaendert. Rahmengeometrie neu
  // aus PDF-Koordinaten berechnen statt alte Pixelmasse beizubehalten.
  UpdateFormFocusFrame;
end;

procedure TFreePDF64PDFiumView.ZoomIn;
const
  Steps: array[0..17] of Integer =
    (8, 12, 18, 25, 33, 50, 67, 75, 100, 125, 150, 175,
     200, 300, 400, 600, 800, 1000);
var
  I: Integer;
  CurrentPercent, TargetZoom: Double;
begin
  if (FCore = nil) or (FCore.PageCount = 0) or (FZoom <= 0) then Exit;
  CurrentPercent := FZoom * 7200.0 / CurrentPPI;
  for I := Low(Steps) to High(Steps) do
    if Steps[I] > CurrentPercent + 0.01 then
    begin
      TargetZoom := Steps[I] * CurrentPPI / 7200.0;
      ZoomByFactor(TargetZoom / FZoom);
      Exit;
    end;
end;

procedure TFreePDF64PDFiumView.ZoomOut;
const
  Steps: array[0..17] of Integer =
    (8, 12, 18, 25, 33, 50, 67, 75, 100, 125, 150, 175,
     200, 300, 400, 600, 800, 1000);
var
  I: Integer;
  CurrentPercent, TargetZoom: Double;
begin
  if (FCore = nil) or (FCore.PageCount = 0) or (FZoom <= 0) then Exit;
  CurrentPercent := FZoom * 7200.0 / CurrentPPI;
  for I := High(Steps) downto Low(Steps) do
    if Steps[I] < CurrentPercent - 0.01 then
    begin
      TargetZoom := Steps[I] * CurrentPPI / 7200.0;
      ZoomByFactor(TargetZoom / FZoom);
      Exit;
    end;
end;

procedure TFreePDF64PDFiumView.Zoom100Click(Sender: TObject);
begin
  // Nicht einfach den Ansichtsmodus wechseln: das wuerde die
  // aktuelle Scrollposition neu berechnen und die sichtbare Stelle verlieren.
  // Stattdessen relativ auf 100 % zoomen und den sichtbaren Seitenanker
  // durch die vorhandene ZoomByFactor-Routine erhalten.
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  if FZoom <= 0 then Exit;
  // PDF-Seitengroessen sind in Punkten (72 dpi). Das Layout berechnet
  // Pixel aus Punkten * FZoom. 100 % auf einem Windows-Bildschirm muss
  // daher die Punkte in Bildschirm-Pixel umrechnen (typisch 96/72).
  // Der bisherige Wert 1.0 stellte nur 72/96 = 75 % dar.
  if Abs(FZoom - (CurrentPPI / 72.0)) > 0.0001 then
    ZoomByFactor((CurrentPPI / 72.0) / FZoom)
  else
  begin
    FFitMode := False;
    FViewMode := 2;
    if FViewSelect <> nil then FViewSelect.ItemIndex := 2;
    PaintPage;
  end;
  FViewMode := 2;
  if FViewSelect <> nil then FViewSelect.ItemIndex := 2;
  // Die Prozentanzeige bezieht sich auf die tatsaechliche 100-%-Groesse.
  if FZoomStatus <> nil then FZoomStatus.Caption := '100%';
end;

procedure TFreePDF64PDFiumView.ZoomClick(Sender: TObject);
var
  ClickedButton: TObject;
begin
  // Die PNG-Grafik ist ein TImage innerhalb des TButton. Beim Klick
  // liefert VCL das TImage als Sender, nicht den zugehoerigen Button.
  // Daher zuerst den eigentlichen Button ermitteln.
  ClickedButton := Sender;
  if Sender is TImage then
    ClickedButton := TImage(Sender).Parent;

  if ClickedButton = FMinus then
    ZoomIn
  else if ClickedButton = FPlus then
    ZoomOut;
end;

procedure TFreePDF64PDFiumView.FitClick(Sender: TObject);
var
  KeepPage, I, AnchorY, ImageTop, ImageHeight: Integer;
  BestDistance, Distance, TargetY, MaxScrollY: Integer;
  KeepRatio: Double;
  Img: TPDFiumImage;
  P: TPoint;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;

  // Nach WM_SIZE kann FPage noch auf der zuletzt gemeldeten Seite stehen,
  // obwohl im ScrollBox-Viewport bereits eine andere Seite sichtbar ist.
  // Daher den Anker aus den tatsaechlichen Control-Positionen bestimmen.
  KeepPage := EnsureRange(FPage, 0, FCore.PageCount - 1);
  AnchorY := FScroll.ClientHeight div 2;
  KeepRatio := 0.5;
  if FContinuous then
  begin
    BestDistance := MaxInt;
    for I := 0 to FPages.Count - 1 do
    begin
      Img := PageImage(I);
      if (Img = nil) or (not Img.Visible) or (Img.Height <= 1) then Continue;
      P := FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
      ImageTop := P.Y;
      ImageHeight := Img.Height;
      if AnchorY < ImageTop then
        Distance := ImageTop - AnchorY
      else if AnchorY >= ImageTop + ImageHeight then
        Distance := AnchorY - (ImageTop + ImageHeight) + 1
      else
        Distance := 0;
      if Distance < BestDistance then
      begin
        BestDistance := Distance;
        KeepPage := I;
        KeepRatio := (AnchorY - ImageTop) / ImageHeight;
        KeepRatio := Max(0.0, Min(1.0, KeepRatio));
        if Distance = 0 then Break;
      end;
    end;
  end;

  // Ein noch ausstehender Resize-Timer darf die neue Fit-Position nicht
  // spaeter mit einer alten Scrollposition wieder ueberschreiben.
  FResizePending := False;
  FPage := KeepPage;
  FFitMode := True;
  FViewMode := 1;
  FViewSelect.ItemIndex := 1;
  FScroll.HorzScrollBar.Position := 0;
  PaintPage;

  // Nicht ShowPage verwenden: das wuerde die Seite an den oberen Rand
  // springen lassen. Den gleichen relativen Seitenpunkt im Viewport halten.
  if FContinuous then
  begin
    Img := PageImage(KeepPage);
    if (Img <> nil) and (Img.Height > 1) then
    begin
      P := FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
      TargetY := FScroll.VertScrollBar.Position + P.Y +
        Round(KeepRatio * Img.Height) - AnchorY;
      MaxScrollY := Max(0, FScroll.VertScrollBar.Range - FScroll.ClientHeight);
      FScroll.VertScrollBar.Position := EnsureRange(TargetY, 0, MaxScrollY);
    end;
  end;
  FScroll.HorzScrollBar.Position := 0;
  FLastScrollPosition := FScroll.VertScrollBar.Position;
  FRenderPending := True;
  if not FPageEdit.Focused then
    FPageEdit.Text := IntToStr(FPage + 1);
  FPageTotal.Caption := Format('/ %d', [FCore.PageCount]);
  UpdateThumbnailSelection;
end;


procedure TFreePDF64PDFiumView.RefreshLanguage;
var
  I: Integer;
begin
  // Refresh every hint and child control, then explicitly reset the toolbar
  // captions from their German source strings so repeated language changes work.
  TranslatePDFControls(Self);
  FPrev.Caption := '◀';
  FNext.Caption := '▶';
  FGoPage.Caption := Tr('Gehe zu');
  FStatus.Caption := ToolbarHint('Seite:', 'Page:');
  FFit.Caption := '';
  FZoom100Button.Caption := '100 %';
  FMinus.Hint := ToolbarHint('Vergrößern', 'Zoom in');
  FPlus.Hint := ToolbarHint('Verkleinern', 'Zoom out');
  FPrint.Caption := '🖨';
  FColorButton.Caption := Tr('Farbe ...');
  if FNoteButton <> nil then
  begin
    FNoteButton.Caption := ToolbarHint('Kommentar', 'Comment');
    FNoteButton.Hint := ToolbarHint('Textkommentar einfügen', 'Insert text comment');
  end;
  if FTextUndoButton <> nil then FTextUndoButton.Hint := ToolbarHint('Rückgängig', 'Undo');
  if FTextRedoButton <> nil then FTextRedoButton.Hint := ToolbarHint('Wiederholen', 'Redo');
  FQuickSave.Caption := ''; // Symbol wird monochrom gezeichnet
  if FSavePopup <> nil then
  begin
    FSavePopup.Items[0].Caption := ToolbarHint('PDF speichern unter ...', 'Save PDF As ...');
    FSavePopup.Items[1].Caption := ToolbarHint('Seiten als Bilder exportieren ...', 'Export Pages as Images ...');
  end;
  UpdateSaveState;
  UpdateTwoPageIcon();
  if FTwoPageButton <> nil then
  begin
    if FTwoPage then
      FTwoPageButton.Hint := ToolbarHint('Doppelseitenansicht: zur Einzelseite wechseln',
        'Two-page view: switch to single-page view')
    else
      FTwoPageButton.Hint := ToolbarHint('Einzelseitenansicht: zur Doppelseite wechseln',
        'Single-page view: switch to two-page view');
  end;
  FFlowToggleButton.Caption := '☷';
  if FViewSelect <> nil then
  begin
    I := FViewSelect.ItemIndex;
    FViewSelect.Items.BeginUpdate;
    try
      FViewSelect.Items.Clear;
      FViewSelect.Items.Add(Tr('Seitenbreite'));
      FViewSelect.Items.Add(Tr('Ganze Seite'));
      FViewSelect.Items.Add(Tr('Originalgröße (100 %)'));
      FViewSelect.Items.Add(Tr('Benutzerdefiniert'));
      FViewSelect.ItemIndex := EnsureRange(I, 0, FViewSelect.Items.Count - 1);
    finally
      FViewSelect.Items.EndUpdate;
    end;
  end;
  if FFlowToggleButton <> nil then
  begin
    if FContinuous then
    begin
      FFlowToggleButton.Caption := '☷';
      FFlowToggleButton.Hint := ToolbarHint('Durchgehend: zu seitenweiser Anzeige wechseln', 'Continuous view: switch to page-by-page view');
    end
    else
    begin
      FFlowToggleButton.Caption := '▤';
      FFlowToggleButton.Hint := ToolbarHint('Seitenweise: zu durchgehender Anzeige wechseln', 'Page-by-page view: switch to continuous view');
    end;
  end;
  if FFlowSelect <> nil then
  begin
    I := FFlowSelect.ItemIndex;
    FFlowSelect.Items.BeginUpdate;
    try
      FFlowSelect.Items.Clear;
      FFlowSelect.Items.Add(Tr('Durchgehend'));
      FFlowSelect.Items.Add(Tr('Seitenweise'));
      FFlowSelect.ItemIndex := EnsureRange(I, 0, FFlowSelect.Items.Count - 1);
    finally
      FFlowSelect.Items.EndUpdate;
    end;
  end;
  // Sprachwechsel des Hauptfensters wird bereits ueber
  // TPDFBrowserForm.RefreshLanguage an diese Methode weitergegeben.
  if FThumbTab <> nil then
  begin
    FThumbTab.Caption := Tr('Seiten');
  end;
  if FBookmarksTab <> nil then FBookmarksTab.Caption := Tr('Inhalte');
  if FThumbMenu <> nil then RefreshThumbMenuCaptions;
  if FManageLinksMenuItem <> nil then
    FManageLinksMenuItem.Caption := ToolbarHint('Hyperlinks verwalten ...', 'Manage hyperlinks ...');
  if FLinkMenuItem <> nil then
    FLinkMenuItem.Caption := ToolbarHint('Hyperlink hinzufügen ...', 'Add hyperlink ...');
  if (FManageLinksMenuItem <> nil) and (FThumbMenu <> nil) and
     (FManageLinksMenuItem.MenuIndex + 1 < FThumbMenu.Items.Count) then
    FThumbMenu.Items[FManageLinksMenuItem.MenuIndex + 1].Caption :=
      ToolbarHint('Kommentare verwalten ...', 'Manage comments ...');
  if FWatermarkMenuItem <> nil then
    FWatermarkMenuItem.Caption := Tr('Textwasserzeichen hinzufügen ...');
  if FImageWatermarkMenuItem <> nil then
    FImageWatermarkMenuItem.Caption := Tr('Bildwasserzeichen hinzufügen ...');
  if FSignatureMenuItem <> nil then
    FSignatureMenuItem.Caption := ToolbarHint('Unterschrift hinzufügen ...', 'Add signature ...');
  if FMeasureScaleMenuItem <> nil then
    FMeasureScaleMenuItem.Caption := ToolbarHint('Maßstab ...', 'Scale ...');
  if FInsertLinkItem <> nil then
    FInsertLinkItem.Caption := ToolbarHint('Hyperlink hinzufügen ...', 'Add hyperlink ...');
  if FInsertSignatureItem <> nil then
    FInsertSignatureItem.Caption := ToolbarHint('Unterschrift hinzufügen ...', 'Add signature ...');
  if FInsertImageWatermarkItem <> nil then
    FInsertImageWatermarkItem.Caption := ToolbarHint('Bildwasserzeichen hinzufügen ...', 'Add image watermark ...');
  if FInsertTextWatermarkItem <> nil then
    FInsertTextWatermarkItem.Caption := ToolbarHint('Textwasserzeichen hinzufügen ...', 'Add text watermark ...');
  if FInsertManageLinksItem <> nil then
    FInsertManageLinksItem.Caption := ToolbarHint('Hyperlinks verwalten ...', 'Manage hyperlinks ...');
  if FInsertManageCommentsItem <> nil then
    FInsertManageCommentsItem.Caption := ToolbarHint('Kommentare verwalten ...', 'Manage comments ...');
  if FOutlineMenu <> nil then OutlineMenuPopup(nil);
  LayoutToolbar(nil);
end;

procedure TFreePDF64PDFiumView.ShapeSelectChange(Sender: TObject);
begin
  // Trennlinien sind keine Werkzeuge. Zur letzten gültigen Auswahl zurückkehren.
  if FShapeSelect = nil then Exit;
  if FShapeSelect.ItemIndex in [4, 7] then
    FShapeSelect.ItemIndex := 0;

  // Schwaerzungswerkzeuge duerfen nicht vom aktiven Text-Hervorheben
  // abgefangen werden. Sonst wird beim MouseUp FMarkColor verwendet.
  if FShapeSelect.ItemIndex in [5, 6] then
  begin
    if FHighlightMode then
    begin
      FHighlightMode := False;
      if FHighlightButton <> nil then
        FHighlightButton.Caption := ToolbarHint('Text hervorheben', 'Highlight text');
    end;
    FMarkMode := FEditVisible and not FTextInsertMode and not FNoteMode;
  end;

  if FRedactionFinalizeButton <> nil then
  begin
    FRedactionFinalizeButton.SetAccentOrange(FEditVisible and
      (FShapeSelect.ItemIndex = 6));
    // Button bleibt sichtbar; nur die orange Hervorhebung wird zurückgesetzt.
  end;

  case FShapeSelect.ItemIndex of
    5: FShapeSelect.Hint := ToolbarHint(
         'Schwärzen (optisch): Deckt den markierten Bereich schwarz ab. Der ursprüngliche PDF-Inhalt wird nicht entfernt.',
         'Optical redaction: Covers the selected area in black. The original PDF content is not removed.');
    6: FShapeSelect.Hint := ToolbarHint(
         'Schwärzung (Vorschau): Markiert einen Bereich für die spätere dauerhafte Schwärzung. Der PDF-Inhalt wird noch nicht entfernt. Entf entfernt die letzte Vormerkung; ESC löscht alle Vormerkungen.',
         'Redaction preview: Marks an area for later permanent redaction. PDF content is not removed yet. Delete removes the last preview; Esc clears all previews.');
  else
    FShapeSelect.Hint := ToolbarHint(
      'Zeichenwerkzeug auswählen', 'Select drawing tool');
  end;
  if (FRedactionFinalizeButton <> nil) and (FBar <> nil) then
  begin
    UpdateTextUndoButtons;
    LayoutToolbar(nil);
  end;
end;

procedure TFreePDF64PDFiumView.ViewModeChange(Sender: TObject);
begin
  FViewMode := FViewSelect.ItemIndex;
  FFitMode := FViewMode in [0, 1];
  if FViewMode = 2 then FZoom := CurrentPPI / 72.0;
  PaintPage;
end;

procedure TFreePDF64PDFiumView.UpdateTwoPageIcon;
var
  B: TBitmap;
  IconSize, Dpi, X, Y, W, H, PenW, Gap: Integer;
  procedure DrawPage(AX: Integer);
  begin
    B.Canvas.Brush.Style := bsClear;
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := PenW;
    B.Canvas.Rectangle(AX, Y, AX + W, Y + H);
  end;
begin
  if (FTwoPageIcon = nil) or (FTwoPageButton = nil) then Exit;
  Dpi := Max(96, CurrentPPI);
  IconSize := MulDiv(24, Dpi, 96);
  B := TBitmap.Create;
  try
    // Direkt in Zielaufloesung zeichnen: kein StretchDraw und keine
    // weissen Raender/Pixel durch die Transparenzmaske.
    B.PixelFormat := pf24bit;
    B.SetSize(IconSize, IconSize);
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, IconSize, IconSize));
    B.TransparentColor := clFuchsia;
    B.TransparentMode := tmFixed;
    B.Transparent := True;
    PenW := Max(1, MulDiv(2, Dpi, 96));
    H := MulDiv(17, Dpi, 96);
    Y := (IconSize - H) div 2;
    if FTwoPage then
    begin
      W := MulDiv(8, Dpi, 96);
      Gap := MulDiv(3, Dpi, 96);
      X := (IconSize - (W * 2 + Gap)) div 2;
      DrawPage(X);
      DrawPage(X + W + Gap);
    end
    else
    begin
      W := MulDiv(13, Dpi, 96);
      X := (IconSize - W) div 2;
      DrawPage(X);
    end;
    FTwoPageIcon.Picture.Bitmap.Assign(B);
    FTwoPageIcon.Transparent := True;
    FTwoPageIcon.Stretch := False;
    FTwoPageIcon.SetBounds((FTwoPageButton.Width - IconSize) div 2,
      (FTwoPageButton.Height - IconSize) div 2, IconSize, IconSize);
  finally
    B.Free;
  end;
end;

procedure TFreePDF64PDFiumView.TwoPageClick(Sender: TObject);
begin
  FTwoPage := not FTwoPage;
  if FTwoPage then
  begin
    UpdateTwoPageIcon;
    FTwoPageButton.Hint := ToolbarHint('Doppelseitenansicht: zur Einzelseite wechseln',
      'Two-page view: switch to single-page view');
  end
  else
  begin
    UpdateTwoPageIcon;
    FTwoPageButton.Hint := ToolbarHint('Einzelseitenansicht: zur Doppelseite wechseln',
      'Single-page view: switch to two-page view');
  end;
  PaintPage;
end;

procedure TFreePDF64PDFiumView.FlowToggleClick(Sender: TObject);
begin
  FFlowSelect.ItemIndex := Ord(FContinuous);
  FlowModeChange(Sender);
end;

procedure TFreePDF64PDFiumView.FlowModeChange(Sender: TObject);
var
  KeepPage: Integer;
begin
  if FFlowSelect.ItemIndex = 0 then
  begin
    FFlowToggleButton.Caption := '☷';
    FFlowToggleButton.Hint := ToolbarHint('Durchgehend: zu seitenweiser Anzeige wechseln', 'Continuous view: switch to page-by-page view');
  end
  else
  begin
    FFlowToggleButton.Caption := '▤';
    FFlowToggleButton.Hint := ToolbarHint('Seitenweise: zu durchgehender Anzeige wechseln', 'Page-by-page view: switch to continuous view');
  end;
  if FCore.PageCount = 0 then
  begin
    FContinuous := FFlowSelect.ItemIndex = 0;
    Exit;
  end;
  if FContinuous = (FFlowSelect.ItemIndex = 0) then Exit;
  // Der Anzeigemodus ist keine Seitennavigation. Die zuletzt sichtbare
  // PDF-Seite bleibt beim Wechsel zwischen beiden Modi erhalten.
  KeepPage := EnsureRange(FPage, 0, FCore.PageCount - 1);
  FContinuous := FFlowSelect.ItemIndex = 0;
  FPage := KeepPage;
  // Beide Modi benoetigen ein neues Layout. ShowPage allein aktualisiert
  // im durchgehenden Modus nur bei noch nicht aufgebauten Seiten.
  // Synchrones PDFium-Rendering waehrend des Umschaltens vermeiden:
  // der Render-Timer uebernimmt das sichtbare Seitenbild anschliessend.
  FResizePending := True;
  FLastResizeTick := GetTickCount64;
  try
    LayoutAllPages;
    ShowPage(KeepPage);
  finally
    FResizePending := False;
    FRenderPending := True;
  end;
end;

procedure TFreePDF64PDFiumView.ToggleOutline(Sender: TObject);
var V: TFreePDF64PDFiumView;
begin
  FOutlinePanel.Visible := not FOutlinePanel.Visible;
  FOutlineSplitter.Visible := FOutlinePanel.Visible;
  if FOutlinePanel.Visible then
  begin
    FScroll.SendToBack;
    FOutlinePanel.BringToFront;
    FOutlineSplitter.BringToFront;
    FOutlineSplitter.Left := FOutlinePanel.Left + FOutlinePanel.Width;
    // Nur die aktive Seitenleistenansicht aufbauen.
    // Das Inhaltsverzeichnis wurde beim schnellen PDF-Start absichtlich
    // nicht mehr geladen und muss hier bei Bedarf nachgeholt werden.
    if FOutlineTree.Visible then
      PopulateOutline
    else
    begin
      if (FThumbImages.Count = 0) and (FCore.PageCount > 0) then
        BuildThumbnails;
      ThumbAreaResize(nil);
      ScrollThumbnailToCurrentPage;
    end;
  end;
  // Only user-initiated sidebar clicks update the global preference.
  // Programmatic calls (Sender=nil) must not overwrite the saved value.
  if (Sender <> nil) and not GThumbnailSplitMode then
  begin
    LoadGlobalThumbnails;
    GThumbnailsVisible := FOutlinePanel.Visible and FThumbScroll.Visible;
    SaveGlobalThumbnails;
    if GThumbnailViews <> nil then
      for V in GThumbnailViews do
        if V <> Self then V.SetPageThumbnailsVisible(GThumbnailsVisible);
  end;
end;

procedure TFreePDF64PDFiumView.ShowOutlineTab(AThumbnails: Boolean);
begin
  FThumbScroll.Visible := AThumbnails;
  FOutlineTree.Visible := not AThumbnails;
  if AThumbnails then
  begin
    FThumbScroll.BringToFront;
    if FOutlinePanel.Visible and (FCore.PageCount > 0) and
       (FThumbImages.Count = 0) then
      BuildThumbnails;
    if FOutlinePanel.Visible then
    begin
      ThumbAreaResize(nil);
      ScrollThumbnailToCurrentPage;
    end;
  end
  else
  begin
    FOutlineTree.BringToFront;
    if FOutlinePanel.Visible then PopulateOutline;
  end;
end;

procedure TFreePDF64PDFiumView.OutlineTabClick(Sender: TObject);
var V: TFreePDF64PDFiumView;
begin
  ShowOutlineTab(TButton(Sender).Tag = 1);
  if not GThumbnailSplitMode then
  begin
    LoadGlobalThumbnails;
    GThumbnailsVisible := FOutlinePanel.Visible and FThumbScroll.Visible;
    SaveGlobalThumbnails;
    if GThumbnailViews <> nil then
      for V in GThumbnailViews do
        if V <> Self then V.SetPageThumbnailsVisible(GThumbnailsVisible);
  end;
end;

procedure TFreePDF64PDFiumView.ThumbClick(Sender: TObject);
var
  Index, I, A, B: Integer;
  Ctrl, ShiftDown: Boolean;
begin
  if FThumbSuppressClick then
  begin
    FThumbSuppressClick := False;
    Exit;
  end;
  if not (Sender is TControl) then Exit;
  Index := TControl(Sender).Tag;
  Ctrl := GetKeyState(VK_CONTROL) < 0;
  ShiftDown := GetKeyState(VK_SHIFT) < 0;
  if not Ctrl and not ShiftDown then FThumbSelected.Clear;
  if ShiftDown and (FThumbAnchor >= 0) then
  begin
    A := Min(FThumbAnchor, Index);
    B := Max(FThumbAnchor, Index);
    for I := A to B do
      if FThumbSelected.IndexOf(I) < 0 then FThumbSelected.Add(I);
  end
  else if Ctrl and (FThumbSelected.IndexOf(Index) >= 0) then
    FThumbSelected.Remove(Index)
  else if FThumbSelected.IndexOf(Index) < 0 then
    FThumbSelected.Add(Index);
  if not ShiftDown then FThumbAnchor := Index;
  UpdateThumbnailSelection;
  // Tastaturfokus auf die Miniaturleiste setzen, damit ESC dort ankommt.
  if FThumbScroll.CanFocus then FThumbScroll.SetFocus;
  // Beim Anklicken einer Miniatur darf die Leiste nicht zur Mitte
  // springen: die Position des Benutzers hat Vorrang.
  FThumbClickNavigation := True;
  FThumbScrollTarget := -1;
  try
    ShowPage(Index);
  finally
    FThumbClickNavigation := False;
    FThumbScrollTarget := -1;
  end;
end;

procedure TFreePDF64PDFiumView.EndThumbDragVisual;
begin
  FreeAndNil(FThumbDropLine);
  FreeAndNil(FThumbGhost);
  FThumbDropTarget := -1;
end;

procedure TFreePDF64PDFiumView.UpdateThumbDragVisual(const ScreenPos: TPoint);
var
  I, MidY, PosY, NewPos, MaxPos: Integer;
  Img, GhostImage: TImage;
  TopP: TPoint;
begin
  if (FThumbDragSource < 0) or (FThumbImages = nil) or
     (FThumbDragSource >= FThumbImages.Count) then Exit;
  if FThumbGhost = nil then
  begin
    Img := TImage(FThumbImages[FThumbDragSource]);
    FThumbGhost := TForm.CreateNew(nil);
    FThumbGhost.BorderStyle := bsNone;
    FThumbGhost.Position := poDesigned;
    FThumbGhost.AlphaBlend := True;
    FThumbGhost.AlphaBlendValue := 170;
    FThumbGhost.Width := Img.Width + 8;
    FThumbGhost.Height := Img.Height + 8;
    FThumbGhost.Color := clWhite;
    GhostImage := TImage.Create(FThumbGhost);
    GhostImage.Parent := FThumbGhost;
    GhostImage.SetBounds(4, 4, Img.Width, Img.Height);
    GhostImage.Stretch := True;
    GhostImage.Proportional := True;
    GhostImage.Center := True;
    GhostImage.Picture.Assign(Img.Picture);
    // Nicht aktivieren: der Maus-Capture bleibt auf der Miniatur-ScrollBox.
    ShowWindow(FThumbGhost.Handle, SW_SHOWNOACTIVATE);
    FThumbDropLine := TShape.Create(FThumbScroll);
    FThumbDropLine.Parent := FThumbScroll;
    FThumbDropLine.Shape := stRectangle;
    FThumbDropLine.Brush.Color := clBlue;
    FThumbDropLine.Pen.Style := psClear;
    FThumbDropLine.Height := 4;
  end;
  SetWindowPos(FThumbGhost.Handle, HWND_TOPMOST,
    ScreenPos.X + 14, ScreenPos.Y + 12, 0, 0,
    SWP_NOSIZE or SWP_NOACTIVATE);
  // Automatisches Scrollen am oberen/unteren Rand.
  TopP := FThumbScroll.ScreenToClient(ScreenPos);
  NewPos := FThumbScroll.VertScrollBar.Position;
  MaxPos := Max(0, FThumbScroll.VertScrollBar.Range - FThumbScroll.ClientHeight);
  if TopP.Y < 26 then Dec(NewPos, 18)
  else if TopP.Y > FThumbScroll.ClientHeight - 26 then Inc(NewPos, 18);
  FThumbScroll.VertScrollBar.Position := EnsureRange(NewPos, 0, MaxPos);
  FThumbDropTarget := FThumbImages.Count - 1;
  for I := 0 to FThumbImages.Count - 1 do
  begin
    Img := TImage(FThumbImages[I]);
    TopP := Img.ClientToScreen(Point(0, 0));
    MidY := TopP.Y + Img.Height div 2;
    if ScreenPos.Y < MidY then
    begin
      FThumbDropTarget := I;
      Break;
    end;
  end;
  Img := TImage(FThumbImages[FThumbDropTarget]);
  TopP := FThumbScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
  PosY := TopP.Y - 5;
  if FThumbDropTarget > FThumbDragSource then
    PosY := TopP.Y + Img.Height + 4;
  FThumbDropLine.SetBounds(4, PosY, Max(20, FThumbScroll.ClientWidth - 12), 4);
  FThumbDropLine.BringToFront;
end;

procedure TFreePDF64PDFiumView.ThumbMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Index: Integer;
begin
  if not (Sender is TControl) then Exit;
  Index := TControl(Sender).Tag;
  if Button = mbLeft then
  begin
    FThumbDragSource := -1;
    FThumbDragging := False;
    EndThumbDragVisual;
    FThumbSuppressClick := False;
    // Bei Strg/Umschalt wird kein Drag-Capture eingerichtet.
    // Die Auswahl direkt bei MouseDown aktualisieren, da MouseUp
    // ohne DragSource sonst sofort beendet wird.
    if (ssCtrl in Shift) or (ssShift in Shift) then
    begin
      ThumbClick(Sender);
      Exit;
    end;
    // Bei bestehender Mehrfachauswahl muss ein einfacher Linksklick
    // sofort die alte Auswahl aufheben und nur diese Seite markieren.
    // Ohne Drag-Capture wuerde ThumbMouseUp sonst vorzeitig enden.
    if FThumbSelected.Count > 1 then
    begin
      ThumbClick(Sender);
      // Ein eventuell nachfolgendes OnClick nicht doppelt auswerten.
      FThumbSuppressClick := True;
      Exit;
    end;
    if FThumbSelected.Count <= 1 then
    begin
      FThumbDragSource := Index;
      FThumbDragStart := TControl(Sender).ClientToScreen(Point(X, Y));
      // TImage/TLabel besitzen kein eigenes HWND. Capture deshalb am
      // gemeinsamen ScrollBox-Fenster halten, auch ausserhalb der Miniatur.
      Winapi.Windows.SetCapture(FThumbScroll.Handle);
    end;
    Exit;
  end;
  if Button <> mbRight then Exit;
  FThumbDragSource := -1;
  EndThumbDragVisual;
  if GetCapture = FThumbScroll.Handle then ReleaseCapture;
  if FThumbSelected.IndexOf(Index) < 0 then
  begin
    FThumbSelected.Clear;
    FThumbSelected.Add(Index);
    FThumbAnchor := Index;
  end;
  UpdateThumbnailSelection;
end;

procedure TFreePDF64PDFiumView.ThumbMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  if FThumbDragSource < 0 then Exit;
  if (GetAsyncKeyState(VK_ESCAPE) < 0) or not (ssLeft in Shift) then
  begin
    FThumbDragSource := -1;
    FThumbDragging := False;
    EndThumbDragVisual;
    if GetCapture = FThumbScroll.Handle then ReleaseCapture;
    Exit;
  end;
  GetCursorPos(P);
  if not FThumbDragging then
    FThumbDragging := (Abs(P.X - FThumbDragStart.X) >= GetSystemMetrics(SM_CXDRAG)) or
      (Abs(P.Y - FThumbDragStart.Y) >= GetSystemMetrics(SM_CYDRAG));
  if FThumbDragging then UpdateThumbDragVisual(P);
end;

procedure TFreePDF64PDFiumView.ThumbMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  SourceIndex, TargetIndex, I, Step: Integer;
  WasDragging: Boolean;
  SourceControl: TControl;
  P, TopP, BottomP: TPoint;
  MenuItem: TMenuItem;
begin
  if (Button <> mbLeft) or not (Sender is TControl) then Exit;
  SourceControl := TControl(Sender);
  SourceControl.Cursor := crDefault;
  SourceIndex := FThumbDragSource;
  WasDragging := FThumbDragging;
  TargetIndex := FThumbDropTarget;
  EndThumbDragVisual;
  FThumbDragSource := -1;
  FThumbDragging := False;
  // Capture vor der Seitenverschiebung freigeben: diese aktualisiert Controls.
  if GetCapture = FThumbScroll.Handle then ReleaseCapture;
  if SourceIndex < 0 then Exit;
  if not WasDragging then
  begin
    // OnClick wird bei Capture auf der ScrollBox nicht sicher ausgeloest.
    // Die einfache Seitennavigation deshalb hier explizit ausfuehren.
    if SourceIndex < FThumbImages.Count then
      ThumbClick(TImage(FThumbImages[SourceIndex]));
    Exit;
  end;
  FThumbSuppressClick := False;
  if (FCore = nil) or (FThumbImages.Count = 0) then Exit;
  GetCursorPos(P);
  // Die Zielposition anhand der sichtbaren Miniaturen ermitteln.
  // Ausserhalb des Bereichs wird die erste/letzte aufgebaute Miniatur verwendet.
  if TargetIndex < 0 then TargetIndex := FThumbImages.Count - 1;
  for I := 0 to FThumbImages.Count - 1 do
  begin
    TopP := TImage(FThumbImages[I]).ClientToScreen(Point(0, 0));
    BottomP := TImage(FThumbImages[I]).ClientToScreen(
      Point(0, TImage(FThumbImages[I]).Height));
    if P.Y < (TopP.Y + BottomP.Y) div 2 then
    begin
      TargetIndex := I;
      Break;
    end;
  end;
  if (SourceIndex = TargetIndex) or (TargetIndex >= FCore.PageCount) then Exit;
  // Die bereits abgenommene Verschiebe-Routine arbeitet mit Nachbarseiten.
  // Mehrere Schritte erhalten die richtige Reihenfolge ohne neue PDF-Logik.
  if TargetIndex > SourceIndex then Step := 1 else Step := -1;
  FThumbSelected.Clear;
  FThumbSelected.Add(SourceIndex);
  FThumbAnchor := SourceIndex;
  MenuItem := TMenuItem.Create(nil);
  try
    MenuItem.Tag := Step;
    I := SourceIndex;
    while I <> TargetIndex do
    begin
      MoveSelectedThumb(MenuItem);
      if (FThumbSelected.Count <> 1) or (FThumbSelected[0] <> I + Step) then Break;
      Inc(I, Step);
    end;
  finally
    MenuItem.Free;
  end;
end;

procedure TFreePDF64PDFiumView.UpdateSaveState;
  procedure SetButtonState(B: TPDFiumSaveButton);
  begin
    if B = nil then Exit;
    if HasUnsavedChanges then
    begin
      B.Highlighted := True;
      B.Caption := ''; // Schwarzer Statuspunkt wird im Symbol gezeichnet
      B.Font.Style := [fsBold];
      B.Hint := ToolbarHint('Speichern unter ... (Strg+S) – Änderungen nicht gespeichert', 'Save As ... (Ctrl+S) – Unsaved changes');
    end
    else
    begin
      B.Highlighted := False;
      B.Caption := ''; // Schwarz-weisses Diskettensymbol
      B.Font.Style := [];
      B.Hint := ToolbarHint('Speichern unter ... (Strg+S)', 'Save As ... (Ctrl+S)');
    end;
    B.ShowHint := True;
    B.Invalidate;
  end;
begin
  SetButtonState(FQuickSave);
  if FReloadMenuItem <> nil then FReloadMenuItem.Enabled := (FCore <> nil) and (FCore.FileName <> '') and FileExists(FCore.FileName);
end;

procedure TFreePDF64PDFiumView.MoveSelectedThumb(Sender: TObject);
var
  Index, Target, I: Integer;
  Img: TPDFiumImage;
  SwapPicture: TPicture;
  WasLoaded: Boolean;
  PageW, PageH: Single;
  SizeValid: Boolean;
  Busy: TForm;
  OldRenderTimer, OldThumbTimer: Boolean;
  NeedsLayout: Boolean;
begin
  if (FThumbSelected.Count <> 1) or (FCore = nil) then Exit;
  Index := FThumbSelected[0];
  Target := Index + TMenuItem(Sender).Tag;
  if (Target < 0) or (Target >= FCore.PageCount) then Exit;
  OldThumbTimer := FThumbTimer.Enabled;
  OldRenderTimer := FRenderTimer.Enabled;
  Busy := ShowPDFBusyNotice('Seite wird verschoben.');
  FThumbTimer.Enabled := False;
  FRenderTimer.Enabled := False;
  try
    try
    // QPDF schreibt die PDF neu und oeffnet sie erneut. Solange dies
    // geschieht, keine Layout- oder Miniatur-Timer laufen lassen.
    // Keine vollstaendige PDF-Sicherung vor der Aktion mehr.
    NeedsLayout := (Index < Length(FPageWidths)) and
      (Target < Length(FPageWidths)) and
      ((FPageWidths[Index] <> FPageWidths[Target]) or
       (FPageHeights[Index] <> FPageHeights[Target]));
    // Nur die virtuelle Seitenzuordnung aendern, keine QPDF-Datei schreiben.
    FCore.MovePage(Index, Target);
    FPage := Target;
    FThumbSelected.Clear;
    FThumbSelected.Add(Target);
    FThumbAnchor := Target;

    // Unveraenderte Seiten und ihre gerenderten Bitmaps bleiben erhalten.
    // Nur die zwei getauschten Positionen muessen ihre Bilder tauschen.
    if (Index < FPages.Count) and (Target < FPages.Count) then
    begin
      SwapPicture := TPicture.Create;
      try
        SwapPicture.Assign(PageImage(Index).Picture);
        PageImage(Index).Picture.Assign(PageImage(Target).Picture);
        PageImage(Target).Picture.Assign(SwapPicture);
      finally
        SwapPicture.Free;
      end;
    end;
    if (Index < Length(FLoadedPages)) and
       (Target < Length(FLoadedPages)) then
    begin
      WasLoaded := FLoadedPages[Index];
      FLoadedPages[Index] := FLoadedPages[Target];
      FLoadedPages[Target] := WasLoaded;
    end;
    if (Index < Length(FPageSizesValid)) and
       (Target < Length(FPageSizesValid)) then
    begin
      SizeValid := FPageSizesValid[Index];
      FPageSizesValid[Index] := FPageSizesValid[Target];
      FPageSizesValid[Target] := SizeValid;
      PageW := FPageWidths[Index];
      PageH := FPageHeights[Index];
      FPageWidths[Index] := FPageWidths[Target];
      FPageHeights[Index] := FPageHeights[Target];
      FPageWidths[Target] := PageW;
      FPageHeights[Target] := PageH;
    end;
    // Bereits vorhandene Miniatur-Bitmaps direkt vertauschen.
    if (Index >= 0) and (Target >= 0) and
       (Index < FThumbImages.Count) and (Target < FThumbImages.Count) then
    begin
      SwapPicture := TPicture.Create;
      try
        SwapPicture.Assign(TImage(FThumbImages[Index]).Picture);
        TImage(FThumbImages[Index]).Picture.Assign(
          TImage(FThumbImages[Target]).Picture);
        TImage(FThumbImages[Target]).Picture.Assign(SwapPicture);
      finally
        SwapPicture.Free;
      end;
    end;
    UpdateThumbnailSelection;
    SetLength(FSearchMatches, 0);
    FSearchRunning := False;
    FFindTerm := '';
    UpdateSaveState;
    // Einmalige Layoutkorrektur ohne kompletten Seiten-Neuaufbau.
    // Bestehendes Layout nur bei unterschiedlichem Seitenformat anpassen.
    if NeedsLayout then LayoutAllPages;
    ShowPage(Target);
    // PDF-Gliederung nur bei tatsaechlich geoeffnetem Inhaltsverzeichnis.
    if FOutlineTree.Visible then PopulateOutline;
  except
    on E: Exception do
      PDFModernMessageDlg(Tr('Seite konnte nicht verschoben werden: ') +
        E.Message, mtError, [mbOK], 0);
    end;
  finally
    Busy.Free;
    FThumbTimer.Enabled := OldThumbTimer and FThumbScroll.Visible and
      (FCore.PageCount > 0);
    FRenderTimer.Enabled := OldRenderTimer;
  end;
end;

procedure TFreePDF64PDFiumView.ExtractSelectedThumbs(Sender: TObject);
var
  D: TSaveDialog;
  Pages: TArray<Integer>;
  I, J, Temp: Integer;
begin
  if (FCore = nil) or (FCore.PageCount = 0) or
     (FThumbSelected.Count = 0) then Exit;
  Pages := FThumbSelected.ToArray;
  for I := 0 to High(Pages) do
    for J := I + 1 to High(Pages) do
      if Pages[J] < Pages[I] then
      begin
        Temp := Pages[I]; Pages[I] := Pages[J]; Pages[J] := Temp;
      end;
  D := TSaveDialog.Create(Self);
  try
    D.Title := Tr('Ausgewählte PDF-Seiten extrahieren');
    D.Filter := Tr('PDF-Dateien (*.pdf)') + '|*.pdf';
    D.DefaultExt := 'pdf';
    D.Options := D.Options + [ofOverwritePrompt, ofPathMustExist];
    D.InitialDir := ExtractFilePath(FCore.FileName);
    D.FileName := ChangeFileExt(ExtractFileName(FCore.FileName), '_Seiten.pdf');
    if not D.Execute then Exit;
    if SameText(ExpandFileName(D.FileName), ExpandFileName(FCore.FileName)) then
    begin
      PDFModernMessageDlg(Tr('Bitte einen anderen Dateinamen wählen.'),
        mtWarning, [mbOK], 0);
      Exit;
    end;
    try
      FCore.ExportPages(Pages, D.FileName);
      PDFModernMessageDlg(Format(Tr('%d Seite(n) gespeichert.'), [Length(Pages)]),
        mtInformation, [mbOK], 0);
    except
      on E: Exception do
        PDFModernMessageDlg(Tr('Extrahieren fehlgeschlagen: ') + E.Message,
          mtError, [mbOK], 0);
    end;
  finally
    D.Free;
  end;
end;

procedure TFreePDF64PDFiumView.InsertPDFAtThumbnail(Sender: TObject);
var
  D: TOpenDialog;
  Target, BeforeCount: Integer;
  WasRenderTimerEnabled, WasThumbResizeTimerEnabled: Boolean;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  // Bei Mehrfachauswahl gilt die erste markierte Seite.
  Target := FPage;
  if (Sender is TMenuItem) and
     (TMenuItem(Sender).GetParentMenu = FPageContextMenu) then
    Target := FPage
  else if FThumbSelected.Count > 0 then
  begin
    Target := FThumbSelected[0];
    for BeforeCount := 1 to FThumbSelected.Count - 1 do
      Target := Min(Target, FThumbSelected[BeforeCount]);
  end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = 1) then Inc(Target);
  D := TOpenDialog.Create(Self);
  try
    D.Title := Tr('PDF-Datei zum Einfügen auswählen');
    D.Filter := Tr('PDF-Dateien (*.pdf)') + '|*.pdf';
    D.Options := D.Options + [ofFileMustExist, ofPathMustExist];
    D.InitialDir := ExtractFilePath(FCore.FileName);
    if not D.Execute then Exit;
    // Seitenimport veraendert die PDFium-Seitenstruktur. Solange die
    // Operation laeuft, duerfen keine Timer alte Seiten referenzieren.
    WasRenderTimerEnabled := FRenderTimer.Enabled;
    WasThumbResizeTimerEnabled := FThumbResizeTimer.Enabled;
    FRenderTimer.Enabled := False;
    FThumbTimer.Enabled := False;
    FThumbResizeTimer.Enabled := False;
    try
      try
        // Aktiven Editor vor der Seitenstruktur-Aenderung abschliessen.
      FinishInlineFormEdit(False);
      BeforeCount := FCore.PageCount;
      FCore.ImportPDFPages(D.FileName, Target);
      FThumbSelected.Clear;
      FThumbAnchor := -1;
      FSearchTimer.Enabled := False;
      FSearchRunning := False;
      SetLength(FSearchMatches, 0);
      FFindTerm := '';
      FMatchPage := -1;
      FMatchChar := -1;
      FMatchCount := 0;
      FTotalSearchMatches := 0;
      if Assigned(FOnSearchCountChanged) then FOnSearchCountChanged(Self);
      SetLength(FPageSizesValid, 0);
      SetLength(FLoadedPages, 0);
      FPage := EnsureRange(Target, 0, FCore.PageCount - 1);
      FLayoutPageLimit := Min(1, FCore.PageCount);
      PaintPage;
      PopulateOutline;
      BuildThumbnails;
      ShowPage(FPage);
      UpdateSaveState;
      PDFModernMessageDlg(Format(Tr('%d PDF-Seite(n) eingefügt.'),
        [FCore.PageCount - BeforeCount]), mtInformation, [mbOK], 0);
      except
        on E: Exception do
          PDFModernMessageDlg(Tr('PDF konnte nicht eingefügt werden: ') +
            E.Message, mtError, [mbOK], 0);
      end;
    finally
      FRenderTimer.Enabled := WasRenderTimerEnabled;
      FThumbResizeTimer.Enabled := WasThumbResizeTimerEnabled;
      // Der Miniatur-Timer wird beim erfolgreichen Neuaufbau von
      // BuildThumbnails passend zur neuen Seitenanzahl gestartet.
    end;
  finally
    D.Free;
  end;
end;

procedure TFreePDF64PDFiumView.RefreshThumbMenuCaptions;
begin
  if FThumbMenu = nil then Exit;
  // Feste, sprachunabhaengige Quelltexte: niemals bereits uebersetzte
  // Captions als Schluessel verwenden.
  if FThumbMenu.Items.Count < 13 then Exit;
  FThumbMenu.Items[0].Caption := Tr('Ausgewählte Seite(n) löschen');
  FThumbMenu.Items[2].Caption :=
    ToolbarHint('Ausgewählte Seite(n) 90° nach rechts drehen', 'Rotate selected page(s) 90° right');
  FThumbMenu.Items[3].Caption :=
    ToolbarHint('Ausgewählte Seite(n) 90° nach links drehen', 'Rotate selected page(s) 90° left');
  FMoveUpItem.Caption := Tr('↑ Seite nach oben');
  FMoveDownItem.Caption := Tr('↓ Seite nach unten');
  FExtractItem.Caption := Tr('Seite(n) extrahieren ...');
  FInsertBeforeItem.Caption := Tr('PDF davor einfügen ...');
  FInsertAfterItem.Caption := Tr('PDF danach einfügen ...');
  if FManageLinksMenuItem <> nil then
    FManageLinksMenuItem.Caption := ToolbarHint('Hyperlinks verwalten ...', 'Manage hyperlinks ...');
  if FLinkMenuItem <> nil then
    FLinkMenuItem.Caption := ToolbarHint('Hyperlink hinzufügen ...', 'Add hyperlink ...');
  if (FManageLinksMenuItem <> nil) and (FThumbMenu <> nil) and
     (FManageLinksMenuItem.MenuIndex + 1 < FThumbMenu.Items.Count) then
    FThumbMenu.Items[FManageLinksMenuItem.MenuIndex + 1].Caption :=
      ToolbarHint('Kommentare verwalten ...', 'Manage comments ...');
  if FWatermarkMenuItem <> nil then
    FWatermarkMenuItem.Caption := Tr('Textwasserzeichen hinzufügen ...');
  if FImageWatermarkMenuItem <> nil then
    FImageWatermarkMenuItem.Caption := Tr('Bildwasserzeichen hinzufügen ...');
  if FSignatureMenuItem <> nil then
    FSignatureMenuItem.Caption := ToolbarHint('Unterschrift hinzufügen ...', 'Add signature ...');
  if FRequiredFieldsMenuItem <> nil then
    FRequiredFieldsMenuItem.Caption := Tr('Pflichtfelder prüfen ...') + ' (F7)';
  FReloadMenuItem.Caption :=
    Tr('PDF neu laden (Änderungen verwerfen)');
end;

function AskHyperlinkDetails(AOwner: TComponent; const AEnglish: Boolean;
  out ACaption, ATarget: string): Boolean;
var
  Dlg: TForm;
  L1, L2: TLabel;
  E1, E2: TEdit;
  OKBtn, CancelBtn: TButton;
  PPI: Integer;
  function Px(V: Integer): Integer;
  begin
    Result := MulDiv(V, PPI, 96);
  end;
begin
  Result := False;
  Dlg := TForm.CreateNew(AOwner);
  try
    PPI := Screen.PixelsPerInch;
    if AOwner is TControl then
      PPI := TControl(AOwner).CurrentPPI;
    Dlg.Scaled := False;
    Dlg.Font.Name := 'Segoe UI';
    Dlg.Font.Size := 9;
    Dlg.BorderStyle := bsDialog;
    Dlg.Position := poScreenCenter;
    Dlg.ClientWidth := Px(420);
    Dlg.ClientHeight := Px(172);
    Dlg.Caption := 'Hyperlink hinzufügen';
    if AEnglish then Dlg.Caption := 'Add hyperlink';

    L1 := TLabel.Create(Dlg);
    L1.Parent := Dlg;
    L1.SetBounds(Px(16), Px(12), Px(388), Px(18));
    L1.Caption := 'Anzeigetext:';
    if AEnglish then L1.Caption := 'Display text:';
    E1 := TEdit.Create(Dlg);
    E1.Parent := Dlg;
    E1.SetBounds(Px(16), Px(32), Px(388), Px(25));
    E1.Text := ACaption;
    L2 := TLabel.Create(Dlg);
    L2.Parent := Dlg;
    L2.SetBounds(Px(16), Px(66), Px(388), Px(18));
    L2.Caption := 'Webadresse oder E-Mail-Adresse:';
    if AEnglish then L2.Caption := 'Web address or email address:';
    E2 := TEdit.Create(Dlg);
    E2.Parent := Dlg;
    E2.SetBounds(Px(16), Px(86), Px(388), Px(25));
    E2.Text := ATarget;
    OKBtn := TButton.Create(Dlg);
    OKBtn.Parent := Dlg;
    OKBtn.SetBounds(Px(222), Px(131), Px(85), Px(28));
    OKBtn.Caption := 'OK';
    OKBtn.ModalResult := mrOk;
    OKBtn.Default := True;
    CancelBtn := TButton.Create(Dlg);
    CancelBtn.Parent := Dlg;
    CancelBtn.SetBounds(Px(319), Px(131), Px(85), Px(28));
    CancelBtn.Caption := 'Abbrechen';
    if AEnglish then CancelBtn.Caption := 'Cancel';
    CancelBtn.ModalResult := mrCancel;
    CancelBtn.Cancel := True;
    Dlg.ActiveControl := E1;
    // Bei ungueltiger Eingabe den Dialog offen lassen, damit der Benutzer
    // den fehlerhaften Wert direkt korrigieren kann.
    while Dlg.ShowModal = mrOk do
    begin
      if Trim(E1.Text) = '' then
      begin
        PDFModernMessageDlg(
          ToolbarHint('Bitte einen Anzeigetext eingeben.',
            'Please enter display text.'), mtWarning, [mbOK], 0);
        Dlg.ActiveControl := E1;
        Continue;
      end;
      ATarget := Trim(E2.Text);
      if (Pos('@', ATarget) > 0) and (Pos(':', ATarget) = 0) then
        ATarget := 'mailto:' + ATarget;
      if not ((Pos('https://', LowerCase(ATarget)) = 1) or
              (Pos('http://', LowerCase(ATarget)) = 1) or
              (Pos('mailto:', LowerCase(ATarget)) = 1)) or
         (ATarget = 'https://') or (ATarget = 'http://') or
         (ATarget = 'mailto:') then
      begin
        PDFModernMessageDlg(
          ToolbarHint('Bitte eine gültige http://-, https://- oder E-Mail-Adresse eingeben.',
            'Please enter a valid http://, https:// or email address.'),
          mtWarning, [mbOK], 0);
        Dlg.ActiveControl := E2;
        E2.SelectAll;
        Continue;
      end;
      ACaption := Trim(E1.Text);
      Result := True;
      Break;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TFreePDF64PDFiumView.ManageLinksClick(Sender: TObject);
var
  Dlg: TForm;
  Links: TArray<TPDFManagedLink>;
  LV: TListView;
  BtnJump, BtnEdit, BtnDelete, BtnClose: TButton;
  I, Index, Choice, PPI: Integer;
  NewTarget, Prompt: string;
  English: Boolean;
  Changed: Boolean;
  Navigator: TPDFLinkListNavigator;

  function Px(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, PPI, 96);
  end;

  procedure FillList;
  var
    K: Integer;
    L: TListItem;
  begin
    Links := FCore.GetManagedLinks;
    LV.Items.BeginUpdate;
    try
      LV.Items.Clear;
      for K := 0 to High(Links) do
      begin
        L := LV.Items.Add;
        L.Caption := IntToStr(Links[K].PageIndex + 1);
        L.SubItems.Add(Links[K].DisplayText);
        L.SubItems.Add(Links[K].Target);
      end;
      if LV.Items.Count > 0 then
      begin
        LV.ItemIndex := 0;
        LV.Selected := LV.Items[0];
      end;
    finally
      LV.Items.EndUpdate;
    end;
  end;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  English := PDFLanguage = 'en';
  Dlg := TForm.CreateNew(Self);
  try
    Dlg.Caption := ToolbarHint('Hyperlinks verwalten', 'Manage hyperlinks');
    Dlg.BorderStyle := bsSizeable;
    Dlg.Position := poScreenCenter;
    Dlg.Scaled := True;
    PPI := CurrentPPI;
    Dlg.ClientWidth := Px(660);
    Dlg.ClientHeight := Px(390);
    Dlg.Constraints.MinWidth := Px(510);
    Dlg.Constraints.MinHeight := Px(300);
    LV := TListView.Create(Dlg);
    LV.Parent := Dlg;
    LV.ViewStyle := vsReport;
    LV.ReadOnly := True;
    LV.RowSelect := True;
    LV.HideSelection := False;
    LV.SetBounds(Px(12), Px(12), Dlg.ClientWidth - Px(24),
      Dlg.ClientHeight - Px(74));
    LV.Anchors := [akLeft, akTop, akRight, akBottom];
    with LV.Columns.Add do
    begin
      Caption := ToolbarHint('Seite', 'Page');
      Width := Px(70);
    end;
    with LV.Columns.Add do
    begin
      Caption := ToolbarHint('Anzeigetext', 'Display text');
      Width := Px(180);
    end;
    with LV.Columns.Add do
    begin
      Caption := ToolbarHint('Linkziel', 'Link target');
      Width := Px(360);
    end;
    LV.OnDblClick := nil;
    Navigator := TPDFLinkListNavigator.Create(Dlg, Self, LV);
    LV.OnClick := Navigator.ListClick;
    BtnJump := TPDFDesignButton.Create(Dlg);
    BtnJump.Parent := Dlg;
    BtnJump.Caption := ToolbarHint('Zur Seite', 'Go to page');
    BtnJump.SetBounds(Px(12), Dlg.ClientHeight - Px(49), Px(108), Px(32));
    BtnJump.Anchors := [akLeft, akBottom];
    BtnJump.OnClick := Navigator.JumpClick;
    BtnEdit := TPDFDesignButton.Create(Dlg);
    BtnEdit.Parent := Dlg;
    BtnEdit.Caption := ToolbarHint('Linkziel ändern ...', 'Edit target ...');
    BtnEdit.SetBounds(Px(128), Dlg.ClientHeight - Px(49), Px(150), Px(32));
    BtnEdit.Anchors := [akLeft, akBottom];
    BtnEdit.ModalResult := mrRetry;
    BtnDelete := TPDFDesignButton.Create(Dlg);
    BtnDelete.Parent := Dlg;
    BtnDelete.Caption := ToolbarHint('Link löschen', 'Delete link');
    BtnDelete.SetBounds(Px(286), Dlg.ClientHeight - Px(49), Px(122), Px(32));
    BtnDelete.Anchors := [akLeft, akBottom];
    BtnDelete.ModalResult := mrNo;
    BtnClose := TPDFDesignButton.Create(Dlg);
    BtnClose.Parent := Dlg;
    BtnClose.Caption := ToolbarHint('Schließen', 'Close');
    BtnClose.SetBounds(Dlg.ClientWidth - Px(112),
      Dlg.ClientHeight - Px(49), Px(100), Px(32));
    BtnClose.Anchors := [akRight, akBottom];
    BtnClose.ModalResult := mrCancel;
    BtnClose.Cancel := True;
    Changed := False;
    FillList;
    ApplyManagedDialogPalette(Dlg, LV, FEditToggle.FDesign);
    repeat
      Choice := Dlg.ShowModal;
      if Choice = mrCancel then Break;
      Index := LV.ItemIndex;
      if (Index < 0) or (Index >= Length(Links)) then Continue;
      case Choice of
        mrRetry:
          begin
            NewTarget := Links[Index].Target;
            Prompt := ToolbarHint('Neue Webadresse oder E-Mail-Adresse:',
              'New web address or email address:');
            if InputQuery(ToolbarHint('Linkziel ändern', 'Edit link target'),
              Prompt, NewTarget) and (Trim(NewTarget) <> '') then
            begin
              if (Pos(':', NewTarget) = 0) then
              begin
                if Pos('@', NewTarget) > 0 then NewTarget := 'mailto:' + NewTarget
                else NewTarget := 'https://' + NewTarget;
              end;
              Changed := FCore.ChangeManagedLink(Links[Index], NewTarget) or Changed;
            end;
          end;
        mrNo:
          if MessageDlg(ToolbarHint('Diesen Hyperlink wirklich löschen? Der sichtbare Text bleibt erhalten.',
            'Delete this hyperlink? The visible text will remain.'),
            mtConfirmation, [mbYes, mbNo], 0) = mrYes then
            Changed := FCore.DeleteManagedLink(Links[Index]) or Changed;
      end;
      FillList;
    until False;
    if Changed then
    begin
      UpdateSaveState;
      RefreshPDFDisplay;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TFreePDF64PDFiumView.LinkMenuClick(Sender: TObject);
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  FLinkMode := not FLinkMode;
  if FLinkMode then
  begin
    FTextInsertMode := False;
    FHighlightMode := False;
    FNoteMode := False;
    FMeasureMode := False;
    CancelMeasurement;
    FMeasureButton.Font.Style := [];
    FMarkMode := False;
    if FTextEditor <> nil then FinishTextEditor(False);
    Screen.Cursor := crCross;
  end
  else
  begin
    Screen.Cursor := crDefault;
    if FImage <> nil then FImage.Cursor := crDefault;
  end;
end;

procedure TFreePDF64PDFiumView.TextWatermarkClick(Sender: TObject);
var
  D: TForm;
  L: TLabel;
  EditText: TEdit;
  CbSize, CbOpacity, CbAngle, CbScope: TComboBox;
  BtnOK, BtnCancel: TButton;
  FontSize, Angle: Double;
  Opacity, I, FirstPage, LastPage: Integer;
  Scale: Integer;

  procedure AddLabel(const ACaption: string; ATop: Integer);
  begin
    L := TLabel.Create(D);
    L.Parent := D;
    L.Caption := ACaption;
    L.SetBounds(MulDiv(18, Scale, 96), MulDiv(ATop, Scale, 96),
      MulDiv(370, Scale, 96), MulDiv(19, Scale, 96));
  end;

  procedure SetupCombo(C: TComboBox; ATop: Integer);
  begin
    C.Parent := D;
    C.Style := csDropDownList;
    C.SetBounds(MulDiv(18, Scale, 96), MulDiv(ATop, Scale, 96),
      MulDiv(350, Scale, 96), MulDiv(25, Scale, 96));
  end;

begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  D := TForm.CreateNew(Self);
  try
    Scale := CurrentPPI;
    D.Caption := Tr('Textwasserzeichen');
    D.Position := poScreenCenter;
    D.BorderStyle := bsDialog;
    D.Font.Assign(Font);
    D.ClientWidth := MulDiv(390, Scale, 96);
    D.ClientHeight := MulDiv(345, Scale, 96);

    AddLabel(Tr('Wasserzeichentext:'), 12);
    EditText := TEdit.Create(D);
    EditText.Parent := D;
    EditText.Text := 'ENTWURF';
    EditText.SetBounds(MulDiv(18, Scale, 96), MulDiv(33, Scale, 96),
      MulDiv(350, Scale, 96), MulDiv(25, Scale, 96));

    AddLabel(Tr('Schriftgröße in Punkt (1–200):'), 68);
    CbSize := TComboBox.Create(D);
    SetupCombo(CbSize, 89);
    CbSize.Items.Text := '12'#13#10'16'#13#10'20'#13#10'24'#13#10'28'#13#10'32'#13#10'36'#13#10'40'#13#10'48'#13#10'56'#13#10'64'#13#10'72'#13#10'96'#13#10'120'#13#10'144'#13#10'180'#13#10'200';
    CbSize.ItemIndex := CbSize.Items.IndexOf('48');

    AddLabel(Tr('Deckkraft in Prozent (1–100):'), 123);
    CbOpacity := TComboBox.Create(D);
    SetupCombo(CbOpacity, 144);
    CbOpacity.Items.Text := '10 %'#13#10'20 %'#13#10'30 %'#13#10'40 %'#13#10'50 %'#13#10'60 %'#13#10'70 %'#13#10'80 %'#13#10'90 %'#13#10'100 %';
    CbOpacity.ItemIndex := 2;

    AddLabel(Tr('Drehwinkel in Grad (-180 bis 180):'), 178);
    CbAngle := TComboBox.Create(D);
    SetupCombo(CbAngle, 199);
    CbAngle.Items.Text := '-180'#13#10'-135'#13#10'-90'#13#10'-60'#13#10'-45'#13#10'-30'#13#10'0'#13#10'30'#13#10'45'#13#10'60'#13#10'90'#13#10'135'#13#10'180';
    CbAngle.ItemIndex := CbAngle.Items.IndexOf('45');

    AddLabel(Tr('Seitenbereich:'), 233);
    CbScope := TComboBox.Create(D);
    SetupCombo(CbScope, 254);
    CbScope.Items.Add(Tr('Aktuelle Seite'));
    CbScope.Items.Add(Tr('Alle Seiten'));
    CbScope.ItemIndex := 0;

    BtnOK := TButton.Create(D);
    BtnOK.Parent := D;
    BtnOK.Caption := Tr('OK');
    BtnOK.ModalResult := mrOk;
    BtnOK.Default := True;
    BtnOK.SetBounds(MulDiv(191, Scale, 96), MulDiv(301, Scale, 96),
      MulDiv(84, Scale, 96), MulDiv(28, Scale, 96));
    BtnCancel := TButton.Create(D);
    BtnCancel.Parent := D;
    BtnCancel.Caption := Tr('Abbrechen');
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Cancel := True;
    BtnCancel.SetBounds(MulDiv(284, Scale, 96), MulDiv(301, Scale, 96),
      MulDiv(84, Scale, 96), MulDiv(28, Scale, 96));

    if D.ShowModal <> mrOk then Exit;
    if Trim(EditText.Text) = '' then Exit;
    FontSize := StrToFloat(CbSize.Text);
    Opacity := StrToInt(StringReplace(CbOpacity.Text, ' %', '', []));
    Angle := StrToFloat(CbAngle.Text);
    if CbScope.ItemIndex = 1 then
    begin
      FirstPage := 0;
      LastPage := FCore.PageCount - 1;
    end
    else
    begin
      FirstPage := FPage;
      LastPage := FPage;
    end;
    try
      FCore.AddTextWatermark(EditText.Text, CbScope.ItemIndex = 1, FPage,
        FontSize, Round(Opacity * 255 / 100), Angle);
      for I := FirstPage to LastPage do
      begin
        if I < Length(FLoadedPages) then FLoadedPages[I] := False;
        if I < FPages.Count then PageImage(I).Picture.Assign(nil);
        if I < FThumbImages.Count then
          TImage(FThumbImages[I]).Picture.Assign(nil);
      end;
      PaintPage;
      UpdateSaveState;
      FRenderPending := True;
      if not FEditVisible then
      begin
        ToggleEditBar(nil);
        FMarkMode := False;
      end;
      UpdateTextUndoButtons;
    except
      on E: Exception do
        MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  finally
    D.Free;
  end;
end;

procedure TFreePDF64PDFiumView.SignatureApplicationMessage(
  var Msg: TMsg; var Handled: Boolean);
var
  SigPageImage: TPDFiumImage;
  Step, DX, DY, MaxLeft, MaxTop: Integer;
begin
  // Modale Berichtstasten dürfen niemals PDF-Vormerkungen verändern.
  if FRedactionReportOpen then Exit;
  // Patch 32au: Nur lesender Analysebericht fuer vorgemerkte Schwaerzungen.
  // Strg+Umschalt+R ist bewusst nur im Vorschauwerkzeug aktiv.
  if (Msg.message = WM_KEYDOWN) and (Msg.wParam = Ord('R')) and
     (GetKeyState(VK_CONTROL) < 0) and (GetKeyState(VK_SHIFT) < 0) and
     (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6) and
     FEditVisible and (FRedactionPreviews <> nil) and
     (FRedactionPreviews.Count > 0) and
     (Screen.ActiveCustomForm <> nil) and
     (FInlineFormEditor = nil) and (FTextEditor = nil) and
     not (Screen.ActiveControl is TCustomEdit) then
  begin
    var Analysis: TPDFRedactionBatchAnalysis;
    var AnalysisOK := AnalyzePendingRedactions(Analysis);
    var ReportText := Format(ToolbarHint(
      'Vorgemerkte Bereiche: %d'#13#10 +
      'Analysierte Bereiche: %d'#13#10 +
      'Fehlgeschlagene Bereiche: %d'#13#10 +
      'Betroffene Seitenobjekte: %d'#13#10 +
      'Davon Textobjekte: %d'#13#10 +
      'Davon Bildobjekte: %d'#13#10 +
      'Davon Pfad-/Vektorobjekte: %d'#13#10 +
      'Davon sonstige Objekte: %d'#13#10 +
      'Vollständig enthalten: %d'#13#10 +
      'Teilweise betroffen: %d'#13#10 +
      '  Davon Textobjekte: %d'#13#10 +
      '  Davon Bildobjekte: %d'#13#10 +
      '  Davon Pfad-/Vektorobjekte: %d'#13#10 +
      '  Davon sonstige Objekte: %d'#13#10 +
      'Objekte mit unbekannten Grenzen: %d'#13#10 +
      'Betroffene Annotationen (eindeutig): %d'#13#10 +
      'Davon Kommentar-/Markierungsarten: %d'#13#10 +
      'Davon Formular-/Signatur-Widgets: %d'#13#10 +
      'Davon sonstige Annotationen: %d'#13#10 +
      'Mehrfachtreffer durch mehrere Bereiche: %d',
      'Marked regions: %d'#13#10 +
      'Analyzed regions: %d'#13#10 +
      'Failed regions: %d'#13#10 +
      'Intersecting page objects: %d'#13#10 +
      'Text objects: %d'#13#10 +
      'Image objects: %d'#13#10 +
      'Path/vector objects: %d'#13#10 +
      'Other objects: %d'#13#10 +
      'Fully contained: %d'#13#10 +
      'Partially intersecting: %d'#13#10 +
      '  Partial text objects: %d'#13#10 +
      '  Partial image objects: %d'#13#10 +
      '  Partial path/vector objects: %d'#13#10 +
      '  Partial other objects: %d'#13#10 +
      'Objects with unknown bounds: %d'#13#10 +
      'Affected annotations (unique): %d'#13#10 +
      'Comment/markup types: %d'#13#10 +
      'Form/signature widgets: %d'#13#10 +
      'Other annotations: %d'#13#10 +
      'Duplicate hits across regions: %d'),
      [Analysis.RegionCount, Analysis.AnalyzedRegions,
       Analysis.FailedRegions, Analysis.IntersectingObjects,
       Analysis.TextObjects, Analysis.ImageObjects,
       Analysis.PathObjects, Analysis.OtherObjects,
       Analysis.FullyContainedObjects, Analysis.PartiallyIntersectingObjects,
       Analysis.PartialTextObjects, Analysis.PartialImageObjects,
       Analysis.PartialPathObjects, Analysis.PartialOtherObjects,
       Analysis.UnknownBoundsObjects, Analysis.AnnotationCount,
       Analysis.AnnotationComments, Analysis.AnnotationWidgets,
       Analysis.AnnotationOther, Analysis.AnnotationDuplicateHits]);
    // Patch 32av: Der Status beschreibt ausschließlich die Vollständigkeit
    // der Voranalyse, nicht die Sicherheit einer späteren Schwärzung.
    if AnalysisOK and not Analysis.HasUnsupportedContent then
      ReportText := ReportText + #13#10#13#10 + ToolbarHint(
        'Prüfstatus: Alle Bereiche analysiert. Keine Hindernisse in dieser Vorprüfung erkannt.',
        'Inspection status: All regions analyzed. No obstacles detected by this preliminary check.')
    else
      ReportText := ReportText + #13#10#13#10 + ToolbarHint(
        'Prüfstatus: Weitere Prüfung erforderlich. Keine Freigabe zur sicheren Schwärzung.',
        'Inspection status: Further verification required. Not approved for secure redaction.');
    if not AnalysisOK then
      ReportText := ReportText + #13#10#13#10 + ToolbarHint(
        'Warnung: Nicht alle Bereiche konnten analysiert werden.',
        'Warning: Not all regions could be analyzed.');
    if Analysis.HasUnsupportedContent then
      ReportText := ReportText + #13#10 + ToolbarHint(
        'Warnung: Nicht unterstützte oder unklare Inhalte erkannt.',
        'Warning: Unsupported or uncertain content detected.');
    ReportText := ReportText + #13#10#13#10 + ToolbarHint(
      'Nur Voranalyse! Es wurden keine PDF-Inhalte entfernt. ' +
      'Objektzahlen können bei überlappenden Bereichen mehrfach gezählt werden.',
      'Analysis only! No PDF content was removed. ' +
      'Overlapping regions may count objects more than once.');
    Handled := True;
    FRedactionReportOpen := True;
    try
      PDFModernMessageDlg(ReportText, mtInformation, [mbOK], 0, True);
    finally
      FRedactionReportOpen := False;
    end;
    Exit;
  end;
  // Tastaturereignisse erreichen den eingebetteten Viewer nicht immer
  // direkt: Der Fokus kann bei der uebergeordneten Registerkarten-Form
  // liegen. Deshalb nicht auf IsChild(Handle, Msg.hwnd) beschraenken.
  // Eingabefelder und Dialoge bleiben von den Kurzbefehlen ausgenommen.
  if ((Msg.message = WM_KEYDOWN) or (Msg.message = WM_SYSKEYDOWN)) and
     (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6) and
     FEditVisible and (FRedactionPreviews <> nil) and
     (FRedactionPreviews.Count > 0) and
     ((Msg.wParam = VK_DELETE) or (Msg.wParam = VK_ESCAPE)) and
     (GetForegroundWindow <> 0) and
     (Screen.ActiveCustomForm <> nil) and
     (FInlineFormEditor = nil) and (FTextEditor = nil) and
     not (Screen.ActiveControl is TCustomEdit) then
  begin
    // Nur die Seiten mit geloeschten Vormerkungen neu aufbauen.
    // RenderVisiblePages allein kann eine gecachte Bitmap unveraendert
    // lassen; das schwarze Rechteck bliebe dann optisch stehen.
    var ChangedPages := TList<Integer>.Create;
    try
      if Msg.wParam = VK_ESCAPE then
      begin
        for var K := 0 to FRedactionPreviewPages.Count - 1 do
          if ChangedPages.IndexOf(FRedactionPreviewPages[K]) < 0 then
            ChangedPages.Add(FRedactionPreviewPages[K]);
        FRedactionPreviews.Clear;
        FRedactionPreviewPages.Clear;
        ClearRedactionRedo;
      end
      else
      begin
        var LastPage := FRedactionPreviewPages[FRedactionPreviewPages.Count - 1];
        ChangedPages.Add(LastPage);
        FRedactionPreviews.Delete(FRedactionPreviews.Count - 1);
        FRedactionPreviewPages.Delete(FRedactionPreviewPages.Count - 1);
        ClearRedactionRedo;
      end;
      for var K := 0 to ChangedPages.Count - 1 do
      begin
        var Pg := ChangedPages[K];
        if (Pg >= 0) and (Pg < Length(FLoadedPages)) and
           FLoadedPages[Pg] and (PageImage(Pg) <> nil) then
        begin
          FCore.RenderPage(Pg, PageImage(Pg).Picture.Bitmap,
            PageImage(Pg).Width, PageImage(Pg).Height);
          DrawPageStrokes(Pg);
          PageImage(Pg).Invalidate;
        end;
      end;
    finally
      ChangedPages.Free;
    end;
    UpdateTextUndoButtons;
    Handled := True;
    Exit;
  end;
  // Eine noch nicht eingebettete Signatur pixelgenau positionieren.
  // Umschalt + Pfeiltaste verschiebt um zehn statt um einen Bildschirmpixel.
  if FSignatureMode and FSignaturePlaced and (Msg.message = WM_KEYDOWN) and
     (Msg.wParam in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN]) then
  begin
    SigPageImage := nil;
    if (FSignaturePreviewPage >= 0) and
       (FSignaturePreviewPage < FPages.Count) then
      SigPageImage := PageImage(FSignaturePreviewPage);
    if SigPageImage <> nil then
    begin
      Step := 1;
      if GetKeyState(VK_SHIFT) < 0 then Step := 10;
      DX := 0;
      DY := 0;
      case Msg.wParam of
        VK_LEFT: DX := -Step;
        VK_RIGHT: DX := Step;
        VK_UP: DY := -Step;
        VK_DOWN: DY := Step;
      end;
      MaxLeft := Max(0, SigPageImage.Width - FSignatureRect.Width);
      MaxTop := Max(0, SigPageImage.Height - FSignatureRect.Height);
      OffsetRect(FSignatureRect,
        EnsureRange(FSignatureRect.Left + DX, 0, MaxLeft) - FSignatureRect.Left,
        EnsureRange(FSignatureRect.Top + DY, 0, MaxTop) - FSignatureRect.Top);
      SigPageImage.Invalidate;
    end;
    Handled := True;
    Exit;
  end;
  // Entf verwirft nur die noch nicht übernommene Signatur.
  // Bereits gespeicherte PDF-Objekte bleiben unberührt.
  if FSignatureMode and FSignaturePlaced and (Msg.message = WM_KEYDOWN) and
     (Msg.wParam = VK_DELETE) then
  begin
    SigPageImage := nil;
    if (FSignaturePreviewPage >= 0) and
       (FSignaturePreviewPage < FPages.Count) then
      SigPageImage := PageImage(FSignaturePreviewPage);
    CancelSignature;
    if SigPageImage <> nil then SigPageImage.Invalidate;
    Handled := True;
    Exit;
  end;
  // ESC must cancel BEFORE the active main form or its controls process it.
  // Never create a PDF image object from a keyboard event.
  if FSignatureMode and FSignaturePlaced and (Msg.message = WM_KEYDOWN) and
     (Msg.wParam = VK_RETURN) then
  begin
    CommitSignature;
    Handled := True;
    Exit;
  end;
  if FSignatureMode and (Msg.message = WM_KEYDOWN) and
     (Msg.wParam = VK_ESCAPE) then
  begin
    CancelSignature;
    Handled := True;
    if FImage <> nil then FImage.Invalidate;
  end;
end;

procedure TFreePDF64PDFiumView.CommitSignature;
var
  Pg: Integer;
  Img: TPDFiumImage;
  PageW, PageH: Single;
  X1, Y1, X2, Y2: Double;
  SigW, SigH: Double;
begin
  if not FSignaturePlaced or (FCore = nil) or (FSignatureFile = '') then Exit;
  Pg := FSignaturePreviewPage;
  if (Pg < 0) or (Pg >= FPages.Count) then Exit;
  Img := PageImage(Pg);
  if (Img = nil) or (Img.Width <= 0) or (Img.Height <= 0) then Exit;
  if not FCore.PageSize(Pg, PageW, PageH) then Exit;
  if not FCore.DevicePointToPage(Pg, Img.Width, Img.Height,
    FSignatureRect.Left, FSignatureRect.Top, X1, Y1) then Exit;
  if not FCore.DevicePointToPage(Pg, Img.Width, Img.Height,
    FSignatureRect.Right, FSignatureRect.Bottom, X2, Y2) then Exit;
  SigW := Abs(X2-X1);
  SigH := Abs(Y2-Y1);
  if (SigW <= 0) or (SigH <= 0) then Exit;
  try
    FCore.InsertSignatureImage(FSignatureFile, Pg,
      EnsureRange(Min(X1,X2),0.0,Double(PageW)-SigW),
      EnsureRange(Min(Y1,Y2),0.0,Double(PageH)-SigH), SigW, SigH);
    CancelSignature;
    if Pg < Length(FLoadedPages) then FLoadedPages[Pg] := False;
    if Pg < FPages.Count then PageImage(Pg).Picture.Assign(nil);
    if Pg < FThumbImages.Count then TImage(FThumbImages[Pg]).Picture.Assign(nil);
    PaintPage;
    UpdateSaveState;
    UpdateTextUndoButtons;
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TFreePDF64PDFiumView.CancelSignature;
begin
  FSignaturePreviewVisible := False;
  FSignaturePlaced := False;
  FSignatureDragging := False;
  FSignatureResizing := False;
  FreeAndNil(FSignaturePreview);
  FSignatureMode := False;
  Screen.Cursor := crDefault;
  if FImage <> nil then FImage.Cursor := crDefault;
  if FSignatureTemporary and (FSignatureFile <> '') then
    System.SysUtils.DeleteFile(FSignatureFile);
  FSignatureTemporary := False;
  FSignatureFile := '';
end;

procedure TFreePDF64PDFiumView.SignatureClick(Sender: TObject);
var
  Choice: Integer;
  FileDlg: TOpenDialog;
  FileName: string;
  WidthMM: Double;
  Temporary: Boolean;
  SignatureFolder, SaveName, SavedPath: string;
  SaveChoice: Integer;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  CancelSignature;
  Choice := ChoosePDFSignatureSource(Self, FEditToggle.FDesign,
    ToolbarHint('Unterschrift hinzufügen', 'Add signature'),
    ToolbarHint('Unterschrift zeichnen', 'Draw signature'),
    ToolbarHint('PNG importieren', 'Import PNG'),
    ToolbarHint('Abbrechen', 'Cancel'));
  if (Choice <> mrYes) and (Choice <> mrNo) and (Choice <> mrRetry) then Exit;
  FileName := '';
  Temporary := False;
  SignatureFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'Signaturen';
  if Choice = mrRetry then
  begin
    ForceDirectories(SignatureFolder);
    if not SelectStoredPDFSignature(Self, SignatureFolder,
      ToolbarHint('Gespeicherte Unterschriften', 'Saved signatures'),
      ToolbarHint('Verwenden', 'Use'),
      ToolbarHint('Umbenennen', 'Rename'),
      ToolbarHint('Löschen', 'Delete'),
      ToolbarHint('Abbrechen', 'Cancel'),
      ToolbarHint('Name:', 'Name:'),
      ToolbarHint('Unterschrift wirklich löschen?', 'Delete this signature?'),
      FileName, FEditToggle.FDesign) then Exit;
  end
  else if Choice = mrYes then
  begin
    if not CreatePDFSignaturePNG(Self,
      ToolbarHint('Unterschrift zeichnen', 'Draw signature'),
      ToolbarHint('Mit gedrückter linker Maustaste unterschreiben',
        'Draw with the left mouse button pressed'),
      ToolbarHint('Löschen', 'Clear'), ToolbarHint('OK', 'OK'),
      ToolbarHint('Abbrechen', 'Cancel'), FileName, FEditToggle.FDesign) then Exit;
    Temporary := True;
  end
  else
  begin
    FileDlg := TOpenDialog.Create(Self);
    try
      FileDlg.Title := ToolbarHint('Unterschrift als PNG auswählen',
        'Choose signature PNG');
      FileDlg.Filter := 'PNG (*.png)|*.png';
      if not FileDlg.Execute then Exit;
      FileName := FileDlg.FileName;
    finally
      FileDlg.Free;
    end;
  end;
  // Speichern ist optional: eine Unterschrift wird niemals ohne Einwilligung
  // dauerhaft in das portable Programmverzeichnis kopiert.
  if Choice <> mrRetry then
  begin
    if ConfirmStoreSignature(Self, FEditToggle.FDesign,
      ToolbarHint('Unterschrift speichern', 'Save signature'),
      ToolbarHint('Diese Unterschrift für spätere Verwendung lokal speichern?',
        'Save this signature locally for future use?'),
      ToolbarHint('Hinweis: Die PNG-Datei wird unverschlüsselt im Ordner Signaturen gespeichert.',
        'Note: The PNG file is stored unencrypted in the Signaturen folder.'),
      ToolbarHint('Ja', 'Yes'), ToolbarHint('Nein', 'No')) then
      SaveChoice := mrYes
    else
      SaveChoice := mrNo;
    if SaveChoice = mrYes then
    begin
      SaveName := ToolbarHint('Meine Unterschrift', 'My signature');
      if InputSignatureName(Self, FEditToggle.FDesign,
        ToolbarHint('Unterschrift speichern', 'Save signature'),
        ToolbarHint('Name:', 'Name:'),
        'OK', ToolbarHint('Abbrechen', 'Cancel'), SaveName) then
      begin
        SaveName := Trim(SaveName);
        // Nur Dateinamen zulassen, niemals Pfade oder Traversal.
        for var J := 1 to Length(SaveName) do
          if CharInSet(SaveName[J], ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
            SaveName[J] := '_';
        if SaveName <> '' then
        begin
          ForceDirectories(SignatureFolder);
          SavedPath := IncludeTrailingPathDelimiter(SignatureFolder) + SaveName + '.png';
          if FileExists(SavedPath) then
          begin
            if not ConfirmStoreSignature(Self, FEditToggle.FDesign,
              ToolbarHint('Unterschrift überschreiben', 'Overwrite signature'),
              ToolbarHint('Vorhandene Unterschrift überschreiben?',
                'Overwrite existing signature?'),
              ToolbarHint('Die gespeicherte Unterschrift wird ersetzt.',
                'The saved signature will be replaced.'),
              ToolbarHint('Ja', 'Yes'), ToolbarHint('Nein', 'No')) then
              SavedPath := '';
          end;
          if SavedPath <> '' then
            if not CopyFile(PChar(FileName), PChar(SavedPath), False) then
              MessageDlg(ToolbarHint('Unterschrift konnte nicht gespeichert werden.',
                'Could not save signature.'), mtWarning, [mbOK], 0);
        end;
      end;
    end;
  end;
  if not ChooseSignatureWidth(Self, FEditToggle.FDesign,
    ToolbarHint('Unterschrift platzieren', 'Place signature'),
    ToolbarHint('Breite in mm (5–200):', 'Width in mm (5–200):'),
    ToolbarHint('Abbrechen', 'Cancel'),
    ToolbarHint('Bitte eine Breite zwischen 5 und 200 mm eingeben.',
      'Enter a width between 5 and 200 mm.'), WidthMM) then
  begin
    if Temporary then System.SysUtils.DeleteFile(FileName);
    Exit;
  end;
  FSignatureFile := FileName;
  FSignatureTemporary := Temporary;
  FSignatureWidthMM := WidthMM;
  FSignaturePreview := TPicture.Create;
  try
    FSignaturePreview.LoadFromFile(FSignatureFile);
    // Die Vorschau muss dieselbe Weiß-Transparenz zeigen wie
    // InsertSignatureImage beim Einbetten in die PDF.
    // PNGs mit echtem Alphakanal behalten ihren Alphakanal.
    if not ((FSignaturePreview.Graphic is TPngImage) and
      (TPngImage(FSignaturePreview.Graphic).TransparencyMode = ptmPartial)) then
    begin
      var SourceBmp := TBitmap.Create;
      var AlphaPng := TPngImage.Create;
      try
        SourceBmp.PixelFormat := pf24bit;
        SourceBmp.SetSize(FSignaturePreview.Width, FSignaturePreview.Height);
        SourceBmp.Canvas.Brush.Color := clWhite;
        SourceBmp.Canvas.FillRect(Rect(0, 0, SourceBmp.Width, SourceBmp.Height));
        SourceBmp.Canvas.Draw(0, 0, FSignaturePreview.Graphic);
        AlphaPng.Assign(SourceBmp);
        AlphaPng.CreateAlpha;
        for var Row := 0 to SourceBmp.Height - 1 do
        begin
          var Pixels := PByte(SourceBmp.ScanLine[Row]);
          var AlphaRow := AlphaPng.AlphaScanline[Row];
          for var Col := 0 to SourceBmp.Width - 1 do
          begin
            // Schwarz: deckend, Weiß: transparent, Grau: teiltransparent.
            AlphaRow[Col] := 255 - Min(Pixels[0],
              Min(Pixels[1], Pixels[2]));
            Inc(Pixels, 3);
          end;
        end;
        FSignaturePreview.Assign(AlphaPng);
      finally
        AlphaPng.Free;
        SourceBmp.Free;
      end;
    end;
  except
    FreeAndNil(FSignaturePreview);
    if FSignatureTemporary then System.SysUtils.DeleteFile(FSignatureFile);
    FSignatureFile := '';
    FSignatureTemporary := False;
    raise;
  end;
  FSignaturePreviewVisible := False;
  FSignaturePlaced := False;
  FSignatureDragging := False;
  FSignatureResizing := False;
  FSignatureResizeCorner := 0;
  FSignaturePreviewPage := -1;
  FSignatureMode := True;
  FMeasureMode := False;
  CancelMeasurement;
  if FMeasureButton <> nil then FMeasureButton.Font.Style := [];
  FLinkMode := False;
  FTextInsertMode := False;
  FHighlightMode := False;
  FNoteMode := False;
  FMarkMode := False;
  Screen.Cursor := crCross;
  if FImage <> nil then FImage.Cursor := crCross;
  // ESC wird über den fokussierten Scrollbereich abgefangen.
  if (FScroll <> nil) and FScroll.CanFocus then FScroll.SetFocus;
end;

procedure TFreePDF64PDFiumView.ImageWatermarkClick(Sender: TObject);
var
  FileDlg: TOpenDialog;
  D: TForm;
  L: TLabel;
  CbWidth, CbOpacity, CbAngle, CbScope: TComboBox;
  BtnOK, BtnCancel: TButton;
  Scale, I, FirstPage, LastPage, Opacity: Integer;
  ImageFile: string;
  procedure AddCombo(var C: TComboBox; const Caption: string;
    Top: Integer; const Values, DefaultValue: string);
  begin
    L := TLabel.Create(D);
    L.Parent := D;
    L.Caption := Tr(Caption);
    L.SetBounds(MulDiv(18, Scale, 96), MulDiv(Top, Scale, 96),
      MulDiv(350, Scale, 96), MulDiv(19, Scale, 96));
    C := TComboBox.Create(D);
    C.Parent := D;
    C.Style := csDropDownList;
    C.SetBounds(MulDiv(18, Scale, 96), MulDiv(Top + 21, Scale, 96),
      MulDiv(350, Scale, 96), MulDiv(25, Scale, 96));
    C.Items.Text := Values;
    C.ItemIndex := C.Items.IndexOf(DefaultValue);
  end;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  FileDlg := TOpenDialog.Create(Self);
  try
    FileDlg.Title := Tr('Bild für Wasserzeichen auswählen');
    FileDlg.Filter := 'Bilder (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg';
    if not FileDlg.Execute then Exit;
    ImageFile := FileDlg.FileName;
  finally
    FileDlg.Free;
  end;
  D := TForm.CreateNew(Self);
  try
    Scale := CurrentPPI;
    D.Caption := Tr('Bildwasserzeichen');
    D.Position := poScreenCenter;
    D.BorderStyle := bsDialog;
    D.Font.Assign(Font);
    D.ClientWidth := MulDiv(390, Scale, 96);
    D.ClientHeight := MulDiv(285, Scale, 96);
    AddCombo(CbWidth, 'Bildbreite (Prozent der Seitenbreite):', 12,
      '10'#13#10'20'#13#10'30'#13#10'40'#13#10'50'#13#10'60'#13#10'70'#13#10'80'#13#10'90', '40');
    AddCombo(CbOpacity, 'Deckkraft:', 67,
      '10 %'#13#10'20 %'#13#10'30 %'#13#10'40 %'#13#10'50 %'#13#10'60 %'#13#10'70 %'#13#10'80 %'#13#10'90 %'#13#10'100 %', '30 %');
    AddCombo(CbAngle, 'Drehwinkel:', 122,
      '-90'#13#10'-45'#13#10'0'#13#10'45'#13#10'90', '0');
    AddCombo(CbScope, 'Seitenbereich:', 177, '', '');
    CbScope.Items.Add(Tr('Aktuelle Seite'));
    CbScope.Items.Add(Tr('Alle Seiten'));
    CbScope.ItemIndex := 0;
    BtnOK := TButton.Create(D);
    BtnOK.Parent := D;
    BtnOK.Caption := Tr('OK');
    BtnOK.ModalResult := mrOk;
    BtnOK.Default := True;
    BtnOK.SetBounds(MulDiv(191, Scale, 96), MulDiv(242, Scale, 96),
      MulDiv(84, Scale, 96), MulDiv(28, Scale, 96));
    BtnCancel := TButton.Create(D);
    BtnCancel.Parent := D;
    BtnCancel.Caption := Tr('Abbrechen');
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Cancel := True;
    BtnCancel.SetBounds(MulDiv(284, Scale, 96), MulDiv(242, Scale, 96),
      MulDiv(84, Scale, 96), MulDiv(28, Scale, 96));
    if D.ShowModal <> mrOk then Exit;
    Opacity := StrToInt(StringReplace(CbOpacity.Text, ' %', '', []));
    if CbScope.ItemIndex = 1 then
    begin
      FirstPage := 0;
      LastPage := FCore.PageCount - 1;
    end
    else
    begin
      FirstPage := FPage;
      LastPage := FPage;
    end;
    try
      FCore.AddImageWatermark(ImageFile, CbScope.ItemIndex = 1, FPage,
        StrToInt(CbWidth.Text), Round(Opacity * 255 / 100),
        StrToFloat(CbAngle.Text));
      for I := FirstPage to LastPage do
      begin
        if I < Length(FLoadedPages) then FLoadedPages[I] := False;
        if I < FPages.Count then PageImage(I).Picture.Assign(nil);
        if I < FThumbImages.Count then
          TImage(FThumbImages[I]).Picture.Assign(nil);
      end;
      PaintPage;
      UpdateSaveState;
      FRenderPending := True;
      if not FEditVisible then
      begin
        ToggleEditBar(nil);
        FMarkMode := False;
      end;
      UpdateTextUndoButtons;
    except
      on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  finally
    D.Free;
  end;
end;

procedure TFreePDF64PDFiumView.ThumbMenuPopup(Sender: TObject);
begin
  // PDFLanguage wird zentral vom Hauptfenster gesetzt.
  // Niemals anhand von Menuetexten die Sprache ueberschreiben.
  if FThumbTab <> nil then FThumbTab.Caption := Tr('Seiten');
  if FBookmarksTab <> nil then FBookmarksTab.Caption := Tr('Inhalte');
  if FThumbMenu <> nil then RefreshThumbMenuCaptions;
  if FExtractItem <> nil then
    FExtractItem.Enabled := FThumbSelected.Count > 0;
  if FInsertBeforeItem <> nil then
    FInsertBeforeItem.Enabled := (FCore <> nil) and (FCore.PageCount > 0);
  if FInsertAfterItem <> nil then
    FInsertAfterItem.Enabled := (FCore <> nil) and (FCore.PageCount > 0);
  if FReloadMenuItem <> nil then
    FReloadMenuItem.Enabled := (FCore <> nil) and (FCore.FileName <> '') and FileExists(FCore.FileName);
  if FMoveUpItem <> nil then
    FMoveUpItem.Enabled := (FThumbSelected.Count = 1) and
      (FThumbSelected[0] > 0);
  if FMoveDownItem <> nil then
    FMoveDownItem.Enabled := (FThumbSelected.Count = 1) and
      (FThumbSelected[0] < FCore.PageCount - 1);
end;

procedure TPDFiumScrollBox.CMDialogKey(var Message: TCMDialogKey);
var
  Viewer: TFreePDF64PDFiumView;
  Direction: Integer;
begin
  // ESC im Hyperlink-Modus vor der normalen Dialogbehandlung abfangen.
  if (Message.CharCode = VK_ESCAPE) and
     (Owner is TFreePDF64PDFiumView) then
  begin
    Viewer := TFreePDF64PDFiumView(Owner);
    if Viewer.FSignatureMode then
    begin
      Viewer.CancelSignature;
      Message.Result := 1;
      Exit;
    end;
    if Viewer.FLinkMode then
    begin
      Viewer.FLinkMode := False;
      Screen.Cursor := crDefault;
      if Viewer.FImage <> nil then Viewer.FImage.Cursor := crDefault;
      Message.Result := 1;
      Exit;
    end;
  end;
  // ESC direkt im Miniatur-Scrollbereich abfangen, bevor das
  // uebergeordnete Formular die Taste als Schliessen interpretiert.
  if (Message.CharCode = VK_ESCAPE) and
     (Owner is TFreePDF64PDFiumView) then
  begin
    Viewer := TFreePDF64PDFiumView(Owner);
    if (Viewer.FThumbScroll = Self) and Self.Visible then
    begin
      Viewer.FThumbSelected.Clear;
      Viewer.FThumbAnchor := -1;
      Viewer.UpdateThumbnailSelection;
      Message.Result := 1;
      Exit;
    end;
  end;
  // ESC im PDF-Anzeigebereich als Dialogtaste abfangen, damit
  // die bestehende Textauswahl vor einem Formular-ESC geloescht wird.
  if (Message.CharCode = VK_ESCAPE) and
     (Owner is TFreePDF64PDFiumView) then
  begin
    Viewer := TFreePDF64PDFiumView(Owner);
    if (Viewer.FScroll = Self) and
       (Viewer.FSelAnchorPage >= 0) and (Viewer.FSelFocusPage >= 0) then
    begin
      Viewer.FSelecting := False;
      Viewer.FSelAnchorPage := -1;
      Viewer.FSelFocusPage := -1;
      Viewer.FSelAnchorChar := -1;
      Viewer.FSelFocusChar := -1;
      Viewer.RefreshSelectedPages;
      Message.Result := 1;
      Exit;
    end;
  end;
  if (Message.CharCode = VK_TAB) and (Parent is TFreePDF64PDFiumView) then
  begin
    Viewer := TFreePDF64PDFiumView(Parent);
    if Viewer.HasActiveFormWidget then
    begin
      if GetKeyState(VK_SHIFT) < 0 then Direction := -1
      else Direction := 1;
      Viewer.FocusAdjacentFormWidget(Direction);
      Message.Result := 1;
      Exit;
    end;
  end;
  inherited;
end;

procedure TInlineFormEdit.WndProc(var Message: TMessage);
begin
  if Message.Msg = WM_GETDLGCODE then
  begin
    inherited WndProc(Message);
    Message.Result := Message.Result or DLGC_WANTTAB;
  end
  else inherited WndProc(Message);
end;

procedure TInlineFormMemo.WndProc(var Message: TMessage);
begin
  if Message.Msg = WM_GETDLGCODE then
  begin
    inherited WndProc(Message);
    Message.Result := Message.Result or DLGC_WANTTAB;
  end
  else inherited WndProc(Message);
end;

procedure TFreePDF64PDFiumView.WMFreeInlineEditor(var Msg: TMessage);
begin
  // Erst nach Ende der Tastatur-/Fokus-Nachrichten freigeben.
  TObject(Msg.WParam).Free;
end;

procedure TFreePDF64PDFiumView.FinishInlineFormEdit(ACommit: Boolean);
var
  NewValue: string;
  Page, Index, I: Integer;
  OldEditor: TCustomEdit;
begin
  if (FInlineFormEditor = nil) or FInlineFormClosing then Exit;
  FInlineFormClosing := True;
  try
    Page := FInlineFormPage;
    Index := FInlineFormIndex;
    NewValue := FInlineFormEditor.Text;
    OldEditor := FInlineFormEditor;
    FInlineFormEditor := nil;
    TInlineFormEditAccess(OldEditor).OnExit := nil;
    TInlineFormEditAccess(OldEditor).OnKeyDown := nil;
    OldEditor.Visible := False;
    // Nicht innerhalb des eigenen OnKeyDown/OnExit freigeben.
    PostMessage(Handle, WM_APP + 172, WPARAM(OldEditor), 0);
    if ACommit and (NewValue <> FInlineFormOriginal) then
    begin
      if FCore.SetFormWidgetText(Page, Index, NewValue) then
      begin
        // Formularberechnungen koennen Werte auf anderen PDF-Seiten
        // aendern. Deshalb nach jedem erfolgreichen Feld-Commit alle
        // Seitenbitmaps als veraltet markieren, nicht nur die Eingabeseite.
        // Die vorhandenen Bitmaps bleiben bis zum Neurendern sichtbar,
        // damit beim Seitenwechsel kein graues Aufblitzen entsteht.
        for I := 0 to High(FLoadedPages) do
          FLoadedPages[I] := False;
        RenderVisiblePages;
        UpdateSaveState;
      end
      else
        MessageDlg(Tr('Das Formularfeld konnte nicht geaendert werden.'),
          mtWarning, [mbOK], 0);
    end;
  finally
    FInlineFormClosing := False;
  end;
end;

procedure TFreePDF64PDFiumView.InlineFormEditorExit(Sender: TObject);
begin
  FinishInlineFormEdit(True);
end;

procedure TFreePDF64PDFiumView.InlineFormEditorKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    FinishInlineFormEdit(False);
    Key := 0;
  end
  else if (Key = VK_RETURN) and (not (Sender is TMemo)) then
  begin
    FinishInlineFormEdit(True);
    Key := 0;
  end
  else if (Key = VK_TAB) or (Key = VK_F8) then
  begin
    Key := 0;
    FinishInlineFormEdit(True);
    // Do not navigate/re-enter PDFium from inside the editor KeyDown.
    // The old editor is disposed of by the posted WM_APP+172 message.
    if ssShift in Shift then
      PostMessage(Handle, WM_APP + 173, 0, 0)
    else
      PostMessage(Handle, WM_APP + 173, 1, 0);
  end;
end;

procedure TFreePDF64PDFiumView.WMDeferredFormTab(var Msg: TMessage);
begin
  // Navigate only after the editor's keyboard/focus event has returned.
  // In particular, an XFA widget may invalidate its native focus state
  // during the preceding commit.
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  if Msg.WParam = 0 then FocusAdjacentFormWidget(-1)
  else FocusAdjacentFormWidget(1);
end;

procedure TFreePDF64PDFiumView.UpdateInlineFormEditorFont;
var
  FontSize: Integer;
  PDFSize: Single;
  MaxTextHeight: Integer;
begin
  if FInlineFormEditor = nil then Exit;
  // FZoom enthaelt bereits die Monitor-DPI (bei 100%: CurrentPPI / 72).
  // VCL skaliert Font.Size ebenfalls mit der DPI: deshalb nur den
  // dimensionslosen PDF-Zoom anwenden, sonst wird doppelt skaliert.
  // Feldgeometrie und vorhandene Hoehenbegrenzung bleiben unveraendert.
  if (FCore <> nil) and FCore.FormWidgetFontSize(FInlineFormPage,
    FInlineFormIndex, PDFSize) and (PDFSize > 0) then
    // Fuer groessere PDF-Standardschriften nicht pauschal bei 10 pt
    // abschneiden; die vorhandene Hoehenpruefung begrenzt weiterhin
    // die Darstellung auf die tatsaechliche Edit-Feldhoehe.
    FontSize := EnsureRange(Round(PDFSize * FZoom * 72.0 / Max(1, CurrentPPI)), 1,
      16)
  else
    FontSize := EnsureRange(Round(9 * FZoom * 72.0 / Max(1, CurrentPPI)), 1, 10);

  TInlineFormEditAccess(FInlineFormEditor).Font.Size := FontSize;
  if FInlineFormEditor is TInlineFormEdit then
  begin
    // Nur reduzieren, wenn die reale Windows-Schrifthoehe nicht in
    // das bestehende Edit-Feld passt. Keine Feldvergroesserung.
    MaxTextHeight := Max(1, MulDiv(FInlineFormEditor.ClientHeight - 1, 135, 100));
    while (FontSize > 1) and
      (Abs(TInlineFormEditAccess(FInlineFormEditor).Font.Height) > MaxTextHeight) do
    begin
      Dec(FontSize);
      TInlineFormEditAccess(FInlineFormEditor).Font.Size := FontSize;
    end;
  end;
end;

procedure TFreePDF64PDFiumView.UpdateFormFocusFrame;
var
  Img: TPDFiumImage;
  R: TRect;
begin
  if FFormFocusFrame <> nil then FFormFocusFrame.Visible := False;
  if (FCore = nil) or (FCore.PageCount = 0) or
     (FActiveFormWidgetPage < 0) or
     (FActiveFormWidgetPage >= FCore.PageCount) or
     (FActiveFormWidgetIndex < 0) then Exit;
  Img := PageImage(FActiveFormWidgetPage);
  if (Img = nil) or (Img.Parent = nil) or
     (Img.Width <= 0) or (Img.Height <= 0) then Exit;
  if not FCore.FormWidgetDeviceRect(FActiveFormWidgetPage,
    FActiveFormWidgetIndex, Img.Width, Img.Height, R) then Exit;
  if FFormFocusFrame = nil then
  begin
    FFormFocusFrame := TShape.Create(Self);
    FFormFocusFrame.Shape := stRectangle;
    FFormFocusFrame.Brush.Style := bsClear;
    FFormFocusFrame.Pen.Color := clBlue;
    FFormFocusFrame.Pen.Width := 2;
    FFormFocusFrame.Enabled := False;
  end;
  if FFormFocusFrame.Parent <> Img.Parent then
    FFormFocusFrame.Parent := Img.Parent;
  FFormFocusFrame.SetBounds(Img.Left + R.Left - 2,
    Img.Top + R.Top - 2, Max(8, R.Right - R.Left + 4),
    Max(8, R.Bottom - R.Top + 4));
  FFormFocusFrame.Visible := True;
  FFormFocusFrame.BringToFront;
  if (FInlineFormEditor <> nil) and
     (FInlineFormPage = FActiveFormWidgetPage) and
     (FInlineFormIndex = FActiveFormWidgetIndex) then
  begin
    // Geometrie des aktiven Editors bei Zoom und Layout angleichen.
    FInlineFormEditor.SetBounds(Img.Left + R.Left + 2,
      Img.Top + R.Top + 2, Max(12, R.Right - R.Left - 4),
      Max(12, R.Bottom - R.Top - 4));
    UpdateInlineFormEditorFont;
    FInlineFormEditor.BringToFront;
  end;
end;

procedure TFreePDF64PDFiumView.BeginInlineFormEdit(APage, AIndex: Integer);
var
  Img: TPDFiumImage;
  R: TRect;
  Value: string;
  FieldType, FieldFlags: Integer;
  Multiline: Boolean;
begin
  FinishInlineFormEdit(True);
  if FCore.FormWidgetReadOnly(APage, AIndex) then Exit;
  if not FCore.FormWidgetFieldInfo(APage, AIndex, FieldType,
    FieldFlags) or (FieldType <> 6) then Exit;
  Img := PageImage(APage);
  if Img = nil then Exit;
  if not FCore.FormWidgetDeviceRect(APage, AIndex,
    Img.Width, Img.Height, R) then Exit;
  Value := '';
  if not FCore.EditFormWidgetText(APage, AIndex, Value) then Exit;
  Multiline := FCore.FormWidgetLikelyMultiline(APage, AIndex);
  if Multiline then FInlineFormEditor := TInlineFormMemo.Create(Self)
  else FInlineFormEditor := TInlineFormEdit.Create(Self);
  FInlineFormPage := APage;
  FInlineFormIndex := AIndex;
  FInlineFormOriginal := Value;
  FInlineFormEditor.Parent := Img.Parent;
  // PDF-eigene Umrandung nicht mit dem Windows-Edit ueberzeichnen.
  // Editor innerhalb der Widget-Grenzen platzieren (auch bei Zoom).
  FInlineFormEditor.Text := Value;
  TInlineFormEditAccess(FInlineFormEditor).Font.Name := 'Arial';
  TInlineFormEditAccess(FInlineFormEditor).Color := clWhite;
  TInlineFormEditAccess(FInlineFormEditor).BorderStyle := bsNone;
  if FInlineFormEditor is TInlineFormEdit then
    TInlineFormEdit(FInlineFormEditor).AutoSize := False;
  FInlineFormEditor.SetBounds(Img.Left + R.Left + 2,
    Img.Top + R.Top + 2, Max(12, R.Right - R.Left - 4),
    Max(12, R.Bottom - R.Top - 4));
  UpdateInlineFormEditorFont;
  TInlineFormEditAccess(FInlineFormEditor).OnExit := InlineFormEditorExit;
  TInlineFormEditAccess(FInlineFormEditor).OnKeyDown := InlineFormEditorKeyDown;
  UpdateFormFocusFrame;
  FInlineFormEditor.BringToFront;
  FInlineFormEditor.SetFocus;
end;

function TFreePDF64PDFiumView.HasActiveFormWidget: Boolean;
begin
  Result := (FCore <> nil) and (FCore.PageCount > 0) and
    (FActiveFormWidgetPage >= 0) and
    (FActiveFormWidgetPage < FCore.PageCount) and
    (FActiveFormWidgetIndex >= 0);
end;

procedure TFreePDF64PDFiumView.ActivateFocusedFormChoice;
var
  Page: Integer;
begin
  if not HasActiveFormWidget then Exit;
  Page := FActiveFormWidgetPage;
  if FCore.FormWidgetReadOnly(Page, FActiveFormWidgetIndex) then Exit;
  if FCore.ToggleFormWidgetChoice(Page, FActiveFormWidgetIndex) then
  begin
    // JavaScript-Berechnungen koennen Formularwerte auf anderen Seiten
    // aendern. Alle zwischengespeicherten Seitenbilder invalidieren.
    // Die Bitmaps bleiben bis zum Neurendern sichtbar (kein Aufblitzen).
    for Page := 0 to High(FLoadedPages) do
      FLoadedPages[Page] := False;
    RenderVisiblePages;
    UpdateSaveState;
    UpdateFormFocusFrame;
  end;
end;

procedure TFreePDF64PDFiumView.FocusAdjacentFormWidget(ADirection: Integer);
var
  NextPage, NextIndex: Integer;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  if (FActiveFormWidgetPage < 0) or
     (FActiveFormWidgetPage >= FCore.PageCount) then
  begin
    FActiveFormWidgetPage := FPage;
    if ADirection < 0 then FActiveFormWidgetIndex := MaxInt
    else FActiveFormWidgetIndex := -1;
  end;
  if FCore.FindAdjacentFormWidget(FActiveFormWidgetPage,
    FActiveFormWidgetIndex, ADirection, NextPage, NextIndex) then
  begin
    FActiveFormWidgetPage := NextPage;
    FActiveFormWidgetIndex := NextIndex;
    ShowPage(NextPage);
    UpdateFormFocusFrame;
    if (FFormFocusFrame <> nil) and FFormFocusFrame.Visible then
      FScroll.ScrollInView(FFormFocusFrame);
    BeginInlineFormEdit(NextPage, NextIndex);
    if (FInlineFormEditor = nil) and FScroll.CanFocus then
      FScroll.SetFocus;
    FStatus.Caption := Format(Tr('Formularfeld %d auf Seite %d'),
      [NextIndex + 1, NextPage + 1]);
    // Die laengere Statusmeldung benoetigt eine neue, DPI-skalierte Breite.
    LayoutToolbar(nil);
  end
  else
    PDFModernMessageDlg(Tr('Keine weiteren Formularfelder gefunden.'),
      mtInformation, [mbOK], 0);
end;

procedure TFreePDF64PDFiumView.ShowRequiredFieldsReport;
begin
  RequiredFieldsReportClick(nil);
end;

procedure TFreePDF64PDFiumView.RequiredFieldsReportClick(Sender: TObject);
var
  Report: TStringList;
  Dialog: TForm;
  Memo: TMemo;
  ButtonPanel: TPanel;
  CloseButton, CopyButton, ExportButton: TButton;
  MissingCount, I: Integer;
  ExportDialog: TSaveDialog;
begin
  // Auch beim direkten Aufruf den Sprachzustand abgleichen.
  ThumbMenuPopup(nil);
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  Report := TStringList.Create;
  try
    try
      MissingCount := FCore.ListEmptyRequiredFields(Report);
    except
      on E: Exception do
      begin
        PDFModernMessageDlg(Tr('Pflichtfeldpruefung fehlgeschlagen: ') +
          E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
    Dialog := TForm.CreateNew(Self);
    try
      Dialog.Caption := Tr('Pflichtfeldbericht');
      Dialog.Position := poScreenCenter;
      Dialog.BorderStyle := bsSizeable;
      Dialog.ClientWidth := 680;
      Dialog.ClientHeight := 460;
      Dialog.Constraints.MinWidth := 430;
      Dialog.Constraints.MinHeight := 260;

      ButtonPanel := TPanel.Create(Dialog);
      ButtonPanel.Parent := Dialog;
      ButtonPanel.Align := alBottom;
      ButtonPanel.Height := 48;
      ButtonPanel.BevelOuter := bvNone;

      CloseButton := TButton.Create(Dialog);
      CloseButton.Parent := ButtonPanel;
      CloseButton.SetBounds(560, 8, 108, 32);
      CloseButton.Anchors := [akRight, akTop];
      CloseButton.Caption := Tr('Schliessen');
      CloseButton.ModalResult := mrOk;
      CloseButton.Default := True;

      CopyButton := TButton.Create(Dialog);
      CopyButton.Parent := ButtonPanel;
      CopyButton.SetBounds(12, 8, 155, 32);
      CopyButton.Caption := Tr('Bericht kopieren');

      ExportButton := TButton.Create(Dialog);
      ExportButton.Parent := ButtonPanel;
      ExportButton.SetBounds(178, 8, 155, 32);
      ExportButton.Caption := Tr('Als Text speichern');

      Memo := TMemo.Create(Dialog);
      Memo.Parent := Dialog;
      Memo.Align := alClient;
      Memo.ReadOnly := True;
      Memo.ScrollBars := ssVertical;
      Memo.WordWrap := True;
      Memo.TabStop := True;
      Memo.Lines.BeginUpdate;
      try
        Memo.Lines.Add(Format(Tr('Fehlende Pflichtfelder: %d'),
          [MissingCount]));
        Memo.Lines.Add('');
        if MissingCount = 0 then
          Memo.Lines.Add(Tr('Alle erkannten Pflichtfelder sind ausgefüllt.'))
        else
          begin
          for I := 0 to Report.Count - 1 do
          begin
            // Feldnamen bleiben unveraendert; nur der Berichtsrahmen
            // (Seite, Typ) wird uebersetzt.
            if PDFLanguage = 'en' then
              Memo.Lines.Add(
                StringReplace(
                  StringReplace(
                    StringReplace(
                      StringReplace(
                        StringReplace(Report[I], 'Seite ', 'Page ', []),
                        ' (Text/Auswahl)', ' (text/choice)', []),
                      ' (Checkbox)', ' (checkbox)', []),
                    ' (Radio-Gruppe)', ' (radio group)', []),
                  ', Feld ', ', field ', []))
            else
              Memo.Lines.Add(Report[I]);
          end;
        end;
      finally
        Memo.Lines.EndUpdate;
      end;

      // Keine zusaetzlichen globalen Event-Handler: Aktionen laufen
      // in einem lokalen modalen Dialog ueber die Button-ModalResults.
      CopyButton.ModalResult := mrRetry;
      ExportButton.ModalResult := mrYes;
      repeat
        case Dialog.ShowModal of
          mrRetry:
            Clipboard.AsText := Memo.Lines.Text;
          mrYes:
            begin
              ExportDialog := TSaveDialog.Create(Dialog);
              try
                ExportDialog.Title := Tr('Pflichtfeldbericht speichern');
                ExportDialog.Filter := Tr('Textdateien') + ' (*.txt)|*.txt';
                ExportDialog.DefaultExt := 'txt';
                ExportDialog.FileName := 'FreePDF64_Pflichtfeldbericht.txt';
                if ExportDialog.Execute then
                  try
                    Memo.Lines.SaveToFile(ExportDialog.FileName, TEncoding.UTF8);
                  except
                    on E: Exception do
                      PDFModernMessageDlg(
                        Tr('Bericht konnte nicht gespeichert werden: ') +
                        E.Message, mtError, [mbOK], 0);
                  end;
              finally
                ExportDialog.Free;
              end;
            end;
        else
          Break;
        end;
      until False;
    finally
      Dialog.Free;
    end;
  finally
    Report.Free;
  end;
end;

procedure TFreePDF64PDFiumView.ReloadCurrentPDF;
begin
  ReloadPDFClick(nil);
end;

procedure TFreePDF64PDFiumView.ReloadPDFClick(Sender: TObject);
var
  SourceFile: string;
  Target: Integer;
  WasRenderTimer, WasThumbTimer: Boolean;
begin
  if FCore = nil then Exit;
  SourceFile := FCore.FileName;
  if (SourceFile = '') or not FileExists(SourceFile) then Exit;
  if HasUnsavedChanges and
     (PDFModernMessageDlg(
       Tr('Alle nicht gespeicherten Änderungen verwerfen und den letzten Speicherstand wiederherstellen?'),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  // Der Benutzer hat das Verwerfen bestaetigt: auch den aktiven Editor
  // schliessen, bevor das PDFium-Dokument ersetzt wird.
  CancelSignature;
  FinishInlineFormEdit(False);
  if FFormFocusFrame <> nil then FFormFocusFrame.Visible := False;
  FActiveFormWidgetIndex := -1;
  Target := FPage;
  WasRenderTimer := FRenderTimer.Enabled;
  WasThumbTimer := FThumbTimer.Enabled;
  FRenderTimer.Enabled := False;
  FThumbTimer.Enabled := False;
  try
    try
      // OpenFile verwirft den geaenderten PDFium-Dokumentzustand und
      // liest die zuletzt gespeicherte Originaldatei erneut ein.
      FCore.OpenFile(SourceFile);
      // Nicht gespeicherte Messungen erst nach erfolgreichem Neuladen verwerfen.
      CancelMeasurement;
      FMeasureRects.Clear;
      FMeasureRedo.Clear;
      FMeasureUndo.Clear;
      FMeasureDirty := False;
      UpdateTextUndoButtons;
      SetLength(FPageSizesValid, 0);
      SetLength(FLoadedPages, 0);
      FPage := 0;
      FLayoutPageLimit := Min(1, FCore.PageCount);
      FThumbSelected.Clear;
      FThumbAnchor := -1;
      FResizePending := False;
      PaintPage;
      PopulateOutline;
      BuildThumbnails;
      if FCore.PageCount > 0 then
        ShowPage(Min(Target, FCore.PageCount - 1));
      UpdateSaveState;
      FRenderPending := True;
    except
      on E: Exception do
        PDFModernMessageDlg(Tr('PDF konnte nicht neu geladen werden: ') +
          E.Message, mtError, [mbOK], 0);
    end;
  finally
    FRenderTimer.Enabled := WasRenderTimer;
    FThumbTimer.Enabled := WasThumbTimer and FThumbScroll.Visible;
  end;
end;

procedure TFreePDF64PDFiumView.PageContextRotateClick(Sender: TObject);
var
  Angle: Integer;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  Angle := 90;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = -90) then
    Angle := -90;
  try
    // Nur die per Rechtsklick gewaehlte Seite, nicht die Miniaturauswahl.
    RotatePages(FPage + 1, FPage + 1, Angle);
    RenderVisiblePages;
  except
    on E: Exception do
      PDFModernMessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TFreePDF64PDFiumView.RotateSelectedThumbs(Sender: TObject);
var
  Pages: TArray<Integer>;
  I: Integer;
  OldScrollY: Integer;
  WasTimerEnabled: Boolean;
  Degrees: Integer;
  VisiblePage, OldLayoutLimit: Integer;
  Busy: TForm;
begin
  if FThumbSelected.Count = 0 then Exit;
  Degrees := 90;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Tag = -90) then
    Degrees := -90;
  Pages := FThumbSelected.ToArray;
  WasTimerEnabled := FRenderTimer.Enabled;
  FRenderTimer.Enabled := False;
  OldScrollY := FScroll.VertScrollBar.Position;
  VisiblePage := FPage;
  OldLayoutLimit := FLayoutPageLimit;
  Busy := ShowPDFBusyNotice('Seite(n) werden gedreht.');
  try
    try
      FThumbTimer.Enabled := False;
    // Keine vollstaendige PDF-Sicherung vor der Aktion mehr.
    for I := 0 to High(Pages) do
      FCore.RotateInMemory(Pages[I] + 1, Pages[I] + 1, Degrees);
    // Die PDFium-Seitenrotation aendert die Geometrie. Der bisherige
    // Rendercache und die gemerkten Seitenmasse sind damit ungueltig.
    // Ohne diese Invalidierung zeigt die Hauptansicht alte Bitmaps an.
    for I := 0 to High(Pages) do
    begin
      if (Pages[I] >= 0) and (Pages[I] < Length(FPageSizesValid)) then
        FPageSizesValid[Pages[I]] := False;
      if (Pages[I] >= 0) and (Pages[I] < Length(FLoadedPages)) then
        FLoadedPages[Pages[I]] := False;
      if (Pages[I] >= 0) and (Pages[I] < FPages.Count) then
        TPDFiumImage(FPages[Pages[I]]).Picture.Assign(nil);
    end;
    // Beim Drehen der sichtbaren Seite deren neue Geometrie fuer
    // "Ganze Seite" verwenden. Eine andere Miniatur darf die aktuelle
    // Seite dagegen nicht heimlich aendern.
    FPage := VisiblePage;
    // Auch eine noch nicht vom Hintergrundaufbau erreichte Zielseite
    // muss beim Drehen ein gueltiges Seiten-Control besitzen.
    if FContinuous and (Pages[High(Pages)] >= FLayoutPageLimit) then
      FLayoutPageLimit := Min(FCore.PageCount,
        Max(OldLayoutLimit, Pages[High(Pages)] + 1));
    // Alte Resize-Sperre darf die Aktualisierung nicht verhindern.
    FResizePending := False;
    // Nur ein Layoutdurchlauf; die vorherige Scrollposition bleibt stabil.
    // Keine mehrfachen Render-Timer-Aufrufe während des Layouts.
    PaintPage;
    if FContinuous then
    begin
      // Nach einer 90-Grad-Drehung aendert sich die Seitenhoehe.
      // Ein unveraenderter Pixel-Scrollwert kann daher eine andere
      // Seite bzw. eine leere Flaeche sichtbar machen.
      // Bei "Ganze Seite" die bisher aktive Seite einmalig verankern.
      if (FViewMode = 1) and (VisiblePage >= 0) and
         (VisiblePage < FPages.Count) then
        FScroll.VertScrollBar.Position := Max(0,
          FScroll.VertScrollBar.Position +
          FScroll.ScreenToClient(
            TPDFiumImage(FPages[VisiblePage]).ClientToScreen(Point(0, 0))).Y - 12)
      else
        FScroll.VertScrollBar.Position := OldScrollY;
    end;
    // Die alte Bitmap ist geloescht. Den sichtbaren Bereich direkt
    // nach dem Layout rendern; nicht auf einen spaeteren Timer-Tick
    // warten, der zunaechst weitere Layout-Batches ausfuehren kann.
    FResizePending := False;
    RenderVisiblePages;
    if FOutlinePanel.Visible then PopulateOutline;
    // Die Miniatur-Steuerelemente und die Mehrfachauswahl erhalten.
    // BuildThumbnails wuerde alle Controls loeschen und FThumbSelected
    // leeren: dadurch gingen Markierung, Fokus und Scrollposition verloren.
    for I := 0 to High(Pages) do
      if (Pages[I] >= 0) and (Pages[I] < FThumbImages.Count) then
        TImage(FThumbImages[Pages[I]]).Picture.Assign(nil);
    UpdateThumbnailSelection;
    UpdateSaveState;
    // Kein ShowPage direkt nach PaintPage: das wuerde die Scrollposition
    // erneut verschieben und in der durchgehenden Ansicht ein zweites
    // Layout/Rendering ausloesen (sichtbares Zittern).
    // Die sichtbare Seite bleibt waehrend des Renderns erhalten.
    // FPage hier nicht erneut überschreiben: dies konnte bei
    // durchgehender Ansicht ein Pendeln zwischen zwei Seiten auslösen.
    FRenderPending := True;
    FThumbTimer.Enabled := FThumbScroll.Visible and (FCore.PageCount > 0);
    except
      on E: Exception do PDFModernMessageDlg(Tr('Drehen fehlgeschlagen: ') + E.Message,
        mtError, [mbOK], 0);
    end;
  finally
    Busy.Free;
    FRenderTimer.Enabled := WasTimerEnabled;
  end;
end;

procedure TFreePDF64PDFiumView.DeleteSelectedThumbs(Sender: TObject);
var
  Pages: TArray<Integer>;
  I, Target: Integer;
  Img: TPDFiumImage;
begin
  if FThumbSelected.Count = 0 then Exit;
  if FThumbSelected.Count >= FCore.PageCount then
  begin
    PDFModernMessageDlg(Tr('Mindestens eine Seite muss erhalten bleiben.'), mtWarning, [mbOK], 0);
    Exit;
  end;
  if PDFModernMessageDlg(Format('%d ausgewählte PDF-Seite(n) entfernen?'+sLineBreak+
     'Das Original bleibt unverändert. Dauerhaft wird die Änderung erst mit "Speichern unter ...".',
     [FThumbSelected.Count]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Pages := FThumbSelected.ToArray;
  Target := FPage;
  for I := 0 to High(Pages) do
    if Pages[I] < FPage then Dec(Target);
  FThumbTimer.Enabled := False;
  try
    // Keine vollstaendige PDF-Sicherung vor der Aktion mehr.
    FCore.DeletePages(Pages);
    FThumbSelected.Clear;
    FThumbAnchor := -1;
    FPage := Max(0, Min(FCore.PageCount - 1, Target));
    FSelecting := False;
    FSelAnchorPage := -1;
    FSelFocusPage := -1;
    FSearchTimer.Enabled := False;
    FSearchRunning := False;
    SetLength(FSearchMatches, 0);
    FFindTerm := '';
    FMatchPage := -1;
    FMatchChar := -1;
    FMatchCount := 0;
    FTotalSearchMatches := 0;
    if Assigned(FOnSearchCountChanged) then FOnSearchCountChanged(Self);
    // Nach dem Loeschen beziehen sich die bisherigen Bitmap-Indizes auf
    // andere physische PDF-Seiten. Alle alten Seitenbilder verwerfen,
    // sonst bleibt die geloeschte Seite sichtbar (gleiche Seitengroesse).
    for I := 0 to High(FLoadedPages) do
      FLoadedPages[I] := False;
    for I := 0 to FPages.Count - 1 do
    begin
      Img := TPDFiumImage(FPages[I]);
      Img.Picture.Assign(nil);
    end;
    SetLength(FPageSizesValid, 0);
    FInitialRenderDeferred := False;
    FZoomRenderPending := False;
    FScrollRenderPending := False;
    FResizePending := False;
    PaintPage;
    FRenderPending := True;
    FRenderTimer.Enabled := True;
    PopulateOutline;
    // Keine Zwischenanzeige von Seite 1 waehrend des asynchronen Neuaufbaus.
    FThumbDeleteRebuildPending := True;
    if FOutlinePanel.HandleAllocated then
      SendMessage(FOutlinePanel.Handle, WM_SETREDRAW, 0, 0);
    if FThumbScroll.HandleAllocated then
      SendMessage(FThumbScroll.Handle, WM_SETREDRAW, 0, 0);
    BuildThumbnails;
    // Die aktive Seite nach dem Neuaufbau anzeigen und den blauen Rahmen
    // sowie die Scrollposition der Miniaturansicht synchronisieren.
    ShowPage(FPage);
    FThumbScrollTarget := FPage;
    UpdateThumbnailSelection;
    ScrollThumbnailToCurrentPage;
    UpdateSaveState;
  except
    on E: Exception do
    begin
      if FThumbDeleteRebuildPending then
      begin
        FThumbDeleteRebuildPending := False;
        if FThumbScroll.HandleAllocated then
        begin
          SendMessage(FThumbScroll.Handle, WM_SETREDRAW, 1, 0);
          FThumbScroll.Invalidate;
        end;
        if FOutlinePanel.HandleAllocated then
        begin
          SendMessage(FOutlinePanel.Handle, WM_SETREDRAW, 1, 0);
          FOutlinePanel.Invalidate;
        end;
      end;
      PDFModernMessageDlg(Tr('Seiten konnten nicht entfernt werden: ') + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFreePDF64PDFiumView.OutlineHeaderResize(Sender: TObject);
var
  Margin, Gap, CloseW, TabH, ButtonW, TabsWidth, DesiredH, FirstW, SecondW, NeededW: Integer;
  MeasureBitmap: TBitmap;
begin
  if (FOutlineHeader = nil) or (FThumbTab = nil) or
     (FBookmarksTab = nil) or (FOutlineClose = nil) then Exit;

  // Dieselbe Schrift wie in der Ansichtsauswahl ("Seitenbreite") verwenden.
  // Designfarben bleiben erhalten; nur Schriftfamilie, Groesse und Stil
  // werden uebernommen. Nur bei Aenderung zuweisen (kein Flackern).
  if FViewSelect <> nil then
  begin
    if (FThumbTab.Font.Name <> FViewSelect.Font.Name) or
       (FThumbTab.Font.Size <> FViewSelect.Font.Size) or
       (FThumbTab.Font.Style <> FViewSelect.Font.Style) then
    begin
      FThumbTab.ParentFont := False;
      FThumbTab.Font.Name := FViewSelect.Font.Name;
      FThumbTab.Font.Size := FViewSelect.Font.Size;
      FThumbTab.Font.Style := FViewSelect.Font.Style;
    end;
    if (FBookmarksTab.Font.Name <> FViewSelect.Font.Name) or
       (FBookmarksTab.Font.Size <> FViewSelect.Font.Size) or
       (FBookmarksTab.Font.Style <> FViewSelect.Font.Style) then
    begin
      FBookmarksTab.ParentFont := False;
      FBookmarksTab.Font.Name := FViewSelect.Font.Name;
      FBookmarksTab.Font.Size := FViewSelect.Font.Size;
      FBookmarksTab.Font.Style := FViewSelect.Font.Style;
    end;
  end;

  // Nur eine Zeile: Seiten | Inhalte                          X
  // Alle Abmessungen an aktuelle DPI und Schriftgroesse anpassen.
  Margin := Max(5, MulDiv(6, CurrentPPI, 96));
  Gap := Max(3, MulDiv(4, CurrentPPI, 96));
  MeasureBitmap := TBitmap.Create;
  try
    MeasureBitmap.Canvas.Font.Assign(FThumbTab.Font);
    TabH := Max(MeasureBitmap.Canvas.TextHeight('Ag') + Gap * 3,
      MulDiv(28, CurrentPPI, 96));
    CloseW := Max(TabH, MulDiv(28, CurrentPPI, 96));
    CloseW := Min(CloseW, Max(18, FOutlineHeader.ClientWidth div 4));
    TabsWidth := Max(0, FOutlineHeader.ClientWidth - 2 * Margin - CloseW - 2 * Gap);
    // Englisch "Bookmarks" braucht mehr Platz als "Pages".
    // Reale Textbreiten statt starrer 50/50-Aufteilung verwenden.
    FirstW := MeasureBitmap.Canvas.TextWidth(FThumbTab.Caption) + 2 * Gap + MulDiv(14, CurrentPPI, 96);
    MeasureBitmap.Canvas.Font.Assign(FBookmarksTab.Font);
    SecondW := MeasureBitmap.Canvas.TextWidth(FBookmarksTab.Caption) + 2 * Gap + MulDiv(14, CurrentPPI, 96);
    NeededW := FirstW + SecondW + Gap;
    if NeededW > TabsWidth then
    begin
      // Bei sehr schmaler Seitenleiste bekommt der laengere Text Vorrang.
      FirstW := Max(0, TabsWidth - Gap) * FirstW div Max(1, FirstW + SecondW);
      SecondW := Max(0, TabsWidth - Gap - FirstW);
    end;
    ButtonW := FirstW;
    FThumbTab.SetBounds(Margin, Margin, ButtonW, TabH);
    FBookmarksTab.SetBounds(Margin + ButtonW + Gap, Margin,
      SecondW, TabH);
    FOutlineClose.SetBounds(FOutlineHeader.ClientWidth - Margin - CloseW,
      Margin, CloseW, TabH);
    DesiredH := TabH + 2 * Margin;
    if FOutlineHeader.Height <> DesiredH then
      FOutlineHeader.Height := DesiredH;
  finally
    MeasureBitmap.Free;
  end;
end;

procedure TFreePDF64PDFiumView.ThumbAreaResize(Sender: TObject);
begin
  if (FThumbScroll = nil) or (FThumbImages = nil) or
     FThumbResizeInProgress then Exit;

  // Eine neue Bitmap (z.B. nach Wasserzeichen) kann die Scrollbar
  // umschalten und damit ClientWidth aendern, ohne dass die Seitenleiste
  // selbst breiter geworden ist. Das darf die Miniaturen nicht vergroessern.
  // Explizite Layout-Aufrufe (Sender=nil) bleiben immer moeglich.
  if (Sender <> nil) and (FOutlinePanel <> nil) then
  begin
    // Eine neu eingeblendete Scrollleiste veraendert ClientWidth,
    // ohne die Breite der Seitenleiste zu veraendern.
    if (FThumbLastOutlineWidth = FOutlinePanel.ClientWidth) and
       (FThumbLastClientWidth = FThumbScroll.ClientWidth) then Exit;
    FThumbLastOutlineWidth := FOutlinePanel.ClientWidth;
    FThumbLastClientWidth := FThumbScroll.ClientWidth;
  end
  else if FOutlinePanel <> nil then
  begin
    FThumbLastOutlineWidth := FOutlinePanel.ClientWidth;
    FThumbLastClientWidth := FThumbScroll.ClientWidth;
  end;

  // Bei laufendem Ziehen nicht fuer jede einzelne Mausbewegung alle
  // Steuerelemente neu positionieren. Der Timer buendelt die Updates auf
  // maximal ca. 28 Aktualisierungen pro Sekunde. Explizite Aufrufe (z.B.
  // nach dem Erzeugen eines Batches) werden sofort ausgefuehrt.
  FThumbResizePending := True;
  if Sender = nil then
  begin
    if FThumbResizeTimer <> nil then
      FThumbResizeTimer.Enabled := False;
    ThumbResizeTimerTick(nil);
  end
  else if FThumbResizeTimer <> nil then
    FThumbResizeTimer.Enabled := True;
end;

procedure TFreePDF64PDFiumView.ThumbResizeTimerTick(Sender: TObject);
begin
  if FThumbResizeTimer <> nil then
    FThumbResizeTimer.Enabled := False;
  if not FThumbResizePending then Exit;
  FThumbResizePending := False;
  ApplyThumbnailLayout;
end;

procedure TFreePDF64PDFiumView.ApplyThumbnailLayout;
var
  I, ThumbWidth, ThumbHeight, LeftX, Y: Integer;
  Img: TImage;
  Lab: TLabel;
  Border, SelectionBorder: TShape;
begin
  if (FThumbScroll = nil) or (FThumbImages = nil) or
     FThumbResizeInProgress then Exit;

  FThumbResizeInProgress := True;
  try
    // Miniaturen an die tatsaechliche Breite der Seitenleiste anpassen.
    // Stabile Bildbreite unabhaengig davon, ob die vertikale Scrollleiste
    // sichtbar ist. Nur die horizontale Position folgt der Clientbreite.
    ThumbWidth := EnsureRange(FThumbScroll.Width -
      GetSystemMetrics(SM_CXVSCROLL) - 24, 80, 320);
    ThumbWidth := Min(ThumbWidth, Max(1, FThumbScroll.ClientWidth - 16));
    LeftX := Max(0, (FThumbScroll.ClientWidth - ThumbWidth) div 2);
    // TScrollBox verschiebt die Top-Koordinaten der Child-Controls
    // beim Scrollen. Ein erneutes Layout darf den Scrolloffset nicht
    // als zusaetzlichen oberen Leerraum in die Miniaturen einbauen.
    Y := 12 - FThumbScroll.VertScrollBar.Position;
    Border := nil;
    SelectionBorder := nil;

    // Grafikcontrols werden in einem Durchlauf neu angeordnet. Das Redraw
    // des Scrollbereichs bleibt waehrenddessen gesperrt, damit bei grossen
    // PDFs nicht tausende Einzelinvalidierungen sichtbar ruckeln.
    if not FThumbScroll.HandleAllocated then
      FThumbScroll.HandleNeeded;
    SendMessage(FThumbScroll.Handle, WM_SETREDRAW, 0, 0);
    FThumbScroll.DisableAlign;
    try
      for I := 0 to FThumbScroll.ControlCount - 1 do
      begin
        if FThumbScroll.Controls[I] is TShape then
        begin
          if Copy(FThumbScroll.Controls[I].Name, 1, 15) = 'ThumbSelection_' then
            SelectionBorder := TShape(FThumbScroll.Controls[I])
          else
            Border := TShape(FThumbScroll.Controls[I]);
          Continue;
        end;

        if FThumbScroll.Controls[I] is TImage then
        begin
          Img := TImage(FThumbScroll.Controls[I]);

          // Seitenverhaeltnis aus dem bereits vorhandenen Seitenmass-Cache.
          // Es wird waehrend des Ziehens kein PDFium-Rendering ausgeloest.
          if (Img.Tag >= 0) and (Img.Tag < Length(FPageSizesValid)) and
             FPageSizesValid[Img.Tag] and
             (FPageWidths[Img.Tag] > 0) and (FPageHeights[Img.Tag] > 0) then
            ThumbHeight := Round(ThumbWidth *
              FPageHeights[Img.Tag] / FPageWidths[Img.Tag])
          else if (Length(FPageSizesValid) > 0) and FPageSizesValid[0] and
                  (FPageWidths[0] > 0) and (FPageHeights[0] > 0) then
            // Noch nicht geladene Seiten mit demselben Massstab wie Seite 1.
            ThumbHeight := Round(ThumbWidth * FPageHeights[0] / FPageWidths[0])
          else
            ThumbHeight := Round(118 * ThumbWidth / 145);
          ThumbHeight := EnsureRange(ThumbHeight, 55, 420);

          if (Img.Left <> LeftX) or (Img.Top <> Y) or
             (Img.Width <> ThumbWidth) or (Img.Height <> ThumbHeight) then
            Img.SetBounds(LeftX, Y, ThumbWidth, ThumbHeight);

          if Border <> nil then
          begin
            if (Border.Left <> LeftX - 4) or (Border.Top <> Y - 4) or
               (Border.Width <> ThumbWidth + 8) or
               (Border.Height <> ThumbHeight + 8) then
              Border.SetBounds(LeftX - 4, Y - 4,
                ThumbWidth + 8, ThumbHeight + 8);
            Border := nil;
          end;
          if SelectionBorder <> nil then
          begin
            if (SelectionBorder.Left <> LeftX - 2) or
               (SelectionBorder.Top <> Y - 2) or
               (SelectionBorder.Width <> ThumbWidth + 4) or
               (SelectionBorder.Height <> ThumbHeight + 4) then
              SelectionBorder.SetBounds(LeftX - 2, Y - 2,
                ThumbWidth + 4, ThumbHeight + 4);
            SelectionBorder := nil;
          end;
          Inc(Y, ThumbHeight + 5);
          Continue;
        end;

        if FThumbScroll.Controls[I] is TLabel then
        begin
          Lab := TLabel(FThumbScroll.Controls[I]);
          if Copy(Lab.Name, 1, 11) = 'ThumbCheck_' then
           begin
             Lab.Left := LeftX + ThumbWidth - Lab.Width - 4;
             Continue;
           end;
           if (Lab.Left <> (FThumbScroll.ClientWidth - 70) div 2) or
             (Lab.Top <> Y) or (Lab.Width <> 70) or (Lab.Height <> 18) then
            Lab.SetBounds((FThumbScroll.ClientWidth - 70) div 2, Y, 70, 18);
          Inc(Y, 29);
        end;
      end;
    finally
      FThumbScroll.EnableAlign;
      SendMessage(FThumbScroll.Handle, WM_SETREDRAW, 1, 0);
      FThumbScroll.Invalidate;
    end;
  finally
    FThumbResizeInProgress := False;
  end;
end;

procedure TFreePDF64PDFiumView.AppendThumbnailBatch(ACount: Integer);
var
  I, Y, H, LastPage: Integer;
  Border, SelectionBorder: TShape;
  Img: TImage;
  Lab, CheckMark: TLabel;
  W, PH: Single;
begin
  if (FThumbScroll = nil) or (FCore = nil) then Exit;
  // Maximal ACount Steuerelementgruppen pro Timer-Durchlauf erstellen.
  // Kein PDFium-PageSize fuer jede Seite vor der ersten Anzeige aufrufen.
  Y := 12;
  if FThumbScroll.ControlCount > 0 then
  begin
    Lab := FThumbScroll.Controls[FThumbScroll.ControlCount - 1] as TLabel;
    Y := Lab.Top + Lab.Height + 11;
  end;
  LastPage := Min(FCore.PageCount, FThumbNext + ACount);
  FThumbScroll.DisableAlign;
  try
    for I := FThumbNext to LastPage - 1 do
    begin
      H := 118;
      if (Length(FPageSizesValid) > 0) and FPageSizesValid[0] and
         (FPageWidths[0] > 0) and (FPageHeights[0] > 0) then
        H := Round(145 * FPageHeights[0] / FPageWidths[0]);
      if (I < Length(FPageSizesValid)) and FPageSizesValid[I] and
         (FPageWidths[I] > 0) and (FPageHeights[I] > 0) then
      begin
        W := FPageWidths[I];
        PH := FPageHeights[I];
        H := Round(145 * PH / W);
      end;
      H := EnsureRange(H, 55, 185);
      Border := TShape.Create(FThumbScroll);
      Border.Parent := FThumbScroll;
      Border.SetBounds(4, Y - 4, 153, H + 8);
      Border.Shape := stRectangle;
      Border.Brush.Style := bsClear;
      Border.Pen.Width := 3;
      Border.Pen.Color := clWhite;
      Border.Tag := I;
      // Zweiter, innenliegender Rahmen: Markierung unabhaengig von der
      // blauen Kennzeichnung der aktuell angezeigten Seite darstellen.
      SelectionBorder := TShape.Create(FThumbScroll);
      SelectionBorder.Name := 'ThumbSelection_' + IntToStr(I);
      SelectionBorder.Parent := FThumbScroll;
      SelectionBorder.SetBounds(6, Y - 2, 149, H + 4);
      SelectionBorder.Shape := stRectangle;
      SelectionBorder.Brush.Style := bsClear;
      SelectionBorder.Pen.Width := 2;
      SelectionBorder.Pen.Color := clRed;
      SelectionBorder.Visible := False;
      SelectionBorder.Tag := I;
      Img := TImage.Create(FThumbScroll);
      Img.Parent := FThumbScroll;
      Img.SetBounds(8, Y, 145, H);
      Img.Stretch := True;
      Img.Proportional := True;
      Img.Center := True;
      Img.Tag := I;
      // Navigation erfolgt in ThumbMouseUp, damit Capture sie nicht verschluckt.
      Img.OnMouseDown := ThumbMouseDown;
      Img.OnMouseMove := ThumbMouseMove;
      Img.OnMouseUp := ThumbMouseUp;
      Img.PopupMenu := FThumbMenu;
      FThumbImages.Add(Img);
      // Zusaetzliches Haekchen fuer die Mehrfachauswahl.
      // Transparent und deaktiviert: Mausklicks/Drag-and-drop gehen
      // weiterhin an die darunterliegende Miniatur.
      CheckMark := TLabel.Create(FThumbScroll);
      CheckMark.Name := 'ThumbCheck_' + IntToStr(I);
      CheckMark.Parent := FThumbScroll;
      CheckMark.AutoSize := False;
      CheckMark.SetBounds(128, Y + 4, 21, 23);
      CheckMark.Alignment := taCenter;
      CheckMark.Caption := '✓';
      CheckMark.Font.Name := 'Segoe UI Symbol';
      CheckMark.Font.Size := 14;
      CheckMark.Font.Style := [fsBold];
      CheckMark.Font.Color := clRed;
      CheckMark.Transparent := True;
      CheckMark.Enabled := False;
      CheckMark.Visible := False;
      CheckMark.Tag := I;
      Inc(Y, H + 5);
      Lab := TLabel.Create(FThumbScroll);
      Lab.Parent := FThumbScroll;
      Lab.Caption := IntToStr(I + 1);
      Lab.SetBounds(70, Y, 70, 18);
      Lab.Tag := I;
      // Navigation erfolgt in ThumbMouseUp.
      Lab.OnMouseDown := ThumbMouseDown;
      Lab.OnMouseMove := ThumbMouseMove;
      Lab.OnMouseUp := ThumbMouseUp;
      Lab.PopupMenu := FThumbMenu;
      Inc(Y, 29);
    end;
    FThumbNext := LastPage;
  finally
    FThumbScroll.EnableAlign;
  end;
  ThumbAreaResize(nil);
  UpdateThumbnailSelection;
  if (FThumbScrollTarget >= 0) and (FThumbScrollTarget < FThumbNext) then
    ScrollThumbnailToCurrentPage;
  if FThumbDeleteRebuildPending and (FThumbScrollTarget < 0) then
  begin
    FThumbDeleteRebuildPending := False;
    if FThumbScroll.HandleAllocated then
    begin
      SendMessage(FThumbScroll.Handle, WM_SETREDRAW, 1, 0);
      FThumbScroll.Invalidate;
    end;
    if FOutlinePanel.HandleAllocated then
    begin
      SendMessage(FOutlinePanel.Handle, WM_SETREDRAW, 1, 0);
      FOutlinePanel.Invalidate;
    end;
  end;
end;

procedure TFreePDF64PDFiumView.BuildThumbnails;
begin
  EndThumbDragVisual;
  FThumbTimer.Enabled := False;
  FThumbSelected.Clear;
  FThumbAnchor := -1;
  FThumbImages.Clear;
  // Bei Loeschaktionen bleibt die Neuzeichnung bis zur Zielminiatur
  // gesperrt. Keinen sichtbaren Zwischenzustand auf Seite 1 erzeugen.
  if not FThumbDeleteRebuildPending then
    FThumbScroll.VertScrollBar.Position := 0;
  while FThumbScroll.ControlCount > 0 do
    FThumbScroll.Controls[0].Free;
  FThumbNext := 0;
  FThumbScrollTarget := EnsureRange(FPage, 0, Max(0, FCore.PageCount - 1));
  // Erste Miniaturen sofort anzeigen; den Rest ohne UI-Blockade nachbauen.
  AppendThumbnailBatch(12);
  FThumbTimer.Interval := 40;
  FThumbTimer.Enabled := (FCore.PageCount > 0);
end;

procedure TFreePDF64PDFiumView.ScrollThumbnailToCurrentPage;
var
  Img: TImage;
  Desired, MaxPos: Integer;
begin
  if (FThumbScroll = nil) or not FThumbScroll.Visible or
     (FOutlinePanel = nil) or not FOutlinePanel.Visible or
     (FCore = nil) or (FCore.PageCount = 0) then Exit;
  // Im kontinuierlichen Modus ist FPage die aktuell sichtbare Seite.
  // Bei noch nicht erstellten Miniaturen wird der Sprung nachgeholt.
  if FThumbScrollTarget < 0 then
    FThumbScrollTarget := EnsureRange(FPage, 0, FCore.PageCount - 1);
  if FThumbScrollTarget >= FThumbImages.Count then
  begin
    // Die Zielminiatur wird inkrementell aufgebaut. Keine synchrone
    // Schleife ueber hunderte Controls im UI-Thread.
    FThumbTimer.Enabled := True;
    Exit;
  end;
  Img := TImage(FThumbImages[FThumbScrollTarget]);
  // Die TScrollBox verschiebt Img.Top beim Scrollen. Daher muss die
  // absolute Dokumentposition aus sichtbarer Position + Scrolloffset
  // berechnet werden. Img.Top allein springt sonst zurueck an den Anfang.
  Desired := FThumbScroll.VertScrollBar.Position +
    FThumbScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0))).Y -
    Max(0, (FThumbScroll.ClientHeight - Img.Height) div 2);
  MaxPos := Max(0, FThumbScroll.VertScrollBar.Range - FThumbScroll.ClientHeight);
  FThumbScroll.VertScrollBar.Position := EnsureRange(Desired, 0, MaxPos);
  FThumbScrollTarget := -1;
end;

procedure TFreePDF64PDFiumView.UpdateThumbnailSelection;
var
  NewCaption, NewHint: string;
  I: Integer;
  Border: TShape;
  CheckMark: TLabel;
  Selected: Boolean;
begin
  if FThumbScroll = nil then Exit;
  for I := 0 to FThumbScroll.ControlCount - 1 do
  begin
    if FThumbScroll.Controls[I] is TShape then
    begin
      Border := TShape(FThumbScroll.Controls[I]);
      Selected := FThumbSelected.IndexOf(Border.Tag) >= 0;
      if Copy(Border.Name, 1, 15) = 'ThumbSelection_' then
      begin
        // Roter Innenrahmen bei Auswahl, auch auf der aktiven Seite.
        Border.Visible := Selected;
      end
      else
      begin
        // Blauer Aussenrahmen kennzeichnet ausschliesslich die aktive Seite.
        if Border.Tag = FPage then
          Border.Pen.Color := clHighlight
        else
          Border.Pen.Color := clWhite;
      end;
    end
    else if (FThumbScroll.Controls[I] is TLabel) and
            (Copy(FThumbScroll.Controls[I].Name, 1, 11) = 'ThumbCheck_') then
    begin
      CheckMark := TLabel(FThumbScroll.Controls[I]);
      CheckMark.Visible := FThumbSelected.IndexOf(CheckMark.Tag) >= 0;
    end;
  end;
  if FThumbTab <> nil then
  begin
    // Caption nur bei tatsaechlicher Aenderung setzen: ein erneutes
    // Zuweisen bei jedem Miniaturklick zeichnet den Header unnoetig neu.
    NewCaption := Tr('Seiten');
    if FThumbTab.Caption <> NewCaption then
      FThumbTab.Caption := NewCaption;
    NewHint := Tr('Blau: aktuelle Seite; Rot und Häkchen: ausgewählte Seiten');
    if FThumbTab.Hint <> NewHint then
      FThumbTab.Hint := NewHint;
    if not FThumbTab.ShowHint then
      FThumbTab.ShowHint := True;
  end;
end;

procedure TFreePDF64PDFiumView.ThumbTimerTick(Sender: TObject);
var
  Img: TImage;
  Bmp: TBitmap;
  I, TopY, BottomY, RenderW, RenderH: Integer;
  PageW, PageH, Ratio: Single;
  Pt: TPoint;
begin
  // Der Timer darf den Kopfbereich nicht bei jedem Tick neu zeichnen.
  if (FThumbScroll = nil) or not FThumbScroll.Visible then Exit;
  // Weitere Miniaturen inkrementell aufbauen, statt tausende Controls
  // beim Klick auf die Seitenleiste synchron zu erzeugen.
  if FThumbNext < FCore.PageCount then
    AppendThumbnailBatch(12);
  // Nur Miniaturen im sichtbaren Bereich rendern, statt 800 Seiten
  // unnoetig im Hintergrund zu erzeugen.
  for I := 0 to FThumbImages.Count - 1 do
  begin
    Img := TImage(FThumbImages[I]);
    if not Img.Picture.Bitmap.Empty then Continue;
    Pt := FThumbScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
    TopY := Pt.Y;
    BottomY := TopY + Img.Height;
    if (BottomY < -200) or (TopY > FThumbScroll.ClientHeight + 200) then
      Continue;
    // Die fuer das Layout verwendeten vorlaeufigen Seitenmasse duerfen
    // nicht die Bitmap verzerren: erst die echten PDF-Seitenmasse lesen.
    // Die gerenderte Bitmap muss das Original-Seitenverhaeltnis behalten.
    if not FCore.PageSize(Img.Tag, PageW, PageH) then Continue;
    if (PageW <= 0) or (PageH <= 0) then Continue;
    Ratio := PageW / PageH;
    RenderW := Img.Width;
    RenderH := Round(RenderW / Ratio);
    if RenderH > Img.Height then
    begin
      RenderH := Img.Height;
      RenderW := Max(1, Round(RenderH * Ratio));
    end;
    RenderW := Max(1, RenderW);
    RenderH := Max(1, RenderH);
    Bmp := TBitmap.Create;
    try
      FCore.RenderPage(Img.Tag, Bmp, RenderW, RenderH);
      // Erst nach vollstaendigem Rendern das fertige Bild uebergeben.
      Img.Picture.Bitmap.Assign(Bmp);
    finally Bmp.Free; end;
    Break; // Eine Miniatur je Tick, damit die VCL reagiert.
  end;
end;

procedure TFreePDF64PDFiumView.OutlineChange(Sender: TObject; Node: TTreeNode);
var
  Item: TPDFBookmarkItem;
begin
  if Node = nil then Exit;
  Item := TPDFBookmarkItem(Node.Data);
  if (Item <> nil) and (Item.PageIndex >= 0) and
     (Item.PageIndex < FCore.PageCount) then
    ShowPage(Item.PageIndex);
end;

procedure TFreePDF64PDFiumView.OutlineMenuPopup(Sender: TObject);
begin
  if FOutlineMenu = nil then Exit;
  if SameText(PDFLanguage, 'en') then
  begin
    FOutlineExpandItem.Caption := 'Expand All';
    FOutlineCollapseItem.Caption := 'Collapse All';
  end
  else
  begin
    FOutlineExpandItem.Caption := 'Alle aufklappen';
    FOutlineCollapseItem.Caption := 'Alle zuklappen';
  end;
  FOutlineExpandItem.Enabled := (FOutlineTree <> nil) and (FOutlineTree.Items.Count > 0);
  FOutlineCollapseItem.Enabled := FOutlineExpandItem.Enabled;
end;

procedure TFreePDF64PDFiumView.OutlineExpandAll(Sender: TObject);
var
  Node: TTreeNode;
begin
  if FOutlineTree = nil then Exit;
  FOutlineTree.Items.BeginUpdate;
  try
    Node := FOutlineTree.Items.GetFirstNode;
    while Node <> nil do
    begin
      Node.Expand(False);
      Node := Node.GetNext;
    end;
  finally
    FOutlineTree.Items.EndUpdate;
  end;
end;

procedure TFreePDF64PDFiumView.OutlineCollapseAll(Sender: TObject);
var
  Node: TTreeNode;
begin
  if FOutlineTree = nil then Exit;
  FOutlineTree.Items.BeginUpdate;
  try
    Node := FOutlineTree.Items.GetFirstNode;
    while Node <> nil do
    begin
      Node.Collapse(False);
      Node := Node.GetNext;
    end;
  finally
    FOutlineTree.Items.EndUpdate;
  end;
end;

procedure TFreePDF64PDFiumView.PopulateOutline;
  procedure AddNodes(AParent: TTreeNode; AList: TObjectList<TPDFBookmarkItem>);
  var
    I: Integer;
    Node: TTreeNode;
  begin
    for I := 0 to AList.Count - 1 do
    begin
      Node := FOutlineTree.Items.AddChildObject(AParent, AList[I].Title, AList[I]);
      AddNodes(Node, AList[I].Children);
    end;
  end;
begin
  FOutlineTree.Items.BeginUpdate;
  try
    FOutlineTree.Items.Clear;
    FOutlineItems.Clear;
    FCore.ReadBookmarks(FOutlineItems);
    if FOutlineItems.Count = 0 then
      FOutlineTree.Items.Add(nil, Tr('Keine PDF-Lesezeichen vorhanden'))
    else
      AddNodes(nil, FOutlineItems);
  finally
    FOutlineTree.Items.EndUpdate;
  end;
end;

procedure TFreePDF64PDFiumView.UpdateSecurityIcon;
begin
  if FInfo = nil then Exit;
  if (FCore <> nil) and (FCore.PageCount > 0) and
     (FCore.SecurityRevision >= 0) then
  begin
    FInfo.Caption := '🔒';
    FInfo.Hint := Tr('Verschlüsseltes PDF – Dokumenteigenschaften anzeigen');
  end
  else
  begin
    FInfo.Caption := 'ⓘ';
    FInfo.Hint := Tr('Dokumenteigenschaften anzeigen');
  end;
end;

procedure TFreePDF64PDFiumView.ToggleEditBar(Sender: TObject);
begin
  FEditVisible := not FEditVisible;
  // Nach dem Zurueckwechsel aus der geteilten Ansicht kann ein
  // natives ComboBox-Handle seine Auswahl verlieren. Nur ungueltige
  // Auswahlwerte restaurieren; Benutzerauswahl sonst beibehalten.
  if FEditVisible then
  begin
    if (FShapeSelect <> nil) and (FShapeSelect.Items.Count > 0) and
       (FShapeSelect.ItemIndex < 0) then
      FShapeSelect.ItemIndex := 0;
    if (FWidthSelect <> nil) and (FWidthSelect.Items.Count > 0) and
       (FWidthSelect.ItemIndex < 0) then
      FWidthSelect.ItemIndex := Min(3, FWidthSelect.Items.Count - 1);
  end;
  FEditToggle.Highlighted := FEditVisible;
  FMarkMode := FEditVisible and not FTextInsertMode and not FHighlightMode and not FNoteMode;
  if not FEditVisible then
  begin
    // Beim Schliessen der Werkzeugleiste keinen aktiven Texteingabemodus
    // oder unbestaetigten Editor zuruecklassen.
    if FTextEditor <> nil then
      FinishTextEditor(False);
    FTextInsertMode := False;
    FHighlightMode := False;
    FNoteMode := False;
    FMeasureMode := False;
    CancelMeasurement;
    if FMeasureButton <> nil then
      FMeasureButton.Font.Style := [];
    FMarkMode := False;
    if FNoteButton <> nil then FNoteButton.Caption := ToolbarHint('Kommentar', 'Comment');
    Screen.Cursor := crDefault;
    FHighlightButton.Caption := ToolbarHint('Text hervorheben', 'Highlight text');
    FTextInsertButton.Caption := Tr('Text einfügen');
  end;
  // Nach dem Schliessen und erneuten Oeffnen die Schrift des
  // Einfuegen-Dropdowns an den nun inaktiven Modi ausrichten.
  UpdateTextUndoButtons;
  // Align dauerhaft beibehalten. Ein Wechsel zwischen alNone/alTop
  // waehrend des Layouts kann unvorhersehbare Leerzeilen erzeugen.
  FEditBar.DisableAlign;
  try
    FEditBar.Align := alTop;
    if FEditVisible then
    begin
      FEditBar.Height := MulDiv(30, CurrentPPI, 96);
      FEditBar.Visible := True;
    end
    else
    begin
      FEditBar.Visible := False;
      FEditBar.Height := 0;
    end;
  finally
    FEditBar.EnableAlign;
  end;
  // Bei zwei alTop-Panels die Reihenfolge explizit sichern:
  // Hauptleiste oben, Bearbeitungswerkzeuge direkt darunter.
  FBar.BringToFront;
  FEditToggle.Caption := '';
  LayoutToolbar(nil);
  Realign;
  // Messungen beim Schließen der Werkzeuge nur ausblenden.
  if not FEditVisible then
    for var MeasurePageIndex := 0 to FPages.Count - 1 do
      if TObject(FPages[MeasurePageIndex]) is TPDFiumImage then
        TPDFiumImage(FPages[MeasurePageIndex]).Invalidate;
end;

procedure TFreePDF64PDFiumView.HelpClick(Sender: TObject);
var
  Dlg: TForm;
  HelpText: string;
begin
  if PDFLanguage = 'en' then
    HelpText :=
      'FreePDF64 Viewer Help' + sLineBreak + sLineBreak +
      'NAVIGATION' + sLineBreak +
      'Table of contents: Show bookmarks and page thumbnails.' + sLineBreak +
      'Back / Next: Go to the previous or next PDF page.' + sLineBreak +
      'Page number / Go to: Jump directly to a page.' + sLineBreak + sLineBreak +
      'ZOOM AND VIEW' + sLineBreak +
      '- / +: Zoom out or in.' + sLineBreak +
      'Fit page: Fit the PDF page to the viewing area.' + sLineBreak +
      'View selector: Page width, full page, 100%, or custom zoom.' + sLineBreak +
      '1 page / 2 pages: Single-page or two-page view.' + sLineBreak +
      'Continuous / Paged: Scroll continuously or page by page.' + sLineBreak + sLineBreak +
      'SEARCH AND TEXT' + sLineBreak +
      'Find text / Ctrl+F: Search for a term in the PDF.' + sLineBreak +
      'F3 / Shift+F3: Next / previous match.' + sLineBreak +
      'Without edit mode: Select text with the mouse.' + sLineBreak +
      'Ctrl+C: Copy selected text.' + sLineBreak +
      'Ctrl+A: Select all PDF text.' + sLineBreak + sLineBreak +
      'EDITING' + sLineBreak +
      'Edit: Show or hide drawing tools.' + sLineBreak +
      'Choose freehand, line, rectangle, ellipse, visual redaction, or Hand Tool.' + sLineBreak +
      'Hand Tool: Drag a zoomed PDF with the left mouse button.' + sLineBreak +
      'Alt + left mouse button: Temporarily pan a zoomed PDF.' + sLineBreak +
      'Redaction draws a black rectangle. The underlying PDF text remains and can be copied or restored. Not suitable for confidential data.' + sLineBreak +
      'Secure redaction: mark areas with Redaction preview, then use Apply secure redaction to create a new PDF. Marked pages are rasterized at 300 DPI; text selection/search is unavailable on those pages. Bookmarks are not transferred.' + sLineBreak +
      'Set line width and color, then draw with the mouse.' + sLineBreak + sLineBreak +
      'DOCUMENT AND FILE' + sLineBreak +
      'Attachments: Show embedded files.' + sLineBreak +
      'Rotate: Rotate PDF pages.' + sLineBreak +
      'Document info (i/lock): Properties and security.' + sLineBreak +
      'Page thumbnails: Right-click to delete selected pages.' + sLineBreak +
      'Ctrl-click / Shift-click: Select multiple pages.' + sLineBreak +
      'Deleted pages are permanently removed only when you use Save As.' + sLineBreak +
      'Save As: Save the PDF as a new file.' + sLineBreak +
      'Print: Print the PDF.' + sLineBreak + sLineBreak +
      'KEYBOARD' + sLineBreak +
      'Ctrl+Shift+A: Tab search.' + sLineBreak +
      'F11: Toggle full-screen mode.' + sLineBreak +
      'Esc in full screen: Return to the normal window.' + sLineBreak +
      'Esc otherwise: Close the attachments window or the active PDF tab.'
  else
    HelpText :=
      'Hilfe zum FreePDF64-Viewer' + sLineBreak + sLineBreak +
      'NAVIGATION' + sLineBreak +
      'Inhaltsverzeichnis: Lesezeichen und Seitenminiaturen einblenden.' + sLineBreak +
      'Zurück / Weiter: Zur vorherigen oder nächsten PDF-Seite.' + sLineBreak +
      'Seitenzahl / Gehe zu: Direkt zu einer Seite springen.' + sLineBreak + sLineBreak +
      'ZOOM UND ANSICHT' + sLineBreak +
      '- / +: Ansicht verkleinern oder vergrößern.' + sLineBreak +
      'Seite einpassen: Die PDF-Seite in den Anzeigebereich einpassen.' + sLineBreak +
      'Ansichtsauswahl: Seitenbreite, ganze Seite, 100 % oder frei.' + sLineBreak +
      '1 Seite / 2 Seiten: Einzel- oder Doppelseitenansicht.' + sLineBreak +
      'Durchgehend / Seitenweise: Scrollen oder seitenweise blättern.' + sLineBreak + sLineBreak +
      'SUCHE UND TEXT' + sLineBreak +
      'Text suchen / Strg+F: Begriff im PDF suchen.' + sLineBreak +
      'F3 / Umschalt+F3: Nächster / vorheriger Treffer.' + sLineBreak +
      'Ohne Bearbeitungsmodus: Text mit der Maus auswählen.' + sLineBreak +
      'Strg+C: Ausgewählten Text kopieren.' + sLineBreak +
      'Strg+A: Gesamten PDF-Text auswählen.' + sLineBreak + sLineBreak +
      'BEARBEITEN' + sLineBreak +
      'Bearbeiten: Zeichenwerkzeuge ein- oder ausblenden.' + sLineBreak +
      'Freihand, Linie, Rechteck, Ellipse, Schwärzen (optisch) oder Hand-Werkzeug auswählen.' + sLineBreak +
      'Hand-Werkzeug: Gezoomte PDF mit gedrückter linker Maustaste verschieben.' + sLineBreak +
      'Alt + linke Maustaste: Gezoomte PDF vorübergehend verschieben.' + sLineBreak +
      'Schwärzen zeichnet ein schwarzes Rechteck. Der darunterliegende PDF-Text bleibt erhalten und kann kopiert oder wiederhergestellt werden. Nicht für vertrauliche Daten geeignet.' + sLineBreak +
      'Sichere Schwärzung: Bereiche mit Schwärzung (Vorschau) markieren und anschließend Endgültig schwärzen wählen. Es wird eine neue PDF-Datei erstellt; markierte Seiten werden mit 300 DPI gerastert. Textauswahl und Suche sind auf diesen Seiten danach nicht mehr möglich. Lesezeichen werden nicht übernommen.' + sLineBreak +
      'Strichstärke und Farbe festlegen; mit der Maus zeichnen.' + sLineBreak + sLineBreak +
      'DOKUMENT UND DATEI' + sLineBreak +
      'Anlagen: Eingebettete Dateien anzeigen.' + sLineBreak +
      'Drehen: PDF-Seiten drehen.' + sLineBreak +
      'Dokumentinfo (i/Schloss): Eigenschaften und Sicherheit.' + sLineBreak +
      'Seitenminiaturen: Rechtsklick zum Löschen ausgewählter Seiten.' + sLineBreak +
      'Strg-Klick / Umschalt-Klick: Mehrere Seiten auswählen.' + sLineBreak +
      'Gelöschte Seiten werden erst mit Speichern unter dauerhaft entfernt.' + sLineBreak +
      'Speichern unter: PDF als neue Datei speichern.' + sLineBreak +
      'Drucken: PDF ausdrucken.' + sLineBreak + sLineBreak +
      'TASTATUR' + sLineBreak +
      'Strg+Umschalt+A: Registerkartensuche.' + sLineBreak +
      'F11: Vollbildmodus ein- oder ausschalten.' + sLineBreak +
      'ESC im Vollbild: Zur normalen Fensteransicht zurückkehren.' + sLineBreak +
      'ESC sonst: Anlagenfenster oder aktiven PDF-Tab schließen.';
  Dlg := CreateMessageDialog(HelpText, mtInformation, [mbOK]);
  try
    Dlg.Caption := Tr('FreePDF64-Viewer - Hilfe');
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TFreePDF64PDFiumView.SetMergedToolbarWidth(AWidth: Integer);
begin
  if AWidth < 0 then AWidth := 0;
  // Auch bei unveraenderter Breite nach dem Wechsel von zwei auf eine
  // Werkzeugleiste den Trenner und den Miniaturbutton neu anordnen.
  if FMergedToolbarWidth = AWidth then
  begin
    LayoutToolbar(nil);
    Exit;
  end;
  FMergedToolbarWidth := AWidth;
  LayoutToolbar(nil);
end;

procedure TFreePDF64PDFiumView.RefreshToolbarAfterSplit;
begin
  // Nach dem Zurueckhaengen in den breiten Tab die zuvor im Split
  // ermittelte (ggf. mehrzeilige) PDFium-Leistenhoehe neu bestimmen.
  if FBar = nil then Exit;
  Realign;
  LayoutToolbar(nil);
  Realign;
end;

procedure TFreePDF64PDFiumView.SetMergedToolbarTrailingControls(
  const AControls: array of TControl; AParent: TWinControl);
var
  I: Integer;
  MeasureBitmap: TBitmap;
begin
  SetLength(FMergedTrailingControls, Length(AControls));
  MeasureBitmap := TBitmap.Create;
  try
    for I := 0 to High(AControls) do
    begin
      FMergedTrailingControls[I] := AControls[I];
      if (AControls[I] <> nil) and (AControls[I].Parent <> AParent) then
        AControls[I].Parent := AParent;
      if (AControls[I] is TLabel) and
         ((TLabel(AControls[I]).Name = 'PDFRotatePageLabel') or
          (TLabel(AControls[I]).Name = 'PDFRotateAngleLabel')) then
      begin
        TLabel(AControls[I]).ParentFont := False;
        TLabel(AControls[I]).Font.Name := 'Segoe UI';
        TLabel(AControls[I]).Font.Height := -MulDiv(9, CurrentPPI, 72);
        TLabel(AControls[I]).Font.Style := [];
        // Die Einzeilenleiste hat einen anderen Parent. Daher die Breite
        // nach dem finalen 9-pt-Font neu messen, damit "Winkel:" vollstaendig
        // sichtbar bleibt und die Schriftgroesse in beiden Modi identisch ist.
        TLabel(AControls[I]).AutoSize := False;
        MeasureBitmap.Canvas.Font.Assign(TLabel(AControls[I]).Font);
        TLabel(AControls[I]).Width :=
          MeasureBitmap.Canvas.TextWidth(TLabel(AControls[I]).Caption) +
          MulDiv(7, CurrentPPI, 96);
        TLabel(AControls[I]).Height :=
          Max(MulDiv(14, CurrentPPI, 96),
            MeasureBitmap.Canvas.TextHeight('Ag') + MulDiv(2, CurrentPPI, 96));
      end;
    end;
  finally
    MeasureBitmap.Free;
  end;
end;

procedure TFreePDF64PDFiumView.UpdateUndoRedoGlyphs;
var
  Dpi, Size, Stroke, I, J: Integer;
  B: TBitmap;
  P: array[0..5] of TPoint;
  Btn: TBitBtn;
  IsUndo: Boolean;
  function S(V: Integer): Integer;
  begin
    Result := MulDiv(V, Dpi, 96);
  end;
begin
  if (FTextUndoButton = nil) or (FTextRedoButton = nil) then Exit;
  Dpi := CurrentPPI;
  if Dpi <= 0 then Dpi := 96;
  if FUndoRedoGlyphPPI = Dpi then Exit;
  // Schlanke, bei nativer DPI gerasterte Pfeile statt dicker 24px-Piktogramme.
  Size := Max(16, S(20));
  Stroke := Max(1, S(2));
  for I := 0 to 1 do
  begin
    IsUndo := I = 0;
    if IsUndo then Btn := FTextUndoButton else Btn := FTextRedoButton;
    B := TBitmap.Create;
    try
      B.PixelFormat := pf24bit;
      B.SetSize(Size, Size);
      B.Canvas.Brush.Color := clFuchsia;
      B.Canvas.FillRect(Rect(0, 0, Size, Size));
      B.Canvas.Pen.Color := clBlack;
      B.Canvas.Pen.Width := Stroke;
      B.Canvas.Pen.Style := psSolid;
      B.Canvas.Brush.Style := bsClear;
      // Gebogener Schaft mit freier Pfeilspitze; beide Symbole gespiegelt.
      P[0] := Point(S(5), S(9));
      P[1] := Point(S(8), S(6));
      P[2] := Point(S(13), S(6));
      P[3] := Point(S(16), S(9));
      P[4] := Point(S(16), S(13));
      P[5] := Point(S(13), S(15));
      if not IsUndo then
        for J := 0 to High(P) do
          P[J].X := Size - 1 - P[J].X;
      B.Canvas.Polyline(P);
      if IsUndo then
      begin
        B.Canvas.MoveTo(S(5), S(9));
        B.Canvas.LineTo(S(5), S(5));
        B.Canvas.MoveTo(S(5), S(9));
        B.Canvas.LineTo(S(9), S(9));
      end
      else
      begin
        B.Canvas.MoveTo(Size - 1 - S(5), S(9));
        B.Canvas.LineTo(Size - 1 - S(5), S(5));
        B.Canvas.MoveTo(Size - 1 - S(5), S(9));
        B.Canvas.LineTo(Size - 1 - S(9), S(9));
      end;
      B.TransparentColor := clFuchsia;
      B.Transparent := True;
      Btn.Glyph.Assign(B);
    finally
      B.Free;
    end;
  end;
  FUndoRedoGlyphPPI := Dpi;
end;

procedure TFreePDF64PDFiumView.LayoutToolbar(Sender: TObject);
var
  X, Y, W, H, ButtonH, EditH, Gap, Margin, RowGap, RowH: Integer;
  StatusW: Integer;
  MeasureBitmap: TBitmap;
  MergeSeparator: TShape;
  OutlineSeparator: TPanel;
  PanelIndex, TrailingIndex, TrailingWidth: Integer;
  TrailingControl: TControl;
  function Px(AValue: Integer): Integer;
  begin
    Result := MulDiv(AValue, CurrentPPI, 96);
  end;
  procedure NextRow;
  begin
    X := Margin;
    Inc(Y, RowH + RowGap);
  end;
  procedure EnsureRoom(AWidth: Integer);
  begin
    if (X > Margin) and (X + AWidth > W - Margin) then
      NextRow;
  end;
  procedure PlaceControl(AControl: TControl; AWidth: Integer;
    AHeight: Integer);
  begin
    EnsureRoom(AWidth);
    // Alle Controls einschliesslich Ansichts-Dropdown exakt vertikal
    // zur gemeinsamen Button-Mittellinie ausrichten.
    AControl.SetBounds(X, Y + (RowH - AHeight) div 2, AWidth, AHeight);
    AControl.Visible := True;
    Inc(X, AWidth + Gap);
  end;
  procedure PlaceButton(AButton: TButton; AWidth: Integer);
  begin
    PlaceControl(AButton, Px(AWidth), ButtonH);
  end;
  procedure PlaceGroup(AGroupWidth: Integer);
  begin
    EnsureRoom(AGroupWidth);
  end;
begin
  if (FBar = nil) or (FInfo = nil) or (FEditBar = nil) then Exit;
  if FToolbarLayoutBusy then Exit;
  UpdateUndoRedoGlyphs;
  FToolbarLayoutBusy := True;
  try
  W := FBar.ClientWidth;
  if W < 1 then Exit;

  // Native Combobox-Hoehe beibehalten, damit High-DPI/VCL-Themes stimmen.
  ButtonH := Max(FFlowSelect.Height, Px(28));
  EditH := ButtonH;
  RowH := Max(ButtonH, EditH);
  Gap := Px(2);
  RowGap := Px(2);
  Margin := Px(4);
  X := Margin + FMergedToolbarWidth;
  Y := Px(1);
  // Sichtbare Trennlinie am Uebergang zwischen Browser- und PDF-Werkzeugen.
  // Einmal erzeugen und beim Layoutwechsel nur umpositionieren.
  MergeSeparator := TShape(FindComponent('PDFMergedToolbarSeparator'));
  if (FMergedToolbarWidth > 0) then
  begin
    if MergeSeparator = nil then
    begin
      MergeSeparator := TShape.Create(Self);
      MergeSeparator.Name := 'PDFMergedToolbarSeparator';
      MergeSeparator.Parent := FBar;
      MergeSeparator.Shape := stRectangle;
      MergeSeparator.Brush.Color := clBlack;
      MergeSeparator.Pen.Style := psClear;
    end;
    MergeSeparator.SetBounds(X - Px(5), Y + Px(2), Px(2), Px(20));
    MergeSeparator.Visible := True;
  end
  else if MergeSeparator <> nil then
    MergeSeparator.Visible := False;

  MeasureBitmap := TBitmap.Create;
  try
    MeasureBitmap.Canvas.Font.Assign(FStatus.Font);
    StatusW := Max(Px(38), MeasureBitmap.Canvas.TextWidth(FStatus.Caption) + Px(10));
  finally
    MeasureBitmap.Free;
  end;

  // Gruppen moeglichst zusammenhalten, bei sehr schmalem Fenster
  // einzelne Controls dennoch umbrechen lassen.
  if FMergedToolbarWidth > 0 then
  begin
    // Das links angedockte Browser-Panel verdeckt sonst den Button.
    // Den Button in dieses Panel verschieben, statt hinter ihm zu zeichnen.
    for PanelIndex := 0 to FBar.ControlCount - 1 do
      if (FBar.Controls[PanelIndex] is TWinControl) and
         (FBar.Controls[PanelIndex].Align = alLeft) then
      begin
        if FOutlineButton.Parent <> TWinControl(FBar.Controls[PanelIndex]) then
          FOutlineButton.Parent := TWinControl(FBar.Controls[PanelIndex]);
        Break;
      end;
    // Die Miniaturansicht auf derselben Hoehe wie die Browser-Buttons.
    FOutlineButton.SetBounds(Margin, Y + (RowH - ButtonH) div 2,
      Px(36), ButtonH);
    // Browser-Buttons werden im gemeinsamen Panel um 2 px tiefer zentriert.
    FOutlineButton.Top := FOutlineButton.Top + Px(1);
    FOutlineButton.Visible := True;
    // Schmaler Trennstrich direkt nach der Miniaturansicht.
    OutlineSeparator := TPanel(FindComponent('PDFOutlineToolbarSeparator'));
    if OutlineSeparator = nil then
    begin
      OutlineSeparator := TPanel.Create(Self);
      OutlineSeparator.Name := 'PDFOutlineToolbarSeparator';
      OutlineSeparator.BevelOuter := bvNone;
      OutlineSeparator.BevelInner := bvNone;
      OutlineSeparator.Color := clBtnShadow;
      OutlineSeparator.ParentBackground := False;
      OutlineSeparator.TabStop := False;
    end;
    OutlineSeparator.Parent := FOutlineButton.Parent;
    OutlineSeparator.SetBounds(Px(44), FOutlineButton.Top + Px(2),
      Max(1, Px(1)), Max(1, FOutlineButton.Height - Px(4)));
    OutlineSeparator.Visible := True;
    OutlineSeparator.BringToFront;
  end
  else
  begin
    OutlineSeparator := TPanel(FindComponent('PDFOutlineToolbarSeparator'));
    if OutlineSeparator <> nil then OutlineSeparator.Visible := False;
    if FOutlineButton.Parent <> FBar then
      FOutlineButton.Parent := FBar;
    PlaceGroup(Px(36) + Gap);
    PlaceButton(FOutlineButton, 36);
  end;
  // Trennlinie vor der Seitennavigation:
  // In der zusammengefassten Einzeilenleiste ausblenden; sie wird nur
  // in der getrennten zweizeiligen PDF-Werkzeugleiste benoetigt.
  if FMergedToolbarWidth > 0 then
    FNavigationSeparator.Visible := False
  else
    PlaceControl(FNavigationSeparator, Px(2), Px(22));
  PlaceGroup(StatusW + Px(34 + 38 + 28 + 28) + 5 * Gap);
  PlaceControl(FStatus, StatusW, Px(16));
  PlaceControl(FPageEdit, Px(32), Px(22));
  PlaceControl(FPageTotal, Px(38), Px(16));
  // Seitennavigation direkt hinter der Seitenzahl.
  PlaceButton(FPrev, 28);
  PlaceButton(FNext, 28);
  PlaceControl(FZoomSeparator, Px(2), Px(22));
  PlaceGroup(Px(32 + 32 + 38 + 46) + 4 * Gap);
  // Positionen einschliesslich zugeordneter Funktionen tauschen:
  // links Verkleinern (FPlus), rechts Vergroessern (FMinus).
  PlaceButton(FPlus, 32);
  PlaceButton(FMinus, 32);
  PlaceControl(FZoomStatus, Px(38), Px(16));
  PlaceButton(FZoom100Button, 46);
  PlaceControl(FFitSeparator, Px(2), Px(22));
  PlaceButton(FFit, 38);
  PlaceControl(FViewSelect, Px(130), EditH);
  // Das native Dropdown sitzt optisch etwas hoeher als die Buttons;
  // daher in der gemeinsamen Leiste leicht nach unten versetzen.
  FViewSelect.Top := FViewSelect.Top + Px(4);
  PlaceControl(FPageModeSeparator, Px(2), Px(22));
  PlaceButton(FTwoPageButton, 32);
  PlaceControl(FFlowSeparator, Px(2), Px(22));
  PlaceButton(FFlowToggleButton, 32);
  PlaceControl(FActionSeparator, Px(2), Px(22));
  // Im Einzeilenmodus folgt die bisherige Browser-Endgruppe direkt auf
  // die PDF-Navigations- und Zoomgruppe. Im Zweizeilenmodus bleiben diese
  // Controls in der oberen Browser-Symbolleiste.
  TrailingWidth := 0;
  for TrailingIndex := 0 to High(FMergedTrailingControls) do
  begin
    TrailingControl := FMergedTrailingControls[TrailingIndex];
    if (TrailingControl <> nil) and (TrailingControl.Parent = FBar) and
       TrailingControl.Visible then
    begin
      if TrailingControl.Name = 'PDFRotatePageEdit' then
        TrailingControl.SetBounds(TrailingControl.Left, TrailingControl.Top,
          Px(32), Px(22));
      Inc(TrailingWidth, TrailingControl.Width + Gap);
    end;
  end;
  if TrailingWidth > 0 then
  begin
    PlaceGroup(TrailingWidth);
    for TrailingIndex := 0 to High(FMergedTrailingControls) do
    begin
      TrailingControl := FMergedTrailingControls[TrailingIndex];
      if (TrailingControl <> nil) and (TrailingControl.Parent = FBar) and
         TrailingControl.Visible then
        PlaceControl(TrailingControl, TrailingControl.Width,
          TrailingControl.Height);
    end;
  end;
  // Aktionsgruppe als unteilbaren Block positionieren. Insbesondere darf
  // die Hilfe-Schaltflaeche nicht allein in die naechste Zeile springen.
  H := Px(34) + Px(34) + Px(40) + 2 * Gap;
  if FRedactionFinalizeButton <> nil then
    Inc(H, Px(148) + Gap);
  if (X > Margin) and (X + H > W - Margin) then
    NextRow;
  X := Max(Margin, W - Margin - H);
  FInfo.SetBounds(X, Y + (RowH - ButtonH) div 2, Px(34), ButtonH);
  Inc(X, Px(34) + Gap);
  if FRedactionFinalizeButton <> nil then
  begin
    FRedactionFinalizeButton.SetBounds(X, Y + (RowH - ButtonH) div 2,
      Px(148), ButtonH);
    Inc(X, Px(148) + Gap);
  end;
  FQuickSave.SetBounds(X, Y + (RowH - ButtonH) div 2, Px(34), ButtonH);
  Inc(X, Px(34) + Gap);
  FPrint.SetBounds(X, Y + (RowH - ButtonH) div 2, Px(40), ButtonH);
  FInfo.Visible := True;
  FQuickSave.Visible := True;
  FPrint.Visible := True;

  // Panelhoehe erst nach der Anordnung bestimmen. Dadurch wird beim
  // Verkleinern eine weitere Zeile frei, beim Vergroessern wieder entfernt.
  // Unteren Leerraum der einzeiligen Symbolleiste reduzieren.
  H := Y + RowH + Px(2);
  if (FMergedToolbarWidth > 0) and (H < Px(27)) then H := Px(27);
  if FBar.Height <> H then FBar.Height := H;

  // Bestehende Bearbeitungsleiste unveraendert belassen.
  if FEditVisible and FEditBar.Visible then
  begin
    W := FEditBar.ClientWidth;
    H := RowH + Px(2);
    if FEditBar.Height <> H then FEditBar.Height := H;
    X := Margin;
    Y := Px(1);
    // Die native Hoehe der Auswahlfelder ist die gemeinsame Bezugshoehe.
    // Damit erhalten Buttons, Farbfelder und Auswahllisten eine einheitliche
    // sichtbare Hoehe, auch bei anderer Windows-DPI-Skalierung.
    EditH := FShapeSelect.Height;
    if EditH < 1 then EditH := Px(24);
    PlaceControl(FShapeSelect, Px(165), EditH);
    PlaceControl(FWidthSelect, Px(54), EditH);
    PlaceControl(FHighlightButton, Px(116), EditH);
    PlaceControl(FColorButton, Px(60), EditH);
    PlaceControl(FColorSwatch, Px(22), EditH);
    PlaceControl(FTextInsertSeparator, Px(8), EditH);
    PlaceControl(FInsertButton, Px(94), EditH);
    PlaceControl(FMeasureButton, Px(94), EditH);
    PlaceControl(FMeasureUnitSelect, Px(52), EditH);
    // Maßstab wird ausschließlich über das Messen-Dropdown angeboten.
    PlaceControl(FTextUndoButton, Px(36), EditH);
    PlaceControl(FTextRedoButton, Px(36), EditH);
    // Text-Eingabezeile waehrend der Messung vollstaendig ausblenden.
    // Beim Wechsel zurueck wird sie im bestehenden Layout restauriert.
    if FMeasureMode then
    begin
      FTextFontSelect.Visible := False;
      FTextSizeSelect.Visible := False;
      FTextColorButton.Visible := False;
      FTextColorSwatch.Visible := False;
    end
    else
    begin
      PlaceControl(FTextFontSelect, Px(128), EditH);
      PlaceControl(FTextSizeSelect, Px(48), EditH);
      PlaceControl(FTextColorButton, Px(84), EditH);
      PlaceControl(FTextColorSwatch, Px(22), EditH);
    end;
    H := Y + RowH + Px(1);
    if FEditBar.Height <> H then FEditBar.Height := H;
  end;
  finally
    FToolbarLayoutBusy := False;
  end;
end;

function DetectPDFEncryptionQPDF(const APDFFile: string): string;
var
  ExePath, TempPath, Cmd, Output, Line, Method: string;
  Startup: TStartupInfo;
  ProcInfo: TProcessInformation;
  OutHandle: THandle;
  Lines: TStringList;
  I, Bits: Integer;
  R: DWORD;
  Buffer: array[0..MAX_PATH] of Char;
begin
  Result := 'Nicht verfügbar';
  ExePath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'qpdf\bin\qpdf.exe';
  if not FileExists(ExePath) then Exit;
  if GetTempPath(MAX_PATH, Buffer) = 0 then Exit;
  TempPath := IncludeTrailingPathDelimiter(string(Buffer)) +
    'FreePDF64_qpdf_' + IntToStr(GetCurrentProcessId) + '_' +
    IntToStr(GetTickCount) + '.txt';
  OutHandle := CreateFile(PChar(TempPath), GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, CREATE_ALWAYS,
    FILE_ATTRIBUTE_TEMPORARY, 0);
  if OutHandle = INVALID_HANDLE_VALUE then Exit;
  try
    FillChar(Startup, SizeOf(Startup), 0);
    Startup.cb := SizeOf(Startup);
    Startup.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    Startup.wShowWindow := SW_HIDE;
    Startup.hStdOutput := OutHandle;
    Startup.hStdError := OutHandle;
    Startup.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
    FillChar(ProcInfo, SizeOf(ProcInfo), 0);
    Cmd := '"' + ExePath + '" --show-encryption --password= "' + APDFFile + '"';
    if not CreateProcess(nil, PChar(Cmd), nil, nil, True,
      CREATE_NO_WINDOW, nil, nil, Startup, ProcInfo) then Exit;
    try
      R := WaitForSingleObject(ProcInfo.hProcess, 5000);
      if R = WAIT_TIMEOUT then TerminateProcess(ProcInfo.hProcess, 1);
    finally
      CloseHandle(ProcInfo.hThread);
      CloseHandle(ProcInfo.hProcess);
    end;
  finally
    CloseHandle(OutHandle);
  end;
  Lines := TStringList.Create;
  try
    if not FileExists(TempPath) then Exit;
    Lines.LoadFromFile(TempPath);
    Bits := 0;
    Method := '';
    for I := 0 to Lines.Count - 1 do
    begin
      Line := LowerCase(Trim(Lines[I]));
      // QPDF gibt beispielsweise "encryption key length = 128" aus.
      // Sowohl '=' als auch ':' sind erlaubt.
      if (Pos('encryption key length', Line) > 0) or
         (Pos('key length', Line) > 0) then
      begin
        if Pos('=', Line) > 0 then
          Line := Trim(Copy(Line, Pos('=', Line) + 1, MaxInt))
        else if Pos(':', Line) > 0 then
          Line := Trim(Copy(Line, Pos(':', Line) + 1, MaxInt))
        else
          Line := '';
        // Ziffern am Anfang extrahieren, z.B. "128 bits".
        while (Length(Line) > 0) and (Line[1] in ['0'..'9']) do
        begin
          Bits := Bits * 10 + Ord(Line[1]) - Ord('0');
          Delete(Line, 1, 1);
        end;
        Continue;
      end;
      // Bei PDF-Verschluesselung sind Stream- und String-Verfahren
      // ausschlaggebend. "AESv2" bedeutet AES-128, "AESv3" AES-256.
      if (Pos('aesv3', Line) > 0) or (Pos('aes-256', Line) > 0) then Method := 'AES-256'
      else if ((Pos('aesv2', Line) > 0) or (Pos('aes-128', Line) > 0)) and (Method <> 'AES-256') then
        Method := 'AES-128'
      else if (Pos('rc4', Line) > 0) and (Method = '') then
        Method := 'RC4';
    end;
    if Method = 'AES-256' then Result := '256-Bit AES'
    else if Method = 'AES-128' then Result := '128-Bit AES'
    else if (Method = 'RC4') and (Bits = 128) then Result := '128-Bit RC4'
    else if (Method = 'RC4') and (Bits = 40) then Result := '40-Bit RC4'
    else if Bits in [40, 128] then Result := IntToStr(Bits) + ' Bit (Verfahren unbekannt)'
    else if Bits = 256 then Result := '256 Bit (Verfahren unbekannt)';
  finally
    Lines.Free;
    DeleteFile(TempPath);
  end;
end;

procedure TFreePDF64PDFiumView.InfoDialogClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TFreePDF64PDFiumView.InfoDialogDestroy(Sender: TObject);
begin
  FInfoContentScroll := nil;
  FInfoDialog := nil;
  if Assigned(FInfo) then FInfo.Font.Style := [];
end;

procedure TFreePDF64PDFiumView.InfoDialogMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  SB: TScrollBox;
  NewPos, MaxPos, Step: Integer;
begin
  SB := FInfoContentScroll;
  if (SB = nil) or (WheelDelta = 0) then Exit;
  // Das Mausrad auch dann behandeln, wenn ein Label oder der Schliessen-Button
  // unter dem Mauszeiger liegt. Kein Scrollen im PDF-Hauptfenster.
  Step := MulDiv(60, Screen.PixelsPerInch, 96);
  MaxPos := Max(0, SB.VertScrollBar.Range - SB.ClientHeight);
  NewPos := EnsureRange(SB.VertScrollBar.Position -
    MulDiv(WheelDelta, Step, WHEEL_DELTA), 0, MaxPos);
  SB.VertScrollBar.Position := NewPos;
  Handled := True;
end;

procedure TFreePDF64PDFiumView.InfoCloseButtonClick(Sender: TObject);
begin
  if Assigned(FInfoDialog) then FInfoDialog.Close;
end;

procedure TFreePDF64PDFiumView.ShowDocumentProperties;
begin
  InfoClick(Self);
end;

procedure TFreePDF64PDFiumView.InfoClick(Sender: TObject);
var
  EncryptionText: string;
  Dlg: TForm;
  Header, SectionTitle, Lab, Val: TLabel;
  CloseBtn: TButton;
  ContentScroll: TScrollBox;
  Stream: TFileStream;
  Bytes: Int64;
  RowY, RowStep, FieldHeight, DialogW, DialogH, ContentH: Integer;
  PW, PH: Single;
  PageSizeText, VersionText, FilePath, OrientationText: string;
  PDFWindow: TCustomForm;
  function P(N: Integer): Integer;
  begin
    Result := MulDiv(N, Screen.PixelsPerInch, 96);
  end;
  function DisplayValue(const S: string): string;
  begin
    Result := Trim(S);
    if Result = '' then Result := 'Nicht verfügbar';
    Result := Tr(Result);
  end;
  function PDFDate(const S: string): string;
  var T: string;
  begin
    Result := DisplayValue(S);
    T := S;
    if Copy(T, 1, 2) = 'D:' then Delete(T, 1, 2);
    if Length(T) >= 14 then
      Result := Copy(T, 7, 2) + '.' + Copy(T, 5, 2) + '.' +
        Copy(T, 1, 4) + ', ' + Copy(T, 9, 2) + ':' +
        Copy(T, 11, 2) + ':' + Copy(T, 13, 2);
  end;
  function PermissionText(const Mask: UInt64): string;
  begin
    if (FCore.SecurityRevision < 0) or
       ((FCore.SecurityPermissions and Mask) = Mask) then
      Result := Tr('Erlaubt')
    else
      Result := Tr('Nicht erlaubt');
  end;
  procedure AddSection(const ACaption: string);
  var Sep: TBevel;
  begin
    if RowY > P(100) then
    begin
      Sep := TBevel.Create(Dlg);
      Sep.Parent := ContentScroll;
      Sep.Shape := bsTopLine;
      Sep.SetBounds(P(26), RowY + P(3), P(430), P(2));
      Inc(RowY, P(15));
    end;
    SectionTitle := TLabel.Create(Dlg);
    SectionTitle.Parent := ContentScroll;
    SectionTitle.Caption := Tr(ACaption);
    SectionTitle.Font.Style := [fsBold];
    SectionTitle.SetBounds(P(26), RowY, P(420), FieldHeight);
    Inc(RowY, RowStep + P(2));
  end;
  procedure AddField(const ACaption, AValue: string);
  begin
    Lab := TLabel.Create(Dlg);
    Lab.Parent := ContentScroll;
    Lab.Caption := Tr(ACaption);
    Lab.AutoSize := False;
    Lab.SetBounds(P(26), RowY, P(150), FieldHeight);
    Val := TLabel.Create(Dlg);
    Val.Parent := ContentScroll;
    Val.AutoSize := False;
    Val.EllipsisPosition := epEndEllipsis;
    Val.Caption := DisplayValue(AValue);
    Val.Hint := AValue;
    Val.ShowHint := True;
    Val.SetBounds(P(180), RowY, P(275), FieldHeight);
    Inc(RowY, RowStep);
  end;
  procedure AddPermission(const ACaption: string; const Mask: UInt64);
  begin
    Lab := TLabel.Create(Dlg);
    Lab.Parent := ContentScroll;
    Lab.Caption := Tr(ACaption);
    Lab.AutoSize := False;
    Lab.ShowHint := True;
    Lab.Hint := Lab.Caption;
    Lab.SetBounds(P(26), RowY, P(275), FieldHeight);
    Val := TLabel.Create(Dlg);
    Val.Parent := ContentScroll;
    Val.AutoSize := False;
    Val.Caption := PermissionText(Mask);
    Val.SetBounds(P(305), RowY, P(150), FieldHeight);
    Inc(RowY, RowStep);
  end;
begin
  // Second click closes the already open document properties window.
  if Assigned(FInfoDialog) then
  begin
    FInfoDialog.Close;
    Exit;
  end;
  if FCore.PageCount <= 0 then Exit;
  FilePath := FCore.FileName;
  Bytes := 0;
  if FileExists(FilePath) then
  begin
    Stream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
    try Bytes := Stream.Size; finally Stream.Free; end;
  end;
  PageSizeText := 'Nicht verfügbar';
  if FCore.PageSize(0, PW, PH) then
  begin
    if PW > PH then OrientationText := Tr('Querformat')
    else OrientationText := Tr('Hochformat');
    PageSizeText := Format('%d × %d mm (%s)',
      [Round(PW * 25.4 / 72), Round(PH * 25.4 / 72),
       OrientationText]);
  end;
  VersionText := FCore.PDFVersion;

  // Den Dialog dem tatsaechlichen PDF-Fenster zuordnen,
  // nicht dem Application.MainForm von FreePDF64.
  PDFWindow := GetParentForm(Self);
  if PDFWindow = nil then Exit;
  Dlg := TForm.CreateNew(Self);
  FInfoDialog := Dlg;
  Dlg.OnMouseWheel := InfoDialogMouseWheel;
  Dlg.OnClose := InfoDialogClose;
  Dlg.OnDestroy := InfoDialogDestroy;
  try
    Dlg.PopupMode := pmExplicit;
    Dlg.PopupParent := PDFWindow;
    Dlg.Caption := Tr('Dokumenteigenschaften');
    Dlg.BorderStyle := bsDialog;
    Dlg.Position := poDesigned;
    DialogW := P(485);
    // Kompakter Dialog; der Informationsbereich ist separat scrollbar.
    DialogH := P(610);
    if DialogH > Screen.WorkAreaHeight - P(70) then
      DialogH := Screen.WorkAreaHeight - P(70);
    Dlg.Left := PDFWindow.Left + (PDFWindow.Width - DialogW) div 2;
    Dlg.Top := PDFWindow.Top + (PDFWindow.Height - DialogH) div 2;
    if Dlg.Left < Screen.WorkAreaLeft then Dlg.Left := Screen.WorkAreaLeft;
    if Dlg.Top < Screen.WorkAreaTop then Dlg.Top := Screen.WorkAreaTop;
    Dlg.ClientWidth := DialogW;
    Dlg.ClientHeight := DialogH;
    Dlg.Font.Name := 'Segoe UI';
    Dlg.Font.Size := 9;
    // Die Schrift ist bereits durch VCL/Windows DPI-skaliert.
    // Keine zweite DPI-Multiplikation auf die Zeilenhoehe anwenden.
    FieldHeight := Dlg.Canvas.TextHeight('Ag') + 4;
    RowStep := FieldHeight + 5;
    Header := TLabel.Create(Dlg);
    Header.Parent := Dlg;
    Header.Caption := Tr('Dokumenteigenschaften');
    Header.Font.Size := 16;
    Header.SetBounds(P(26), P(22), P(430), P(36));
    ContentScroll := TScrollBox.Create(Dlg);
    ContentScroll.Parent := Dlg;
    FInfoContentScroll := ContentScroll;
    ContentScroll.OnMouseWheel := InfoDialogMouseWheel;
    ContentScroll.BorderStyle := bsNone;
    ContentScroll.HorzScrollBar.Visible := False;
    ContentScroll.VertScrollBar.Tracking := True;
    ContentScroll.SetBounds(P(8), P(70), DialogW - P(16),
      DialogH - P(70) - P(65));
    RowY := P(15);
    AddSection('Beschreibung');
    AddField('Dateiname:', ExtractFileName(FilePath));
    AddField('Dateigröße:', FormatFloat('#,##0', Bytes / 1024) + ' KB');
    AddField('Titel:', FCore.MetaText('Title'));
    AddField('Autor:', FCore.MetaText('Author'));
    AddField('Antragsteller:', FCore.MetaText('Subject'));
    AddField('Schlüsselwörter:', FCore.MetaText('Keywords'));
    AddField('Erstellt am:', PDFDate(FCore.MetaText('CreationDate')));
    AddField('Geändert am:', PDFDate(FCore.MetaText('ModDate')));
    AddField('Ersteller:', FCore.MetaText('Creator'));
    AddSection('Erweitert');
    AddField('PDF-Produzent:', FCore.MetaText('Producer'));
    AddField('PDF-Version:', VersionText);
    AddField('Standort:', ExtractFilePath(FilePath));
    AddField('Anzahl der Seiten:', IntToStr(FCore.PageCount));
    case FDocumentFormType of
      0: AddField('PDF-Formular:', 'Kein Formular');
      1: AddField('PDF-Formular:', 'AcroForm');
      2: AddField('PDF-Formular:', 'XFA (vollständig)');
      3: AddField('PDF-Formular:', 'XFA (Foreground)');
    else
      AddField('PDF-Formular:', 'Unbekannter Formulartyp');
    end;
    if FDocumentFormType <> 0 then
      AddField('Formular-Widgets:', IntToStr(FCore.FormWidgetCount));
    AddField('Seitengröße:', PageSizeText);
    AddField('Schnelle Webansicht:', 'Nicht verfügbar');
    AddSection('Sicherheit');
    if FCore.SecurityRevision < 0 then
    begin
      AddField('Verschlüsselt:', 'Nein');
      AddField('Verschlüsselung:', 'Keine');
    end
    else
    begin
      AddField('Verschlüsselt:', 'Ja');
      EncryptionText := DetectPDFEncryptionQPDF(FilePath);
      if EncryptionText = 'Nicht verfügbar' then
      begin
        // PDFium kennt die Sicherheitsrevision. Sie bestimmt die
        // Schluessellaenge, aber nicht immer den konkreten Algorithmus.
        case FCore.SecurityRevision of
          2: EncryptionText := Tr('40 Bit (PDF-Sicherheitsrevision 2)');
          3: EncryptionText := Tr('128 Bit (PDF-Sicherheitsrevision 3)');
          4: EncryptionText := Tr('128 Bit (PDF-Sicherheitsrevision 4)');
          5, 6: EncryptionText := Tr('256-Bit AES');
        end;
      end;
      AddField('Verschlüsselung:', EncryptionText);

    end;
    // PDF Standard Security Handler permission bits (ISO 32000).
    // For unencrypted PDFs there are no permission restrictions.
    AddSection('Berechtigungen');
    AddPermission('Drucken:', UInt64(4));
    AddPermission('Hochauflösend drucken:', UInt64(4) or UInt64(2048));
    AddPermission('Modifizieren:', UInt64(8));
    AddPermission('Kopieren von Inhalt:', UInt64(16));
    AddPermission('Kopieren von Inhalt für Barrierefreiheit:', UInt64(512));
    AddPermission('Kommentieren:', UInt64(32));
    AddPermission('Formulare ausfüllen:', UInt64(256));
    AddPermission('Dokumentzusammenstellung:', UInt64(1024));
    CloseBtn := TButton.Create(Dlg);
    CloseBtn.Parent := Dlg;
    CloseBtn.Caption := Tr('Schließen');
    CloseBtn.OnClick := InfoCloseButtonClick;
    CloseBtn.Cancel := True;
    // Der Schliessen-Button bleibt ausserhalb des scrollbaren Bereichs.
    CloseBtn.SetBounds(DialogW - P(225), DialogH - P(51), P(195), P(35));
    ContentH := RowY + P(15);
    ContentScroll.VertScrollBar.Range := ContentH;
    ContentScroll.VertScrollBar.Position := 0;
    // Nach der endgueltigen Groessenberechnung erneut am PDF-Fenster ausrichten.
    Dlg.Left := PDFWindow.Left + (PDFWindow.Width - Dlg.Width) div 2;
    Dlg.Top := PDFWindow.Top + (PDFWindow.Height - Dlg.Height) div 2;
    if Dlg.Left < Screen.WorkAreaLeft then Dlg.Left := Screen.WorkAreaLeft;
    if Dlg.Top < Screen.WorkAreaTop then Dlg.Top := Screen.WorkAreaTop;
    ApplyPDFDialogDesign(Dlg);
    Dlg.Show;
    if Assigned(FInfo) then FInfo.Font.Style := [fsBold];
  except
    FInfoContentScroll := nil;
    FInfoDialog := nil;
    Dlg.Free;
    raise;
  end;
end;

procedure TFreePDF64PDFiumView.ResizeView(Sender: TObject);
begin
  // Nicht bei jeder Mausbewegung alle PDF-Seiten neu layouten/rendern.
  // Der bestehende Render-Timer erledigt das nach einer kurzen Ruhephase.
  if (FCore <> nil) and (FCore.PageCount > 0) and
     (FScroll.ClientWidth > 100) and (FScroll.ClientHeight > 100) and
     IsWindowVisible(Handle) and not IsIconic(GetAncestor(Handle, GA_ROOT)) then
  begin
    FLastResizeTick := GetTickCount64;
    FResizePending := True;
  end;
end;

function TFreePDF64PDFiumView.PageImage(AIndex: Integer): TPDFiumImage;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < FPages.Count) then
    Result := TPDFiumImage(FPages[AIndex]);
end;

procedure TFreePDF64PDFiumView.UpdateVisiblePage;
var I, Y, Best, Dist, D: Integer; Img: TPDFiumImage;
begin
  if FRendering or (FCore.PageCount = 0) then Exit;
  Y := FScroll.ClientHeight div 3;
  Best := FPage;
  Dist := MaxInt;
  if not FContinuous then
  begin
    if not FPageEdit.Focused then
      FPageEdit.Text := IntToStr(FPage + 1);
    FPrev.Enabled := FPage > 0;
    FNext.Enabled := FPage < FCore.PageCount - 1;
    FPageTotal.Caption := Format('/ %d', [FCore.PageCount]);
    FZoomStatus.Caption := Format('%d%%', [Round(FZoom * 7200 / CurrentPPI)]);
    UpdateThumbnailSelection;
    Exit;
  end;
  for I := 0 to FPages.Count - 1 do
  begin
    Img := PageImage(I);
    D := Abs((FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0))).Y + Img.Height div 2) - Y);
    if D < Dist then begin Dist := D; Best := I; end;
  end;
  // Nur eine tatsaechliche Aenderung der sichtbaren Seite soll die
  // Miniaturleiste bewegen. Andernfalls waere sie beim manuellen
  // Durchsehen der Miniaturen nicht mehr bedienbar.
  if Best <> FPage then
  begin
    FPage := Best;
    // Beim Scrollen in der Hauptansicht ein altes ausstehendes Ziel
    // ersetzen. Sonst wird die Miniaturleiste erst bei einem spaeteren
    // Seitenwechsel auf den aktuellen Stand gebracht.
    if not FThumbClickNavigation then
      FThumbScrollTarget := Best;
    if (not FThumbClickNavigation) and
       (FOutlinePanel <> nil) and FOutlinePanel.Visible and
       (FThumbScroll <> nil) and FThumbScroll.Visible then
      ScrollThumbnailToCurrentPage;
  end;
  // Laufende Eingabe niemals durch Scroll-/Render-Aktualisierung ersetzen.
  if not FPageEdit.Focused then
    FPageEdit.Text := IntToStr(FPage + 1);
  FPrev.Enabled := FPage > 0;
  FNext.Enabled := FPage < FCore.PageCount - 1;
  FPageTotal.Caption := Format('/ %d', [FCore.PageCount]);
  FZoomStatus.Caption := Format('%d%%', [Round(FZoom * 7200 / CurrentPPI)]);
  UpdateThumbnailSelection;
end;

procedure TFreePDF64PDFiumView.RenderTimerTick(Sender: TObject);
var
  PositionNow, CenterX, TargetX, MaxX: Integer;
  ImgResize: TPDFiumImage;
begin
  if (FQuickSave <> nil) and (FCore <> nil) then
  begin
    if FCore.Modified <> FQuickSave.Highlighted then
      UpdateSaveState;
  end;
  if FRendering or (FCore.PageCount = 0) then Exit;
  if FSidebarInitPending and GetFirstPageReady then
  begin
    FSidebarInitPending := False;
    if FOutlinePanel.Visible then
    begin
      PopulateOutline;
      BuildThumbnails;
    end;
  end;
  if FInitialRenderDeferred then
  begin
    FInitialRenderDeferred := False;
    FRenderPending := True;
  end;
  if FZoomRenderPending then
  begin
    if GetTickCount64 - FLastZoomTick < 220 then Exit;
    FZoomRenderPending := False;
    FRenderPending := True;
    // Nach der Zoompause nur die jetzt sichtbaren Seiten scharf rendern.
    RenderVisiblePages;
    Exit;
  end;
  // Deadlock vermeiden: Beim initialen Layout kann FResizePending gesetzt
  // bleiben. RenderVisiblePages verweigert dann jede Renderarbeit, waehrend
  // der Batch-Aufbau auf FirstPageReady wartet. Vor dem ersten Rendern
  // die Groessenaenderung abschliessen und ggf. das Layout aktualisieren.
  if FResizePending and (not GetFirstPageReady) then
  begin
    if GetTickCount64 - FLastResizeTick < 100 then Exit;
    FResizePending := False;
    // Vor der ersten Seite kein zweites synchrones Layout erzwingen:
    // OpenPDF/PaintPage hat die erste Seite bereits angeordnet.
  end;
  if FResizePending then
  begin
    // Auch bei benutzerdefiniertem Zoom nach WM_SIZE neu positionieren.
    // Der Zoomfaktor wird von LayoutAllPages nur im Fit-Modus geaendert.
    if GetTickCount64 - FLastResizeTick < 100 then Exit;
    // Erst nach Wiederherstellung der tatsaechlichen Clientgroesse
    // layouten; minimierte/unsichtbare Fenster liefern falsche Werte.
    if (FScroll.ClientWidth <= 100) or (FScroll.ClientHeight <= 100) or
       IsIconic(GetAncestor(Handle, GA_ROOT)) then Exit;
    FResizePending := False;
    PaintPage;
    if not FFitMode then
    begin
      // Beim Zweitseitenmodus das sichtbare Seitenpaar zentrieren,
      // sofern es in den Viewport passt; andernfalls die aktuelle Seite.
      // Die ScrollBox kann nach WM_SIZE einen veralteten horizontalen
      // Scrolloffset besitzen.
      if (FPage >= 0) and (FPage < FPages.Count) then
      begin
        ImgResize := PageImage(FPage);
        if ImgResize <> nil then
        begin
          CenterX := FScroll.ScreenToClient(
            ImgResize.ClientToScreen(Point(ImgResize.Width div 2, 0))).X;
          TargetX := FScroll.HorzScrollBar.Position + CenterX -
            FScroll.ClientWidth div 2;
          MaxX := Max(0, FScroll.HorzScrollBar.Range - FScroll.ClientWidth);
          FScroll.HorzScrollBar.Position := EnsureRange(TargetX, 0, MaxX);
        end;
      end;
    end;
    FLastScrollPosition := FScroll.VertScrollBar.Position;
    Exit;
  end;
  // Nach der ersten Anzeige weitere Seiten in kleinen UI-Batches aufbauen.
  // Kein PDFium-Zugriff aus einem fremden Thread und keine blockierende
  // Schleife ueber Tausende TImage-Controls beim Oeffnen.
  // Seitenwechsel durch Mausrad/Scrollleiste sofort erfassen.
  // Der nachfolgende Hintergrund-Layoutzweig beendet den Timer frueh;
  // ohne diesen Abgleich bleibt die Miniaturauswahl sonst stehen.
  PositionNow := FScroll.VertScrollBar.Position;
  if PositionNow <> FLastScrollPosition then
  begin
    FLastScrollPosition := PositionNow;
    UpdateVisiblePage;
    // Waehrend schneller Scrollfolgen alte Bitmaps anzeigen und
    // teures PDFium-Rendering erst nach einer kurzen Ruhepause starten.
    FScrollRenderPending := True;
    FLastScrollTick := GetTickCount64;
    FRenderPending := True;
    Exit;
  end;
  if FScrollRenderPending then
  begin
    if GetTickCount64 - FLastScrollTick < 130 then Exit;
    FScrollRenderPending := False;
    RenderVisiblePages;
    Exit;
  end;
  // Die erste sichtbare Seite hat Vorrang vor dem Aufbau weiterer
  // Seitencontrols. Andernfalls kann der inkrementelle Layout-Zweig
  // den Render-Timer ueber viele Durchlaeufe belegen.
  if (not GetFirstPageReady) and (FPage >= 0) and
     (FPage < Length(FLoadedPages)) and (not FLoadedPages[FPage]) then
  begin
    RenderVisiblePages;
    Exit;
  end;
  // Sichtbare Seiten und deren Vorladebereich zuerst rendern. Bisher
  // konnte der Seitenaufbau den Render-Timer bis zum letzten PDF-Blatt
  // besetzen, obwohl noch sichtbare Seiten auf eine Bitmap warteten.
  // Nach genau einem Render-Versuch darf der Layoutaufbau weiterlaufen.
  if FRenderPending then
  begin
    RenderVisiblePages;
    Exit;
  end;
  if (FLayoutPageLimit > 0) and (FLayoutPageLimit < FCore.PageCount) then
  begin
    // Den Hintergrundaufbau waehrend und unmittelbar nach Zoom- und
    // Scrollaktionen pausieren. LayoutAllPages arbeitet synchron und
    // wuerde sonst trotz verzoegertem PDFium-Rendering den UI-Thread
    // blockieren. Erst nach einer kurzen Bedienpause weiterarbeiten.
    if ((FLastZoomTick <> 0) and
        (GetTickCount64 - FLastZoomTick < 450)) or
       ((FLastScrollTick <> 0) and
        (GetTickCount64 - FLastScrollTick < 450)) then Exit;
    // Navigation hat Vorrang vor dem sukzessiven Layout.
    if (FPage >= 0) and (FPage < Length(FLoadedPages)) and
       (not FLoadedPages[FPage]) then
    begin
      RenderVisiblePages;
      Exit;
    end;
    // Performance: LayoutAllPages durchlaeuft bei jedem Aufruf erneut
    // alle bisher aufgebauten Seiten. Mit +2 Seiten entsteht bei
    // grossen PDFs sehr viel wiederholte Arbeit (quadratischer Aufwand).
    // Adaptive Batches reduzieren die Anzahl der Komplettdurchlaeufe,
    // ohne sofort hunderte Seiten in einem UI-Tick anzulegen.
    // Die Benutzer-Navigation und sichtbares Rendern bleiben priorisiert.
    FLayoutPageLimit := Min(FCore.PageCount, FLayoutPageLimit +
      Min(24, Max(8, FLayoutPageLimit div 4)));
    LayoutAllPages;
    // Das Layout darf die vom Benutzer gewaehlt Seite nicht aendern.
    // Bei Spruengen zu noch nicht geladenen Seiten wird das Ziel
    // vor dem normalen Hintergrundaufbau bereits aufgebaut.
    Exit;
  end;
  PositionNow := FScroll.VertScrollBar.Position;
  if PositionNow <> FLastScrollPosition then
  begin
    FLastScrollPosition := PositionNow;
    UpdateVisiblePage;
    RenderVisiblePages;
  end
  else if FRenderPending then
    RenderVisiblePages;
end;

procedure TFreePDF64PDFiumView.RenderVisiblePages;
var
  I, BestIndex, BestDistance, Distance, TopOnScreen, BottomOnScreen: Integer;
  CachedCount, EvictIndex, EvictDistance: Integer;
  ScanFirst, ScanLast: Integer;
  Img: TPDFiumImage;
  NewBitmap: TBitmap;
  P: TPoint;
  InView: Boolean;
begin
  if FRendering or (FCore.PageCount = 0) then Exit;
  if FInitialRenderDeferred then Exit;
  // Waehrend einer Zoomfolge nur die vorhandenen Bitmaps skalieren.
  if FZoomRenderPending then Exit;
  if FScrollRenderPending then
  begin
    if GetTickCount64 - FLastScrollTick < 130 then Exit;
    FScrollRenderPending := False;
  end;
  // Beim aktiven Ziehen keine PDFium-Renderarbeit im UI-Thread starten.
  if FResizePending then Exit;
  FRendering := True;
  try
    // Eine PDF-Seite pro Durchlauf: Maus- und Tastaturereignisse
    // koennen zwischen den Renderaufrufen verarbeitet werden.
    BestIndex := -1;
    BestDistance := MaxInt;
    FRenderPending := False;
    // Im Normalfall nur die Umgebung der aktuellen Seite pruefen.
    // Damit werden bei langen Dokumenten nicht bei jedem Render-Tick
    // Hunderte VCL-Controls samt ScreenToClient abgefragt.
    // Die aktuelle Seite wird beim Scrollen durch UpdateVisiblePage gesetzt.
    ScanFirst := Max(0, FPage - 32);
    ScanLast := Min(FPages.Count - 1, FPage + 32);
    for I := ScanFirst to ScanLast do
    begin
      Img := PageImage(I);
      if (Img = nil) or not Img.Visible then Continue;
      P := FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
      TopOnScreen := P.Y;
      BottomOnScreen := TopOnScreen + Img.Height;
      // Eine Bildschirmhoehe vor und hinter dem sichtbaren Bereich
      // vorladen. Sichtbare Seiten erhalten unten weiterhin Vorrang.
      InView := (BottomOnScreen >= -FScroll.ClientHeight) and
        (TopOnScreen <= 2 * FScroll.ClientHeight);
      if (I = FPage) or InView then
      begin
        if not FLoadedPages[I] then
        begin
          Distance := Abs((TopOnScreen + Img.Height div 2) -
            FScroll.ClientHeight div 2);
          // Erst sichtbare Seiten, danach Seiten im Vorladebereich.
          // Das verhindert, dass das Vorladen die Anzeige ausbremst.
          if (BottomOnScreen < 0) or
             (TopOnScreen > FScroll.ClientHeight) then
            Inc(Distance, 2 * FScroll.ClientHeight);
          // Beim ersten Anzeigen zuerst die gewaehlte Seite zeichnen.
          if I = FPage then Distance := -1;
          if Distance < BestDistance then
          begin
            BestDistance := Distance;
            BestIndex := I;
          end;
          FRenderPending := True;
        end;
      end;
    end;
    if BestIndex >= 0 then
    begin
      Img := PageImage(BestIndex);
      // Rendern in einen separaten Puffer: keine leere/halbfertige Seite.
      NewBitmap := TBitmap.Create;
      try
        FCore.RenderPage(BestIndex, NewBitmap, Img.Width, Img.Height);
        Img.Picture.Bitmap.Assign(NewBitmap);
        Img.Stretch := False;
        FLoadedPages[BestIndex] := True;
      finally
        NewBitmap.Free;
      end;
      DrawPageStrokes(BestIndex);
      DrawSearchHighlight(BestIndex);
      DrawTextSelection(BestIndex);
      Img.Invalidate;
    end;

    // Der Cache kann nur wachsen, wenn gerade eine neue Seite gerendert
    // wurde. Ohne neuen Treffer den teuren Komplettscan aller Seiten
    // bei jedem Timer-Tick vermeiden (besonders bei langen PDFs).
    if BestIndex >= 0 then
    begin
      CachedCount := 0;
      for I := 0 to High(FLoadedPages) do
        if FLoadedPages[I] then Inc(CachedCount);
      while CachedCount > FPageCacheLimit do
      begin
      EvictIndex := -1;
      EvictDistance := -1;
      for I := 0 to High(FLoadedPages) do
        if FLoadedPages[I] and (I <> BestIndex) then
        begin
          Img := PageImage(I);
          if Img = nil then Continue;
          // Entfernung zuerst ueber die Seitennummer bestimmen.
          // Nur fuer einen moeglichen Verdraengungskandidaten ist
          // die aufwendigere Bildschirmkoordinatenpruefung noetig.
          Distance := Abs(I - FPage);
          if Distance > EvictDistance then
          begin
            P := FScroll.ScreenToClient(Img.ClientToScreen(Point(0, 0)));
            TopOnScreen := P.Y;
            BottomOnScreen := TopOnScreen + Img.Height;
            // Aktuell sichtbare Seiten im Rendercache behalten.
            if Img.Visible and (BottomOnScreen >= 0) and
              (TopOnScreen <= FScroll.ClientHeight) then Continue;
          end;
          if Distance > EvictDistance then
          begin
            EvictDistance := Distance;
            EvictIndex := I;
          end;
        end;
      if EvictIndex < 0 then Break;
      PageImage(EvictIndex).Picture.Assign(nil);
        FLoadedPages[EvictIndex] := False;
        Dec(CachedCount);
      end;
    end;
  finally
    FRendering := False;
  end;
end;

procedure TFreePDF64PDFiumView.LayoutAllPages;
var
  I, W, H, TopY, MaxW, LeftX, PairWidth, PairHeight, GapPages, RowStart, RowEnd, K: Integer;
  PW, PH: Single;
  Img: TPDFiumImage;
  S: Double;
  PairPW, PairPH, MaxPairWidth, MaxPairHeight, QW, QH: Single;
  PreviousScrollY: Integer;
  LayoutWidth: Integer;
begin
  if FRendering or (FCore.PageCount = 0) then Exit;
  if FLayoutPageLimit <= 0 then FLayoutPageLimit := FCore.PageCount;
  FRendering := True;
  // Fuer mehrseitige kontinuierliche Dokumente die spaetere Breite des
  // vertikalen Scrollbalkens bereits beim ersten Zentrieren einplanen.
  // WICHTIG: ScrollBar.Range/Position/Visible werden hier NICHT veraendert.
  // Die VCL verwaltet den Scrollbereich weiterhin allein ueber die Controls.
  LayoutWidth := FScroll.ClientWidth;
  if FContinuous and (FCore.PageCount > 1) and FScroll.HandleAllocated and
     ((GetWindowLong(FScroll.Handle, GWL_STYLE) and WS_VSCROLL) = 0) then
    Dec(LayoutWidth, GetSystemMetrics(SM_CXVSCROLL));
  LayoutWidth := Max(1, LayoutWidth);
  // TScrollBox verschiebt die Child-Koordinaten beim Scrollen.
  // Vor einem neuen Layout zuerst den Scrollursprung normalisieren:
  // andernfalls wandert die erste Seite immer weiter nach unten.
  PreviousScrollY := FScroll.VertScrollBar.Position;
  // Das kurzzeitige Zuruecksetzen der Scrollposition darf nicht auf dem
  // Bildschirm erscheinen. Sonst flackert die Hauptansicht beim Batch-Layout.
  SendMessage(FScroll.Handle, WM_SETREDRAW, 0, 0);
  FScroll.DisableAlign;
  try
    FScroll.VertScrollBar.Position := 0;
    // Beim Wiederaktivieren nach Maximieren koennen inaktive Tabs
    // einen horizontalen Scrollursprung aus der alten Breite behalten.
    if (FLayoutViewportWidth <> FScroll.ClientWidth) or
       (FLayoutViewportHeight <> FScroll.ClientHeight) then
      FScroll.HorzScrollBar.Position := 0;
    // Horizontalen Scrollursprung vor SetBounds ebenfalls normalisieren.
    // Sonst beziehen sich die neuen Left-Koordinaten auf einen alten
    // Scrolloffset aus der zuvor aktivierten Registerkarte.
    if FFitMode and (FViewMode = 1) and not FTwoPage then
      FScroll.HorzScrollBar.Position := 0;
    // Vorhandene Seitencontrols behalten: insbesondere F11/4K loest
    // sonst fuer jede Seite Destroy/Create und Bitmap-Neuberechnung aus.
    while FPages.Count > FCore.PageCount do
    begin
      TObject(FPages[FPages.Count - 1]).Free;
      FPages.Delete(FPages.Count - 1);
    end;
    if FPages.Count = 0 then
      FPages.Add(FImage);
    FImage.Tag := 0;
    if FFitMode then
    begin
      MaxW := 1;
      for I := 0 to Min(FCore.PageCount, Max(1, FLayoutPageLimit)) - 1 do
        if CachedPageSize(I, PW, PH) then
          MaxW := Max(MaxW, Ceil(PW));
      if FTwoPage then
      begin
        MaxPairWidth := 1;
        MaxPairHeight := 1;
        I := 0;
        while I < Min(FCore.PageCount, Max(1, FLayoutPageLimit)) do
        begin
          PairPW := 0;
          PairPH := 0;
          for K := I to Min(I + 1, FCore.PageCount - 1) do
            if CachedPageSize(K, QW, QH) then
            begin
              PairPW := PairPW + QW;
              PairPH := Max(PairPH, QH);
            end;
          MaxPairWidth := Max(MaxPairWidth, PairPW);
          if (FPage >= I) and (FPage <= I + 1) then
            MaxPairHeight := Max(1, PairPH);
          Inc(I, 2);
        end;
        // Zwischen den beiden Seiten liegt ebenfalls ein Abstand.
        S := (LayoutWidth - 56 - 12) / MaxPairWidth;
        // Bei "Ganze Seite" muss das gesamte Seitenpaar sowohl in der
        // Breite als auch in der Hoehe in den sichtbaren Bereich passen.
        // Vorher wurde die Hoehenbegrenzung bei FTwoPage ausgeschlossen.
        if FViewMode = 1 then
          S := Min(S, (FScroll.ClientHeight - 32) / MaxPairHeight);
      end
      else
        S := (LayoutWidth - 36) / MaxW;
      if (FViewMode = 1) and not FTwoPage then
      begin
        // Ganze Seite: ausschliesslich die aktuelle Seite bestimmt den
        // Zoom. Der globale MaxW enthaelt moeglicherweise breitere,
        // gedrehte Seiten und wuerde die aktuelle Seite zu klein machen.
        if CachedPageSize(FPage, PW, PH) and (PW > 0) and (PH > 0) then
          S := Min((LayoutWidth - 36) / PW,
                   (FScroll.ClientHeight - 32) / PH);
      end;
      FZoom := Max(0.1, Min(5.0, S));
    end;
    // Zoom auch beim ersten Laden und nach Arbeitsbereich-Wiederherstellung anzeigen.
    FZoomStatus.Caption := Format('%d%%', [Round(FZoom * 7200 / CurrentPPI)]);
    SetLength(FLoadedPages, FCore.PageCount);
    TopY := 12;
    PairWidth := 0;
    PairHeight := 0;
    GapPages := 12;
    for I := 0 to Min(FCore.PageCount, Max(1, FLayoutPageLimit)) - 1 do
    begin
      if not CachedPageSize(I, PW, PH) then
      begin
        PW := 595;
        PH := 842;
      end;
      W := Max(1, Round(PW * FZoom));
      H := Max(1, Round(PH * FZoom));
      if (W > 12000) or (H > 12000) then
        raise EPDFiumViewer.Create('Die gewählte Vergrößerung ist zu groß.');
      if I = 0 then Img := FImage
      else if I < FPages.Count then
        Img := TPDFiumImage(FPages[I])
      else
      begin
        Img := TPDFiumImage.Create(Self);
        Img.AfterPaint := PageImagePainted;
        Img.Parent := FScroll;
        Img.Stretch := False;
        Img.Proportional := False;
        Img.OnMouseDown := ImageMouseDown;
        Img.OnDblClick := ImageDblClick;
        Img.OnMouseMove := ImageMouseMove;
        Img.OnMouseUp := ImageMouseUp;
        Img.OnMouseWheel := ScrollMouseWheel;
        FPages.Add(Img);
      end;
      // Gecachte Bitmap nur verwerfen, wenn sich die Rendergroesse
      // geaendert hat. Das spart PDFium-Rendering beim Vollbildwechsel.
      if (Img.Picture.Bitmap.Width <> W) or
         (Img.Picture.Bitmap.Height <> H) then
      begin
        // Altes Seitenbild bis zum vollstaendigen Rendern behalten.
        // Nur bei gleichem Seitenverhaeltnis voruebergehend skalieren.
        // Bei abweichendem Verhaeltnis darf es nicht verzerrt werden.
        Img.Stretch := (Img.Picture.Bitmap.Width > 0) and
          (Img.Picture.Bitmap.Height > 0) and
          (Abs((Img.Picture.Bitmap.Width / Img.Picture.Bitmap.Height) -
               (W / H)) < 0.005);
        FLoadedPages[I] := False;
      end
      else
        Img.Stretch := False;
      Img.Tag := I;
      if not FContinuous then
      begin
        // Seitenweise: nur die aktuelle Seite bzw. das aktuelle Paar zeigen.
        RowStart := FPage;
        if FTwoPage then RowStart := (FPage div 2) * 2;
        RowEnd := RowStart;
        if FTwoPage then RowEnd := Min(RowStart + 1, FCore.PageCount - 1);
        Img.Visible := (I >= RowStart) and (I <= RowEnd);
        if Img.Visible then
        begin
          if FTwoPage then
          begin
            PairWidth := W;
            if CachedPageSize(RowStart, QW, QH) then
              PairWidth := Max(1, Round(QW * FZoom));
            if RowEnd > RowStart then
            begin
              if CachedPageSize(RowEnd, QW, QH) then
                PairWidth := PairWidth + GapPages + Max(1, Round(QW * FZoom));
            end;
            LeftX := Max(12, (LayoutWidth - PairWidth) div 2);
            if I = RowEnd then LeftX := LeftX + PairWidth - W;
          end
          else
            LeftX := Max(12, (LayoutWidth - W) div 2);
          Img.SetBounds(LeftX, 12, W, H);
        end
        else
          Img.SetBounds(0, 0, 1, 1);
      end
      else if FTwoPage then
      begin
        Img.Visible := True;
        // Jede Zeile besteht aus zwei nebeneinander angeordneten PDF-Seiten.
        if (I mod 2) = 0 then
        begin
          PairWidth := W;
          PairHeight := H;
          if I + 1 < FCore.PageCount then
          begin
            if CachedPageSize(I + 1, QW, QH) then
            begin
              PairWidth := PairWidth + GapPages + Max(1, Round(QW * FZoom));
              PairHeight := Max(PairHeight, Max(1, Round(QH * FZoom)));
            end;
          end;
        end;
        LeftX := Max(12, (LayoutWidth - PairWidth) div 2);
        if (I mod 2) = 1 then
          LeftX := LeftX + PairWidth - W;
        Img.SetBounds(LeftX, TopY, W, H);
        if (I mod 2 = 1) or (I = FCore.PageCount - 1) then
          TopY := TopY + PairHeight + 16;
      end
      else
      begin
        Img.Visible := True;
        LeftX := Max(12, (LayoutWidth - W) div 2);
        Img.SetBounds(LeftX, TopY, W, H);
        TopY := TopY + H + 16;
      end;
    end;
  finally
    try
      FScroll.EnableAlign;
      // Position vor dem Wiederfreigeben der Darstellung wiederherstellen.
      if FContinuous and (PreviousScrollY > 0) then
        FScroll.VertScrollBar.Position := PreviousScrollY;
    finally
      SendMessage(FScroll.Handle, WM_SETREDRAW, 1, 0);
      // Neuzeichnen ohne vorheriges Loeschen des gesamten Hintergrunds.
      // So bleiben die vorhandenen Seitenbilder bis zum Paint sichtbar.
      RedrawWindow(FScroll.Handle, nil, 0, RDW_INVALIDATE or RDW_ALLCHILDREN or RDW_NOERASE);
      FRendering := False;
    end;
  end;
  FLayoutViewportWidth := FScroll.ClientWidth;
  FLayoutViewportHeight := FScroll.ClientHeight;
  if not FInitialRenderDeferred then
    RenderVisiblePages;
  FLastScrollPosition := FScroll.VertScrollBar.Position;
  // Das Layout ist kein Benutzerscrollen: FPage nicht aus einer
  // eventuell noch unvollstaendigen Seitenliste neu ermitteln.
  FPageTotal.Caption := Format('/ %d', [FCore.PageCount]);
  UpdateThumbnailSelection;
  // 3b.63: Auch Fit, Fenster-Resize und Ansichtswechsel aktualisieren
  // die Pixelkoordinaten des sichtbaren PDF-Formularfokus.
  UpdateFormFocusFrame;
end;

function TFreePDF64PDFiumView.GetFirstPageReady: Boolean;
begin
  Result := (FCore <> nil) and (FCore.PageCount > 0) and
    (Length(FLoadedPages) > FPage) and (FPage >= 0) and
    FLoadedPages[FPage];
end;

procedure TFreePDF64PDFiumView.PaintPage;
begin

  LayoutAllPages;

  // LayoutAllPages aktualisiert sichtbare Seite und rendert bereits.
  // ShowPage hier erneut aufzurufen erzwingt unnötiges Scrollen/Rendering
  // bei jedem F11- und Fenstergroessenwechsel.
end;

procedure TFreePDF64PDFiumView.PlaceEditButton(AParent: TWinControl; ALeft, ATop, AHeight: Integer);
var
  ButtonWidth: Integer;
begin
  FEditToggle.Parent := AParent;
  // Nur ein Symbol, ohne Text und ohne die alte breite Text-Schaltflaeche.
  FEditToggle.Caption := '';
  FEditToggle.Layout := blGlyphLeft;
  FEditToggle.Margin := -1;
  ButtonWidth := MulDiv(34, FEditToggle.CurrentPPI, 96);
  FEditToggle.SetBounds(ALeft, ATop, ButtonWidth, AHeight);
  FEditToggle.BringToFront;
end;

procedure TFreePDF64PDFiumView.ToggleMarker;
begin
  MarkerClick(nil);
end;

procedure TFreePDF64PDFiumView.MarkerClick(Sender: TObject);
begin
  // Kompatibilitaet fuer vorhandene Aufrufer: Bearbeiten und Markieren sind gekoppelt.
  ToggleEditBar(nil);
end;

// Verbindet die nicht persistenten Vormerkungen mit der Core-Sammelanalyse.
// Weder PDF-Inhalte noch die Vorschau-Rechtecke werden hier veraendert.
function TFreePDF64PDFiumView.AnalyzePendingRedactions(
  out AAnalysis: TPDFRedactionBatchAnalysis): Boolean;
var
  Regions: TArray<TPDFRedactionRegion>;
  I, N: Integer;
  P1, P2: TPDFInkPoint;
begin
  FillChar(AAnalysis, SizeOf(AAnalysis), 0);
  Result := False;
  if (FCore = nil) or (FRedactionPreviews = nil) or
     (FRedactionPreviewPages = nil) or
     (FRedactionPreviews.Count <> FRedactionPreviewPages.Count) then Exit;
  SetLength(Regions, FRedactionPreviews.Count);
  N := 0;
  for I := 0 to FRedactionPreviews.Count - 1 do
  begin
    if (FRedactionPreviews[I] = nil) or
       (FRedactionPreviews[I].Count < 2) then Continue;
    P1 := FRedactionPreviews[I][0];
    P2 := FRedactionPreviews[I][1];
    Regions[N].PageIndex := FRedactionPreviewPages[I];
    Regions[N].Bounds.Left := Min(P1.X, P2.X);
    Regions[N].Bounds.Right := Max(P1.X, P2.X);
    Regions[N].Bounds.Bottom := Min(P1.Y, P2.Y);
    Regions[N].Bounds.Top := Max(P1.Y, P2.Y);
    Inc(N);
  end;
  SetLength(Regions, N);
  Result := FCore.AnalyzeRedactionRegions(Regions, AAnalysis);
end;

procedure TFreePDF64PDFiumView.FinalizeRedactionClick(Sender: TObject);
var
  D: TSaveDialog;
  Regions: TArray<TPDFRedactionRegion>;
  Analysis: TPDFRedactionBatchAnalysis;
  I, N, AffectedPages: Integer;
  P1, P2: TPDFInkPoint;
  PageSeen: TList<Integer>;
  OutputName, VerifyReport, ReportName: string;
  ReportLines: TStringList;
begin
  if (FCore = nil) or (FRedactionPreviews = nil) or
     (FRedactionPreviews.Count = 0) or
     (FRedactionPreviews.Count <> FRedactionPreviewPages.Count) then
  begin
    PDFModernMessageDlg(Tr('Es sind keine gültigen Schwärzungsbereiche vorgemerkt.'),
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if not AnalyzePendingRedactions(Analysis) or
     (Analysis.FailedRegions > 0) then
  begin
    PDFModernMessageDlg(ToolbarHint(
      'Mindestens ein Schwärzungsbereich konnte nicht vollständig geprüft werden. Es wurde keine Datei erstellt.',
      'At least one redaction region could not be fully inspected. No file was created.'),
      mtError, [mbOK], 0);
    Exit;
  end;

  SetLength(Regions, FRedactionPreviews.Count);
  N := 0;
  PageSeen := TList<Integer>.Create;
  try
    for I := 0 to FRedactionPreviews.Count - 1 do
    begin
      if (FRedactionPreviews[I] = nil) or
         (FRedactionPreviews[I].Count < 2) then Continue;
      P1 := FRedactionPreviews[I][0];
      P2 := FRedactionPreviews[I][1];
      Regions[N].PageIndex := FRedactionPreviewPages[I];
      Regions[N].Bounds.Left := Min(P1.X, P2.X);
      Regions[N].Bounds.Right := Max(P1.X, P2.X);
      Regions[N].Bounds.Bottom := Min(P1.Y, P2.Y);
      Regions[N].Bounds.Top := Max(P1.Y, P2.Y);
      Inc(N);
      if PageSeen.IndexOf(FRedactionPreviewPages[I]) < 0 then
        PageSeen.Add(FRedactionPreviewPages[I]);
    end;
    SetLength(Regions, N);
    AffectedPages := PageSeen.Count;
  finally
    PageSeen.Free;
  end;
  if Length(Regions) = 0 then
  begin
    PDFModernMessageDlg(Tr('Es wurden keine gültigen Schwärzungsrechtecke gefunden.'),
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if PDFModernMessageDlg(Format(ToolbarHint(
      'Es wird eine neue PDF-Datei mit %d vollständig gerasterten Seite(n) erstellt (300 DPI). Auf diesen Seiten sind Textauswahl und Textsuche anschließend nicht mehr möglich. Lesezeichen werden nicht übernommen. Die Originaldatei bleibt unverändert. Fortfahren?',
      'A new PDF will be created with %d fully rasterized page(s) (300 DPI). Text selection and text search will no longer be available on those pages. Bookmarks will not be transferred. The original file remains unchanged. Continue?'),
      [AffectedPages]), mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  D := TSaveDialog.Create(Self);
  try
    D.Title := ToolbarHint('Sichere Schwärzung – neue PDF-Datei speichern',
      'Secure redaction – save new PDF file');
    D.Filter := Tr('PDF-Dateien (*.pdf)') + '|*.pdf';
    D.DefaultExt := 'pdf';
    D.Options := D.Options + [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];
    D.InitialDir := ExtractFilePath(FCore.FileName);
    if PDFLanguage = 'en' then
      OutputName := ChangeFileExt(ExtractFileName(FCore.FileName), '_redacted.pdf')
    else
      OutputName := ChangeFileExt(ExtractFileName(FCore.FileName), '_geschwärzt.pdf');
    D.FileName := OutputName;
    if not D.Execute then Exit;
    if SameText(ExpandFileName(D.FileName), ExpandFileName(FCore.FileName)) then
    begin
      PDFModernMessageDlg(Tr('Die Originaldatei darf nicht überschrieben werden. Bitte einen anderen Dateinamen wählen.'),
        mtWarning, [mbOK], 0);
      Exit;
    end;
    try
      FCore.CreateSecureRedactedPDF(Regions, D.FileName, 300);
      if not FCore.VerifyRedactedOutput(D.FileName, Regions, VerifyReport) then
        raise Exception.Create(ToolbarHint(
          'Die abschließende Prüfung der Ausgabedatei ist fehlgeschlagen. Bitte die PDF nicht weitergeben.' + sLineBreak + VerifyReport,
          'Final verification of the output file failed. Do not share this PDF.' + sLineBreak + VerifyReport));
      ReportName := ChangeFileExt(D.FileName, '.redaction-check.txt');
      ReportLines := TStringList.Create;
      try
        ReportLines.Text := VerifyReport;
        ReportLines.SaveToFile(ReportName, TEncoding.UTF8);
      finally
        ReportLines.Free;
      end;
      PDFModernMessageDlg(Format(ToolbarHint(
        'Die neue PDF-Datei wurde erstellt und erneut geprüft.' + sLineBreak +
        'Prüfbericht: ' + ExtractFileName(ReportName) + sLineBreak +
        'Gerasterte Seiten: %d' + sLineBreak +
        'Lesezeichen wurden nicht übernommen.' + sLineBreak +
        'Auf diesen Seiten sind die ursprünglichen PDF-Objekte nicht mehr enthalten.' + sLineBreak +
        'Die Originaldatei wurde nicht verändert.' + sLineBreak + sLineBreak +
        'Bitte öffne die Ausgabedatei und kontrolliere das Ergebnis vor der Weitergabe.',
        'The new PDF was created and checked again.' + sLineBreak +
        'Verification report: ' + ExtractFileName(ReportName) + sLineBreak +
        'Rasterized pages: %d' + sLineBreak +
        'Bookmarks were not transferred.' + sLineBreak +
        'The original PDF objects are no longer present on these pages.' + sLineBreak +
        'The original file was not changed.' + sLineBreak + sLineBreak +
        'Please open the output file and inspect it before sharing.'), [AffectedPages]),
        mtInformation, [mbOK], 0);
    except
      on E: Exception do
        PDFModernMessageDlg(ToolbarHint('Die sichere Schwärzung ist fehlgeschlagen: ',
          'Secure redaction failed: ') + E.Message, mtError, [mbOK], 0);
    end;
  finally
    D.Free;
  end;
end;

procedure TFreePDF64PDFiumView.AppendPoint(X, Y: Integer);
var P: TPDFInkPoint; DX, DY: Double;
begin
  if FCurrentStroke = nil then Exit;
  if not FCore.DevicePointToPage(FStrokePage, PageImage(FStrokePage).Width, PageImage(FStrokePage).Height,
    X, Y, DX, DY) then Exit;
  P.X := DX; P.Y := DY;
  FCurrentStroke.Add(P);
end;

procedure TFreePDF64PDFiumView.BuildEllipseStroke(X1, Y1, X2, Y2: Integer);
var
  I: Integer;
  A, CX, CY, RX, RY: Double;
begin
  CX := (X1 + X2) / 2;
  CY := (Y1 + Y2) / 2;
  RX := Abs(X2 - X1) / 2;
  RY := Abs(Y2 - Y1) / 2;
  for I := 0 to 48 do
  begin
    A := 2 * Pi * I / 48;
    AppendPoint(Round(CX + RX * Cos(A)), Round(CY + RY * Sin(A)));
  end;
end;

procedure TFreePDF64PDFiumView.UpdateShapeStroke(X, Y: Integer);
begin
  if FCurrentStroke = nil then Exit;
  FCurrentStroke.Clear;
  case FShapeSelect.ItemIndex of
    1: begin
         AppendPoint(FShapeStart.X, FShapeStart.Y);
         AppendPoint(X, Y);
       end;
    2: begin
         AppendPoint(FShapeStart.X, FShapeStart.Y);
         AppendPoint(X, FShapeStart.Y);
         AppendPoint(X, Y);
         AppendPoint(FShapeStart.X, Y);
         AppendPoint(FShapeStart.X, FShapeStart.Y);
       end;
    3: BuildEllipseStroke(FShapeStart.X, FShapeStart.Y, X, Y);
    5: begin
         AppendPoint(FShapeStart.X, FShapeStart.Y);
         AppendPoint(X, Y);
       end;
    6: begin
         AppendPoint(FShapeStart.X, FShapeStart.Y);
         AppendPoint(X, Y);
       end;
  end;
end;

function PDFiumColorDialogHook(hDlg: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM): UINT_PTR; stdcall;
var
  DialogChoice: PChooseColor;
  Desired: PPoint;
  R: TRect;
  Work: TRect;
  W, H, X, Y: Integer;
begin
  Result := 0;
  if uMsg <> WM_INITDIALOG then Exit;
  DialogChoice := PChooseColor(lParam);
  if (DialogChoice = nil) or (DialogChoice^.lCustData = 0) then Exit;
  Desired := PPoint(DialogChoice^.lCustData);
  GetWindowRect(hDlg, R);
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  // VCL-Monitorermittlung vermeidet SDK-abhängige WinAPI-Deklarationen.
  Work := Screen.MonitorFromPoint(Desired^).WorkareaRect;
  X := Max(Work.Left, Min(Desired^.X, Work.Right - W));
  Y := Desired^.Y;
  if Y + H > Work.Bottom then
    Y := Work.Bottom - H;
  Y := Max(Work.Top, Y);
  SetWindowPos(hDlg, 0, X, Y, 0, 0,
    SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure TFreePDF64PDFiumView.ColorClick(Sender: TObject);
var
  Choice: TChooseColor;
  CustomColors: array[0..15] of COLORREF;
  PDFWindow: TCustomForm;
  I: Integer;
  ButtonOrigin: TPoint;
begin
  // Direkter Windows-Dialog mit dem PDF-Fenster als HWND-Owner.
  // VCL-TColorDialog kann bei mehreren Formularen die Hauptform aktivieren.
  PDFWindow := GetParentForm(Self);
  if PDFWindow = nil then Exit;
  for I := Low(CustomColors) to High(CustomColors) do
    CustomColors[I] := RGB(255, 255, 255);
  ZeroMemory(@Choice, SizeOf(Choice));
  Choice.lStructSize := SizeOf(Choice);
  Choice.hwndOwner := PDFWindow.Handle;
  Choice.rgbResult := ColorToRGB(FMarkColor);
  Choice.lpCustColors := @CustomColors[0];
  // Position unmittelbar unter dem Farbbutton, nicht oben links auf der PDF.
  ButtonOrigin := FColorButton.ClientToScreen(Point(0, FColorButton.Height + 4));
  Choice.lCustData := LPARAM(@ButtonOrigin);
  Choice.lpfnHook := @PDFiumColorDialogHook;
  Choice.Flags := CC_RGBINIT or CC_FULLOPEN or CC_ENABLEHOOK;
  if ChooseColor(Choice) then
  begin
    FMarkColor := TColor(Choice.rgbResult);
    FColorSwatch.Color := FMarkColor;
    FColorSwatch.Invalidate;
  end;
end;

procedure TFreePDF64PDFiumView.DrawLivePreview;
var
  Img: TPDFiumImage;
  B: TBitmap;
  J, PX, PY, X2, Y2: Integer;
  P: TPDFInkPoint;
  First: Boolean;
begin
  if FCurrentStroke = nil then Exit;
  if (not FCurrentStroke.IsCover) and (FPreviewBitmap = nil) then Exit;
  if (FStrokePage < 0) or (FStrokePage >= FPages.Count) then Exit;
  Img := PageImage(FStrokePage);
  B := Img.Picture.Bitmap;
  if FCurrentStroke.IsCover then
  begin
    // Der AfterPaint-Handler zeichnet das Rechteck als Bildschirm-Overlay.
    // Hier darf die PDF-Bitmap nicht angefasst werden.
    Img.Invalidate;
    Exit;
  end;
  B.Assign(FPreviewBitmap);
  B.Canvas.Brush.Style := bsClear;
  B.Canvas.Pen.Color := FCurrentStroke.StrokeColor;
  B.Canvas.Pen.Width := Max(1, Round(FCurrentStroke.LineWidth * FZoom));
  B.Canvas.Pen.Style := psSolid;
  First := True;
  for J := 0 to FCurrentStroke.Count - 1 do
  begin
    P := FCurrentStroke[J];
    if not FCore.PagePointToDevice(FStrokePage, Img.Width, Img.Height,
      P.X, P.Y, PX, PY) then Continue;
    if First then
    begin
      B.Canvas.MoveTo(PX, PY);
      First := False;
    end
    else
      B.Canvas.LineTo(PX, PY);
  end;
  Img.Invalidate;
  Img.Update;
end;

function TFreePDF64PDFiumView.SelectionHit(Sender: TObject; X, Y: Integer): Integer;
var Img: TPDFiumImage; PX, PY: Double;
begin
  Result := -1;
  if not (Sender is TPDFiumImage) then Exit;
  Img := TPDFiumImage(Sender);
  if not FCore.DevicePointToPage(Img.Tag, Img.Width, Img.Height, X, Y, PX, PY) then Exit;
  Result := FCore.TextCharAt(Img.Tag, PX, PY);
end;

procedure TFreePDF64PDFiumView.RefreshSelectedPages;
var I: Integer; Img: TPDFiumImage;
begin
  for I := 0 to FPages.Count - 1 do
  begin
    if (I >= Length(FLoadedPages)) or not FLoadedPages[I] then Continue;
    Img := PageImage(I);
    if Img = nil then Continue;
    FCore.RenderPage(I, Img.Picture.Bitmap, Img.Width, Img.Height);
    DrawPageStrokes(I);
    DrawSearchHighlight(I);
    DrawTextSelection(I);
    Img.Invalidate;
  end;
end;

procedure TFreePDF64PDFiumView.DrawTextSelection(APage: Integer);
var
  A, B, StartChar, EndChar, I, X1, Y1, X2, Y2: Integer;
  BorderRect: TRect;
  Img: TPDFiumImage;
  Boxes: TArray<TPDFInkRect>;
  Box: TPDFInkRect;
  Overlay: TBitmap;
  Blend: TBlendFunction;
begin
  if (FSelAnchorPage < 0) or (FSelFocusPage < 0) then Exit;
  A := Min(FSelAnchorPage, FSelFocusPage);
  B := Max(FSelAnchorPage, FSelFocusPage);
  if (APage < A) or (APage > B) then Exit;
  Img := PageImage(APage);
  if (Img = nil) or Img.Picture.Bitmap.Empty then Exit;
  if FSelAnchorPage = FSelFocusPage then
  begin
    StartChar := Min(FSelAnchorChar, FSelFocusChar);
    EndChar := Max(FSelAnchorChar, FSelFocusChar) + 1;
  end
  else if FSelAnchorPage < FSelFocusPage then
  begin
    if APage = A then StartChar := FSelAnchorChar else StartChar := 0;
    if APage = B then EndChar := FSelFocusChar + 1 else EndChar := FCore.TextCharCount(APage);
  end
  else
  begin
    if APage = A then StartChar := FSelFocusChar else StartChar := 0;
    if APage = B then EndChar := FSelAnchorChar + 1 else EndChar := FCore.TextCharCount(APage);
  end;
  if EndChar <= StartChar then Exit;
  Boxes := FCore.MatchCharRects(APage, StartChar, EndChar - StartChar);
  Overlay := TBitmap.Create;
  try
    Overlay.PixelFormat := pf24bit;
    Overlay.SetSize(1, 1);
    Overlay.Canvas.Pixels[0, 0] := RGB(175, 211, 250);
    FillChar(Blend, SizeOf(Blend), 0);
    Blend.BlendOp := AC_SRC_OVER;
    Blend.SourceConstantAlpha := 85;
    for Box in Boxes do
      if FCore.PagePointToDevice(APage, Img.Width, Img.Height, Box.Left, Box.Top, X1, Y1) and
         FCore.PagePointToDevice(APage, Img.Width, Img.Height, Box.Right, Box.Bottom, X2, Y2) then
        if (X1 <> X2) and (Y1 <> Y2) then
          begin
            Winapi.Windows.AlphaBlend(Img.Picture.Bitmap.Canvas.Handle,
              Min(X1, X2), Min(Y1, Y2), Abs(X2-X1), Abs(Y2-Y1),
              Overlay.Canvas.Handle, 0, 0, 1, 1, Blend);
            // Grosszuegiger hellblauer Auswahlrahmen mit Abstand zu den Buchstaben.
            // An den Bildraendern begrenzen, damit kein Zeichnen ausserhalb erfolgt.
            BorderRect := Rect(Max(0, Min(X1, X2) - 4),
              Max(0, Min(Y1, Y2) - 4),
              Min(Img.Picture.Bitmap.Width - 1, Max(X1, X2) + 4),
              Min(Img.Picture.Bitmap.Height - 1, Max(Y1, Y2) + 4));
            if (BorderRect.Right > BorderRect.Left) and
               (BorderRect.Bottom > BorderRect.Top) then
            begin
              Img.Picture.Bitmap.Canvas.Brush.Style := bsClear;
              Img.Picture.Bitmap.Canvas.Pen.Color := RGB(135, 181, 231);
              Img.Picture.Bitmap.Canvas.Pen.Width := 2;
              Img.Picture.Bitmap.Canvas.Rectangle(BorderRect);
              Img.Picture.Bitmap.Canvas.Pen.Width := 1;
              Img.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
            end;
          end;
  finally Overlay.Free; end;
end;

procedure TFreePDF64PDFiumView.SelectAllText;
var I: Integer;
begin
  if FCore.PageCount = 0 then Exit;
  FSelAnchorPage := 0;
  FSelAnchorChar := 0;
  FSelFocusPage := FCore.PageCount - 1;
  FSelFocusChar := Max(0, FCore.TextCharCount(FSelFocusPage) - 1);
  RefreshSelectedPages;
end;

function TFreePDF64PDFiumView.SelectedText: string;
var A, B, I, StartChar, EndChar: Integer; S, Part: string;
begin
  Result := '';
  if (FSelAnchorPage < 0) or (FSelFocusPage < 0) then Exit;
  A := Min(FSelAnchorPage, FSelFocusPage);
  B := Max(FSelAnchorPage, FSelFocusPage);
  S := '';
  for I := A to B do
  begin
    if FSelAnchorPage = FSelFocusPage then
    begin
      StartChar := Min(FSelAnchorChar, FSelFocusChar);
      EndChar := Max(FSelAnchorChar, FSelFocusChar) + 1;
    end
    else if FSelAnchorPage < FSelFocusPage then
    begin
      if I = A then StartChar := FSelAnchorChar else StartChar := 0;
      if I = B then EndChar := FSelFocusChar + 1 else EndChar := FCore.TextCharCount(I);
    end
    else
    begin
      if I = A then StartChar := FSelFocusChar else StartChar := 0;
      if I = B then EndChar := FSelAnchorChar + 1 else EndChar := FCore.TextCharCount(I);
    end;
    Part := FCore.TextRange(I, StartChar, EndChar - StartChar);
    if I > A then S := S + sLineBreak;
    S := S + Part;
  end;
  Result := S;
end;

procedure TFreePDF64PDFiumView.CopySelectedText;
var S: string;
begin
  S := SelectedText;
  if S <> '' then Clipboard.AsText := S;
end;

procedure TFreePDF64PDFiumView.SelectionMenuClick(Sender: TObject);
var
  S, URL, TargetLanguage: string;
begin
  if not (Sender is TMenuItem) then Exit;
  if TMenuItem(Sender).Tag = 1 then
  begin
    CopySelectedText;
    Exit;
  end;
  S := SelectedText;
  if Trim(S) = '' then Exit;
  case TMenuItem(Sender).Tag of
    2:
      begin
        if SameText(PDFLanguage, 'en') then TargetLanguage := 'en'
        else TargetLanguage := 'de';
        URL := 'https://translate.google.com/?sl=auto&tl=' +
          TargetLanguage + '&text=' + TNetEncoding.URL.Encode(S) + '&op=translate';
      end;
    3: URL := 'https://www.google.com/search?q=' + TNetEncoding.URL.Encode(S);
    4: URL := 'https://www.bing.com/search?q=' + TNetEncoding.URL.Encode(S);
  else
    Exit;
  end;
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
end;

function TFreePDF64PDFiumView.LinkAtImagePoint(Sender: TObject;
  X, Y: Integer; out ATarget: TPDFLinkTarget): Boolean;
var
  Img: TPDFiumImage;
begin
  Result := False;
  if FMarkMode or FSelecting or (FCurrentStroke <> nil) or
     not (Sender is TPDFiumImage) then Exit;
  Img := TPDFiumImage(Sender);
  Result := FCore.LinkAtPoint(Img.Tag, Img.Width, Img.Height, X, Y, ATarget);
end;

function EditPDFFormTextDialog(const ACaption: string;
  var AValue: string; AMultiline: Boolean): Boolean;
var
  Dialog: TForm;
  Editor: TMemo;
  SingleEditor: TEdit;
  OKButton, CancelButton: TButton;
  OptionWidth, I: Integer;
begin
  Result := False;
  Dialog := TForm.Create(nil);
  try
    Dialog.Caption := ACaption;
    Dialog.Position := poScreenCenter;
    Dialog.BorderStyle := bsDialog;
    Dialog.ClientWidth := 480;
    Dialog.ClientHeight := 270;
    Dialog.Font.Name := 'Segoe UI';
    Dialog.Font.Size := 9;

    Editor := nil;
    SingleEditor := nil;
    if AMultiline then
    begin
      Editor := TMemo.Create(Dialog);
      Editor.Parent := Dialog;
      Editor.SetBounds(12, 12, Dialog.ClientWidth - 24,
        Dialog.ClientHeight - 64);
      Editor.Anchors := [akLeft, akTop, akRight, akBottom];
      Editor.ScrollBars := ssVertical;
      Editor.WordWrap := True;
      Editor.Text := AValue;
      Editor.TabOrder := 0;
    end
    else
    begin
      Dialog.ClientHeight := 104;
      SingleEditor := TEdit.Create(Dialog);
      SingleEditor.Parent := Dialog;
      SingleEditor.SetBounds(12, 12, Dialog.ClientWidth - 24, 26);
      SingleEditor.Anchors := [akLeft, akTop, akRight];
      SingleEditor.Text := StringReplace(StringReplace(AValue,
        #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
      SingleEditor.TabOrder := 0;
    end;

    OKButton := TButton.Create(Dialog);
    OKButton.Parent := Dialog;
    OKButton.Caption := 'OK';
    OKButton.ModalResult := mrOk;
    OKButton.Default := True;
    OKButton.SetBounds(Dialog.ClientWidth - 184,
      Dialog.ClientHeight - 42, 80, 28);
    OKButton.Anchors := [akRight, akBottom];

    CancelButton := TButton.Create(Dialog);
    CancelButton.Parent := Dialog;
    CancelButton.Caption := 'Abbrechen';
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    CancelButton.SetBounds(Dialog.ClientWidth - 96,
      Dialog.ClientHeight - 42, 84, 28);
    CancelButton.Anchors := [akRight, akBottom];

    if AMultiline then
      Dialog.ActiveControl := Editor
    else
      Dialog.ActiveControl := SingleEditor;
    Result := Dialog.ShowModal = mrOk;
    if Result then
    begin
      if AMultiline then
        AValue := Editor.Text
      else
        AValue := SingleEditor.Text;
    end;
  finally
    Dialog.Free;
  end;
end;

// Doppelklick uebernimmt den markierten Dropdown-Eintrag.
procedure TFreePDF64PDFiumView.FormOptionDoubleClick(Sender: TObject);
var
  L: TListBox;
begin
  if not (Sender is TListBox) then Exit;
  L := TListBox(Sender);
  if (L.ItemIndex >= 0) and (L.Parent is TForm) then
    TForm(L.Parent).ModalResult := mrOk;
end;

procedure TFreePDF64PDFiumView.UpdateTextEditorHeight;
var
  Measure: TBitmap;
  NeededHeight: Integer;
begin
  if FTextEditor = nil then Exit;
  Measure := TBitmap.Create;
  try
    Measure.Canvas.Font.Assign(FTextEditor.Font);
    // Zeichenhoehe plus DPI-abhaengiger Innenabstand des Eingabefeldes.
    NeededHeight := Measure.Canvas.TextHeight('HgÄÜ') +
      MulDiv(12, CurrentPPI, 96);
  finally
    Measure.Free;
  end;
  if FTextEditor.Height < NeededHeight then
  begin
    FTextEditor.Height := NeededHeight;
    PositionTextResizeGrip;
  end;
end;

procedure TFreePDF64PDFiumView.TextStyleChange(Sender: TObject);
var
  N: Integer;
begin
  if TryStrToInt(Trim(FTextSizeSelect.Text), N) and (N >= 1) and (N <= 200) then
    FTextInsertSize := N;
  if FTextEditor <> nil then
  begin
    FTextEditor.Font.Name := FTextFontSelect.Text;
    FTextEditor.Font.Size := FTextInsertSize;
    FTextEditor.Font.Color := FTextInsertColor;
    UpdateTextEditorHeight;
  end;
end;

procedure TFreePDF64PDFiumView.TextColorClick(Sender: TObject);
var
  Dialog: TColorDialog;
begin
  Dialog := TColorDialog.Create(Self);
  try
    Dialog.Color := FTextInsertColor;
    Dialog.Options := [cdFullOpen];
    if Dialog.Execute then
    begin
      FTextInsertColor := Dialog.Color;
      FTextColorSwatch.Color := FTextInsertColor;
      if FTextEditor <> nil then FTextEditor.Font.Color := FTextInsertColor;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TFreePDF64PDFiumView.ClearStrokeRedo;
var
  I: Integer;
begin
  if FStrokeRedo <> nil then
  begin
    for I := 0 to FStrokeRedo.Count - 1 do FStrokeRedo[I].Free;
    FStrokeRedo.Clear;
  end;
  if FStrokeRedoPages <> nil then FStrokeRedoPages.Clear;
end;

procedure TFreePDF64PDFiumView.ClearRedactionRedo;
begin
  FRedactionRedo.Clear;
  FRedactionRedoPages.Clear;
end;

procedure TFreePDF64PDFiumView.RefreshRedactionPage(APage: Integer);
begin
  if (APage >= 0) and (APage < Length(FLoadedPages)) and
     FLoadedPages[APage] and (PageImage(APage) <> nil) then
  begin
    FCore.RenderPage(APage, PageImage(APage).Picture.Bitmap,
      PageImage(APage).Width, PageImage(APage).Height);
    DrawPageStrokes(APage);
    PageImage(APage).Invalidate;
  end;
end;

procedure TFreePDF64PDFiumView.UpdateTextUndoButtons;
begin
  // Gleiche Aktiv-Kennzeichnung wie beim Dropdown "Messen".
  if FInsertButton <> nil then
  begin
    if FTextInsertMode or FNoteMode then
      FInsertButton.Font.Style := [fsBold]
    else
      FInsertButton.Font.Style := [];
  end;
  if FTextUndoButton <> nil then
    FTextUndoButton.Enabled := ((FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6) and (FRedactionPreviews.Count > 0)) or (FMeasureMode and (FMeasureUndo.Count > 0)) or (FCore.Strokes.Count > 0) or FCore.CanUndoInsertedText or FCore.CanUndoNote;
  if FTextRedoButton <> nil then
    FTextRedoButton.Enabled := ((FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6) and (FRedactionRedo.Count > 0)) or (FMeasureMode and (FMeasureRedo.Count > 0)) or (FStrokeRedo.Count > 0) or FCore.CanRedoInsertedText or FCore.CanRedoNote;
  if FRedactionFinalizeButton <> nil then
  begin
    // Den Orange-Zustand immer aus dem tatsaechlich aktiven Werkzeugmodus
    // ableiten, auch beim Schliessen der Werkzeugleiste ohne OnChange.
    FRedactionFinalizeButton.SetAccentOrange(FEditVisible and
      (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6));
    FRedactionFinalizeButton.Enabled := FEditVisible and
      (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6) and
      (FRedactionPreviews <> nil) and (FRedactionPreviews.Count > 0) and
      (FCore <> nil) and (FCore.PageCount > 0);
  end;
end;

procedure TFreePDF64PDFiumView.RefreshTextPage(APageIndex: Integer);
begin
  if (APageIndex >= 0) and (APageIndex < Length(FLoadedPages)) and
     FLoadedPages[APageIndex] then
  begin
    FCore.RenderPage(APageIndex, PageImage(APageIndex).Picture.Bitmap,
      PageImage(APageIndex).Width, PageImage(APageIndex).Height);
    DrawPageStrokes(APageIndex);
    PageImage(APageIndex).Invalidate;
  end;
  UpdateSaveState;
  UpdateTextUndoButtons;
end;

procedure TFreePDF64PDFiumView.InvalidateAllWatermarkPages;
var
  I: Integer;
begin
  for I := 0 to High(FLoadedPages) do
  begin
    FLoadedPages[I] := False;
    if I < FPages.Count then PageImage(I).Picture.Assign(nil);
    if I < FThumbImages.Count then TImage(FThumbImages[I]).Picture.Assign(nil);
  end;
  FRenderPending := True;
  PaintPage;
end;

procedure TFreePDF64PDFiumView.RecordMeasureAction(
  const ARect: TPDFMeasureRect; AIndex: Integer; AWasDelete: Boolean);
var
  Action: TPDFMeasureAction;
begin
  Action.Rect := ARect;
  Action.Index := AIndex;
  Action.WasDelete := AWasDelete;
  FMeasureUndo.Add(Action);
  FMeasureRedo.Clear;
  FMeasureDirty := True;
end;

procedure TFreePDF64PDFiumView.TextUndoClick(Sender: TObject);
var
  Pg, Index: Integer;
  Action: TPDFMeasureAction;
begin
  if (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6) and
     (FRedactionPreviews.Count > 0) then
  begin
    Pg := FRedactionPreviews.Count - 1;
    FRedactionRedoPages.Add(FRedactionPreviewPages[Pg]);
    FRedactionRedo.Add(FRedactionPreviews.Extract(FRedactionPreviews[Pg]));
    FRedactionPreviewPages.Delete(Pg);
    RefreshRedactionPage(FRedactionRedoPages.Last);
    UpdateTextUndoButtons;
    Exit;
  end;
  if FMeasureMode and (FMeasureUndo.Count > 0) then
  begin
    Action := FMeasureUndo.Last;
    FMeasureUndo.Delete(FMeasureUndo.Count - 1);
    Index := Min(Action.Index, FMeasureRects.Count);
    if Action.WasDelete then
      FMeasureRects.Insert(Index, Action.Rect)
    else if (Index >= 0) and (Index < FMeasureRects.Count) then
      FMeasureRects.Delete(Index);
    FMeasureRedo.Add(Action);
    FMeasureDirty := True;
    RefreshMeasurePages;
    UpdateTextUndoButtons;
    UpdateSaveState;
    Exit;
  end;

  if FTextEditor <> nil then FinishTextEditor(True);
  try
    if FCore.CanUndoNote then
    begin
      if not CanModifyComments then Exit;
      if FCore.UndoNote(Pg) then RefreshTextPage(Pg);
    end
    else if FCore.CanUndoInsertedText then
    begin
      if FCore.UndoInsertedText(Pg) then
      begin
        InvalidateAllWatermarkPages;
        RefreshTextPage(Pg);
      end;
    end
    else if FCore.Strokes.Count > 0 then
    begin
      Pg := FCore.Strokes.Count - 1;
      FStrokeRedoPages.Add(FCore.StrokePages[Pg]);
      FStrokeRedo.Add(FCore.Strokes.Extract(FCore.Strokes[Pg]));
      FCore.StrokePages.Delete(Pg);
      InvalidateAllWatermarkPages;
    end;
  except
    on E: Exception do PDFModernMessageDlg(E.Message, mtError, [mbOK], 0);
  end;
  UpdateTextUndoButtons;
end;

procedure TFreePDF64PDFiumView.TextRedoClick(Sender: TObject);
var
  Pg, Index: Integer;
  Action: TPDFMeasureAction;
begin
  if (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 6) and
     (FRedactionRedo.Count > 0) then
  begin
    Pg := FRedactionRedo.Count - 1;
    FRedactionPreviewPages.Add(FRedactionRedoPages[Pg]);
    FRedactionPreviews.Add(FRedactionRedo.Extract(FRedactionRedo[Pg]));
    FRedactionRedoPages.Delete(Pg);
    RefreshRedactionPage(FRedactionPreviewPages.Last);
    UpdateTextUndoButtons;
    Exit;
  end;
  if FMeasureMode and (FMeasureRedo.Count > 0) then
  begin
    Action := FMeasureRedo.Last;
    FMeasureRedo.Delete(FMeasureRedo.Count - 1);
    Index := Min(Action.Index, FMeasureRects.Count);
    if Action.WasDelete then
    begin
      if (Index >= 0) and (Index < FMeasureRects.Count) then
        FMeasureRects.Delete(Index);
    end
    else
      FMeasureRects.Insert(Index, Action.Rect);
    FMeasureUndo.Add(Action);
    FMeasureDirty := True;
    RefreshMeasurePages;
    UpdateTextUndoButtons;
    UpdateSaveState;
    Exit;
  end;

  if FTextEditor <> nil then FinishTextEditor(True);
  try
    if FCore.CanRedoNote then
    begin
      if not CanModifyComments then Exit;
      if FCore.RedoNote(Pg) then RefreshTextPage(Pg);
    end
    else if FCore.CanRedoInsertedText then
    begin
      if FCore.RedoInsertedText(Pg) then
      begin
        InvalidateAllWatermarkPages;
        RefreshTextPage(Pg);
      end;
    end
    else if FStrokeRedo.Count > 0 then
    begin
      Pg := FStrokeRedo.Count - 1;
      FCore.Strokes.Add(FStrokeRedo[Pg]);
      FCore.StrokePages.Add(FStrokeRedoPages[Pg]);
      FStrokeRedo.Delete(Pg);
      FStrokeRedoPages.Delete(Pg);
      InvalidateAllWatermarkPages;
    end;
  except
    on E: Exception do PDFModernMessageDlg(E.Message, mtError, [mbOK], 0);
  end;
  UpdateTextUndoButtons;
end;

procedure TFreePDF64PDFiumView.PageContextToolClick(Sender: TObject);
begin
  if not FEditVisible then ToggleEditBar(nil);
  case (Sender as TMenuItem).Tag of
    1: TextInsertClick(Sender);
    2: HighlightClick(Sender);
    3: NoteButtonClick(Sender);
  end;
end;

procedure TFreePDF64PDFiumView.HighlightClick(Sender: TObject);
begin
  if FTextEditor <> nil then FinishTextEditor(True);
  FHighlightMode := not FHighlightMode;
  Screen.Cursor := crDefault;
  if FHighlightMode then
  begin
    FTextInsertMode := False;
    FNoteMode := False;
    if FNoteButton <> nil then FNoteButton.Caption := ToolbarHint('Kommentar', 'Comment');
    FTextInsertButton.Caption := Tr('Text einfügen');
  end;
  FMarkMode := FEditVisible and not FTextInsertMode and not FHighlightMode and not FNoteMode;
  if FHighlightMode then
    FHighlightButton.Caption := ToolbarHint('Hervorheben: EIN', 'Highlight: ON')
  else
    FHighlightButton.Caption := ToolbarHint('Text hervorheben', 'Highlight text');
  UpdateTextUndoButtons;
end;

procedure TFreePDF64PDFiumView.PopupMeasureItem(Sender: TObject;
  ACanvas: TCanvas; var Width, Height: Integer);
var
  Item: TMenuItem;
  PPI: Integer;
begin
  if not (Sender is TMenuItem) then Exit;
  Item := TMenuItem(Sender);
  PPI := CurrentPPI;
  Width := ACanvas.TextWidth(Item.Caption) + MulDiv(48, PPI, 96);
  Height := Max(ACanvas.TextHeight('Ag') + MulDiv(12, PPI, 96),
    MulDiv(27, PPI, 96));
end;

procedure TFreePDF64PDFiumView.PopupDrawItem(Sender: TObject;
  ACanvas: TCanvas; ARect: TRect; Selected: Boolean);
var
  BackColor, TextColor, AccentColor: TColor;
  Item: TMenuItem;
  MarkRect, TextRect: TRect;
  PPI: Integer;
begin
  if not (Sender is TMenuItem) then Exit;
  Item := TMenuItem(Sender);
  PPI := CurrentPPI;
  case FEditToggle.FDesign of
    1: begin BackColor := RGB(245,247,250); TextColor := RGB(35,48,65); AccentColor := RGB(215,228,244); end;
    2: begin BackColor := RGB(65,70,79); TextColor := clWhite; AccentColor := RGB(83,105,135); end;
    3: begin BackColor := RGB(192,192,192); TextColor := clBlack; AccentColor := RGB(166,189,215); end;
    4: begin BackColor := RGB(45,48,54); TextColor := clWhite; AccentColor := RGB(69,91,124); end;
    5: begin BackColor := RGB(205,225,245); TextColor := RGB(24,55,88); AccentColor := RGB(161,198,233); end;
  else
    begin BackColor := clMenu; TextColor := clMenuText; AccentColor := clHighlight; end;
  end;
  ACanvas.Brush.Style := bsSolid;
  if Selected then ACanvas.Brush.Color := AccentColor
  else ACanvas.Brush.Color := BackColor;
  ACanvas.FillRect(ARect);
  ACanvas.Font.Color := TextColor;
  ACanvas.Font.Style := [];
  if Item.Checked then
  begin
    MarkRect := ARect;
    MarkRect.Left := ARect.Left + MulDiv(9, PPI, 96);
    MarkRect.Right := MarkRect.Left + MulDiv(15, PPI, 96);
    DrawText(ACanvas.Handle, PChar('✓'), 1, MarkRect,
      DT_LEFT or DT_VCENTER or DT_SINGLELINE);
  end;
  TextRect := ARect;
  Inc(TextRect.Left, MulDiv(32, PPI, 96));
  DrawText(ACanvas.Handle, PChar(Item.Caption), Length(Item.Caption),
    TextRect, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
end;

procedure TFreePDF64PDFiumView.InsertDropdownClick(Sender: TObject);
var
  P: TPoint;
begin
  if (FInsertPopup = nil) or (FInsertButton = nil) then Exit;
  UpdateTextUndoButtons;
  FInsertTextItem.Checked := FTextInsertMode;
  FInsertNoteItem.Checked := FNoteMode;
  FInsertNoteItem.Enabled := CanModifyComments(False);
  FInsertLinkItem.Checked := FLinkMode;
  P := FInsertButton.ClientToScreen(Point(0, FInsertButton.Height));
  FInsertPopup.Popup(P.X, P.Y);
end;

procedure TFreePDF64PDFiumView.InsertTextMenuClick(Sender: TObject);
begin
  TextInsertClick(FTextInsertButton);
end;

procedure TFreePDF64PDFiumView.InsertNoteMenuClick(Sender: TObject);
begin
  NoteButtonClick(FNoteButton);
end;

procedure TFreePDF64PDFiumView.TextInsertClick(Sender: TObject);
begin
  if FTextEditor <> nil then FinishTextEditor(True);
  FTextInsertMode := not FTextInsertMode;
  if FTextInsertMode then
  begin
    if FMeasureMode then
    begin
      FMeasureMode := False;
      CancelMeasurement;
      if FMeasureButton <> nil then FMeasureButton.Font.Style := [];
    end;
    FNoteMode := False;
    if FNoteButton <> nil then FNoteButton.Caption := ToolbarHint('Kommentar', 'Comment');
    FHighlightMode := False;
    Screen.Cursor := crDefault;
    FHighlightButton.Caption := ToolbarHint('Text hervorheben', 'Highlight text');
  end;
  FMarkMode := FEditVisible and not FTextInsertMode and not FHighlightMode and not FNoteMode;
  if FTextInsertMode then
    FTextInsertButton.Caption := Tr('Text: EIN')
  else
    FTextInsertButton.Caption := Tr('Text einfügen');
  UpdateTextUndoButtons;
  LayoutToolbar(nil);
end;

procedure TFreePDF64PDFiumView.FinishTextEditor(ACommit: Boolean);
var
  S: string;
  LocalX, LocalY: Integer;
  PX, PY: Double;
  Img: TPDFiumImage;
begin
  if FTextEditor = nil then Exit;
  // Position aus dem aktuellen Eingabefeld ableiten. Die PDF-Koordinaten
  // beziehen sich auf die Schrift-Basislinie, nicht auf die Unterkante
  // des Windows-Edit-Rahmens. Der obere Innenabstand ist ca. 3 Pixel.
  Img := FTextEditorImage;
  if Img <> nil then
  begin
    LocalX := FTextEditor.Left - Img.Left + 3;
    LocalY := FTextEditor.Top - Img.Top + 3 +
      MulDiv(FTextInsertSize, Screen.PixelsPerInch, 72);
    if FCore.DevicePointToPage(FTextEditorPage, Img.Width, Img.Height,
      LocalX, LocalY, PX, PY) then
    begin
      FTextEditorX := PX;
      FTextEditorY := PY;
    end;
  end;
  FTextDragging := False;
  FTextResizing := False;
  FreeAndNil(FTextResizeGrip);
  S := FTextEditor.Text;
  FTextEditor.OnKeyDown := nil;
  FreeAndNil(FTextEditor);
  FTextEditorImage := nil;
  if ACommit and (Trim(S) <> '') then
  begin
    try
      FCore.InsertText(FTextEditorPage, FTextEditorX, FTextEditorY,
        S, FTextInsertSize, FTextInsertColor, FTextFontSelect.Text);
      // PaintPage fuehrt nur LayoutAllPages aus und zeichnet eine bereits
      // geladene Bitmap nicht zwingend neu. Die betroffene Seite direkt rendern.
      if (FTextEditorPage >= 0) and (FTextEditorPage < Length(FLoadedPages)) and
         FLoadedPages[FTextEditorPage] then
      begin
        FCore.RenderPage(FTextEditorPage, PageImage(FTextEditorPage).Picture.Bitmap,
          PageImage(FTextEditorPage).Width, PageImage(FTextEditorPage).Height);
        DrawPageStrokes(FTextEditorPage);
        PageImage(FTextEditorPage).Invalidate;
      end;
      UpdateSaveState;
      UpdateTextUndoButtons;
    except
      on E: Exception do
        PDFModernMessageDlg(Tr('Text konnte nicht eingefügt werden: ') + E.Message,
          mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFreePDF64PDFiumView.WMFinishTextEditor(var Message: TMessage);
begin
  // Nach Abschluss der Tastatur-Nachricht ausführen: niemals das
  // gerade in TEdit.WndProc aktive Steuerelement im OnKeyDown freigeben.
  FinishTextEditor(Message.WParam <> 0);
end;

procedure TFreePDF64PDFiumView.TextEditorKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    if FTextEditor <> nil then FTextEditor.Enabled := False;
    PostMessage(Handle, WM_PDF_FINISH_TEXT, 1, 0);
  end
  else if Key = VK_ESCAPE then
  begin
    Key := 0;
    if FTextEditor <> nil then FTextEditor.Enabled := False;
    PostMessage(Handle, WM_PDF_FINISH_TEXT, 0, 0);
  end;
end;

procedure TFreePDF64PDFiumView.TextEditorMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // Strg + linke Maustaste: Eingabefeld verschieben; ohne Strg Text markieren.
  if (Button = mbLeft) and (ssCtrl in Shift) and (FTextEditor <> nil) then
  begin
    FTextDragging := True;
    FTextDragStart := Mouse.CursorPos;
    FTextDragLeft := FTextEditor.Left;
    FTextDragTop := FTextEditor.Top;
  end;
end;

procedure TFreePDF64PDFiumView.TextEditorMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if FTextDragging and (FTextEditor <> nil) then
  begin
    // Bildschirmkoordinaten bleiben beim Verschieben des Controls stabil.
    // X/Y aus OnMouseMove sind dagegen relativ zum sich bewegenden Edit.
    FTextEditor.SetBounds(
      FTextDragLeft + Mouse.CursorPos.X - FTextDragStart.X,
      FTextDragTop + Mouse.CursorPos.Y - FTextDragStart.Y,
      FTextEditor.Width, FTextEditor.Height);
    PositionTextResizeGrip;
  end;
end;

procedure TFreePDF64PDFiumView.TextEditorMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FTextDragging := False;
  end;
end;

procedure TFreePDF64PDFiumView.PositionTextResizeGrip;
begin
  if (FTextEditor = nil) or (FTextResizeGrip = nil) then Exit;
  FTextResizeGrip.SetBounds(FTextEditor.Left + FTextEditor.Width - FTextResizeGrip.Width,
    FTextEditor.Top + FTextEditor.Height - FTextResizeGrip.Height,
    FTextResizeGrip.Width, FTextResizeGrip.Height);
end;

procedure TFreePDF64PDFiumView.TextResizeMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button <> mbLeft) or (FTextEditor = nil) then Exit;
  FTextResizing := True;
  FTextResizeStart := Mouse.CursorPos;
  FTextResizeWidth := FTextEditor.Width;
  FTextResizeHeight := FTextEditor.Height;
  Winapi.Windows.SetCapture(FTextResizeGrip.Handle);
end;

procedure TFreePDF64PDFiumView.TextResizeMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if not FTextResizing or (FTextEditor = nil) then Exit;
  FTextEditor.SetBounds(FTextEditor.Left, FTextEditor.Top,
    Max(100, FTextResizeWidth + Mouse.CursorPos.X - FTextResizeStart.X),
    Max(28, FTextResizeHeight + Mouse.CursorPos.Y - FTextResizeStart.Y));
  PositionTextResizeGrip;
end;

procedure TFreePDF64PDFiumView.TextResizeMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  FTextResizing := False;
  if (FTextResizeGrip <> nil) and (Winapi.Windows.GetCapture = FTextResizeGrip.Handle) then
    Winapi.Windows.ReleaseCapture;
  if FTextEditor <> nil then FTextEditor.SetFocus;
end;

procedure TFreePDF64PDFiumView.RefreshMeasurePages;
var I: Integer;
begin
  for I := 0 to FPages.Count - 1 do
    if TObject(FPages[I]) is TPDFiumImage then
      TPDFiumImage(FPages[I]).Invalidate;
end;

procedure TFreePDF64PDFiumView.ShowMeasureReport(Sender: TObject);
var
  D: TForm;
  LV: TListView;
  Footer: TPanel;
  Info: TLabel;
  BCopy, BCSV, BClose: TButton;
  Lines: TStringList;
  I, PPI, Choice: Integer;
  M: TPDFMeasureRect;
  Item: TListItem;
  U, ScaleText, Line: string;
  Factor, WidthValue, HeightValue: Double;
  SD: TSaveDialog;
  function DP(N: Integer): Integer;
  begin
    Result := MulDiv(N, PPI, 96);
  end;
  procedure AddColumn(const ACaption: string; AWidth: Integer);
  var
    Col: TListColumn;
  begin
    Col := LV.Columns.Add;
    Col.Caption := ACaption;
    Col.Width := DP(AWidth);
  end;
begin
  Lines := TStringList.Create;
  try
    Lines.Add(ToolbarHint('Seite;Nr.;Breite;Höhe;Einheit;Maßstab',
      'Page;No.;Width;Height;Unit;Scale'));
    D := TForm.Create(Self);
    try
      D.Caption := ToolbarHint('Messbericht', 'Measurement report');
      D.Position := poScreenCenter;
      D.Scaled := True;
      D.BorderStyle := bsSizeable;
      PPI := CurrentPPI;
      D.ClientWidth := DP(620);
      D.ClientHeight := DP(330);
      D.Constraints.MinWidth := DP(500);
      D.Constraints.MinHeight := DP(250);

      Footer := TPanel.Create(D);
      Footer.Parent := D;
      Footer.Align := alBottom;
      Footer.Height := DP(64);
      Footer.BevelOuter := bvNone;

      Info := TLabel.Create(D);
      Info.Parent := D;
      Info.Align := alTop;
      Info.AutoSize := False;
      Info.Height := DP(42);
      Info.Layout := tlCenter;
      Info.Margins.Left := DP(14);
      Info.Caption := '  ' + ToolbarHint('Messungen: ', 'Measurements: ') +
        IntToStr(FMeasureRects.Count);
      Info.Font.Style := [fsBold];

      LV := TListView.Create(D);
      LV.Parent := D;
      LV.Align := alClient;
      LV.ViewStyle := vsReport;
      LV.ReadOnly := True;
      LV.RowSelect := True;
      LV.GridLines := False;
      LV.HideSelection := False;
      AddColumn(ToolbarHint('Seite', 'Page'), 70);
      AddColumn(ToolbarHint('Nr.', 'No.'), 55);
      AddColumn(ToolbarHint('Breite', 'Width'), 100);
      AddColumn(ToolbarHint('Höhe', 'Height'), 100);
      AddColumn(ToolbarHint('Einheit', 'Unit'), 85);
      AddColumn(ToolbarHint('Maßstab', 'Scale'), 110);
      LV.Items.BeginUpdate;
      try
        for I := 0 to FMeasureRects.Count - 1 do
        begin
          M := FMeasureRects[I];
          case M.UnitIndex of
            1: begin U := 'cm'; Factor := 10; end;
            2: begin U := 'in'; Factor := 25.4; end;
          else
            U := 'mm'; Factor := 1;
          end;
          WidthValue := Abs(M.X2 - M.X1) * M.Scale / Factor;
          HeightValue := Abs(M.Y2 - M.Y1) * M.Scale / Factor;
          ScaleText := '1:' + FormatFloat('0.##', M.Scale / (25.4 / 72.0));
          Item := LV.Items.Add;
          Item.Caption := IntToStr(M.Page + 1);
          Item.SubItems.Add(IntToStr(I + 1));
          Item.SubItems.Add(FormatFloat('0.##', WidthValue));
          Item.SubItems.Add(FormatFloat('0.##', HeightValue));
          Item.SubItems.Add(U);
          Item.SubItems.Add(ScaleText);
          Line := IntToStr(M.Page + 1) + ';' + IntToStr(I + 1) + ';' +
            FormatFloat('0.##', WidthValue) + ';' +
            FormatFloat('0.##', HeightValue) + ';' + U + ';' + ScaleText;
          Lines.Add(Line);
        end;
      finally
        LV.Items.EndUpdate;
      end;

      BClose := TButton.Create(D);
      BClose.Parent := Footer;
      BClose.SetBounds(DP(484), DP(15), DP(120), DP(34));
      BClose.Anchors := [akRight, akTop];
      BClose.Caption := ToolbarHint('Schließen', 'Close');
      BClose.ModalResult := mrClose;
      BClose.Default := True;
      BClose.Cancel := True;

      BCSV := TButton.Create(D);
      BCSV.Parent := Footer;
      BCSV.SetBounds(DP(167), DP(15), DP(160), DP(34));
      BCSV.Caption := ToolbarHint('Als CSV speichern', 'Save as CSV');
      BCSV.ModalResult := mrNo;

      BCopy := TButton.Create(D);
      BCopy.Parent := Footer;
      BCopy.SetBounds(DP(12), DP(15), DP(145), DP(34));
      BCopy.Caption := ToolbarHint('Bericht kopieren', 'Copy report');
      BCopy.ModalResult := mrYes;

      ApplyManagedDialogPalette(D, LV, FEditToggle.FDesign);
      Footer.ParentColor := False;
      Footer.Color := D.Color;
      Info.ParentFont := False;
      Info.Font.Color := D.Font.Color;
      repeat
        Choice := D.ShowModal;
        case Choice of
          mrYes: Clipboard.AsText := Lines.Text;
          mrNo:
            begin
              SD := TSaveDialog.Create(D);
              try
                SD.Filter := 'CSV (*.csv)|*.csv';
                SD.DefaultExt := 'csv';
                SD.FileName := ToolbarHint('Messbericht.csv', 'Measurement_report.csv');
                if SD.Execute then Lines.SaveToFile(SD.FileName, TEncoding.UTF8);
              finally
                SD.Free;
              end;
            end;
        end;
      until not (Choice in [mrYes, mrNo]);
    finally
      D.Free;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TFreePDF64PDFiumView.CancelMeasurement;
var
  I: Integer;
begin
  FMeasureDragging := False;
  FMeasurePage := -1;
  Screen.Cursor := crDefault;
  for I := 0 to FPages.Count - 1 do
    if TObject(FPages[I]) is TPDFiumImage then
    begin
      TPDFiumImage(FPages[I]).MouseCapture := False;
      TPDFiumImage(FPages[I]).Cursor := crDefault;
      TPDFiumImage(FPages[I]).Invalidate;
    end;
end;

procedure TFreePDF64PDFiumView.MeasureDropdownClick(Sender: TObject);
var
  P: TPoint;
begin
  if (FMeasurePopup = nil) or (FMeasureButton = nil) then Exit;
  FMeasureMenuItem.Checked := FMeasureMode;
  P := FMeasureButton.ClientToScreen(Point(0, FMeasureButton.Height));
  FMeasurePopup.Popup(P.X, P.Y);
end;

procedure TFreePDF64PDFiumView.MeasureClick(Sender: TObject);
begin
  // Einen noch offenen Texteingabe-Editor vor dem Moduswechsel schliessen.
  if FTextEditor <> nil then FinishTextEditor(True);
  FMeasureMode := not FMeasureMode;
  CancelMeasurement;
  if FMeasureMode then
  begin
    FLinkMode := False;
    FTextInsertMode := False;
    FHighlightMode := False;
    FNoteMode := False;
    if FNoteButton <> nil then
      FNoteButton.Caption := ToolbarHint('Kommentar', 'Comment');
    if FTextInsertButton <> nil then
      FTextInsertButton.Caption := Tr('Text einfügen');
    if FHighlightButton <> nil then
      FHighlightButton.Caption := ToolbarHint('Text hervorheben', 'Highlight text');
    FMarkMode := False;
  end;
  FMeasureButton.Caption := ToolbarHint(
    'Messen', 'Measure') + ' ' + #$25BE;
  UpdateTextUndoButtons;
  // Layout muss die Text-Steuerelemente im Messmodus ausblenden.
  LayoutToolbar(nil);
  if FMeasureMode then
    FMeasureButton.Font.Style := [fsBold]
  else
    FMeasureButton.Font.Style := [];
  // Erst nach der Modusumschaltung zeichnen, nicht vorher.
  for var I := 0 to FPages.Count - 1 do
    if TObject(FPages[I]) is TPDFiumImage then
      TPDFiumImage(FPages[I]).Invalidate;
end;

procedure TFreePDF64PDFiumView.MeasureUnitChange(Sender: TObject);
begin
  FMeasureUnit := FMeasureUnitSelect.ItemIndex;
  if (FMeasurePage >= 0) and (FMeasurePage < FPages.Count) then
    TPDFiumImage(FPages[FMeasurePage]).Invalidate;
end;

procedure TFreePDF64PDFiumView.MeasureScaleClick(Sender: TObject);
var
  S: string;
  N, A, B: Double;
  P, PPI: Integer;
  D: TForm;
  Prompt: TLabel;
  Edit: TEdit;
  OKButton, CancelButton: TButton;
  function DP(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, PPI, 96);
  end;
begin
  D := TForm.Create(Self);
  try
    PPI := CurrentPPI;
    D.Caption := ToolbarHint('Maßstab', 'Drawing scale');
    D.Position := poScreenCenter;
    D.BorderStyle := bsDialog;
    D.Scaled := True;
    D.ClientWidth := DP(300);
    D.ClientHeight := DP(145);

    Prompt := TLabel.Create(D);
    Prompt.Parent := D;
    Prompt.SetBounds(DP(24), DP(20), DP(252), DP(22));
    Prompt.Caption := ToolbarHint('Maßstab eingeben (z. B. 1:50):',
      'Enter scale (e.g. 1:50):');

    Edit := TEdit.Create(D);
    Edit.Parent := D;
    Edit.SetBounds(DP(24), DP(48), DP(252), DP(27));
    Edit.Text := '1:1';
    Edit.SelectAll;

    OKButton := TButton.Create(D);
    OKButton.Parent := D;
    OKButton.SetBounds(DP(104), DP(96), DP(80), DP(32));
    OKButton.Caption := 'OK';
    OKButton.ModalResult := mrOk;
    OKButton.Default := True;

    CancelButton := TButton.Create(D);
    CancelButton.Parent := D;
    CancelButton.SetBounds(DP(196), DP(96), DP(80), DP(32));
    CancelButton.Caption := ToolbarHint('Abbrechen', 'Cancel');
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;

    ApplyManagedDialogPalette(D, nil, FEditToggle.FDesign);
    Prompt.ParentFont := False;
    Prompt.Font.Color := D.Font.Color;
    Edit.ParentColor := False;
    case FEditToggle.FDesign of
      1: begin Edit.Color := RGB(245,247,250); Edit.Font.Color := RGB(35,48,65); end;
      2: begin Edit.Color := RGB(65,70,79); Edit.Font.Color := clWhite; end;
      3: begin Edit.Color := clWhite; Edit.Font.Color := clBlack; end;
      4: begin Edit.Color := RGB(45,48,54); Edit.Font.Color := clWhite; end;
      5: begin Edit.Color := RGB(246,250,255); Edit.Font.Color := RGB(24,55,88); end;
    else
      begin Edit.Color := clWindow; Edit.Font.Color := clWindowText; end;
    end;
    D.ActiveControl := Edit;
    if D.ShowModal <> mrOk then Exit;
    S := Trim(Edit.Text);
  finally
    D.Free;
  end;
  P := Pos(':', S);
  if P > 0 then
  begin
    if not TryStrToFloat(Trim(Copy(S, 1, P - 1)), A) or
       not TryStrToFloat(Trim(Copy(S, P + 1, MaxInt)), B) or
       (A <= 0) or (B <= 0) then
    begin
      MessageBeep(MB_ICONWARNING);
      Exit;
    end;
    N := B / A;
  end
  else if not TryStrToFloat(S, N) or (N <= 0) then
  begin
    MessageBeep(MB_ICONWARNING);
    Exit;
  end;
  FMeasureScale := (25.4 / 72.0) * N;
  if (FMeasurePage >= 0) and (FMeasurePage < FPages.Count) then
    TPDFiumImage(FPages[FMeasurePage]).Invalidate;
end;

procedure TFreePDF64PDFiumView.DrawMeasurement(Sender: TObject);
var
  Img: TPDFiumImage;
  C: TCanvas;
  M: TPDFMeasureRect;
  I: Integer;
  AX, AY, BX, BY: Double;
  P1, P2: TPoint;

  procedure PaintOne(const A, B: TPoint; AScale: Double; AUnit: Integer;
    const PAX, PAY, PBX, PBY: Double);
  var
    WMM, HMM, Factor: Double;
    UnitName, WT, HT: string;
    R: TRect;
    MX, MY, TW, TH: Integer;
  begin
    WMM := Abs(PBX - PAX) * AScale;
    HMM := Abs(PBY - PAY) * AScale;
    case AUnit of
      1: begin Factor := 10; UnitName := ' cm'; end;
      2: begin Factor := 25.4; UnitName := ' in'; end;
    else
      Factor := 1; UnitName := ' mm';
    end;
    WT := FormatFloat('0.##', WMM / Factor) + UnitName;
    HT := FormatFloat('0.##', HMM / Factor) + UnitName;
    R := Rect(Min(A.X, B.X), Min(A.Y, B.Y),
      Max(A.X, B.X), Max(A.Y, B.Y));
    C.Pen.Color := clRed;
    C.Pen.Width := Max(2, MulDiv(2, CurrentPPI, 96));
    C.Brush.Style := bsClear;
    C.Rectangle(R.Left, R.Top, R.Right, R.Bottom);
    C.Font.Color := clRed;
    C.Brush.Style := bsClear;
    TW := C.TextWidth(WT);
    TH := C.TextHeight(WT);
    MX := (R.Left + R.Right) div 2;
    C.TextOut(Max(0, Min(Max(0, Img.Width - TW), MX - TW div 2)),
      Max(0, R.Top - TH - 3), WT);
    TW := C.TextWidth(HT);
    TH := C.TextHeight(HT);
    MY := (R.Top + R.Bottom) div 2;
    C.TextOut(Max(0, Min(Max(0, Img.Width - TW), R.Left - TW - 9)),
      Max(0, Min(Max(0, Img.Height - TH), MY - TH div 2)), HT);
  end;
begin
  if not (Sender is TPDFiumImage) or
     (FCore = nil) then Exit;
  Img := TPDFiumImage(Sender);
  // Im AfterPaint-Callback die echte Paint-Canvas des TGraphicControl
  // verwenden. TControlCanvas zeichnet direkt auf das Parent-Fenster und
  // wird durch dessen DoubleBuffer-Paint unmittelbar wieder uebermalt.
  C := TPDFGraphicCanvasAccess(Img).Canvas;
  try
    for I := 0 to FMeasureRects.Count - 1 do
    begin
      M := FMeasureRects[I];
      if M.Page <> Img.Tag then Continue;
      if FCore.PagePointToDevice(Img.Tag, Img.Width, Img.Height,
          M.X1, M.Y1, P1.X, P1.Y) and
         FCore.PagePointToDevice(Img.Tag, Img.Width, Img.Height,
          M.X2, M.Y2, P2.X, P2.Y) then
        PaintOne(P1, P2, M.Scale, M.UnitIndex,
          M.X1, M.Y1, M.X2, M.Y2);
    end;
    if FMeasureMode and (FMeasurePage = Img.Tag) and
       FCore.DevicePointToPage(Img.Tag, Img.Width, Img.Height,
         FMeasureStart.X, FMeasureStart.Y, AX, AY) and
       FCore.DevicePointToPage(Img.Tag, Img.Width, Img.Height,
         FMeasureEnd.X, FMeasureEnd.Y, BX, BY) then
      PaintOne(FMeasureStart, FMeasureEnd, FMeasureScale,
        FMeasureUnit, AX, AY, BX, BY);
  finally
    C.Brush.Style := bsSolid;
  end;
end;

procedure TFreePDF64PDFiumView.ImageMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Target: TPDFLinkTarget;
  URL: string;
  WidgetIndex: Integer;
  FormValue: string;
  Img: TPDFiumImage;
  IsMultiline: Boolean;
  Options: TStringList;
  OptionDlg: TForm;
  OptionList: TListBox;
  SearchEdit: TPDFOptionSearch;
  ResultLabel: TLabel;
  OKButton, CancelButton: TButton;
  OptionWidth, I, FieldType, FieldFlags, SelectedCount: Integer;
  DialogDPI, Margin, Gap, ButtonWidth, ButtonHeight, SearchHeight: Integer;
  ListHeight, FooterHeight, FooterTop, RowHeight, ContentWidth: Integer;
  SelectedIndices: TArray<Integer>;
  IsListBox, IsMultiSelect: Boolean;
  PX, PY: Double;
  NoteItem: TMenuItem;
begin
  if FSignatureMode and (Sender is TPDFiumImage) then
  begin
    Img := TPDFiumImage(Sender);
    if Button = mbRight then
    begin
      CancelSignature;
      Img.Invalidate;
      Exit;
    end;
    if Button = mbLeft then
    begin
      if FSignaturePlaced then
      begin
        if Img.Tag <> FSignaturePreviewPage then Exit;
        // Die Eckgriffe liegen teilweise AUSSERHALB des Rechtecks.
        // Daher immer zuerst die vier Griffe prüfen, erst danach den Innenbereich.
        FSignatureResizeCorner := 0;
        if (Abs(X-FSignatureRect.Left) <= 12) and (Abs(Y-FSignatureRect.Top) <= 12) then
          FSignatureResizeCorner := 1
        else if (Abs(X-FSignatureRect.Right) <= 12) and (Abs(Y-FSignatureRect.Top) <= 12) then
          FSignatureResizeCorner := 2
        else if (Abs(X-FSignatureRect.Left) <= 12) and (Abs(Y-FSignatureRect.Bottom) <= 12) then
          FSignatureResizeCorner := 3
        else if (Abs(X-FSignatureRect.Right) <= 12) and (Abs(Y-FSignatureRect.Bottom) <= 12) then
          FSignatureResizeCorner := 4;
        if (FSignatureResizeCorner <> 0) or PtInRect(FSignatureRect, Point(X,Y)) then
        begin
          FSignatureDragOrigin := Point(X,Y);
          FSignatureRectOrigin := FSignatureRect;
          FSignatureResizing := FSignatureResizeCorner <> 0;
          FSignatureDragging := not FSignatureResizing;
          if FSignatureResizing then
          begin
            if FSignatureResizeCorner in [1, 4] then
              Img.Cursor := crSizeNWSE
            else
              Img.Cursor := crSizeNESW;
          end
          else
            Img.Cursor := crSizeAll;
          // Screen.Cursor hat Vorrang vor dem Cursor des Bild-Controls.
          Screen.Cursor := Img.Cursor;
          Img.MouseCapture := True;
        end
        else
          CommitSignature;
      end
      else if (FSignaturePreview <> nil) and (FSignaturePreview.Width > 0) then
      begin
        var PW, PH: Single;
        if not FCore.PageSize(Img.Tag, PW, PH) then Exit;
        var W := Max(1, Round(FSignatureWidthMM * 72 / 25.4 *
          Img.Width / Max(1.0, Double(PW))));
        var H := Max(1, MulDiv(W, FSignaturePreview.Height,
          Max(1, FSignaturePreview.Width)));
        FSignatureRect := Rect(EnsureRange(X,0,Max(0,Img.Width-W)),
          EnsureRange(Y,0,Max(0,Img.Height-H)),0,0);
        FSignatureRect.Right := FSignatureRect.Left + W;
        FSignatureRect.Bottom := FSignatureRect.Top + H;
        FSignaturePreviewPage := Img.Tag;
        FSignaturePreviewVisible := True;
        FSignaturePlaced := True;
        Img.Invalidate;
      end;
    end;
    Exit;
  end;
  if FMeasureMode and (Sender is TPDFiumImage) then
  begin
    if Button = mbRight then
    begin
      // Rechtsklick in ein Messrechteck entfernt genau diese Messung.
      if (FCore <> nil) and FCore.DevicePointToPage(
        TPDFiumImage(Sender).Tag, TPDFiumImage(Sender).Width,
        TPDFiumImage(Sender).Height, X, Y, PX, PY) then
        for I := FMeasureRects.Count - 1 downto 0 do
        begin
          var M := FMeasureRects[I];
          if (M.Page = TPDFiumImage(Sender).Tag) and
             (PX >= Min(M.X1, M.X2)) and (PX <= Max(M.X1, M.X2)) and
             (PY >= Min(M.Y1, M.Y2)) and (PY <= Max(M.Y1, M.Y2)) then
          begin
            RecordMeasureAction(M, I, True);
            FMeasureRects.Delete(I);
            UpdateTextUndoButtons;
            UpdateSaveState;
            TPDFiumImage(Sender).Repaint;
            Break;
          end;
        end;
      Exit;
    end;
    if Button = mbLeft then
    begin
      FMeasurePage := TPDFiumImage(Sender).Tag;
      FMeasureStart := Point(X, Y);
      FMeasureEnd := FMeasureStart;
      FMeasureDragging := True;
      TPDFiumImage(Sender).MouseCapture := True;
      TPDFiumImage(Sender).Cursor := crCross;
      TPDFiumImage(Sender).Invalidate;
    end;
    Exit;
  end;
  if (Button = mbLeft) and (ssCtrl in Shift) and
     (Sender is TPDFiumImage) and (FCore <> nil) and
     LinkAtImagePoint(Sender, X, Y, Target) and
     ((Target.URI <> '') or (Target.PageIndex >= 0)) then
  begin
    FLinkMovePending := True;
    FLinkMovePage := TPDFiumImage(Sender).Tag;
    FLinkMoveStart := Point(X, Y);
    FLinkMoveEnd := FLinkMoveStart;
    TPDFiumImage(Sender).MouseCapture := True;
    TPDFiumImage(Sender).Cursor := crSizeAll;
    Exit;
  end;
  if FLinkMode and (Sender is TPDFiumImage) then
  begin
    if Button = mbLeft then
    begin
      FHighlightAreaDragging := True;
      FHighlightAreaPage := TPDFiumImage(Sender).Tag;
      FHighlightAreaStartX := X;
      FHighlightAreaStartY := Y;
      FHighlightAreaEndX := X;
      FHighlightAreaEndY := Y;
      TPDFiumImage(Sender).MouseCapture := True;
      TPDFiumImage(Sender).Cursor := crCross;
      Screen.Cursor := crCross;
    end;
    Exit;
  end;
  if (Sender is TPDFiumImage) and (FCore <> nil) then
  begin
    Img := TPDFiumImage(Sender);
    // Rechtsklick auf eine vorhandene PDF-Textauswahl: Markierung erhalten.
    // Kommentarmenü hat Vorrang, falls auf eine Notiz geklickt wurde.
    if (Button = mbRight) and
       (FSelAnchorPage >= 0) and (FSelFocusPage >= 0) and
       (Trim(SelectedText) <> '') and
       not NoteAtPoint(Img, X, Y, FNoteSelected) then
    begin
      if FSelectionMenu = nil then
      begin
        FSelectionMenu := TPopupMenu.Create(Self);
        FSelectionMenu.AutoPopup := False;
      end;
      FSelectionMenu.Items.Clear;
      NoteItem := TMenuItem.Create(FSelectionMenu);
      NoteItem.Caption := ToolbarHint('Kopieren (Strg+C)', 'Copy (Ctrl+C)');
      NoteItem.Tag := 1;
      NoteItem.OnClick := SelectionMenuClick;
      FSelectionMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FSelectionMenu);
      NoteItem.Caption := '-';
      FSelectionMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FSelectionMenu);
      NoteItem.Caption := ToolbarHint('Mit Google übersetzen', 'Translate with Google');
      NoteItem.Tag := 2;
      NoteItem.OnClick := SelectionMenuClick;
      FSelectionMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FSelectionMenu);
      NoteItem.Caption := '-';
      FSelectionMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FSelectionMenu);
      NoteItem.Caption := ToolbarHint('Mit Bing suchen', 'Search with Bing');
      NoteItem.Tag := 4;
      NoteItem.OnClick := SelectionMenuClick;
      FSelectionMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FSelectionMenu);
      NoteItem.Caption := ToolbarHint('Mit Google suchen', 'Search with Google');
      NoteItem.Tag := 3;
      NoteItem.OnClick := SelectionMenuClick;
      FSelectionMenu.Items.Add(NoteItem);
      FSelectionMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
      Exit;
    end;
    if (Button = mbRight) and NoteAtPoint(Img, X, Y, FNoteSelected) then
    begin
      if not CanModifyComments then Exit;
      // Das Popup muss bis zur Ausfuehrung des OnClick-Ereignisses leben.
      // VCL kann die Menueaktion erst nach Rueckkehr aus Popup zustellen.
      FreeAndNil(FNotePopup);
      FNotePopup := TPopupMenu.Create(Self);
      begin
        FNotePopup.AutoPopup := False;
        NoteItem := TMenuItem.Create(FNotePopup);
        with NoteItem do
        begin
          Caption := ToolbarHint('Kommentar bearbeiten', 'Edit comment');
          Tag := 1;
          OnClick := NoteMenuClick;
          FNotePopup.Items.Add(NoteItem);
        end;
        NoteItem := TMenuItem.Create(FNotePopup);
        with NoteItem do
        begin
          Caption := ToolbarHint('Kommentar verschieben', 'Move comment');
          Tag := 2;
          OnClick := NoteMenuClick;
          FNotePopup.Items.Add(NoteItem);
        end;
        // Trennstrich vor dem Löschen des Kommentars.
        NoteItem := TMenuItem.Create(FNotePopup);
        NoteItem.Caption := '-';
        FNotePopup.Items.Add(NoteItem);
        NoteItem := TMenuItem.Create(FNotePopup);
        with NoteItem do
        begin
          Caption := ToolbarHint('Kommentar löschen', 'Delete comment');
          Tag := 3;
          OnClick := NoteMenuClick;
          FNotePopup.Items.Add(NoteItem);
        end;
        FNotePopup.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
      end;
      Exit;
    end;
    if (Button = mbRight) and (FPageContextMenu <> nil) then
    begin
      // Kontextmenue der PDF-Seite, unabhaengig vom Miniaturmenue.
      // Die vorhandenen Aktionen werden unveraendert wiederverwendet.
      FPage := Img.Tag;
      FPageContextMenu.Items.Clear;
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Seite um 90° nach rechts drehen', 'Rotate page 90° clockwise');
      NoteItem.Tag := 90;
      NoteItem.OnClick := PageContextRotateClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Seite um 90° nach links drehen', 'Rotate page 90° counterclockwise');
      NoteItem.Tag := -90;
      NoteItem.OnClick := PageContextRotateClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := '-';
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := Tr('PDF davor einfügen ...');
      NoteItem.Tag := 0;
      NoteItem.OnClick := InsertPDFAtThumbnail;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := Tr('PDF danach einfügen ...');
      NoteItem.Tag := 1;
      NoteItem.OnClick := InsertPDFAtThumbnail;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := '-';
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Text einfügen ...', 'Insert text ...');
      NoteItem.Checked := FTextInsertMode;
      NoteItem.Tag := 1;
      NoteItem.OnClick := PageContextToolClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Text hervorheben ...', 'Highlight text ...');
      NoteItem.Checked := FHighlightMode;
      NoteItem.Tag := 2;
      NoteItem.OnClick := PageContextToolClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Kommentar hinzufügen ...', 'Add comment ...');
      NoteItem.Checked := FNoteMode;
      NoteItem.Enabled := CanModifyComments(False);
      NoteItem.Tag := 3;
      NoteItem.OnClick := PageContextToolClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := '-';
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Hyperlink hinzufügen ...', 'Add hyperlink ...');
      NoteItem.OnClick := LinkMenuClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Unterschrift hinzufügen ...', 'Add signature ...');
      NoteItem.OnClick := SignatureClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := Tr('Bildwasserzeichen hinzufügen ...');
      NoteItem.OnClick := ImageWatermarkClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := Tr('Textwasserzeichen hinzufügen ...');
      NoteItem.OnClick := TextWatermarkClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := '-';
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Hyperlinks verwalten ...', 'Manage hyperlinks ...');
      NoteItem.OnClick := ManageLinksClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := ToolbarHint('Kommentare verwalten ...', 'Manage comments ...');
      NoteItem.OnClick := ShowCommentOverviewMenuClick;
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := '-';
      FPageContextMenu.Items.Add(NoteItem);
      NoteItem := TMenuItem.Create(FPageContextMenu);
      NoteItem.Caption := Tr('PDF neu laden (Änderungen verwerfen)');
      NoteItem.Enabled := (FCore.FileName <> '') and FileExists(FCore.FileName);
      NoteItem.OnClick := ReloadPDFClick;
      FPageContextMenu.Items.Add(NoteItem);
      FPageContextMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
      Exit;
    end;
    if Button = mbLeft then
    begin
      if FNoteMovePending then
      begin
        if not CanModifyComments then
        begin
          FNoteMovePending := False;
          Screen.Cursor := crDefault;
          Img.Cursor := crDefault;
          Exit;
        end;
        FNoteMovePending := False;
        Screen.Cursor := crDefault;
        Img.Cursor := crDefault;
        if FCore.DevicePointToPage(Img.Tag, Img.Width, Img.Height, X, Y, PX, PY) and
           (Img.Tag = FNoteSelected.PageIndex) then
          if FCore.ChangeNote(FNoteSelected, '', PX, PY, True) then
          begin
            RefreshTextPage(Img.Tag);
            UpdateSaveState;
          end;
        Exit;
      end;
      if NoteAtPoint(Img, X, Y, FNoteSelected) then Exit;
      if FNoteMode then
      begin
        if not CanModifyComments then Exit;
        FormValue := '';
        if NoteDialog(FormValue) and
           FCore.DevicePointToPage(Img.Tag, Img.Width, Img.Height, X, Y, PX, PY) then
          if FCore.AddNote(Img.Tag, PX, PY, FormValue) then
            RefreshTextPage(Img.Tag);
        Exit;
      end;
    end;
  end;
  if (Button = mbLeft) and FTextInsertMode and (Sender is TPDFiumImage) and
     (FCore <> nil) and (FCore.PageCount > 0) then
  begin
    // Direkt auf der PDF-Seite schreiben, ohne vorgeschalteten Dialog.
    if FTextEditor <> nil then FinishTextEditor(True);
    Img := TPDFiumImage(Sender);
    if not FCore.DevicePointToPage(Img.Tag, Img.Width, Img.Height, X, Y, PX, PY) then Exit;
    FTextEditorImage := Img;
    FTextEditorPage := Img.Tag;
    FTextEditorX := PX;
    FTextEditorY := PY;
    TextStyleChange(nil);
    FTextEditor := TEdit.Create(Self);
    FTextEditor.Parent := Img.Parent;
    FTextEditor.AutoSize := False;
    FTextEditor.Font.Name := FTextFontSelect.Text;
    FTextEditor.Font.Size := FTextInsertSize;
    FTextEditor.Font.Color := FTextInsertColor;
    FTextEditor.SetBounds(Img.Left + X, Img.Top + Y - FTextEditor.Height + 4,
      Max(180, Min(400, Img.Width - X)), Max(28, FTextEditor.Height));
    UpdateTextEditorHeight;
    FTextEditor.OnKeyDown := TextEditorKeyDown;
    FTextEditor.OnMouseDown := TextEditorMouseDown;
    FTextEditor.OnMouseMove := TextEditorMouseMove;
    FTextEditor.OnMouseUp := TextEditorMouseUp;
    FTextEditor.Hint := Tr('Enter: Text einfügen | Esc: Abbrechen') + ' | ' +
      Tr('Strg + Ziehen: Position ändern');
    FTextEditor.ShowHint := True;
    FTextResizeGrip := TPanel.Create(Self);
    FTextResizeGrip.Parent := Img.Parent;
    FTextResizeGrip.Width := 14;
    FTextResizeGrip.Height := 14;
    FTextResizeGrip.Caption := '◢';
    FTextResizeGrip.BevelOuter := bvNone;
    FTextResizeGrip.Cursor := crSizeNWSE;
    FTextResizeGrip.Hint := ToolbarHint('Ziehen: Eingabefeld in Breite und Höhe ändern',
      'Drag: resize text input width and height');
    FTextResizeGrip.ShowHint := True;
    FTextResizeGrip.OnMouseDown := TextResizeMouseDown;
    FTextResizeGrip.OnMouseMove := TextResizeMouseMove;
    FTextResizeGrip.OnMouseUp := TextResizeMouseUp;
    PositionTextResizeGrip;
    FTextEditor.BringToFront;
    FTextResizeGrip.BringToFront;
    FTextEditor.SetFocus;
    Exit;
  end;
  if (Button <> mbLeft) or (FCore.PageCount = 0) then Exit;
  if FHighlightMode and not (FEditVisible and (FShapeSelect <> nil) and
     (FShapeSelect.ItemIndex in [5, 6])) then
  begin
    FSelAnchorChar := SelectionHit(Sender, X, Y);
    if (ssShift in Shift) or (FSelAnchorChar < 0) then
    begin
      // Ohne PDF-Text (z.B. gescannte Seiten) einen Bildbereich markieren.
      FHighlightAreaDragging := True;
      FHighlightAreaPage := TPDFiumImage(Sender).Tag;
      FHighlightAreaStartX := X;
      FHighlightAreaStartY := Y;
      FHighlightAreaEndX := X;
      FHighlightAreaEndY := Y;
      TPDFiumImage(Sender).Cursor := crCross;
      Screen.Cursor := crCross; // Fadenkreuz auch waehrend MouseCapture anzeigen
      TPDFiumImage(Sender).MouseCapture := True;
      Exit;
    end;
    FSelAnchorPage := TPDFiumImage(Sender).Tag;
    FSelFocusPage := FSelAnchorPage;
    FSelFocusChar := FSelAnchorChar;
    FSelecting := True;
    TPDFiumImage(Sender).MouseCapture := True;
    RefreshSelectedPages;
    Exit;
  end;
  // Doppelklick direkt beim zweiten MouseDown behandeln. Bei TImage
  // wird OnDblClick nicht in allen Konstellationen ausgeloest.
  if (ssDouble in Shift) and not FMarkMode and (Sender is TPDFiumImage) then
  begin
    ImageDblClick(Sender);
    Exit;
  end;
  // Ein Klick in die PDF entfernt vorhandene Suchmarkierungen.
  if Assigned(FOnPDFPageClick) then
    FOnPDFPageClick(Self);
  // Formular-Widgets haben Vorrang vor Hand-Werkzeug und Textauswahl.
  // Klick-Hit-Test als Grundlage fuer die naechste FormFill-Eingabestufe.
  if not FMarkMode and not (ssShift in Shift) and not (ssCtrl in Shift) and
     not (FEditVisible and (FShapeSelect.ItemIndex = 8)) and
     (Sender is TPDFiumImage) then
  begin
    Img := TPDFiumImage(Sender);
    if FCore.FormWidgetAtPoint(Img.Tag, Img.Width, Img.Height,
      X, Y, WidgetIndex) then
    begin
      FActiveFormWidgetPage := Img.Tag;
      FActiveFormWidgetIndex := WidgetIndex;
      UpdateFormFocusFrame;
      Img.Cursor := crIBeam;
      Img.Hint := Tr('PDF-Formularfeld: Text bearbeiten');
      if FCore.FormWidgetRequired(Img.Tag, WidgetIndex) then
        Img.Hint := Img.Hint + ' ' + Tr('(Pflichtfeld)');
      Img.ShowHint := True;
      // 3b.52: PDF-internen Schreibschutz respektieren. Ein gesperrtes
      // Feld darf weder per Mausklick noch per Dialog veraendert werden.
      if FCore.FormWidgetReadOnly(Img.Tag, WidgetIndex) then
      begin
        MessageDlg(Tr('Dieses PDF-Formularfeld ist schreibgeschützt.'),
          mtInformation, [mbOK], 0);
        Exit;
      end;
      // Patch 3b.6: Keine Optionsabfrage mit nil-Formhandle.
      // Diese lieferte fuer die verwendete PDFium-Version keine
      // verlaessliche Dropdown-Typunterscheidung und fuehrte zu
      // fehlenden Werten. Bis zur echten FormFill-Integration wird
      // das Dropdown wie zuvor ueber den Texteditor bearbeitet.
      // Auswahl-Widgets zuerst behandeln; Textfelder behalten den Editor.
      if FCore.ToggleFormWidgetChoice(Img.Tag, WidgetIndex) then
      begin
        // Wie beim Textfeld-Commit auch die Ergebnisse auf anderen
        // Seiten neu rendern; vorhandene Bitmaps bleiben sichtbar.
        for I := 0 to High(FLoadedPages) do
          FLoadedPages[I] := False;
        RenderVisiblePages;
        Exit;
      end;
      Options := TStringList.Create;
      try
        if FCore.FormWidgetOptions(Img.Tag, WidgetIndex, Options) then
        begin
          FieldType := 0;
          FieldFlags := 0;
          FCore.FormWidgetFieldInfo(Img.Tag, WidgetIndex,
            FieldType, FieldFlags);
          IsListBox := FieldType = 5;
          IsMultiSelect := IsListBox and ((FieldFlags and $200000) <> 0);
          OptionDlg := TForm.CreateNew(Self);
          try
            OptionDlg.Caption := Tr('PDF-Auswahlliste') +
              Format(' (%d)', [Options.Count]);
            OptionDlg.Position := poScreenCenter;
            OptionDlg.BorderStyle := bsDialog;
            // Patch 25m: Alle Dialogabmessungen einheitlich anhand der
            // aktuellen Monitor-DPI berechnen. Keine gemischten 96-DPI-
            // Pixelwerte mehr (4K/250 %: Buttons und Status ueberlappten).
            OptionDlg.Scaled := False;
            OptionDlg.Font.Assign(Self.Font);
            DialogDPI := Max(96, CurrentPPI);
            Margin := MulDiv(12, DialogDPI, 96);
            Gap := MulDiv(8, DialogDPI, 96);
            ButtonWidth := MulDiv(104, DialogDPI, 96);
            ButtonHeight := MulDiv(30, DialogDPI, 96);
            SearchHeight := MulDiv(28, DialogDPI, 96);
            FooterHeight := Max(ButtonHeight, MulDiv(24, DialogDPI, 96));
            RowHeight := Max(MulDiv(23, DialogDPI, 96),
              Abs(OptionDlg.Canvas.TextHeight('Ag')) + MulDiv(9, DialogDPI, 96));
            OptionWidth := MulDiv(440, DialogDPI, 96);
            for I := 0 to Options.Count - 1 do
              OptionWidth := Max(OptionWidth,
                OptionDlg.Canvas.TextWidth(Options[I]) + 4 * Margin);
            OptionWidth := Min(MulDiv(720, DialogDPI, 96), OptionWidth);
            ContentWidth := OptionWidth - 2 * Margin;
            ListHeight := RowHeight * Max(4, Min(12, Options.Count)) +
              MulDiv(6, DialogDPI, 96);
            OptionDlg.ClientWidth := OptionWidth;
            if IsMultiSelect then
              OptionDlg.ClientHeight := 2 * Margin + ListHeight + Gap + FooterHeight
            else
              OptionDlg.ClientHeight := 2 * Margin + SearchHeight + Gap +
                ListHeight + Gap + FooterHeight;
            FooterTop := OptionDlg.ClientHeight - Margin - FooterHeight;

            OptionList := TListBox.Create(OptionDlg);
            OptionList.Parent := OptionDlg;
            OptionList.Font.Assign(OptionDlg.Font);
            OptionList.ItemHeight := RowHeight;
            SearchEdit := TPDFOptionSearch.Create(OptionDlg);
            SearchEdit.Parent := OptionDlg;
            SearchEdit.Font.Assign(OptionDlg.Font);
            SearchEdit.SetBounds(Margin, Margin, ContentWidth, SearchHeight);
            SearchEdit.TextHint := Tr('Eintrag suchen ...');
            OptionList.SetBounds(Margin, Margin + SearchHeight + Gap,
              ContentWidth, ListHeight);
            OptionList.Items.Assign(Options);
            if IsMultiSelect then OptionList.MultiSelect := True;
            ResultLabel := TLabel.Create(OptionDlg);
            ResultLabel.Parent := OptionDlg;
            ResultLabel.Font.Assign(OptionDlg.Font);
            ResultLabel.AutoSize := False;
            ResultLabel.Layout := tlCenter;
            ResultLabel.SetBounds(Margin, FooterTop,
              ContentWidth - 2 * ButtonWidth - 3 * Gap, FooterHeight);
            if IsMultiSelect then
            begin
              // Filtern wuerde die PDFium-Optionsindizes verschieben.
              SearchEdit.Visible := False;
              OptionList.SetBounds(Margin, Margin, ContentWidth, ListHeight);
              ResultLabel.Caption := Format('%d %s',
                [Options.Count, Tr('Eintraege')]);
            end
            else
              SearchEdit.Setup(OptionList, Options, ResultLabel);
            if not IsMultiSelect then
              OptionList.OnDblClick := FormOptionDoubleClick;
            if IsMultiSelect then OptionDlg.ActiveControl := OptionList
            else OptionDlg.ActiveControl := SearchEdit;
            FormValue := '';
            if FCore.EditFormWidgetText(Img.Tag, WidgetIndex, FormValue) then
              OptionList.ItemIndex := OptionList.Items.IndexOf(FormValue);
            if OptionList.ItemIndex >= 0 then
              OptionList.TopIndex := OptionList.ItemIndex
            else if OptionList.Count > 0 then
              OptionList.ItemIndex := 0;
            OKButton := TButton.Create(OptionDlg);
            OKButton.Parent := OptionDlg;
            OKButton.Caption := 'OK';
            OKButton.ModalResult := mrOk;
            OKButton.Default := True;
            OKButton.SetBounds(OptionWidth - Margin - 2 * ButtonWidth - Gap,
              FooterTop, ButtonWidth, ButtonHeight);
            CancelButton := TButton.Create(OptionDlg);
            CancelButton.Parent := OptionDlg;
            CancelButton.Caption := Tr('Abbrechen');
            CancelButton.ModalResult := mrCancel;
            CancelButton.Cancel := True;
            CancelButton.SetBounds(OptionWidth - Margin - ButtonWidth,
              FooterTop, ButtonWidth, ButtonHeight);
            if OptionDlg.ShowModal = mrOk then
            begin
              if IsMultiSelect then
              begin
                SelectedCount := 0;
                SetLength(SelectedIndices, OptionList.Count);
                for I := 0 to OptionList.Count - 1 do
                  if OptionList.Selected[I] then
                  begin
                    SelectedIndices[SelectedCount] := I;
                    Inc(SelectedCount);
                  end;
                SetLength(SelectedIndices, SelectedCount);
                if SelectedCount = 0 then Exit;
              end
              else
              begin
                if OptionList.ItemIndex < 0 then Exit;
                if OptionList.Items[OptionList.ItemIndex] = FormValue then Exit;
                SetLength(SelectedIndices, 1);
                SelectedIndices[0] := OptionList.ItemIndex;
              end;
              if (IsListBox and FCore.SetFormWidgetSelectedIndices(
                    Img.Tag, WidgetIndex, SelectedIndices)) or
                 ((not IsListBox) and FCore.SetFormWidgetText(
                    Img.Tag, WidgetIndex,
                    OptionList.Items[OptionList.ItemIndex])) then
              begin
                if (Img.Tag >= 0) and (Img.Tag < Length(FLoadedPages)) then
                  FLoadedPages[Img.Tag] := False;
                RenderVisiblePages;
              end
              else
                MessageDlg(Tr('Die Dropdown-Auswahl konnte nicht gespeichert werden.'),
                  mtWarning, [mbOK], 0);
            end;
          finally
            OptionDlg.Free;
          end;
          Exit;
        end;
      finally
        Options.Free;
      end;
      BeginInlineFormEdit(Img.Tag, WidgetIndex);
      Exit;
    end;
  end;

  if not (ssShift in Shift) and not (ssCtrl in Shift) and
     not (FEditVisible and (FShapeSelect.ItemIndex in [6, 8])) and
     LinkAtImagePoint(Sender, X, Y, Target) then
  begin
    if Target.PageIndex >= 0 then
      ShowPage(Target.PageIndex)
    else
    begin
      URL := LowerCase(Target.URI);
      if URL.StartsWith('https://') or URL.StartsWith('http://') or
         URL.StartsWith('mailto:') then
        ShellExecute(0, 'open', PChar(Target.URI), nil, nil, SW_SHOWNORMAL);
    end;
    Exit;
  end;
  // Hand-Werkzeug: ausschliesslich bei linker Maustaste verschieben.
  // Die vorhandene Alt-Ziehen-Funktion bleibt unveraendert.
  if (Button = mbLeft) and FEditVisible and
     (FShapeSelect <> nil) and (FShapeSelect.ItemIndex = 8) then
  begin
    if (FScroll.HorzScrollBar.Range <= FScroll.ClientWidth) and
       (FScroll.VertScrollBar.Range <= FScroll.ClientHeight) then Exit;
    FDraggingPage := True;
    FDragStartScreen := Mouse.CursorPos;
    FDragStartHorz := FScroll.HorzScrollBar.Position;
    FDragStartVert := FScroll.VertScrollBar.Position;
    TPDFiumImage(Sender).MouseCapture := True;
    TPDFiumImage(Sender).Cursor := crSizeAll;
    Screen.Cursor := crSizeAll;
    Exit;
  end;
  // Ein einfacher Klick ausserhalb der bestehenden Textauswahl hebt sie auf.
  // Klicks innerhalb der Auswahl behalten sie fuer Kopieren/Kontextmenue bei.
  if (Button = mbLeft) and (FSelAnchorPage >= 0) and
     (FSelFocusPage >= 0) and not (ssShift in Shift) and
     not (ssCtrl in Shift) and not (ssAlt in Shift) then
  begin
    I := SelectionHit(Sender, X, Y);
    if (TPDFiumImage(Sender).Tag < Min(FSelAnchorPage, FSelFocusPage)) or
       (TPDFiumImage(Sender).Tag > Max(FSelAnchorPage, FSelFocusPage)) or
       (I < 0) or
       ((FSelAnchorPage = FSelFocusPage) and
        ((I < Min(FSelAnchorChar, FSelFocusChar)) or
         (I > Max(FSelAnchorChar, FSelFocusChar)))) then
    begin
      FSelecting := False;
      FSelAnchorPage := -1;
      FSelFocusPage := -1;
      FSelAnchorChar := -1;
      FSelFocusChar := -1;
      RefreshSelectedPages;
      Exit;
    end;
  end;
  // Standard: Text mit linker Maustaste markieren.
  // Bisheriges Verschieben bleibt mit Alt + Ziehen erreichbar.
  if not FMarkMode and (ssAlt in Shift) and
     ((FScroll.HorzScrollBar.Range > FScroll.ClientWidth) or
      (FScroll.VertScrollBar.Range > FScroll.ClientHeight)) then
  begin
    FDraggingPage := True;
    FDragStartScreen := Mouse.CursorPos;
    FDragStartHorz := FScroll.HorzScrollBar.Position;
    FDragStartVert := FScroll.VertScrollBar.Position;
    TPDFiumImage(Sender).MouseCapture := True;
    TPDFiumImage(Sender).Cursor := crHandPoint;
    Exit;
  end;
  if not FMarkMode then
  begin
    FSelAnchorChar := SelectionHit(Sender, X, Y);
    if FSelAnchorChar < 0 then Exit;
    FSelAnchorPage := TPDFiumImage(Sender).Tag;
    FSelFocusPage := FSelAnchorPage;
    FSelFocusChar := FSelAnchorChar;
    FSelecting := True;
    if FScroll.CanFocus then FScroll.SetFocus;
    TPDFiumImage(Sender).MouseCapture := True;
    RefreshSelectedPages;
    Exit;
  end;
  FreeAndNil(FCurrentStroke);
  FStrokePage := TPDFiumImage(Sender).Tag;
  FPage := FStrokePage;
  // Beim Start einer Schwaerzung keine Miniatur-/Seitenleistenaktualisierung:
  // sie kann vor dem ersten sichtbaren Rechteck spuerbar blockieren.
  if not (FShapeSelect.ItemIndex in [5, 6]) then
    UpdateVisiblePage;
  FCurrentStroke := TPDFInkStroke.Create;
  FCurrentStroke.IsCover := FShapeSelect.ItemIndex in [5, 6];
  if FCurrentStroke.IsCover then
    FCurrentStroke.StrokeColor := clBlack
  else
    FCurrentStroke.StrokeColor := FMarkColor;
  case FWidthSelect.ItemIndex of
    0: FCurrentStroke.LineWidth := 1;
    1: FCurrentStroke.LineWidth := 2;
    2: FCurrentStroke.LineWidth := 3;
    3: FCurrentStroke.LineWidth := 5;
    4: FCurrentStroke.LineWidth := 8;
    5: FCurrentStroke.LineWidth := 12;
  else
    FCurrentStroke.LineWidth := 5;
  end;
  FShapeStart := Point(X, Y);
  FPreviewLastRectValid := False;
  FreeAndNil(FPreviewBitmap);
  if not FCurrentStroke.IsCover then
  begin
  FPreviewBitmap := TBitmap.Create;
  // Bitmap-Daten direkt kopieren, ohne Assign/Formatkonvertierung.
  // Die Kopie bleibt notwendig, um das alte Live-Rechteck zu restaurieren.
  with TPDFiumImage(Sender).Picture.Bitmap do
  begin
    FPreviewBitmap.PixelFormat := PixelFormat;
    FPreviewBitmap.SetSize(Width, Height);
    BitBlt(FPreviewBitmap.Canvas.Handle, 0, 0, Width, Height,
      Canvas.Handle, 0, 0, SRCCOPY);
  end;
  end;
  AppendPoint(X, Y);
  if FCurrentStroke.IsCover then
  begin
    // Gleicher schneller Auswahlrahmen wie bei "Text hervorheben".
    // Erst nach MouseUp wird das Rechteck schwarz ausgefuellt.
    FHighlightAreaDragging := True;
    FHighlightAreaPage := FStrokePage;
    FHighlightAreaStartX := X;
    FHighlightAreaStartY := Y;
    FHighlightAreaEndX := X;
    FHighlightAreaEndY := Y;
  end;
  // Mausereignisse auch beim Ziehen ausserhalb des Bildes erhalten.
  TPDFiumImage(Sender).MouseCapture := True;
  if not FCurrentStroke.IsCover then
    DrawLivePreview;
end;

// Doppelklick waehlt das ganze Wort unter dem Mauszeiger aus.
// Verwendet ausschliesslich die vorhandene PDFium-Textebene und
// die bestehende Auswahl-/Kopierfunktion.
procedure TFreePDF64PDFiumView.ImageDblClick(Sender: TObject);
var
  Img: TPDFiumImage;
  P: TPoint;
  PageIndex, Hit, FirstChar, LastChar, CharCount: Integer;
  Ch: string;

  function IsWordChar(AIndex: Integer): Boolean;
  var
    C: Char;
  begin
    Result := False;
    if (AIndex < 0) or (AIndex >= CharCount) then Exit;
    Ch := FCore.TextRange(PageIndex, AIndex, 1);
    if Ch = '' then Exit;
    C := Ch[1];
    Result := TCharacter.IsLetterOrDigit(C) or (C = '_');
  end;

begin
  if FMarkMode or FDraggingPage or (FCore = nil) or
     not (Sender is TPDFiumImage) then Exit;
  Img := TPDFiumImage(Sender);
  PageIndex := Img.Tag;
  if (PageIndex < 0) or (PageIndex >= FCore.PageCount) then Exit;
  P := Img.ScreenToClient(Mouse.CursorPos);
  Hit := SelectionHit(Img, P.X, P.Y);
  CharCount := FCore.TextCharCount(PageIndex);
  if (Hit < 0) or (Hit >= CharCount) or not IsWordChar(Hit) then Exit;

  FirstChar := Hit;
  while (FirstChar > 0) and IsWordChar(FirstChar - 1) do
    Dec(FirstChar);
  LastChar := Hit;
  while (LastChar + 1 < CharCount) and IsWordChar(LastChar + 1) do
    Inc(LastChar);

  FSelecting := False;
  Img.MouseCapture := False;
  FSelAnchorPage := PageIndex;
  FSelFocusPage := PageIndex;
  FSelAnchorChar := FirstChar;
  FSelFocusChar := LastChar;
  if FScroll.CanFocus then FScroll.SetFocus;
  RefreshSelectedPages;
end;

procedure TFreePDF64PDFiumView.ImageMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  HoverNote: TPDFNote;
  Target: TPDFLinkTarget;
  CurrentScreen: TPoint;
begin
  if FSignatureMode then
  begin
    if Sender is TPDFiumImage then
    begin
      var SigImg := TPDFiumImage(Sender);
      if FSignaturePlaced then
      begin
        if SigImg.Tag <> FSignaturePreviewPage then Exit;
        // Cursor bereits beim Ueberfahren der vier Skalierungsgriffe anzeigen.
        // Waehrend des Ziehens bleibt die Richtung des aktiven Griffs erhalten.
        if FSignatureResizing then
        begin
          if FSignatureResizeCorner in [1, 4] then
            SigImg.Cursor := crSizeNWSE
          else
            SigImg.Cursor := crSizeNESW;
        end
        else if FSignatureDragging then
          SigImg.Cursor := crSizeAll
        else if (((Abs(X-FSignatureRect.Left) <= 12) and
                  (Abs(Y-FSignatureRect.Top) <= 12)) or
                 ((Abs(X-FSignatureRect.Right) <= 12) and
                  (Abs(Y-FSignatureRect.Bottom) <= 12))) then
          SigImg.Cursor := crSizeNWSE
        else if (((Abs(X-FSignatureRect.Right) <= 12) and
                  (Abs(Y-FSignatureRect.Top) <= 12)) or
                 ((Abs(X-FSignatureRect.Left) <= 12) and
                  (Abs(Y-FSignatureRect.Bottom) <= 12))) then
          SigImg.Cursor := crSizeNESW
        else if PtInRect(FSignatureRect, Point(X,Y)) then
          SigImg.Cursor := crSizeAll
        else
          SigImg.Cursor := crDefault;
        if FSignatureDragging then
        begin
          var DX := X-FSignatureDragOrigin.X;
          var DY := Y-FSignatureDragOrigin.Y;
          var RW := FSignatureRectOrigin.Right-FSignatureRectOrigin.Left;
          var RH := FSignatureRectOrigin.Bottom-FSignatureRectOrigin.Top;
          var LX := EnsureRange(FSignatureRectOrigin.Left+DX,0,Max(0,SigImg.Width-RW));
          var TY := EnsureRange(FSignatureRectOrigin.Top+DY,0,Max(0,SigImg.Height-RH));
          FSignatureRect := Rect(LX,TY,LX+RW,TY+RH);
        end
        else if FSignatureResizing then
        begin
          var RW := Max(12,FSignatureRectOrigin.Right-FSignatureRectOrigin.Left);
          var RH := Max(12,FSignatureRectOrigin.Bottom-FSignatureRectOrigin.Top);
          var DX := X-FSignatureDragOrigin.X;
          var DY := Y-FSignatureDragOrigin.Y;
          var AnchorX, AnchorY, MaxW, NewW, NewH: Integer;
          // Die jeweils gegenüberliegende Ecke bleibt beim Skalieren stehen.
          if FSignatureResizeCorner in [1,3] then
            AnchorX := FSignatureRectOrigin.Right
          else
            AnchorX := FSignatureRectOrigin.Left;
          if FSignatureResizeCorner in [1,2] then
            AnchorY := FSignatureRectOrigin.Bottom
          else
            AnchorY := FSignatureRectOrigin.Top;
          if FSignatureResizeCorner in [1,3] then
            NewW := RW-DX
          else
            NewW := RW+DX;
          if FSignatureResizeCorner in [1,3] then
            MaxW := AnchorX
          else
            MaxW := SigImg.Width-AnchorX;
          if FSignatureResizeCorner in [1,2] then
            MaxW := Min(MaxW, MulDiv(AnchorY,RW,RH))
          else
            MaxW := Min(MaxW, MulDiv(SigImg.Height-AnchorY,RW,RH));
          NewW := EnsureRange(NewW, 12, Max(12,MaxW));
          NewH := Max(12,MulDiv(NewW,RH,RW));
          if FSignatureResizeCorner = 1 then
            FSignatureRect := Rect(AnchorX-NewW,AnchorY-NewH,AnchorX,AnchorY)
          else if FSignatureResizeCorner = 2 then
            FSignatureRect := Rect(AnchorX,AnchorY-NewH,AnchorX+NewW,AnchorY)
          else if FSignatureResizeCorner = 3 then
            FSignatureRect := Rect(AnchorX-NewW,AnchorY,AnchorX,AnchorY+NewH)
          else
            FSignatureRect := Rect(AnchorX,AnchorY,AnchorX+NewW,AnchorY+NewH);
        end;
      end
      else
      begin
        SigImg.Cursor := crCross;
        FSignaturePreviewPoint := Point(X,Y);
        FSignaturePreviewPage := SigImg.Tag;
        FSignaturePreviewVisible := True;
      end;
      // Beim Start des Signaturmodus wird Screen.Cursor auf crCross
      // gesetzt. Ohne diese Aktualisierung verdeckt der globale
      // Mauszeiger die lokalen Resize-/Move-Cursor des PDF-Bildes.
      Screen.Cursor := SigImg.Cursor;
      SigImg.Invalidate;
    end;
    Exit;
  end;
  if FMeasureMode and (Sender is TPDFiumImage) then
  begin
    TPDFiumImage(Sender).Cursor := crCross;
    if FMeasureDragging and (TPDFiumImage(Sender).Tag = FMeasurePage) then
    begin
      if (FMeasureEnd.X <> X) or (FMeasureEnd.Y <> Y) then
      begin
        FMeasureEnd := Point(X, Y);
        // Vollständiges synchrones Zeichnen der PDF-Bitmap und danach
        // des Messrahmens verhindert ruckelnde, verspätete Overlays.
        TPDFiumImage(Sender).Repaint;
      end;
    end;
    Exit;
  end;
  if FEditVisible and (FShapeSelect <> nil) and
     (FShapeSelect.ItemIndex = 8) and (Sender is TPDFiumImage) and
     not FDraggingPage then
  begin
    TPDFiumImage(Sender).Cursor := crHandPoint;
    Screen.Cursor := crHandPoint;
    Exit;
  end;
  if FLinkMovePending and (Sender is TPDFiumImage) then
  begin
    FLinkMoveEnd := Point(X, Y);
    TPDFiumImage(Sender).Cursor := crSizeAll;
    Exit;
  end;
  if FLinkMode and (Sender is TPDFiumImage) and not FHighlightAreaDragging then
  begin
    TPDFiumImage(Sender).Cursor := crCross;
    Exit;
  end;
  if (Sender is TPDFiumImage) and FNoteMovePending then
  begin
    TPDFiumImage(Sender).Cursor := crCross;
    Exit;
  end;
  if (Sender is TPDFiumImage) and (FCore <> nil) then
  begin
    if NoteAtPoint(TPDFiumImage(Sender), X, Y, HoverNote) then
    begin
      TPDFiumImage(Sender).Cursor := crHandPoint;
      TPDFiumImage(Sender).Hint := HoverNote.Contents;
      TPDFiumImage(Sender).ShowHint := True;
      Exit;
    end;
    TPDFiumImage(Sender).Hint := '';
    TPDFiumImage(Sender).ShowHint := False;
  end;
  if FDraggingPage then
  begin
    if not (ssLeft in Shift) then Exit;
    CurrentScreen := Mouse.CursorPos;
    FScroll.HorzScrollBar.Position := Max(0,
      FDragStartHorz - (CurrentScreen.X - FDragStartScreen.X));
    FScroll.VertScrollBar.Position := Max(0,
      FDragStartVert - (CurrentScreen.Y - FDragStartScreen.Y));
    FLastScrollPosition := FScroll.VertScrollBar.Position;
    FScrollRenderPending := True;
    TPDFiumImage(Sender).Cursor := crSizeAll;
    Screen.Cursor := crSizeAll;
    Exit;
  end;
  if FHighlightAreaDragging then
  begin
    if (Sender is TPDFiumImage) and
       (TPDFiumImage(Sender).Tag = FHighlightAreaPage) then
    begin
      if (FHighlightAreaEndX <> X) or (FHighlightAreaEndY <> Y) then
      begin
        // Zuerst die Koordinaten aktualisieren, dann das Seitenbild
        // einschliesslich der PDF-Bitmap und des Rahmens neu zeichnen.
        // Das partielle Invalidieren des Parent-Fensters hinterliess
        // alte Rahmenfragmente ("Straehnen") auf TGraphicControl/TImage.
        FHighlightAreaEndX := X;
        FHighlightAreaEndY := Y;
        TPDFiumImage(Sender).Repaint;
      end;
    end;
    Screen.Cursor := crCross;
    TPDFiumImage(Sender).Cursor := crCross;
    Exit;
  end;
  // Umschalt signalisiert die freie Rechteckauswahl bereits vor dem Ziehen.
  if FHighlightMode and (ssShift in Shift) then
  begin
    TPDFiumImage(Sender).Cursor := crCross;
    Exit;
  end;
  if (not (ssLeft in Shift)) and LinkAtImagePoint(Sender, X, Y, Target) then
  begin
    TPDFiumImage(Sender).Cursor := crHandPoint;
    if Target.URI <> '' then
      TPDFiumImage(Sender).Hint := Target.URI
    else if Target.PageIndex >= 0 then
      TPDFiumImage(Sender).Hint := ToolbarHint('Seite ', 'Page ') +
        IntToStr(Target.PageIndex + 1)
    else
      TPDFiumImage(Sender).Hint := '';
    TPDFiumImage(Sender).ShowHint := TPDFiumImage(Sender).Hint <> '';
  end
  else
  begin
    TPDFiumImage(Sender).Cursor := crDefault;
    TPDFiumImage(Sender).Hint := '';
    TPDFiumImage(Sender).ShowHint := False;
  end;
  if FSelecting then
  begin
    if not (ssLeft in Shift) then Exit;
    // Bei gedrueckter Maustaste bleibt die Auswahl auch ausserhalb des Bildes aktiv.
    if SelectionHit(Sender, X, Y) >= 0 then
    begin
      if FHighlightMode and (TPDFiumImage(Sender).Tag <> FSelAnchorPage) then Exit;
      FSelFocusPage := TPDFiumImage(Sender).Tag;
      if FSelFocusChar <> SelectionHit(Sender, X, Y) then
      begin
        FSelFocusChar := SelectionHit(Sender, X, Y);
        RefreshSelectedPages;
      end;
    end;
    Exit;
  end;
  // Laufende Rechteckzeichnung hat Vorrang vor dem Werkzeug-Cursor.
  // Andernfalls verhindert das fruehe Exit die sichtbare Live-Vorschau.
  if (FCurrentStroke = nil) or not (ssLeft in Shift) then
  begin
    // Fadenkreuz nur waehrend des Aufziehens anzeigen.
    // Nach MouseUp darf MouseMove den normalen Cursor nicht ueberschreiben.
    Exit;
  end;
  if FShapeSelect.ItemIndex in [5, 6] then
  begin
    TPDFiumImage(Sender).Cursor := crCross;
    Screen.Cursor := crCross;
  end;
  if FShapeSelect.ItemIndex = 0 then
    AppendPoint(X, Y)
  else
    UpdateShapeStroke(X, Y);
  DrawLivePreview;
end;

procedure TFreePDF64PDFiumView.ImageMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  StartChar, EndChar, Pg: Integer;
  AX1, AY1, AX2, AY2: Double;
  LinkURL, LinkCaption: string;
  TextX, TextY, TextWidth: Double;
  LinkTextBounds: TPDFInkRect;
begin
  if FSignatureMode and (Sender is TPDFiumImage) then
  begin
    FSignatureDragging := False;
    FSignatureResizing := False;
    FSignatureResizeCorner := 0;
    TPDFiumImage(Sender).MouseCapture := False;
    // Nach dem Loslassen wird der Cursor bei der nächsten Bewegung
    // anhand der tatsächlichen Position neu bestimmt.
    Screen.Cursor := TPDFiumImage(Sender).Cursor;
    Exit;
  end;
  if FMeasureMode and (Sender is TPDFiumImage) then
  begin
    if (Button = mbLeft) and FMeasureDragging then
    begin
      FMeasureDragging := False;
      FMeasureEnd := Point(X, Y);
      if (FCore <> nil) and
         ((Abs(FMeasureStart.X - X) > 2) or
          (Abs(FMeasureStart.Y - Y) > 2)) and
         FCore.DevicePointToPage(TPDFiumImage(Sender).Tag,
           TPDFiumImage(Sender).Width, TPDFiumImage(Sender).Height,
           FMeasureStart.X, FMeasureStart.Y, AX1, AY1) and
         FCore.DevicePointToPage(TPDFiumImage(Sender).Tag,
           TPDFiumImage(Sender).Width, TPDFiumImage(Sender).Height,
           X, Y, AX2, AY2) then
      begin
        var M: TPDFMeasureRect;
        M.Page := TPDFiumImage(Sender).Tag;
        M.X1 := AX1; M.Y1 := AY1;
        M.X2 := AX2; M.Y2 := AY2;
        M.Scale := FMeasureScale;
        M.UnitIndex := FMeasureUnit;
        RecordMeasureAction(M, FMeasureRects.Count, False);
        FMeasureRects.Add(M);
        UpdateTextUndoButtons;
        UpdateSaveState;
      end;
      FMeasurePage := -1;
      TPDFiumImage(Sender).MouseCapture := False;
      // Die fertige Messung bleibt nach Loslassen sichtbar.
      TPDFiumImage(Sender).Repaint;
    end;
    Exit;
  end;
  if FLinkMovePending then
  begin
    FLinkMovePending := False;
    if Sender is TPDFiumImage then
    begin
      TPDFiumImage(Sender).MouseCapture := False;
      TPDFiumImage(Sender).Cursor := crDefault;
      if (FCore <> nil) and
         (TPDFiumImage(Sender).Tag = FLinkMovePage) and
         ((Abs(X - FLinkMoveStart.X) > 1) or
          (Abs(Y - FLinkMoveStart.Y) > 1)) and
         FCore.DevicePointToPage(FLinkMovePage,
           TPDFiumImage(Sender).Width, TPDFiumImage(Sender).Height,
           FLinkMoveStart.X, FLinkMoveStart.Y, AX1, AY1) and
         FCore.DevicePointToPage(FLinkMovePage,
           TPDFiumImage(Sender).Width, TPDFiumImage(Sender).Height,
           X, Y, AX2, AY2) then
      begin
        if FCore.MoveLinkAtPoint(FLinkMovePage, AX1, AY1,
          AX2 - AX1, AY2 - AY1) then
          RefreshTextPage(FLinkMovePage);
      end;
    end;
    Exit;
  end;
  if FDraggingPage then
  begin
    FDraggingPage := False;
    TPDFiumImage(Sender).MouseCapture := False;
    if FEditVisible and (FShapeSelect <> nil) and
       (FShapeSelect.ItemIndex = 8) then
      TPDFiumImage(Sender).Cursor := crHandPoint
    else
      TPDFiumImage(Sender).Cursor := crDefault;
    Screen.Cursor := TPDFiumImage(Sender).Cursor;
    Exit;
  end;
  // Die Schwärzungswerkzeuge nutzen den flüssigen Auswahlrahmen nur
  // während des Ziehens. Die eigentliche Schwärzung erfolgt weiter unten.
  if FHighlightAreaDragging and (FCurrentStroke <> nil) and
     FCurrentStroke.IsCover then
  begin
    FHighlightAreaDragging := False;
    TPDFiumImage(Sender).Invalidate;
  end;
  if FHighlightAreaDragging then
  begin
    FHighlightAreaDragging := False;
    TPDFiumImage(Sender).Invalidate; // Vorschau entfernen
    Screen.Cursor := crDefault;
    TPDFiumImage(Sender).Cursor := crDefault;
    TPDFiumImage(Sender).MouseCapture := False;
    Pg := FHighlightAreaPage;
    if FLinkMode then
    begin
      try
        if (Pg = TPDFiumImage(Sender).Tag) and
           (Abs(X - FHighlightAreaStartX) >= 4) and
           (Abs(Y - FHighlightAreaStartY) >= 4) then
        begin
          if FCore.DevicePointToPage(Pg, TPDFiumImage(Sender).Width,
               TPDFiumImage(Sender).Height, FHighlightAreaStartX,
               FHighlightAreaStartY, AX1, AY1) and
             FCore.DevicePointToPage(Pg, TPDFiumImage(Sender).Width,
               TPDFiumImage(Sender).Height, X, Y, AX2, AY2) then
          begin
            LinkCaption := '';
            LinkURL := 'https://';
            if AskHyperlinkDetails(Self, PDFLanguage = 'en',
              LinkCaption, LinkURL) then
            begin
              if (Pos('@', LinkURL) > 0) and (Pos(':', LinkURL) = 0) then
                LinkURL := 'mailto:' + LinkURL;
              if (Pos('https://', LowerCase(LinkURL)) = 1) or
                 (Pos('http://', LowerCase(LinkURL)) = 1) or
                 (Pos('mailto:', LowerCase(LinkURL)) = 1) then
              begin
                TextX := Min(AX1, AX2) + 2;
                TextY := Min(AY1, AY2) + 4;
                TextWidth := Max(2, Abs(AX2 - AX1) - 4);
                // Linkbereich an den tatsächlichen PDFium-Textgrenzen ausrichten,
                // nicht an der mit der Maus aufgezogenen Auswahl.
                if FCore.InsertVisibleLinkText(Pg, TextX, TextY, TextWidth,
                     LinkCaption, LinkTextBounds) and
                   FCore.AddURILink(Pg, LinkTextBounds.Left - 1,
                     LinkTextBounds.Bottom - 2, LinkTextBounds.Right + 1,
                     LinkTextBounds.Top + 2, LinkURL) then
                  begin
                    RefreshTextPage(Pg);
                    if not FEditVisible then
                    begin
                      ToggleEditBar(nil);
                      FMarkMode := False;
                    end;
                  end
                else
                  PDFModernMessageDlg(ToolbarHint('Hyperlink konnte nicht eingefügt werden.',
                    'Could not insert hyperlink.'), mtError, [mbOK], 0);
              end
              else
                PDFModernMessageDlg(ToolbarHint('Bitte http://, https:// oder eine E-Mail-Adresse eingeben.',
                  'Enter http://, https:// or an email address.'), mtWarning, [mbOK], 0);
            end;
          end;
        end;
      finally
        FLinkMode := False;
        Screen.Cursor := crDefault;
        if Sender is TPDFiumImage then
          TPDFiumImage(Sender).Cursor := crDefault;
        if FImage <> nil then FImage.Cursor := crDefault;
      end;
      Exit;
    end;
    try
      if (Pg = TPDFiumImage(Sender).Tag) and
         FCore.DevicePointToPage(Pg, TPDFiumImage(Sender).Width,
           TPDFiumImage(Sender).Height, FHighlightAreaStartX,
           FHighlightAreaStartY, AX1, AY1) and
         FCore.DevicePointToPage(Pg, TPDFiumImage(Sender).Width,
           TPDFiumImage(Sender).Height, X, Y, AX2, AY2) then
        if FCore.HighlightArea(Pg, AX1, AY1, AX2, AY2, FMarkColor) then
          RefreshTextPage(Pg);
    except
      on E: Exception do PDFModernMessageDlg(E.Message, mtError, [mbOK], 0);
    end;
    Exit;
  end;
  if FSelecting then
  begin
    FSelecting := False;
    TPDFiumImage(Sender).MouseCapture := False;
    if FHighlightMode and (FSelAnchorPage = FSelFocusPage) and
       (FSelAnchorChar >= 0) and (FSelFocusChar >= 0) then
    begin
      Pg := FSelAnchorPage;
      StartChar := Min(FSelAnchorChar, FSelFocusChar);
      EndChar := Max(FSelAnchorChar, FSelFocusChar);
      try
        if FCore.HighlightText(Pg, StartChar, EndChar - StartChar + 1, FMarkColor) then
        begin
          RefreshTextPage(Pg);
          if (Pg >= 0) and (Pg < Length(FLoadedPages)) and FLoadedPages[Pg] then
            PageImage(Pg).Repaint;
        end;
      except
        on E: Exception do PDFModernMessageDlg(E.Message, mtError, [mbOK], 0);
      end;
      FSelAnchorPage := -1;
      FSelFocusPage := -1;
      RefreshSelectedPages;
    end;
    Exit;
  end;
  if FCurrentStroke = nil then Exit;
  TPDFiumImage(Sender).MouseCapture := False;
  if FShapeSelect.ItemIndex <> 0 then
    UpdateShapeStroke(X, Y)
  else
    AppendPoint(X, Y);
  FreeAndNil(FPreviewBitmap);
  FPreviewLastRectValid := False;
  // Nach dem Loslassen wieder den normalen Mauszeiger verwenden.
  if FShapeSelect.ItemIndex in [5, 6] then
  begin
    Screen.Cursor := crDefault;
    TPDFiumImage(Sender).Cursor := crDefault;
    if FImage <> nil then FImage.Cursor := crDefault;
  end;
  if (FShapeSelect.ItemIndex = 6) then
  begin
    if (FCurrentStroke.Count >= 2) and
       ((Abs(FShapeStart.X - X) >= 4) or (Abs(FShapeStart.Y - Y) >= 4)) then
    begin
      // Ausdruecklich nur eine nicht persistente Vorschau.
      // Keine PDF-Speicherung und keine optische Pseudo-Schwaerzung.
      ClearRedactionRedo;
      FRedactionPreviewPages.Add(FStrokePage);
      FRedactionPreviews.Add(FCurrentStroke);
      UpdateTextUndoButtons;
      FCurrentStroke := nil;
    end
    else
      FreeAndNil(FCurrentStroke);
    if (FStrokePage >= 0) and (FStrokePage < Length(FLoadedPages)) and
       FLoadedPages[FStrokePage] then
    begin
      FCore.RenderPage(FStrokePage, PageImage(FStrokePage).Picture.Bitmap,
        PageImage(FStrokePage).Width, PageImage(FStrokePage).Height);
      DrawPageStrokes(FStrokePage);
    end;
    Exit;
  end;
  if FCurrentStroke.Count >= 2 then
  begin
    ClearStrokeRedo;
    FCore.AddStroke(FStrokePage, FCurrentStroke);
    FCurrentStroke := nil;
    UpdateTextUndoButtons;
  end
  else FreeAndNil(FCurrentStroke);
  if (FStrokePage >= 0) and (FStrokePage < Length(FLoadedPages)) and
     FLoadedPages[FStrokePage] then
  begin
    FCore.RenderPage(FStrokePage, PageImage(FStrokePage).Picture.Bitmap,
      PageImage(FStrokePage).Width, PageImage(FStrokePage).Height);
    DrawPageStrokes(FStrokePage);
  end;
end;

procedure TFreePDF64PDFiumView.DrawPageStrokes(APage: Integer);
var
  I: Integer;
  PW, PH: Single;
  Img: TPDFiumImage;
  procedure DrawOne(AStroke: TPDFInkStroke);
  var J, X, Y, X2, Y2: Integer; P: TPDFInkPoint;
  begin
    if AStroke.Count < 2 then Exit;
    if AStroke.IsCover then
    begin
      if FCore.PagePointToDevice(APage, Img.Width, Img.Height,
        AStroke[0].X, AStroke[0].Y, X, Y) then
      begin
        Img.Picture.Bitmap.Canvas.Brush.Color := clBlack;
        Img.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
        Img.Picture.Bitmap.Canvas.Pen.Color := clBlack;
        if FCore.PagePointToDevice(APage, Img.Width, Img.Height,
          AStroke[1].X, AStroke[1].Y, X2, Y2) then
          Img.Picture.Bitmap.Canvas.Rectangle(X, Y, X2, Y2);
      end;
      Exit;
    end;
    Img.Picture.Bitmap.Canvas.Pen.Color := AStroke.StrokeColor;
    Img.Picture.Bitmap.Canvas.Pen.Width := Max(1, Round(AStroke.LineWidth * FZoom));
    for J := 0 to AStroke.Count - 1 do
    begin
      P := AStroke[J];
      if not FCore.PagePointToDevice(APage, Img.Width, Img.Height,
        P.X, P.Y, X, Y) then Continue;
      if J = 0 then Img.Picture.Bitmap.Canvas.MoveTo(X, Y)
      else Img.Picture.Bitmap.Canvas.LineTo(X, Y);
    end;
  end;
begin
  if (APage < 0) or (APage >= FPages.Count) then Exit;
  if (APage >= Length(FLoadedPages)) or not FLoadedPages[APage] then Exit;
  Img := PageImage(APage);
  if not FCore.PageSize(APage, PW, PH) or (PW <= 0) or (PH <= 0) then Exit;
  for I := 0 to FCore.Strokes.Count - 1 do
    if FCore.StrokePages[I] = FCore.SourcePageIndex(APage) then
      DrawOne(FCore.Strokes[I]);
  if (FCurrentStroke <> nil) and (FStrokePage = APage) then
    DrawOne(FCurrentStroke);
  // Vormerkungen werden ausschliesslich in die Bildschirm-Bitmap gezeichnet.
  // Sie gelangen weder in den PDF-Inhalt noch in den Speicherpfad.
  for I := 0 to FRedactionPreviews.Count - 1 do
    if (FRedactionPreviewPages[I] = APage) and
       (FRedactionPreviews[I].Count >= 2) then
    begin
      var R1 := FRedactionPreviews[I][0];
      var R2 := FRedactionPreviews[I][1];
      var PX1, PY1, PX2, PY2: Integer;
      if FCore.PagePointToDevice(APage, Img.Width, Img.Height,
           R1.X, R1.Y, PX1, PY1) and
         FCore.PagePointToDevice(APage, Img.Width, Img.Height,
           R2.X, R2.Y, PX2, PY2) then
      begin
        // Schwarz ausgefuellte Vormerkung, nur in der Anzeige-Bitmap.
        // Der PDF-Inhalt darunter wird dadurch NICHT entfernt.
        Img.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
        Img.Picture.Bitmap.Canvas.Brush.Color := clBlack;
        Img.Picture.Bitmap.Canvas.Pen.Color := clBlack;
        Img.Picture.Bitmap.Canvas.Pen.Style := psSolid;
        Img.Picture.Bitmap.Canvas.Pen.Width := 1;
        Img.Picture.Bitmap.Canvas.Rectangle(PX1, PY1, PX2, PY2);
      end;
    end;
end;

procedure TFreePDF64PDFiumView.DrawSearchHighlight(APage: Integer);
var
  Img: TPDFiumImage;
  Matches: TArray<TPDFTextMatch>;
  Boxes: TArray<TPDFInkRect>;
  Box: TPDFInkRect;
  M: TPDFTextMatch;
  X1, Y1, X2, Y2, W, H: Integer;
  R: TRect;
  Overlay: TBitmap;
  Blend: TBlendFunction;
  IsCurrent: Boolean;
begin
  if (FFindTerm = '') or (APage < 0) then Exit;
  Img := PageImage(APage);
  if (Img = nil) or Img.Picture.Bitmap.Empty then Exit;
  Matches := FSearchMatches;
  if Length(Matches) = 0 then Exit;
  Overlay := TBitmap.Create;
  try
    Overlay.PixelFormat := pf24bit;
    Overlay.SetSize(1, 1);
    FillChar(Blend, SizeOf(Blend), 0);
    Blend.BlendOp := AC_SRC_OVER;
    Blend.AlphaFormat := 0;
    for M in Matches do
    begin
      if M.PageIndex <> APage then Continue;
      // Alle Treffer gelb; der mit F3 aktive Treffer orange und umrandet.
      IsCurrent := (M.PageIndex = FMatchPage) and
        (M.CharIndex = FMatchChar) and (M.CharCount = FMatchCount);
      if IsCurrent then
      begin
        Overlay.Canvas.Pixels[0, 0] := RGB(255, 150, 35);
        Blend.SourceConstantAlpha := 145;
      end
      else
      begin
        Overlay.Canvas.Pixels[0, 0] := RGB(255, 225, 60);
        Blend.SourceConstantAlpha := 110;
      end;
      Boxes := FCore.MatchCharRects(APage, M.CharIndex, M.CharCount);
      for Box in Boxes do
      begin
        if not FCore.PagePointToDevice(APage, Img.Width, Img.Height,
          Box.Left, Box.Top, X1, Y1) then Continue;
        if not FCore.PagePointToDevice(APage, Img.Width, Img.Height,
          Box.Right, Box.Bottom, X2, Y2) then Continue;
        R := Rect(Min(X1, X2), Min(Y1, Y2), Max(X1, X2), Max(Y1, Y2));
        W := R.Right - R.Left;
        H := R.Bottom - R.Top;
        if (W <= 0) or (H <= 0) then Continue;
        Winapi.Windows.AlphaBlend(Img.Picture.Bitmap.Canvas.Handle,
          R.Left, R.Top, W, H, Overlay.Canvas.Handle,
          0, 0, 1, 1, Blend);
        // Alle Fundstellen erhalten einen gut sichtbaren Rahmen mit Abstand.
        // Der aktuelle Treffer bleibt orange, alle weiteren gelb umrandet.
        Img.Picture.Bitmap.Canvas.Brush.Style := bsClear;
        Img.Picture.Bitmap.Canvas.Pen.Style := psSolid;
        if IsCurrent then
          Img.Picture.Bitmap.Canvas.Pen.Color := RGB(210, 95, 0)
        else
          Img.Picture.Bitmap.Canvas.Pen.Color := RGB(180, 140, 0);
        Img.Picture.Bitmap.Canvas.Pen.Width := 2;
        Img.Picture.Bitmap.Canvas.Rectangle(
          Max(0, R.Left - 3), Max(0, R.Top - 3),
          Min(Img.Width, R.Right + 3), Min(Img.Height, R.Bottom + 3));
        Img.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
      end;
    end;
  finally
    Overlay.Free;
  end;
end;

procedure TFreePDF64PDFiumView.DrawStrokes;
var I: Integer;
begin
  for I := 0 to FPages.Count - 1 do
    DrawPageStrokes(I);
end;

procedure TFreePDF64PDFiumView.SavePDFAs;
begin
  SaveClick(Self);
end;

procedure TFreePDF64PDFiumView.SaveDropdownClick(Sender: TObject);
var
  P: TPoint;
begin
  if FSavePopup = nil then Exit;
  P := FQuickSave.ClientToScreen(Point(0, FQuickSave.Height));
  FSavePopup.Popup(P.X, P.Y);
end;

procedure TFreePDF64PDFiumView.ExportPagesAsImages(Sender: TObject);
var
  Dialog: TForm;
  FormatBox, PagesBox, DpiBox: TComboBox;
  RangeEdit: TEdit;
  OKButton, CancelButton: TPDFDesignButton;
  P: Integer;
  FieldBack, FieldText: TColor;
  SaveDlg: TSaveDialog;
  Bitmap: TBitmap;
  GdiBitmap: TGPBitmap;
  TiffEncoder: TGUID;
  Jpg: TJPEGImage;
  Png: TPngImage;
  FirstPage, LastPage, Page, Dash, Dpi, PixelW, PixelH: Integer;
  PW, PH: Single;
  RangeText, TargetBase, TargetName, Ext: string;
  ScaleFactor: Double;
  function AddLabel(const AText: string; ATop: Integer): TLabel;
  begin
    Result := TLabel.Create(Dialog);
    Result.Parent := Dialog;
    Result.SetBounds(MulDiv(20, P, 96), MulDiv(ATop, P, 96),
      MulDiv(440, P, 96), MulDiv(23, P, 96));
    Result.Caption := AText;
  end;
begin
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;
  Dialog := TForm.CreateNew(Self);
  try
    P := Max(96, CurrentPPI);
    Dialog.Scaled := False;
    Dialog.Font.Name := 'Segoe UI';
    Dialog.Font.Size := 10;
    Dialog.Caption := ToolbarHint('PDF-Seiten als Bilder exportieren', 'Export PDF Pages as Images');
    Dialog.Position := poOwnerFormCenter;
    Dialog.BorderStyle := bsDialog;
    Dialog.ClientWidth := MulDiv(460, P, 96);
    Dialog.ClientHeight := MulDiv(310, P, 96);
    AddLabel(ToolbarHint('Bildformat:', 'Image format:'), 15);
    FormatBox := TComboBox.Create(Dialog);
    FormatBox.Parent := Dialog;
    FormatBox.Style := csDropDownList;
    FormatBox.SetBounds(MulDiv(20, P, 96), MulDiv(38, P, 96),
      MulDiv(420, P, 96), MulDiv(26, P, 96));
    FormatBox.Items.Add('PNG');
    FormatBox.Items.Add('JPEG');
    FormatBox.Items.Add('TIFF');
    FormatBox.ItemIndex := 0;
    AddLabel(ToolbarHint('Seiten:', 'Pages:'), 75);
    PagesBox := TComboBox.Create(Dialog);
    PagesBox.Parent := Dialog;
    PagesBox.Style := csDropDownList;
    PagesBox.SetBounds(MulDiv(20, P, 96), MulDiv(98, P, 96),
      MulDiv(420, P, 96), MulDiv(26, P, 96));
    PagesBox.Items.Add(ToolbarHint('Aktuelle Seite', 'Current page'));
    PagesBox.Items.Add(ToolbarHint('Alle Seiten', 'All pages'));
    PagesBox.Items.Add(ToolbarHint('Seitenbereich (z. B. 2-5)', 'Page range (e.g. 2-5)'));
    PagesBox.ItemIndex := 0;
    RangeEdit := TEdit.Create(Dialog);
    RangeEdit.Parent := Dialog;
    RangeEdit.SetBounds(MulDiv(20, P, 96), MulDiv(130, P, 96),
      MulDiv(420, P, 96), MulDiv(26, P, 96));
    RangeEdit.Text := Format('%d-%d', [1, FCore.PageCount]);
    AddLabel(ToolbarHint('Auflösung:', 'Resolution:'), 165);
    DpiBox := TComboBox.Create(Dialog);
    DpiBox.Parent := Dialog;
    DpiBox.Style := csDropDownList;
    DpiBox.SetBounds(MulDiv(20, P, 96), MulDiv(188, P, 96),
      MulDiv(420, P, 96), MulDiv(26, P, 96));
    DpiBox.Items.Add('150 DPI');
    DpiBox.Items.Add('300 DPI');
    DpiBox.Items.Add('600 DPI');
    DpiBox.ItemIndex := 1;
    OKButton := TPDFDesignButton.Create(Dialog);
    OKButton.Parent := Dialog;
    OKButton.SetBounds(MulDiv(240, P, 96), MulDiv(260, P, 96),
      MulDiv(95, P, 96), MulDiv(32, P, 96));
    OKButton.Caption := ToolbarHint('Exportieren', 'Export');
    OKButton.ModalResult := mrOk;
    OKButton.Default := True;
    CancelButton := TPDFDesignButton.Create(Dialog);
    CancelButton.Parent := Dialog;
    CancelButton.SetBounds(MulDiv(345, P, 96), MulDiv(260, P, 96),
      MulDiv(95, P, 96), MulDiv(32, P, 96));
    CancelButton.Caption := ToolbarHint('Abbrechen', 'Cancel');
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    // Palette nur einmal beim Erzeugen anwenden; kein wiederholtes Umfärben.
    ApplyManagedDialogPalette(Dialog, nil, FEditToggle.FDesign);
    case FEditToggle.FDesign of
      1: begin FieldBack := RGB(248,250,253); FieldText := RGB(35,48,65); end;
      2: begin FieldBack := RGB(65,70,79); FieldText := clWhite; end;
      3: begin FieldBack := clWhite; FieldText := clBlack; end;
      4: begin FieldBack := RGB(45,48,54); FieldText := clWhite; end;
      5: begin FieldBack := RGB(246,250,255); FieldText := RGB(24,55,88); end;
    else begin FieldBack := clWindow; FieldText := clWindowText; end;
    end;
    FormatBox.ParentColor := False;
    FormatBox.Color := FieldBack;
    FormatBox.Font.Color := FieldText;
    PagesBox.ParentColor := False;
    PagesBox.Color := FieldBack;
    PagesBox.Font.Color := FieldText;
    DpiBox.ParentColor := False;
    DpiBox.Color := FieldBack;
    DpiBox.Font.Color := FieldText;
    RangeEdit.ParentColor := False;
    RangeEdit.Color := FieldBack;
    RangeEdit.Font.Color := FieldText;
    if Dialog.ShowModal <> mrOk then Exit;
    FirstPage := FPage;
    LastPage := FPage;
    if PagesBox.ItemIndex = 1 then
    begin
      FirstPage := 0;
      LastPage := FCore.PageCount - 1;
    end
    else if PagesBox.ItemIndex = 2 then
    begin
      RangeText := Trim(RangeEdit.Text);
      Dash := Pos('-', RangeText);
      if (Dash = 0) or
         (not TryStrToInt(Trim(Copy(RangeText, 1, Dash - 1)), FirstPage)) or
         (not TryStrToInt(Trim(Copy(RangeText, Dash + 1, MaxInt)), LastPage)) or
         (FirstPage < 1) or (LastPage > FCore.PageCount) or (FirstPage > LastPage) then
      begin
        PDFModernMessageDlg(ToolbarHint('Ungültiger Seitenbereich.', 'Invalid page range.'), mtWarning, [mbOK], 0);
        Exit;
      end;
      Dec(FirstPage);
      Dec(LastPage);
    end;
    Dpi := 150;
    if DpiBox.ItemIndex = 1 then Dpi := 300
    else if DpiBox.ItemIndex = 2 then Dpi := 600;
    case FormatBox.ItemIndex of
      1: Ext := '.jpg';
      2: Ext := '.tif';
    else Ext := '.png';
    end;
    SaveDlg := TSaveDialog.Create(Self);
    try
      SaveDlg.Title := ToolbarHint('Dateiname und Zielordner wählen', 'Choose Filename and Destination Folder');
      SaveDlg.Filter := FormatBox.Text + ' (*' + Ext + ')|*' + Ext;
      SaveDlg.DefaultExt := Copy(Ext, 2, MaxInt);
      SaveDlg.InitialDir := ExtractFilePath(FCore.FileName);
      SaveDlg.FileName := ChangeFileExt(ExtractFileName(FCore.FileName), Ext);
      if not SaveDlg.Execute then Exit;
      TargetBase := ChangeFileExt(SaveDlg.FileName, '');
    finally
      SaveDlg.Free;
    end;
    // Jedes Blatt wird als eigene Bilddatei geschrieben.
    // PDFium rendert bei der gewählten DPI, unabhängig vom Bildschirmzoom.
    for Page := FirstPage to LastPage do
    begin
      if not FCore.PageSize(Page, PW, PH) then
        raise EPDFiumViewer.Create(ToolbarHint('Seitengröße konnte nicht gelesen werden.', 'Could not read page size.'));
      ScaleFactor := Dpi / 72.0;
      PixelW := Round(PW * ScaleFactor);
      PixelH := Round(PH * ScaleFactor);
      if (PixelW < 1) or (PixelH < 1) or
         (Int64(PixelW) * PixelH > 150000000) then
        raise EPDFiumViewer.Create(ToolbarHint('Seite ist für diese Auflösung zu groß.', 'Page too large for this resolution.'));
      if FirstPage = LastPage then
        TargetName := TargetBase + Ext
      else
        TargetName := TargetBase + Format('_Seite_%.3d', [Page + 1]) + Ext;
      if FileExists(TargetName) then
        raise EPDFiumViewer.Create(ToolbarHint('Zieldatei existiert bereits: ', 'Destination already exists: ') + TargetName);
      Bitmap := TBitmap.Create;
      try
        FCore.RenderPage(Page, Bitmap, PixelW, PixelH);
        case FormatBox.ItemIndex of
          0:
          begin
            Png := TPngImage.Create;
            try
              Png.Assign(Bitmap);
              Png.SaveToFile(TargetName);
            finally Png.Free; end;
          end;
          1:
          begin
            Jpg := TJPEGImage.Create;
            try
              Jpg.Assign(Bitmap);
              Jpg.CompressionQuality := 90;
              Jpg.SaveToFile(TargetName);
            finally Jpg.Free; end;
          end;
          2:
          begin
            // TIFF über Windows GDI+ statt Vcl.Imaging.WIC
            // (diese Unit ist nicht in allen Delphi-Versionen vorhanden).
            TiffEncoder := StringToGUID('{557CF405-1A04-11D3-9A73-0000F81EF32E}');
            GdiBitmap := TGPBitmap.Create(Bitmap.Handle, Bitmap.Palette);
            try
              if GdiBitmap.GetLastStatus <> Ok then
                raise EPDFiumViewer.Create(ToolbarHint(
                  'TIFF-Bild konnte nicht erstellt werden.',
                  'Could not create TIFF image.'));
              if GdiBitmap.Save(TargetName, TiffEncoder) <> Ok then
                raise EPDFiumViewer.Create(ToolbarHint(
                  'TIFF-Datei konnte nicht gespeichert werden.',
                  'Could not save TIFF file.'));
            finally
              GdiBitmap.Free;
            end;
          end;
        end;
      finally Bitmap.Free; end;
    end;
    PDFModernMessageDlg(ToolbarHint('Bildexport abgeschlossen.', 'Image export completed.'), mtInformation, [mbOK], 0);
  finally
    Dialog.Free;
  end;
end;

procedure TFreePDF64PDFiumView.SaveClick(Sender: TObject);
var
  D: TSaveDialog;
  EmptyRequiredCount: Integer;
  Answer: Integer;
  MissingFields: TStringList;
  DetailsText: string;
  I: Integer;
  Measurements: TArray<TPDFMeasureAnnotation>;
begin
  FinishInlineFormEdit(True);
  if (FCore = nil) or (FCore.PageCount = 0) then Exit;

  // 3b.63: Pflichtfelder bei JEDEM Speichern pruefen, auch wenn
  // das geoeffnete Dokument noch nicht bearbeitet wurde.
  // F7 verwendet dieselbe ListEmptyRequiredFields-Pruefung.
  // FCore.Modified ist nur fuer die Entscheidung SaveAs/CopyFile relevant.
  begin
    MissingFields := TStringList.Create;
    try
      try
        EmptyRequiredCount := FCore.ListEmptyRequiredFields(MissingFields);
      except
        on E: Exception do
        begin
          PDFModernMessageDlg(
            Tr('Die Pflichtfeldpruefung konnte nicht ausgefuehrt werden: ') +
            E.Message, mtWarning, [mbOK], 0);
          Exit;
        end;
      end;
      if EmptyRequiredCount > 0 then
      begin
        DetailsText := '';
        for I := 0 to Min(MissingFields.Count, 12) - 1 do
          DetailsText := DetailsText + sLineBreak + '  - ' + MissingFields[I];
        if MissingFields.Count > 12 then
          DetailsText := DetailsText + sLineBreak +
            Format(Tr('... und %d weitere Felder.'),
              [MissingFields.Count - 12]);
        Answer := PDFModernMessageDlg(
          Format(Tr('%d Pflichtfeld(er) sind noch leer:'),
            [EmptyRequiredCount]) + sLineBreak + DetailsText +
            sLineBreak + sLineBreak +
            Tr('Trotzdem als PDF-Kopie speichern?'),
          mtConfirmation, [mbYes, mbNo], 0);
        if Answer <> mrYes then Exit;
      end;
    finally
      MissingFields.Free;
    end;
  end;

  D := TSaveDialog.Create(nil);
  try
    D.Title := Tr('Speichern unter');
    D.Filter := Tr('PDF-Dateien') + '|*.pdf';
    D.DefaultExt := 'pdf';
    D.InitialDir := ExtractFilePath(FCore.FileName);
    D.FileName := ExtractFileName(FCore.FileName);
    if D.Execute then
    begin
      try
        if SameText(ExpandFileName(D.FileName), ExpandFileName(FCore.FileName)) then
          raise EPDFiumViewer.Create('Bitte einen anderen Dateinamen wählen.');
        if FMeasureRects.Count > 0 then
        begin
          SetLength(Measurements, FMeasureRects.Count);
          for I := 0 to FMeasureRects.Count - 1 do
          begin
            Measurements[I].PageIndex := FMeasureRects[I].Page;
            Measurements[I].X1 := FMeasureRects[I].X1;
            Measurements[I].Y1 := FMeasureRects[I].Y1;
            Measurements[I].X2 := FMeasureRects[I].X2;
            Measurements[I].Y2 := FMeasureRects[I].Y2;
            Measurements[I].Scale := FMeasureRects[I].Scale;
            Measurements[I].UnitIndex := FMeasureRects[I].UnitIndex;
          end;
          FCore.SaveAsWithMeasurements(D.FileName, Measurements);
        end
        else if FCore.Modified then
          FCore.SaveAs(D.FileName)
        else if not CopyFile(PChar(FCore.FileName), PChar(D.FileName), False) then
          RaiseLastOSError;
        Inc(FSaveSuccessSerial);
        UpdateSaveState;
        PDFModernMessageDlg(Tr('PDF gespeichert: ') + D.FileName, mtInformation, [mbOK], 0);
      except
        on E: Exception do PDFModernMessageDlg(Tr('Speichern fehlgeschlagen: ') + E.Message,
          mtError, [mbOK], 0);
      end;
    end;
  finally D.Free; end;
end;

function TFreePDF64PDFiumView.HasUnsavedChanges: Boolean;
begin
  Result := (FCore <> nil) and (FCore.Modified or FMeasureDirty or
    ((FMeasureRects <> nil) and (FMeasureRects.Count > 0)));
end;

function TFreePDF64PDFiumView.SaveUnsavedChanges: Boolean;
var
  BeforeSave: Integer;
begin
  if not HasUnsavedChanges then Exit(True);
  BeforeSave := FSaveSuccessSerial;
  SaveClick(nil);
  // Eine erfolgreich geschriebene PDF-Kopie genügt zum Schließen.
  // Bei Abbruch oder Fehler bleibt der Tab geöffnet.
  Result := FSaveSuccessSerial <> BeforeSave;
end;

function TFreePDF64PDFiumView.ConfirmUnsaved: Boolean;
var A, BeforeSave: Integer;
begin
  // Noch sichtbare Texteingaben vor der Aenderungspruefung uebernehmen.
  FinishInlineFormEdit(True);
  Result := True;
  if not HasUnsavedChanges then Exit;
  A := PDFModernMessageDlg(Tr('Die PDF wurde geändert. Vor dem Wechsel speichern?'),
    mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if A = mrCancel then Exit(False);
  if A = mrYes then
  begin
    BeforeSave := FSaveSuccessSerial;
    SaveClick(nil);
    Result := FSaveSuccessSerial <> BeforeSave;
  end;
end;

procedure TFreePDF64PDFiumView.PrintClick(Sender: TObject);
var
  B: TBitmap;
  Dlg: TPrintDialog;
  I, W, H, FirstPage, LastPage: Integer;
  PW, PH: Single;
  Scale: Double;
begin
  if FCore.PageCount = 0 then Exit;
  Dlg := TPrintDialog.Create(Self);
  try
    Dlg.Options := [poPageNums];
    Dlg.MinPage := 1;
    Dlg.MaxPage := FCore.PageCount;
    Dlg.FromPage := 1;
    Dlg.ToPage := FCore.PageCount;
    if not Dlg.Execute then Exit;
    FirstPage := 0;
    LastPage := FCore.PageCount - 1;
    if Dlg.PrintRange = prPageNums then
    begin
      FirstPage := Max(0, Dlg.FromPage - 1);
      LastPage := Min(FCore.PageCount - 1, Dlg.ToPage - 1);
    end;
    if LastPage < FirstPage then Exit;
    B := TBitmap.Create;
    try
      Printer.BeginDoc;
    try
      for I := FirstPage to LastPage do
      begin
        if I > FirstPage then Printer.NewPage;
        if not FCore.PageSize(I, PW, PH) then Continue;
        if (PW <= 0) or (PH <= 0) then Continue;
        Scale := Min(Printer.PageWidth / PW, Printer.PageHeight / PH);
        W := Round(PW * Scale);
        H := Round(PH * Scale);
        FCore.RenderPage(I, B, W, H);
        Printer.Canvas.StretchDraw(Rect((Printer.PageWidth - W) div 2,
          (Printer.PageHeight - H) div 2,
          (Printer.PageWidth + W) div 2,
          (Printer.PageHeight + H) div 2), B);
      end;
      Printer.EndDoc;
    except
      Printer.Abort;
      raise;
    end;
    finally
      B.Free;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TFreePDF64PDFiumView.ApplySavedThumbnailsAfterLoad;
begin
  // The PDF is loaded asynchronously, especially when started by FreePDF64.
  // Reapply the shared preference only in normal mode; never override
  // independently controlled thumbnail panels in split view.
  LoadGlobalThumbnails;
  if GThumbnailSplitMode then
  begin
    // Loading/restoring a PDF may reopen its sidebar after split mode
    // has already hidden it. Never import the global thumbnail preference
    // into either split pane during the asynchronous first load.
    SetPageThumbnailsVisible(False);
  end
  else
    SetPageThumbnailsVisible(GThumbnailsVisible);
end;

procedure TFreePDF64PDFiumView.SetPageThumbnailsVisible(AVisible: Boolean);
begin
  if AVisible then
  begin
    // Bereits sichtbare Miniaturen nicht erneut aktivieren und layouten.
    // Das vermeidet einen zweiten sichtbaren Aufbau beim PDF-Start.
    if not FThumbScroll.Visible then
      ShowOutlineTab(True);
    if not FOutlinePanel.Visible then
      ToggleOutline(nil);
  end
  else if FOutlinePanel.Visible then
    ToggleOutline(nil);
end;

class function TFreePDF64PDFiumView.GlobalThumbnailsVisible: Boolean;
begin
  LoadGlobalThumbnails;
  Result := GThumbnailsVisible;
end;

class procedure TFreePDF64PDFiumView.SetGlobalThumbnailSplitMode(AEnabled: Boolean);
var V: TFreePDF64PDFiumView;
begin
  LoadGlobalThumbnails;
  GThumbnailSplitMode := AEnabled;
  if GThumbnailViews <> nil then
    for V in GThumbnailViews do
      V.SetPageThumbnailsVisible(not AEnabled and GThumbnailsVisible);
end;

procedure TFreePDF64PDFiumView.TogglePageThumbnails;
var V: TFreePDF64PDFiumView;
begin
  if GThumbnailSplitMode then
  begin
    SetPageThumbnailsVisible(not (FOutlinePanel.Visible and FThumbScroll.Visible));
    Exit;
  end;
  LoadGlobalThumbnails;
  GThumbnailsVisible := not (FOutlinePanel.Visible and FThumbScroll.Visible);
  SaveGlobalThumbnails;
  if GThumbnailViews <> nil then
    for V in GThumbnailViews do
      V.SetPageThumbnailsVisible(GThumbnailsVisible);
end;

end.

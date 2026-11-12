unit uPDFTabsForm;

interface

uses
  uPDFLanguage,
  System.SysUtils, System.Classes, System.Types, System.Net.HttpClient, System.JSON, Winapi.Windows, Winapi.Messages, Winapi.CommCtrl, Winapi.ShellAPI, Winapi.ShlObj,
  Vcl.Forms, Vcl.Controls, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Buttons,
  Vcl.Dialogs, uPDFModernDialogs, Vcl.Menus, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, System.IniFiles, System.Win.Registry, Math,
  uPDFBrowserForm, uFreePDF64PDFiumView, uFreePDF64PDFiumCore, uPDFGlobalSearch, uPDFMergeTabs, uPDFVisualCompare;

type
  // Teilungsbutton mit orangefarbenem Rahmen; keine protected Color-Eigenschaft.
  TOutlinedSplitButton = class(TButton)
  protected
    procedure WndProc(var Message: TMessage); override;
  end;

  // Mausrad auch dann an den Hilfetext weitergeben, wenn der Schließen-Button
  // den Tastaturfokus besitzt.
  TViewerHelpForm = class(TForm)
  public
    HelpScroll: TScrollBox;
    procedure OpenProjectLink(Sender: TObject);
    procedure OpenContactMail(Sender: TObject);
    procedure JumpToHelpSection(Sender: TObject);
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  end;

  // Die Verlaufsliste ist ein nicht selbst scrollender Bereich. Mausrad-
  // Ereignisse werden an die aeussere, scrollbar angelegte Startseite gegeben.
  TRecentPDFScrollBox = class(TScrollBox)
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  end;

  TPDFTabsForm = class(TForm)
  private
    FTabs: TPageControl;
    FWelcomePanel: TScrollBox;
    FWelcomeImage: TImage;
    FWelcomeTitle: TLabel;
    FWelcomeHint: TLabel;
    FWelcomeOpenButton: TButton;
    FWelcomeWorkspaceButton: TButton;
    FRecentPDFs: TStringList;
    FRecentTitle: TLabel;
    FRecentScroll: TScrollBox;
    FRecentClearButton: TButton;
    FRecentPopup: TPopupMenu;
    FRecentPopupIndex: Integer;
    FEmptyTabStrip: TPanel;
    FViewerHeader: TPanel;
    FTabActionsPanel: TPanel;
    FLeftPDFOverlay: TPanel;
    FTabSplitButton: TButton;
    FSyncScrollButton: TSpeedButton;
    FSyncZoomButton: TSpeedButton;
    FSyncScrollEnabled, FSyncZoomEnabled: Boolean;
    FSyncLastX, FSyncLastY: Integer;
    FSyncLastZoom: Double;
    FSyncRightLastX, FSyncRightLastY: Integer;
    FSyncRightLastZoom: Double;
    FSyncSampleValid: Boolean;
    FTabTextSearchButton: TButton;
    FSplitButtonPopup: TPopupMenu;
    FTabPrevButton: TButton;
    FTabNextButton: TButton;
    FHomeMenu: TMenuItem;
    FFileMenu: TMenuItem;
    FEditMenu: TMenuItem;
    FSplitViewMenuItem: TMenuItem;
    FVisualCompareMenuItem: TMenuItem;
    FSplitHost: TPanel;
    FSplitLeft: TPanel;
    FSplitRight: TPanel;
    FSplitDivider: TSplitter;
    FSplitLeftScaled: Boolean;
    FSplitRightScaled: Boolean;
    FSplitFocusTimer: TTimer;
    FSplitMouseWasDown: Boolean;
    FSplitLeftTopBarVisible: Boolean;
    FSplitRightTopBarVisible: Boolean;
    FSplitLeftNavBarVisible: Boolean;
    FSplitRightNavBarVisible: Boolean;
    FSplitLeftTab: TTabSheet;
    FSplitRightTab: TTabSheet;
    FSplitActiveRight: Boolean;
    FSplitShiftTab: Integer;
    FSplitAnchorTab: TTabSheet;
    FSplitSelectedTab: TTabSheet;
    FSplitLastSelectedTab: TTabSheet;
    FLocalSearchMenuItem: TMenuItem;
    FGlobalSearchMenuItem: TMenuItem;
    FMergePDFMenuItem: TMenuItem;
    FWorkspaceMenu: TMenuItem;
    FOptionsMenu: TMenuItem;
    FHelpRootMenuItem: TMenuItem;
    FUpdateAutoMenuItem: TMenuItem;
    FUpdateManualMenuItem: TMenuItem;
    FUpdateStartupTimer: TTimer;
    FUpdateCheckBusy: Boolean;
    FDesignMenu: TMenuItem;
    FDesignItems: array[0..5] of TMenuItem;
    FDesignIndex: Integer;
    FAppliedDesignIndex: Integer;
    FDesignHasBeenApplied: Boolean;
    FLanguageMenu: TMenuItem;
    FGermanMenuItem: TMenuItem;
    FEnglishMenuItem: TMenuItem;
    FRestartRequested: Boolean;
    FPendingRestartLanguage: string;
    FFullScreen: Boolean;
    FFullScreenPDF: TPDFBrowserForm;
    FFullScreenPDFTab: TTabSheet;
    FFullScreenPDFScaled: Boolean;
    FFullScreenBounds: TRect;
    FFullScreenWindowState: TWindowState;
    FFullScreenBorderStyle: TFormBorderStyle;
    FFullScreenTabsVisible: Boolean;
    FFullScreenEmptyStripVisible: Boolean;
    FUpdatingTabLayout: Boolean;
    FOriginalTabsWindowProc: TWndMethod;
    FClosedPDFs: TStringList;
    FSessionPDFs: TStringList;
    FTabContextMenu: TPopupMenu;
    FReopenClosedItem: TMenuItem;
    FTabHintWindow: THintWindow;
    FTabPreviewMenuItem: TMenuItem;
    FTabPreviewEnabled: Boolean;
    FTabPreviewTimer: TTimer;
    FTabPreviewForm: TForm;
    FTabPreviewImage: TImage;
    FTabPreviewTitle: TLabel;
    FTabPreviewPath: TLabel;
    FTabPreviewIndex: Integer;
    FTabPreviewStarted: Cardinal;
    FTabPreviewRequested: string;
    FHintTabIndex: Integer;
    FTrackingTabsMouseLeave: Boolean;
    FTabHintWatchTimer: TTimer;
    FWindowResizeTimer: TTimer;
    FTabFitTimer: TTimer;
    FTabFitPendingPage: TTabSheet;
    FTabFitRetryCount: Integer;
    FHoverCloseTabIndex: Integer;
    FCloseRestoreTab: TTabSheet; // aktiven Tab beim Schliessen eines anderen erhalten
    FCloseTargetTab: TTabSheet; // X-Schliessen ohne Aktivieren einer ungeladenen PDF
    FTabCloseInProgress: Boolean;
    FDragTabIndex: Integer;
    FDragStartPoint: TPoint;
    FDraggingTab: Boolean;
    FHelpMainMenu: TMainMenu;
    FTrayPopup: TPopupMenu;
    FTrayMenuItem: TMenuItem;
    FWindowsStartMenuItem: TMenuItem;
    FStartMinimizedMenuItem: TMenuItem;
    FStartMinimized: Boolean;
    FStartupMinimizePending: Boolean;
    FTrayEnabled: Boolean;
    FTrayVisible: Boolean;
    FExitFromTray: Boolean;
    FOpenButton: TButton;
    FMainProgramButton: TButton;
    FTabSearchButton: TButton;
    FLocalTabSearchHotkeyRegistered: Boolean;
    FLocalTextSearchHotkeyRegistered: Boolean;
    FTabCountBadge: TPaintBox;
    FGlobalSearchForm: TPDFGlobalSearchForm;
    FTabSearchForm: TForm;
    FTabSearchEdit: TEdit;
    FTabSearchList: TListBox;
    FLastNormalBounds: TRect;
    FRestoringWindowSettings: Boolean;
    FAddingPDF: Boolean;
    FMultiPDFLoadDepth: Integer;
    FMultiPDFLastPDF: TPDFBrowserForm;
    FPendingExplorerFiles: TStringList;
    FExplorerBatchTimer: TTimer;
    FCreatedPDFForegroundTimer: TTimer;
    FDeferredActivePDF: TPDFBrowserForm;
    FActivationTimer: TTimer;
    FActivationChecks: Integer;
    FPendingPDFDisposals: TList;
    FPDFDisposalTimer: TTimer;
    FFirstPDFInitialized: Boolean;
    FInitialWindowOffscreen: Boolean;
    FInitialWindowBounds: TRect;
    FInitialWindowMaximized: Boolean;
    FRightPDFOverlay: TPanel;

    procedure DesignClick(Sender: TObject);
    procedure ApplyViewerDesign;
    procedure UpdateIntegratedOptionsVisibility;
    procedure UpdateAutoClick(Sender: TObject);
    procedure UpdateManualClick(Sender: TObject);
    procedure UpdateStartupTick(Sender: TObject);
    procedure StartUpdateCheck(AManual: Boolean);
    procedure SplitButtonPopup(Sender: TObject);
    procedure SplitPopupCloseLeft(Sender: TObject);
    procedure SplitPopupCloseRight(Sender: TObject);
    procedure SplitPopupSwap(Sender: TObject);
    procedure ReplaceSplitPane(ANewTab: TTabSheet);
    procedure UpdateSplitMenuState;
    procedure SplitMenuClick(Sender: TObject);
    procedure VisualCompareClick(Sender: TObject);
    procedure StartSplit(ALeft, ARight: TTabSheet);
    procedure StopSplit;
    procedure SplitPaneClick(Sender: TObject);
    procedure SplitThumbClick(Sender: TObject);
    procedure SplitFocusTimerTick(Sender: TObject);
    procedure SplitSyncClick(Sender: TObject);
    procedure UpdateSplitSyncButtons;
    procedure CheckSplitSynchronization;
    procedure UpdateSplitBorders;
    procedure SetSplitPDFToolbars(APDF: TPDFBrowserForm; AShow: Boolean;
      var ATopWasVisible, ANavWasVisible: Boolean);
    function PDFInTab(ATab: TTabSheet): TPDFBrowserForm;
    procedure ChangeLanguageClick(Sender: TObject);
    procedure RefreshLanguage;
    procedure PDFDisposalTimerTick(Sender: TObject);
    procedure ShowModernInfo(AAbout: Boolean; AMergeHelp: Boolean = False);
    procedure ShowAboutViewer(Sender: TObject);
    procedure PDFVerknuepfungClick(Sender: TObject);
    procedure ToggleTrayMode(Sender: TObject);
    procedure ToggleWindowsStart(Sender: TObject);
    procedure ToggleStartMinimized(Sender: TObject);
    function IsWindowsStartEnabled: Boolean;
    procedure ApplyStartupMinimized(var Msg: TMessage); message WM_APP + 198;
    procedure RestoreFromTray(Sender: TObject);
    procedure ExitFromTray(Sender: TObject);
    procedure SetTrayIcon(AVisible: Boolean);
    procedure WMTrayCallback(var Msg: TMessage); message WM_APP + 195;
    procedure ShowViewerHelp(Sender: TObject);
    procedure UpdateWelcomeView;
    procedure WelcomeResize(Sender: TObject);
    procedure LoadRecentPDFs;
    procedure SaveRecentPDFs;
    procedure RememberRecentPDF(const AFileName: string);
    procedure RefreshRecentPDFList;
    procedure LoadRecentThumbnail(const AFileName: string; AImage: TImage);
    function RecentPDFPageCount(const AFileName: string): Integer;
    procedure CleanupRecentThumbnails(const AClearAll: Boolean);
    procedure RecentPDFClick(Sender: TObject);
    procedure RecentPDFContext(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure RecentPDFRemove(Sender: TObject);
    procedure RecentPDFShowFolder(Sender: TObject);
    procedure RecentPDFClear(Sender: TObject);
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;

    procedure TabsWindowProc(var Msg: TMessage);
    procedure WMViewerActivate(var Msg: TWMActivate); message WM_ACTIVATE;
    procedure WMViewerHotKey(var Msg: TMessage); message WM_HOTKEY;
    procedure UpdateEmptyTabStrip;
    procedure PositionTabActions;
    procedure TabArrowClick(Sender: TObject);
    procedure TabsResized(Sender: TObject);
    procedure SplitHostResized(Sender: TObject);
    procedure EmptyTabStripMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TabContextPopup(Sender: TObject);
    procedure LoadClosedPDFs;
    procedure SaveClosedPDFs;
    procedure UpdateClosedPDFHistory(const AFileName: string; AAdd: Boolean);
    procedure LoadWorkspace;
    procedure SaveWorkspace;
    procedure OpenWorkspaceClick(Sender: TObject);
    procedure ManageWorkspacesClick(Sender: TObject);
    procedure WorkspaceListDblClick(Sender: TObject);
    procedure OpenWorkspaceFile(const APath: string);
    function WorkspaceFolder: string;
    procedure SaveWorkspaceClick(Sender: TObject);
    procedure ReopenLastClosedPDF(Sender: TObject);
    procedure ReopenSelectedClosedPDF(Sender: TObject);
    procedure ActivationTimerTick(Sender: TObject);
    procedure ExplorerBatchTimerTick(Sender: TObject);
    procedure CreatedPDFForegroundTimerTick(Sender: TObject);
    procedure QueueCreatedPDFForeground;
    procedure RestoreInitialWindow;
    procedure BringViewerToForeground;
    procedure WMOpenQueuedPDF(var Msg: TMessage); message WM_APP + 192;
    procedure WMLoadActivePDF(var Msg: TMessage); message WM_APP + 193;
    procedure OpenPDFClick(Sender: TObject);
    procedure ReloadActivePDFClick(Sender: TObject);
    procedure OpenMainProgramClick(Sender: TObject);
    procedure UpdateTabCount;
    procedure PaintTabCountBadge(Sender: TObject);
    procedure GlobalSearchClick(Sender: TObject);
    procedure MergePDFClick(Sender: TObject);
    procedure LocalSearchMenuClick(Sender: TObject);
    procedure EditMenuClick(Sender: TObject);
    procedure TabSearchClick(Sender: TObject);
    procedure TabSearchChanged(Sender: TObject);
    procedure TabSearchChoose(Sender: TObject);
    procedure TabSearchListMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TabSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TabSearchDeactivate(Sender: TObject);
    procedure TabsFormClose(Sender: TObject; var Action: TCloseAction);
    procedure ClearAllPDFTabs;
    function ConfirmCloseUnsavedPDFs(AOnlyActive: Boolean): Boolean;
    procedure ApplyShownWindowSettings(var Msg: TMessage); message WM_APP + 194;
    procedure TabsFormShow(Sender: TObject);
    procedure LoadWindowSettings;
    procedure SaveWindowSettings;
    procedure RememberNormalBounds;
    procedure HomeMenuClick(Sender: TObject);
    procedure CloseActive(Sender: TObject);
    procedure CloseTabAt(AIndex: Integer);
    function TabCloseRect(AIndex: Integer): TRect;
    procedure ViewerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ToggleFullScreen;
    procedure WMRefreshAfterFullScreen(var Msg: TMessage); message WM_APP + 210;
    procedure WMCopyData(var Msg: TWMCopyData); message WM_COPYDATA;
    function IsShortCut(var Message: TWMKey): Boolean; override;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure AlignHelpMenuRight;
    procedure WMInitMenu(var Msg: TMessage); message WM_INITMENU;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure HideAllAttachmentWindows;
    procedure RefreshAttachmentPositions;
    procedure TabsChange(Sender: TObject);
    procedure TabsChanging(Sender: TObject; var AllowChange: Boolean);
    procedure TabsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TabsMouseLeave(Sender: TObject);
    procedure TabHintWatchTimerTick(Sender: TObject);
    procedure HideTabHint;
    procedure TabPreviewMenuClick(Sender: TObject);
    procedure TabPreviewTimerTick(Sender: TObject);
    procedure HideTabPreview;
    procedure DrawPDFTab(Control: TCustomTabControl; TabIndex: Integer;
      const Rect: TRect; Active: Boolean);

    procedure WindowMoved(var Msg: TWMMove); message WM_MOVE;
    procedure WindowSized(var Msg: TWMSize); message WM_SIZE;
    procedure WindowResizeSettled(Sender: TObject);
    procedure TabFitTimerTick(Sender: TObject);
    procedure TabMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure LoadSelectedPDF;
    procedure TabDoubleClick(Sender: TObject);
    procedure TabMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  public
    procedure ShowPDFMergeHelp;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginMultiPDFLoad;
    procedure EndMultiPDFLoad;
    procedure AddPDF(APDF: TPDFBrowserForm);
    procedure AddAttachmentPDF(APDF: TPDFBrowserForm; ASource: TPDFBrowserForm);
    procedure ActivatePDF(APDF: TPDFBrowserForm);
    procedure ShowCreatedPDFInForeground;
    function PrepareHiddenStartup: Boolean;
    procedure GetOpenPDFFileNames(AFiles: TStrings);
    function ActivateExistingPDF(const AFileName: string): Boolean;
  end;

type
  TPDFTabAttachmentsProc = procedure(const AFileName: string;
    APDF: TPDFBrowserForm);

var
  PDFTabsWindow: TPDFTabsForm;
  PDFTabAttachmentsInitializer: TPDFTabAttachmentsProc;
  // True nur bei einem eigenstaendigen Explorer-Start mit PDF-Parametern.
  PDFTabsExplorerOnlyProcess: Boolean = False;
  // Wurde das Hauptfenster im Explorer-Prozess explizit geoeffnet?
  PDFTabsMainFormWasShown: Boolean = False;

procedure ShowEmptyPDFViewer;
procedure ShowPDFInTabs(APDF: TPDFBrowserForm);
function ActivateExistingPortableViewer: Boolean;
function SendPDFToExistingTabs(const AFileName: string): Boolean;
function SendPDFToExternalTabs(const AFileName: string): Boolean;
procedure ActivateExternalCreatedPDFViewer;
function ActivateRunningMainProgram: Boolean;
procedure MarkMainProgramWindow(Wnd: HWND);

var
  PDFTabsShowMainForm: TNotifyEvent = nil;

implementation

uses
  uPDFAttachmentTemp;

// Das PDF-Formular muss nicht Controls[0] sein (z.B. bei Overlays).
function WorkspaceBrowserInTab(ATab: TTabSheet): TPDFBrowserForm;
var
  K: Integer;
begin
  Result := nil;
  if ATab = nil then Exit;
  for K := 0 to ATab.ControlCount - 1 do
    if ATab.Controls[K] is TPDFBrowserForm then
    begin
      Result := TPDFBrowserForm(ATab.Controls[K]);
      Exit;
    end;
end;

procedure TOutlinedSplitButton.WndProc(var Message: TMessage);
var
  DC: HDC;
  Brush: HBRUSH;
  R: TRect;
  I: Integer;
begin
  inherited WndProc(Message);
  if (Message.Msg = WM_PAINT) or (Message.Msg = WM_NCPAINT) then
  begin
    if not HandleAllocated then Exit;
    DC := GetWindowDC(Handle);
    if DC = 0 then Exit;
    try
      R := Rect(0, 0, Width, Height);
      Brush := CreateSolidBrush(RGB(255, 165, 0));
      try
        // Vier Pixel breiter, orangefarbener Rahmen.
        for I := 1 to 4 do
        begin
          Winapi.Windows.FrameRect(DC, R, Brush);
          InflateRect(R, -1, -1);
        end;
      finally
        DeleteObject(Brush);
      end;
    finally
      ReleaseDC(Handle, DC);
    end;
  end;
end;

// Such-, Sortier- und Vorschaufunktionen des Arbeitsbereich-Managers.
type
  TWorkspaceEntry = record
    DisplayName, FilePath: string;
    SavedAt: TDateTime;
    PDFCount: Integer;
  end;

  TWorkspaceListController = class
  public
    List: TListView;
    Search: TEdit;
    OwnerForm: TForm;
    DesignIndex: Integer;
    SortColumn: Integer;
    SortAscending: Boolean;
    Entries: array of TWorkspaceEntry;
    LastDateWidth, LastPDFWidth: Integer;
    procedure ResizeColumns(Sender: TObject);
    procedure CheckColumnWidths(Sender: TObject);
    procedure Refresh;
    procedure SearchChanged(Sender: TObject);
    procedure ColumnClicked(Sender: TObject; Column: TListColumn);
    procedure ShowContents(Sender: TObject);
    procedure ContentsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

procedure TWorkspaceListController.ResizeColumns(Sender: TObject);
var
  AvailableWidth, NameWidth: Integer;
begin
  if (List = nil) or (List.Columns.Count < 3) then Exit;
  // Die beiden rechten Spalten behalten ihre DPI-skalierten Breiten.
  // Platz fuer die vertikale Scrollleiste einplanen, damit keine
  // horizontale Scrollleiste durch Rundungsdifferenzen entsteht.
  AvailableWidth := List.ClientWidth - GetSystemMetrics(SM_CXVSCROLL) - 4;
  NameWidth := AvailableWidth - List.Columns[1].Width - List.Columns[2].Width;
  if NameWidth < 80 then NameWidth := 80;
  if List.Columns[0].Width <> NameWidth then
    List.Columns[0].Width := NameWidth;
end;

procedure TWorkspaceListController.CheckColumnWidths(Sender: TObject);
var
  Ini: TIniFile;
begin
  if (List = nil) or (List.Columns.Count < 3) then Exit;
  // Mindestbreiten auch nach manuellem Ziehen der Spaltentrenner erzwingen.
  // Die Werte sind DPI-skaliert und lassen Ueberschriften und Daten lesbar.
  if List.Columns[1].Width < MulDiv(150, List.CurrentPPI, 96) then
    List.Columns[1].Width := MulDiv(150, List.CurrentPPI, 96);
  if List.Columns[2].Width < MulDiv(65, List.CurrentPPI, 96) then
    List.Columns[2].Width := MulDiv(65, List.CurrentPPI, 96);
  // Die Spalten 1 und 2 duerfen vom Benutzer ueber den Header veraendert
  // werden. Bei Aenderung passt sich ausschliesslich die Namensspalte an.
  if (LastDateWidth <> List.Columns[1].Width) or
     (LastPDFWidth <> List.Columns[2].Width) then
  begin
    LastDateWidth := List.Columns[1].Width;
    LastPDFWidth := List.Columns[2].Width;
    ResizeColumns(List);
    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      Ini.WriteInteger('Arbeitsbereiche', 'DateColumnWidth', LastDateWidth);
      Ini.WriteInteger('Arbeitsbereiche', 'PDFColumnWidth', LastPDFWidth);
    finally
      Ini.Free;
    end;
  end;
end;

procedure TWorkspaceListController.Refresh;
var
  Indices: array of Integer;
  I, J, Tmp, C: Integer;
  Item: TListItem;
  SelectedFile: string;
  Match: Boolean;
begin
  SelectedFile := '';
  if (List.Selected <> nil) and (List.Selected.SubItems.Count > 2) then
    SelectedFile := List.Selected.SubItems[2];
  // Die Einträge wurden bereits durch ReloadList aus den vorhandenen
  // Arbeitsbereichsdateien geladen. Hier nur die Anzeige sortieren/filtern:
  // ein erneutes Einlesen mit anderem INI-Schema würde die Liste leeren.
  SetLength(Indices, Length(Entries));
  C := 0;
  for I := 0 to High(Entries) do
  begin
    Match := (Search = nil) or
      (Pos(AnsiLowerCase(Trim(Search.Text)),
       AnsiLowerCase(Entries[I].DisplayName)) > 0);
    if Match then
    begin
      Indices[C] := I;
      Inc(C);
    end;
  end;
  SetLength(Indices, C);
  for I := 0 to C - 2 do
    for J := I + 1 to C - 1 do
    begin
      case SortColumn of
        0: Tmp := CompareText(Entries[Indices[I]].DisplayName, Entries[Indices[J]].DisplayName);
        2: Tmp := Entries[Indices[I]].PDFCount - Entries[Indices[J]].PDFCount;
      else
        if Entries[Indices[I]].SavedAt < Entries[Indices[J]].SavedAt then Tmp := -1
        else if Entries[Indices[I]].SavedAt > Entries[Indices[J]].SavedAt then Tmp := 1
        else Tmp := CompareText(Entries[Indices[I]].DisplayName, Entries[Indices[J]].DisplayName);
      end;
      if not SortAscending then Tmp := -Tmp;
      if Tmp > 0 then
      begin
        Tmp := Indices[I]; Indices[I] := Indices[J]; Indices[J] := Tmp;
      end;
    end;
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    for I := 0 to C - 1 do
    begin
      Item := List.Items.Add;
      Item.Caption := Entries[Indices[I]].DisplayName;
      if Entries[Indices[I]].SavedAt > 0 then
        Item.SubItems.Add(FormatDateTime('dd.mm.yyyy hh:nn', Entries[Indices[I]].SavedAt))
      else
        Item.SubItems.Add('–');
      Item.SubItems.Add(IntToStr(Entries[Indices[I]].PDFCount));
      Item.SubItems.Add(Entries[Indices[I]].FilePath);
      if SameText(Entries[Indices[I]].FilePath, SelectedFile) then
        List.Selected := Item;
    end;
    if (List.Selected = nil) and (List.Items.Count > 0) then
      List.Selected := List.Items[0];
  finally
    List.Items.EndUpdate;
  end;
end;

procedure TWorkspaceListController.SearchChanged(Sender: TObject);
var
  I: Integer;
  Item: TListItem;
  Filter, SelectedFile: string;
begin
  // Nur die sichtbaren Einträge filtern. Der vollständige Datenbestand
  // in Entries bleibt bei Eingabe und Löschen des Suchtexts erhalten.
  Filter := AnsiLowerCase(Trim(Search.Text));
  SelectedFile := '';
  if (List.Selected <> nil) and (List.Selected.SubItems.Count > 2) then
    SelectedFile := List.Selected.SubItems[2];
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    for I := 0 to High(Entries) do
    begin
      if (Filter <> '') and
         (Pos(Filter, AnsiLowerCase(Entries[I].DisplayName)) = 0) then
        Continue;
      Item := List.Items.Add;
      Item.Caption := Entries[I].DisplayName;
      if Entries[I].SavedAt > 0 then
        Item.SubItems.Add(FormatDateTime('dd.mm.yyyy hh:nn', Entries[I].SavedAt))
      else
        Item.SubItems.Add('–');
      Item.SubItems.Add(IntToStr(Entries[I].PDFCount));
      Item.SubItems.Add(Entries[I].FilePath);
      if SameText(Entries[I].FilePath, SelectedFile) then
        List.Selected := Item;
    end;
    if (List.Selected = nil) and (List.Items.Count > 0) then
      List.Selected := List.Items[0];
  finally
    List.Items.EndUpdate;
  end;
end;

function CompareWorkspaceListItems(Item1, Item2: TListItem; Data: Integer): Integer;
var
  A, B: string;
  Col: Integer;
begin
  Col := Abs(Data) - 1;
  case Col of
    0: begin A := Item1.Caption; B := Item2.Caption; end;
    2: begin
      Result := StrToIntDef(Item1.SubItems[1], 0) -
                StrToIntDef(Item2.SubItems[1], 0);
      if Data < 0 then Result := -Result;
      Exit;
    end;
  else
    begin
      A := Item1.SubItems[0];
      B := Item2.SubItems[0];
      // dd.mm.yyyy hh:nn -> yyyymmddhhnn
      if Length(A) >= 16 then A := Copy(A, 7, 4) + Copy(A, 4, 2) +
        Copy(A, 1, 2) + Copy(A, 12, 2) + Copy(A, 15, 2);
      if Length(B) >= 16 then B := Copy(B, 7, 4) + Copy(B, 4, 2) +
        Copy(B, 1, 2) + Copy(B, 12, 2) + Copy(B, 15, 2);
    end;
  end;
  Result := CompareText(A, B);
  if Data < 0 then Result := -Result;
end;

procedure TWorkspaceListController.ColumnClicked(Sender: TObject; Column: TListColumn);
begin
  if SortColumn = Column.Index then
    SortAscending := not SortAscending
  else
  begin
    SortColumn := Column.Index;
    SortAscending := Column.Index = 0;
  end;
  // Sortierung dauerhaft in der bereits vorhandenen Viewer-INI speichern.
  with TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini') do
  try
    WriteInteger('Arbeitsbereiche', 'SortColumn', SortColumn);
    WriteBool('Arbeitsbereiche', 'SortAscending', SortAscending);
  finally
    Free;
  end;
  // Bereits sichtbare ListView-Einträge direkt sortieren.
  // Kein Clear/Neuaufbau: die Einträge bleiben bei jedem Spaltenklick erhalten.
  if SortAscending then
    List.CustomSort(@CompareWorkspaceListItems, SortColumn + 1)
  else
    List.CustomSort(@CompareWorkspaceListItems, -(SortColumn + 1));
end;

procedure TWorkspaceListController.ContentsKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    if Sender is TCustomForm then
      TCustomForm(Sender).ModalResult := mrCancel;
    Key := 0;
  end;
end;

procedure TWorkspaceListController.ShowContents(Sender: TObject);
var
  Dialog: TForm;
  Memo: TMemo;
  CloseButton: TButton;
  Ini: TIniFile;
  I, Count: Integer;
  S, FilePath: string;
begin
  if (List.Selected = nil) or (List.Selected.SubItems.Count < 3) then Exit;
  FilePath := List.Selected.SubItems[2];
  if not FileExists(FilePath) then Exit;
  Dialog := TForm.CreateNew(OwnerForm);
  try
    Dialog.Caption := Tr('Inhalt anzeigen ...');
    Dialog.KeyPreview := True;
    Dialog.OnKeyDown := ContentsKeyDown;
    Dialog.Position := poOwnerFormCenter;
    Dialog.BorderStyle := bsSizeable;
    Dialog.Font.Name := 'Segoe UI';
    Dialog.Font.Size := 10;
    Dialog.ClientWidth := MulDiv(660, OwnerForm.CurrentPPI, 96);
    Dialog.ClientHeight := MulDiv(390, OwnerForm.CurrentPPI, 96);
    case DesignIndex of
      1: Dialog.Color := RGB(229,236,246);
      3: Dialog.Color := RGB(232,232,232);
      5: Dialog.Color := RGB(220,233,247);
    else Dialog.Color := clWhite;
    end;
    Memo := TMemo.Create(Dialog);
    Memo.Parent := Dialog;
    Memo.Align := alClient;
    Memo.ReadOnly := True;
    Memo.ScrollBars := ssBoth;
    Memo.WordWrap := False;
    Memo.Font.Name := 'Segoe UI';
    Memo.Font.Size := 10;
    Ini := TIniFile.Create(FilePath);
    try
      Count := Ini.ReadInteger('PDFs', 'Count', 0);
      if Count > 200 then Count := 200;
      if Count < 0 then Count := 0;
      for I := 1 to Count do
      begin
        S := Ini.ReadString('PDFs', 'File' + IntToStr(I), '');
        if S <> '' then Memo.Lines.Add(S);
      end;
    finally
      Ini.Free;
    end;
    CloseButton := TPDFDesignButton.Create(Dialog);
    CloseButton.Parent := Dialog;
    TPDFDesignButton(CloseButton).SetDesign(DesignIndex);
    CloseButton.Align := alBottom;
    CloseButton.Height := MulDiv(42, OwnerForm.CurrentPPI, 96);
    CloseButton.Caption := Tr('Schließen');
    CloseButton.ModalResult := mrOk;
    CloseButton.Cancel := True;
    Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

// Arbeitsbereich-Dialoge mit eigenen DPI-gerechten Abmessungen statt
// der festen Groessen der Standard-InputQuery/MessageDlg-Fenster.
function WorkspaceDialog(AOwner: TForm; const ATitle, AText: string;
  AConfirm: Boolean; AInput: Boolean; var AValue: string; ADesign: Integer): Integer;
var
  Dialog: TForm;
  Heading, Info: TLabel;
  Edit: TEdit;
  AcceptButton, CancelButton: TButton;
  D, Margin, Gap, ContentW, TextH, ButtonW, ButtonH, Y, TotalW: Integer;
  R: TRect;
  Flags: Cardinal;
  S: string;
  BackColor, ForeColor: TColor;
begin
  Result := mrCancel;
  Dialog := TForm.CreateNew(AOwner);
  try
    D := AOwner.CurrentPPI;
    if D < 96 then D := 96;
    Dialog.Scaled := False; // Alle Abmessungen werden genau einmal mit D skaliert.
    Dialog.BorderStyle := bsDialog;
    Dialog.BorderIcons := [biSystemMenu];
    Dialog.Position := poOwnerFormCenter;
    Dialog.Caption := Tr(ATitle);
    Dialog.Font.Name := 'Segoe UI';
    Dialog.Font.Size := 11;
    case ADesign of
      1: begin BackColor := RGB(229,236,246); ForeColor := RGB(35,48,65); end;
      3: begin BackColor := RGB(232,232,232); ForeColor := clBlack; end;
      5: begin BackColor := RGB(220,233,247); ForeColor := RGB(24,55,88); end;
    else begin BackColor := clWhite; ForeColor := clWindowText; end;
    end;
    Dialog.Color := BackColor;
    Dialog.Font.Color := ForeColor;
    Margin := MulDiv(24, D, 96);
    Gap := MulDiv(14, D, 96);
    ContentW := MulDiv(460, D, 96);
    TotalW := ContentW + 2 * Margin;
    Dialog.ClientWidth := TotalW;

    Heading := TLabel.Create(Dialog);
    Heading.Parent := Dialog;
    Heading.SetBounds(Margin, Margin, ContentW, MulDiv(32, D, 96));
    Heading.AutoSize := False;
    Heading.Font.Name := 'Segoe UI Semibold';
    Heading.Font.Size := 15;
    Heading.Caption := Tr(ATitle);
    Heading.Font.Color := ForeColor;

    Info := TLabel.Create(Dialog);
    Info.Parent := Dialog;
    Info.AutoSize := False;
    Info.WordWrap := True;
    Info.Font.Size := 11;
    Info.Caption := Tr(AText);
    Info.Font.Color := ForeColor;
    Dialog.Canvas.Font.Assign(Info.Font);
    R := Rect(0, 0, ContentW, 0);
    Flags := DT_WORDBREAK or DT_CALCRECT or DT_NOPREFIX;
    S := Info.Caption;
    DrawText(Dialog.Canvas.Handle, PChar(S), Length(S), R, Flags);
    TextH := R.Bottom - R.Top + MulDiv(6, D, 96);
    if TextH < MulDiv(36, D, 96) then TextH := MulDiv(36, D, 96);
    Info.SetBounds(Margin, Heading.Top + Heading.Height + Gap,
      ContentW, TextH);
    Y := Info.Top + Info.Height + Gap;

    Edit := nil;
    if AInput then
    begin
      Edit := TEdit.Create(Dialog);
      Edit.Parent := Dialog;
      Edit.Font.Size := 11;
      Edit.SetBounds(Margin, Y, ContentW, MulDiv(36, D, 96));
      Edit.Text := AValue;
      Y := Edit.Top + Edit.Height + Gap;
    end;

    ButtonW := MulDiv(118, D, 96);
    ButtonH := MulDiv(38, D, 96);
    Dialog.ClientHeight := Y + ButtonH + Margin;
    AcceptButton := TPDFDesignButton.Create(Dialog);
    AcceptButton.Parent := Dialog;
    // Primäre Aktion links, alternative Aktion rechts (übliche Dialogreihenfolge).
    AcceptButton.SetBounds(TotalW - Margin - 2 * ButtonW - Gap,
      Y, ButtonW, ButtonH);
    if AConfirm then AcceptButton.Caption := Tr('Ja')
    else if AInput then AcceptButton.Caption := 'OK'
    else AcceptButton.Caption := 'OK';
    if AConfirm then AcceptButton.ModalResult := mrYes
    else AcceptButton.ModalResult := mrOk;
    AcceptButton.Default := True;
    // ESC schliesst reine Hinweisdialoge wie ein Klick auf OK.
    // Bei Eingabe- und Bestaetigungsdialogen bleibt Abbrechen/Nein erhalten.
    AcceptButton.Cancel := not (AConfirm or AInput);
    TPDFDesignButton(AcceptButton).SetDesign(ADesign);

    if AConfirm or AInput then
    begin
      CancelButton := TPDFDesignButton.Create(Dialog);
      CancelButton.Parent := Dialog;
      CancelButton.SetBounds(AcceptButton.Left + ButtonW + Gap,
        Y, ButtonW, ButtonH);
      if AConfirm then CancelButton.Caption := Tr('Nein')
      else CancelButton.Caption := Tr('Abbrechen');
      if AConfirm then CancelButton.ModalResult := mrNo
      else CancelButton.ModalResult := mrCancel;
      CancelButton.Cancel := True;
      TPDFDesignButton(CancelButton).SetDesign(ADesign);
    end;
    if AInput then Dialog.ActiveControl := Edit
    else Dialog.ActiveControl := AcceptButton;
    Result := Dialog.ShowModal;
    if AInput and (Result = mrOk) then AValue := Edit.Text;
  finally
    Dialog.Free;
  end;
end;


// Im Installationsordner von FreePDF64 werden die eigenständigen
// Viewer-Optionen ausgeblendet; außerhalb bleibt alles unverändert.
function RunningAlongsideFreePDF64: Boolean;
begin
  Result := FileExists(IncludeTrailingPathDelimiter(
    ExtractFilePath(ParamStr(0))) + 'FreePDF64.exe');
end;



const
  LOCAL_TAB_SEARCH_HOTKEY_ID = $5A71;
  LOCAL_TEXT_SEARCH_HOTKEY_ID = $5A72;
  PDFTabWindowMarker = 'FreePDF64.Portable.PDFTabs.Window.v1';
  PDFTabMessageId = $46504450;
  PDFCreatedMessageId = $46504451;
  MainProgramWindowMarker = 'FreePDF64.MainProgram.Window.v1';

function FindMainWindowCallback(Wnd: HWND; Data: LPARAM): BOOL; stdcall;
begin
  Result := True;
  if GetProp(Wnd, PChar(MainProgramWindowMarker)) <> 0 then
  begin
    PHandle(Data)^ := Wnd;
    Result := False;
  end;
end;

function ActivateRunningMainProgram: Boolean;
var
  Wnd: HWND;
  TargetPID: DWORD;
begin
  Wnd := 0;
  EnumWindows(@FindMainWindowCallback, LPARAM(@Wnd));
  Result := (Wnd <> 0) and IsWindow(Wnd);
  if not Result then
    Exit;

  // Dem Hauptprogramm die Vordergrundaktivierung gestatten.
  // Die eigentliche Aktivierung erfolgt in dessen Nachrichten-Thread.
  TargetPID := 0;
  GetWindowThreadProcessId(Wnd, @TargetPID);
  if TargetPID <> 0 then
    AllowSetForegroundWindow(TargetPID);
  PostMessage(Wnd, WM_APP + 194, 0, 0);
end;

procedure MarkMainProgramWindow(Wnd: HWND);
begin
  if Wnd <> 0 then
    SetProp(Wnd, PChar(MainProgramWindowMarker), THandle(1));
end;


function FindTabsWindowCallback(Wnd: HWND; Data: LPARAM): BOOL; stdcall;
begin
  Result := True;
  if GetProp(Wnd, PChar(PDFTabWindowMarker)) <> 0 then
  begin
    PPointer(Data)^ := Pointer(Wnd);
    Result := False;
  end;
end;

type
  PExternalPDFWindowSearch = ^TExternalPDFWindowSearch;
  TExternalPDFWindowSearch = record
    Wnd: HWND;
    CurrentPID: DWORD;
  end;

function FindExternalTabsWindowCallback(Wnd: HWND; Data: LPARAM): BOOL; stdcall;
var
  Search: PExternalPDFWindowSearch;
  PID: DWORD;
begin
  Result := True;
  Search := PExternalPDFWindowSearch(Data);
  if GetProp(Wnd, PChar(PDFTabWindowMarker)) = 0 then Exit;
  PID := 0;
  GetWindowThreadProcessId(Wnd, @PID);
  if (PID <> 0) and (PID <> Search^.CurrentPID) then
  begin
    Search^.Wnd := Wnd;
    Result := False;
  end;
end;

function SendPDFToExternalTabs(const AFileName: string): Boolean;
var
  Search: TExternalPDFWindowSearch;
  Data: TCopyDataStruct;
  Path: string;
  Reply: DWORD_PTR;
  TargetPID: DWORD;
begin
  Result := False;
  Search.Wnd := 0;
  Search.CurrentPID := GetCurrentProcessId;
  EnumWindows(@FindExternalTabsWindowCallback, LPARAM(@Search));
  if (Search.Wnd = 0) or not IsWindow(Search.Wnd) then Exit;
  Path := ExpandFileName(AFileName);
  if not FileExists(Path) then Exit;
  Data.dwData := PDFCreatedMessageId;
  Data.cbData := (Length(Path) + 1) * SizeOf(Char);
  Data.lpData := PChar(Path);
  TargetPID := 0;
  GetWindowThreadProcessId(Search.Wnd, @TargetPID);
  if TargetPID <> 0 then AllowSetForegroundWindow(TargetPID);
  // Bei der PDF-Erstellung erst NACH Abschluss aller Hauptfenster-
  // Aktualisierungen aktivieren, sonst holt FreePDF64 sich den Fokus zurueck.
  Reply := 0;
  Result := (SendMessageTimeout(Search.Wnd, WM_COPYDATA, 0,
    LPARAM(@Data), SMTO_ABORTIFHUNG or SMTO_BLOCK, 4000, @Reply) <> 0)
    and (Reply = 1);
end;

procedure ActivateExternalCreatedPDFViewer;
var
  Search: TExternalPDFWindowSearch;
begin
  Search.Wnd := 0;
  Search.CurrentPID := GetCurrentProcessId;
  EnumWindows(@FindExternalTabsWindowCallback, LPARAM(@Search));
  if (Search.Wnd = 0) or not IsWindow(Search.Wnd) then Exit;
  if IsIconic(Search.Wnd) then ShowWindow(Search.Wnd, SW_RESTORE);
  SetWindowPos(Search.Wnd, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  SetWindowPos(Search.Wnd, HWND_NOTOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  SetForegroundWindow(Search.Wnd);
end;

function ActivateExistingPortableViewer: Boolean;
var
  Wnd: HWND;
  TargetPID: DWORD;
begin
  Wnd := 0;
  EnumWindows(@FindTabsWindowCallback, LPARAM(@Wnd));
  Result := (Wnd <> 0) and IsWindow(Wnd);
  if not Result then Exit;
  TargetPID := 0;
  GetWindowThreadProcessId(Wnd, @TargetPID);
  if TargetPID <> 0 then AllowSetForegroundWindow(TargetPID);
  ShowWindow(Wnd, SW_RESTORE);
  SetForegroundWindow(Wnd);
end;

function SendPDFToExistingTabs(const AFileName: string): Boolean;
var
  Wnd: HWND;
  Data: TCopyDataStruct;
  Path: string;
  Reply: DWORD_PTR;
begin
  Result := False;
  Wnd := 0;
  EnumWindows(@FindTabsWindowCallback, LPARAM(@Wnd));
  if Wnd = 0 then Exit;
  Path := ExpandFileName(AFileName);
  Data.dwData := PDFTabMessageId;
  Data.cbData := (Length(Path) + 1) * SizeOf(Char);
  Data.lpData := PChar(Path);
  Reply := 0;
  Result := SendMessageTimeout(Wnd, WM_COPYDATA, 0, LPARAM(@Data),
    SMTO_ABORTIFHUNG or SMTO_BLOCK, 4000, @Reply) <> 0;
  Result := Result and (Reply = 1);
end;

procedure TPDFTabsForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Kein Owner-Fenster: andernfalls bleibt das PDF-Fenster
  // vor dem FreePDF64-Hauptfenster (Windows-Z-Order).
  Params.WndParent := 0;
  Params.Style := Params.Style or WS_CLIPCHILDREN;
  // WS_MINIMIZE hier NICHT setzen: das stoert VCL-Layout und OnShow.
  Params.ExStyle := Params.ExStyle or WS_EX_APPWINDOW;
  Params.ExStyle := Params.ExStyle and not WS_EX_TOPMOST;
end;

procedure TPDFTabsForm.AlignHelpMenuRight;
var
  Info: TMenuItemInfo;
  I: Integer;
  MenuHandle: HMENU;
begin
  if (FHelpMainMenu = nil) or not HandleAllocated then Exit;
  // Sichtbare Position suchen: ausgeblendete VCL-Menuepunkte haben
  // keinen Eintrag im nativen Windows-Menue.
  MenuHandle := GetMenu(Handle);
  if MenuHandle = 0 then Exit;
  for I := 0 to GetMenuItemCount(MenuHandle) - 1 do
  begin
    FillChar(Info, SizeOf(Info), 0);
    Info.cbSize := SizeOf(Info);
    Info.fMask := MIIM_SUBMENU or MIIM_FTYPE;
    if GetMenuItemInfo(MenuHandle, I, True, Info) and
       (Info.hSubMenu = FHelpMainMenu.Items[FHelpMainMenu.Items.Count - 1].Handle) then
    begin
      if (Info.fType and MFT_RIGHTJUSTIFY) = 0 then
      begin
        Info.fMask := MIIM_FTYPE;
        Info.fType := Info.fType or MFT_RIGHTJUSTIFY;
        SetMenuItemInfo(MenuHandle, I, True, Info);
        DrawMenuBar(Handle);
      end;
      Break;
    end;
  end;
end;

procedure TPDFTabsForm.WMInitMenu(var Msg: TMessage);
begin
  inherited;
  AlignHelpMenuRight;
end;

procedure TPDFTabsForm.CreateWnd;
begin
  inherited CreateWnd;
  // Das Hauptfenster erhält ausdrücklich das Programmsymbol.
  // Bei MainFormOnTaskbar verwendet Windows das Fenstersymbol.
  Icon.Assign(Application.Icon);
  SendMessage(Handle, WM_SETICON, ICON_BIG, LPARAM(Icon.Handle));
  SendMessage(Handle, WM_SETICON, ICON_SMALL, LPARAM(Icon.Handle));
  SetProp(Handle, PChar(PDFTabWindowMarker), THandle(1));
  AlignHelpMenuRight;
end;

procedure TPDFTabsForm.DestroyWnd;
begin
  if HandleAllocated then
  begin
    RemoveProp(Handle, PChar(PDFTabWindowMarker));
  end;
  inherited DestroyWnd;
end;

procedure TPDFTabsForm.WMCopyData(var Msg: TWMCopyData);
var
  FileName: string;
begin
  Msg.Result := 0;
  if (Msg.CopyDataStruct = nil) or
     ((Msg.CopyDataStruct^.dwData <> PDFTabMessageId) and
      (Msg.CopyDataStruct^.dwData <> PDFCreatedMessageId)) or
     (Msg.CopyDataStruct^.lpData = nil) or
     (Msg.CopyDataStruct^.cbData < 2 * SizeOf(Char)) or
     (Msg.CopyDataStruct^.cbData mod SizeOf(Char) <> 0) then Exit;
  SetString(FileName, PChar(Msg.CopyDataStruct^.lpData),
    Msg.CopyDataStruct^.cbData div SizeOf(Char) - 1);
  if not (SameText(ExtractFileExt(FileName), '.pdf') or
          SameText(ExtractFileExt(FileName), '.jpg') or
          SameText(ExtractFileExt(FileName), '.jpeg') or
          SameText(ExtractFileExt(FileName), '.png') or
          SameText(ExtractFileExt(FileName), '.bmp') or
          SameText(ExtractFileExt(FileName), '.tif') or
          SameText(ExtractFileExt(FileName), '.tiff')) or
     not FileExists(FileName) then Exit;
  // Niemals im synchronen WM_COPYDATA-Handler PDFium-Forms erstellen.
  FPendingExplorerFiles.Add(FileName);
  // Explorer uebergibt mehrere markierte PDFs oft als einzelne WM_COPYDATA-
  // Nachrichten. Erst nach einer kurzen Empfangspause den Stapel verarbeiten.
  FExplorerBatchTimer.Enabled := False;
  FExplorerBatchTimer.Enabled := True;
  // Nur bei normalen Oeffnungen sofort aktivieren. Bei erstellten
  // PDFs aktiviert das Hauptprogramm erst ganz am Ende den Viewer.
  if Msg.CopyDataStruct^.dwData = PDFTabMessageId then
    BringViewerToForeground;
  Msg.Result := 1;
end;

procedure TPDFTabsForm.QueueCreatedPDFForeground;
begin
  // Keine verzoegerte Aktivierung: vermeidet sichtbares Nach-vorne-Springen.
  FCreatedPDFForegroundTimer.Enabled := False;
end;

procedure TPDFTabsForm.CreatedPDFForegroundTimerTick(Sender: TObject);
begin
  FCreatedPDFForegroundTimer.Enabled := False;
  if (FTabs <> nil) and (FTabs.PageCount > 0) then
    BringViewerToForeground;
end;

procedure TPDFTabsForm.ExplorerBatchTimerTick(Sender: TObject);
begin
  FExplorerBatchTimer.Enabled := False;
  if FPendingExplorerFiles.Count > 0 then
    PostMessage(Handle, WM_APP + 192, 0, 0);
end;

function TPDFTabsForm.ActivateExistingPDF(const AFileName: string): Boolean;
var
  I: Integer;
  Tab: TTabSheet;
  FullName: string;
begin
  Result := False;
  if FTabs = nil then Exit;
  FullName := ExpandFileName(AFileName);
  for I := 0 to FTabs.PageCount - 1 do
  begin
    Tab := FTabs.Pages[I];
    if SameText(ExpandFileName(Tab.Hint), FullName) then
    begin
      FTabs.ActivePage := Tab;
      if not Visible then Show;
      if IsIconic(Handle) then ShowWindow(Handle, SW_RESTORE);
      PostMessage(Handle, WM_APP + 193, 0, 0);
      BringViewerToForeground;
      Result := True;
      Exit;
    end;
  end;
end;

procedure TPDFTabsForm.WMOpenQueuedPDF(var Msg: TMessage);
var
  FileName: string;
  PDF: TPDFBrowserForm;
  LastOpenedPDF: TPDFBrowserForm;
begin
  // Bereits wartende Explorer-Nachrichten vor dem Anlegen verarbeiten.
  // Der Timer sorgt dafuer, dass ein zusammengehoeriger Dateistapel
  // gesammelt wird, bevor die erste PDFium-Instanz starten kann.
  FExplorerBatchTimer.Enabled := False;
  LastOpenedPDF := nil;
  BeginMultiPDFLoad;
  try
  while FPendingExplorerFiles.Count > 0 do
  begin
    FileName := FPendingExplorerFiles[0];
    FPendingExplorerFiles.Delete(0);
    if not FileExists(FileName) then Continue;
    if ActivateExistingPDF(FileName) then Continue;
    PDF := nil;
    try
      PDF := TPDFBrowserForm.Create(nil);
      PDF.OnGlobalSearch := GlobalSearchClick;
      PDF.PDFFileName := FileName;
      PDF.StandalonePDFMode := False;
      AddPDF(PDF);
      LastOpenedPDF := PDF;
    except
      on E: Exception do
      begin
        // AddPDF kann das Formular bereits einem Tab zugeordnet haben.
        if (PDF <> nil) and (PDF.Parent = nil) then PDF.Free;
      end;
    end;
  end;
  finally
    EndMultiPDFLoad;
  end;
  // Die zuletzt per Explorer empfangene PDF sichtbar machen.
  // Erst nach dem Abarbeiten der Warteschlange aktivieren.
  if LastOpenedPDF <> nil then
    ActivatePDF(LastOpenedPDF);
  if LastOpenedPDF <> nil then
  begin
    BringViewerToForeground;
  end;
end;

function TabsIniFileName: string;
begin
  // Alle Viewer-Einstellungen in der gemeinsamen INI im Programmverzeichnis.
  Result := ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini';
end;

procedure TPDFTabsForm.RememberNormalBounds;
begin
  if not FRestoringWindowSettings and not FInitialWindowOffscreen and
      HandleAllocated and Visible and
     (WindowState = wsNormal) and (Width > 200) and (Height > 150) then
    FLastNormalBounds := BoundsRect;
end;

procedure TPDFTabsForm.LoadWindowSettings;
var
  Ini: TIniFile;
  L, T, W, H: Integer;
  R: TRect;
begin
  FRestoringWindowSettings := True;
  try
    Ini := TIniFile.Create(TabsIniFileName);
    try
      W := Ini.ReadInteger('PDFTabsFenster', 'Breite', 1100);
      H := Ini.ReadInteger('PDFTabsFenster', 'Hoehe', 800);
      L := Ini.ReadInteger('PDFTabsFenster', 'Links', (Screen.Width - W) div 2);
      T := Ini.ReadInteger('PDFTabsFenster', 'Oben', (Screen.Height - H) div 2);
      W := EnsureRange(W, 450, Screen.DesktopWidth);
      H := EnsureRange(H, 300, Screen.DesktopHeight);
      R := Rect(L, T, L + W, T + H);
      if not IntersectRect(R, R, Screen.DesktopRect) then
      begin
        L := (Screen.Width - W) div 2;
        T := (Screen.Height - H) div 2;
      end;
      WindowState := wsNormal;
      Position := poDesigned;
      SetBounds(L, T, W, H);
      FLastNormalBounds := BoundsRect;
      if Ini.ReadBool('PDFTabsFenster', 'Maximiert', False) then
        WindowState := wsMaximized;
    finally
      Ini.Free;
    end;
  finally
    FRestoringWindowSettings := False;
  end;
end;

function ViewerVersionString: string;
var
  Dummy, Size: DWORD;
  Buf: TBytes;
  Info: PVSFixedFileInfo;
  InfoPtr: Pointer;
  InfoLen: UINT;
begin
  Result := '0.0.0.0';
  Size := GetFileVersionInfoSize(PChar(Application.ExeName), Dummy);
  if Size = 0 then Exit;
  SetLength(Buf, Size);
  if GetFileVersionInfo(PChar(Application.ExeName), 0, Size, @Buf[0]) and
     VerQueryValue(@Buf[0], '\', InfoPtr, InfoLen) and
     (InfoLen >= SizeOf(TVSFixedFileInfo)) then
  begin
    Info := PVSFixedFileInfo(InfoPtr);
    Result := Format('%d.%d.%d.%d',
      [HiWord(Info.dwFileVersionMS), LoWord(Info.dwFileVersionMS),
       HiWord(Info.dwFileVersionLS), LoWord(Info.dwFileVersionLS)]);
  end;
end;

function NewerViewerVersion(const RemoteTag, LocalVersion: string): Boolean;
var
  A, B: TArray<string>;
  I, N, R, L: Integer;
  Remote: string;
begin
  Result := False;
  Remote := Trim(RemoteTag);
  if (Remote <> '') and (UpCase(Remote[1]) = 'V') then
    Delete(Remote, 1, 1);
  // Only numeric stable releases are compared automatically.
  for I := 1 to Length(Remote) do
    if not CharInSet(Remote[I], ['0'..'9', '.']) then Exit;
  A := Remote.Split(['.']);
  B := LocalVersion.Split(['.']);
  N := Max(Length(A), Length(B));
  for I := 0 to N - 1 do
  begin
    R := 0; L := 0;
    if (I < Length(A)) and not TryStrToInt(A[I], R) then Exit;
    if (I < Length(B)) and not TryStrToInt(B[I], L) then Exit;
    if R > L then Exit(True);
    if R < L then Exit(False);
  end;
end;

procedure TPDFTabsForm.UpdateAutoClick(Sender: TObject);
var
  Ini: TIniFile;
begin
  FUpdateAutoMenuItem.Checked := not FUpdateAutoMenuItem.Checked;
  Ini := TIniFile.Create(TabsIniFileName);
  try
    Ini.WriteBool('Updates', 'Automatic', FUpdateAutoMenuItem.Checked);
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.UpdateManualClick(Sender: TObject);
begin
  StartUpdateCheck(True);
end;

procedure TPDFTabsForm.UpdateStartupTick(Sender: TObject);
var
  Ini: TIniFile;
  Last: TDateTime;
begin
  FUpdateStartupTimer.Enabled := False;
  Ini := TIniFile.Create(TabsIniFileName);
  try
    if not Ini.ReadBool('Updates', 'Automatic', True) then Exit;
    Last := Ini.ReadDateTime('Updates', 'LastCheck', 0);
    if (Last > 0) and (Now - Last < 7) then Exit;
  finally
    Ini.Free;
  end;
  StartUpdateCheck(False);
end;

// Eigenes DPI-skaliertes Updatefenster (125 % / 250 %), ohne Aenderung
// der Netzwerk- oder Versionsvergleichslogik.
function ShowViewerUpdateDialog(AOwner: TCustomForm; const ATitle,
  AMessage, AInstalled, AAvailable, AQuestion: string;
  AOfferOpen: Boolean; const ADownloadUrl: string = ''): Boolean;
var
  Dlg: TForm;
  HeaderPanel, DividerPanel: TPanel;
  Head, InstalledLabel, AvailableLabel, QuestionLabel: TLabel;
  OpenButton, CancelButton: TButton;
  DownloadEdit: TEdit;
  P, W, H, M, FontSize: Integer;
  function Sc(V: Integer): Integer;
  begin
    Result := MulDiv(V, P, 96);
  end;
begin
  Result := False;
  Dlg := TForm.CreateNew(AOwner);
  try
    Dlg.BorderStyle := bsDialog;
    Dlg.Position := poOwnerFormCenter;
    Dlg.Caption := ATitle;
    Dlg.Font.Assign(AOwner.Font);
    P := AOwner.CurrentPPI;
    if P < 96 then P := 96;
    Dlg.Scaled := False;
    Dlg.Font.Name := 'Segoe UI';
    FontSize := Sc(13);
    Dlg.Font.Height := -FontSize;
    Dlg.Color := clWhite;
    W := Sc(540);
    H := Sc(310);
    M := Sc(26);
    Dlg.ClientWidth := W;
    Dlg.ClientHeight := H;
    Dlg.Constraints.MinWidth := W;
    Dlg.Constraints.MinHeight := H + Sc(35);

    // Ruhiger Kopfbereich mit klarer Hierarchie; alle Maße DPI-skaliert.
    HeaderPanel := TPanel.Create(Dlg);
    HeaderPanel.Parent := Dlg;
    HeaderPanel.SetBounds(0, 0, W, Sc(82));
    HeaderPanel.BevelOuter := bvNone;
    HeaderPanel.Color := $00F5F0E9;
    HeaderPanel.ParentBackground := False;

    Head := TLabel.Create(Dlg);
    Head.Parent := HeaderPanel;
    Head.SetBounds(M, Sc(23), W - 2 * M, Sc(38));
    Head.AutoSize := False;
    Head.Transparent := True;
    Head.Font.Name := 'Segoe UI';
    Head.Font.Height := -Sc(17);
    Head.Font.Style := [fsBold];
    Head.Font.Color := $008B4E1D;
    Head.Caption := AMessage;

    InstalledLabel := TLabel.Create(Dlg);
    InstalledLabel.Parent := Dlg;
    InstalledLabel.SetBounds(M, Sc(107), W - 2 * M, Sc(34));
    InstalledLabel.AutoSize := False;
    InstalledLabel.Font.Height := -FontSize;
    InstalledLabel.Font.Color := clWindowText;
    InstalledLabel.Caption := AInstalled;

    AvailableLabel := TLabel.Create(Dlg);
    AvailableLabel.Parent := Dlg;
    AvailableLabel.SetBounds(M, Sc(149), W - 2 * M, Sc(36));
    AvailableLabel.AutoSize := False;
    AvailableLabel.Font.Height := -FontSize;
    AvailableLabel.Font.Style := [fsBold];
    AvailableLabel.Font.Color := $008B4E1D;
    AvailableLabel.Caption := AAvailable;

    QuestionLabel := TLabel.Create(Dlg);
    QuestionLabel.Parent := Dlg;
    QuestionLabel.SetBounds(M, Sc(192), W - 2 * M, Sc(25));
    QuestionLabel.AutoSize := False;
    QuestionLabel.Font.Height := -FontSize;
    QuestionLabel.Caption := AQuestion;

    // Direkter Downloadlink der neuen Version, sichtbar und kopierbar.
    if ADownloadUrl <> '' then
    begin
      DownloadEdit := TEdit.Create(Dlg);
      DownloadEdit.Parent := Dlg;
      DownloadEdit.SetBounds(M, Sc(220), W - 2 * M, Sc(24));
      DownloadEdit.ReadOnly := True;
      DownloadEdit.TabStop := True;
      DownloadEdit.Text := ADownloadUrl;
      DownloadEdit.Hint := ADownloadUrl;
      DownloadEdit.ShowHint := True;
    end;

    DividerPanel := TPanel.Create(Dlg);
    DividerPanel.Parent := Dlg;
    DividerPanel.SetBounds(M, Sc(248), W - 2 * M, Sc(1));
    DividerPanel.BevelOuter := bvNone;
    DividerPanel.Color := $00E2E2E2;
    DividerPanel.ParentBackground := False;

    CancelButton := TButton.Create(Dlg);
    CancelButton.Parent := Dlg;
    CancelButton.SetBounds(W - M - Sc(130), H - Sc(52), Sc(130), Sc(38));
    CancelButton.Font.Height := -Sc(11);
    CancelButton.Caption := 'OK';
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;

    if AOfferOpen then
    begin
      CancelButton.Caption := 'Abbrechen';
      if SameText(PDFLanguage, 'en') then CancelButton.Caption := 'Cancel';
      OpenButton := TButton.Create(Dlg);
      OpenButton.Parent := Dlg;
      OpenButton.SetBounds(W - M - Sc(300), H - Sc(52), Sc(158), Sc(38));
      OpenButton.Font.Height := -Sc(11);
      if ADownloadUrl <> '' then
      begin
        if SameText(PDFLanguage, 'en') then OpenButton.Caption := 'Download'
        else OpenButton.Caption := 'Herunterladen';
      end
      else if SameText(PDFLanguage, 'en') then OpenButton.Caption := 'Open GitHub'
      else OpenButton.Caption := 'GitHub öffnen';
      OpenButton.ModalResult := mrOk;
      OpenButton.Default := True;
    end
    else
      CancelButton.Default := True;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

function ViewerUpdateText(AEnglish: Boolean; const AEnglishText, AGermanText: string): string;
begin
  if AEnglish then
    Result := AEnglishText
  else
    Result := AGermanText;
end;

procedure TPDFTabsForm.StartUpdateCheck(AManual: Boolean);
begin
  if FUpdateCheckBusy then Exit;
  FUpdateCheckBusy := True;
  TThread.CreateAnonymousThread(
    procedure
    var
      Http: THTTPClient;
      Response: IHTTPResponse;
      Root: TJSONValue;
      Tag, Url, DownloadUrl, ErrorText: string;
      Assets: TJSONValue;
      Asset: TJSONValue;
      AssetName, AssetUrl: string;
      I: Integer;
      Success: Boolean;
    begin
      Tag := ''; Url := ''; DownloadUrl := ''; ErrorText := ''; Success := False;
      Http := THTTPClient.Create;
      try
        Http.ConnectionTimeout := 5000;
        Http.ResponseTimeout := 8000;
        Http.UserAgent := 'FreePDF64-Viewer-Portable';
        try
          Response := Http.Get('https://api.github.com/repos/FreePDF64/FreePDF64ViewerPortable/releases/latest');
          if Response.StatusCode <> 200 then
            raise Exception.Create('GitHub HTTP ' + IntToStr(Response.StatusCode));
          Root := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
          try
            if not (Root is TJSONObject) then
              raise Exception.Create('Invalid GitHub response');
            Tag := TJSONObject(Root).GetValue<string>('tag_name', '');
            Url := TJSONObject(Root).GetValue<string>('html_url', '');
            if (Tag = '') or (Url = '') or
               not Url.StartsWith('https://github.com/FreePDF64/FreePDF64ViewerPortable/releases/') then
              raise Exception.Create('Invalid release data');
            // GitHub-Release-Asset statt nur Release-Seite anbieten.
            Assets := TJSONObject(Root).GetValue('assets');
            if Assets is TJSONArray then
              for I := 0 to TJSONArray(Assets).Count - 1 do
              begin
                Asset := TJSONArray(Assets).Items[I];
                if not (Asset is TJSONObject) then Continue;
                AssetName := TJSONObject(Asset).GetValue<string>('name', '');
                AssetUrl := TJSONObject(Asset).GetValue<string>('browser_download_url', '');
                if SameText(ExtractFileExt(AssetName), '.zip') and
                   AssetUrl.StartsWith('https://github.com/FreePDF64/FreePDF64ViewerPortable/releases/download/') then
                begin
                  DownloadUrl := AssetUrl;
                  Break;
                end;
              end;
            Success := True;
          finally
            Root.Free;
          end;
        except
          on E: Exception do ErrorText := E.Message;
        end;
      finally
        Http.Free;
      end;
      TThread.Synchronize(nil, TThreadProcedure(
        procedure
        var
          Ini: TIniFile;
          MsgText: string;
        begin
          if PDFTabsWindow = nil then Exit;
          PDFTabsWindow.FUpdateCheckBusy := False;
          if Success then
          begin
            Ini := TIniFile.Create(TabsIniFileName);
            try
              Ini.WriteDateTime('Updates', 'LastCheck', Now);
            finally
              Ini.Free;
            end;
            if NewerViewerVersion(Tag, ViewerVersionString) then
            begin
              if PDFLanguage = 'en' then
                MsgText := 'A new version is available.' + sLineBreak + sLineBreak +
                  'Installed version: ' + ViewerVersionString + sLineBreak +
                  'Available version: ' + Tag + sLineBreak + sLineBreak +
                  'Open GitHub Releases?'
              else
                MsgText := 'Eine neue Version ist verfügbar.' + sLineBreak + sLineBreak +
                  'Installierte Version: ' + ViewerVersionString + sLineBreak +
                  'Verfügbare Version: ' + Tag + sLineBreak + sLineBreak +
                  'GitHub Releases öffnen?';
              if ShowViewerUpdateDialog(PDFTabsWindow,
                   'FreePDF64-Viewer Portable',
                   ViewerUpdateText(SameText(PDFLanguage, 'en'),
                     'A new version is available.', 'Eine neue Version ist verfügbar.'),
                   ViewerUpdateText(SameText(PDFLanguage, 'en'), 'Installed version: ',
                     'Installierte Version: ') + ViewerVersionString,
                   ViewerUpdateText(SameText(PDFLanguage, 'en'), 'Available version: ',
                     'Verfügbare Version: ') + Tag,
                   ViewerUpdateText(SameText(PDFLanguage, 'en'), 'Open download page on GitHub?',
                     'Downloadseite auf GitHub öffnen?'), True, DownloadUrl) then
              begin
                if DownloadUrl <> '' then
                  ShellExecute(0, 'open', PChar(DownloadUrl), nil, nil, SW_SHOWNORMAL)
                else
                  ShellExecute(0, 'open', PChar(Url), nil, nil, SW_SHOWNORMAL);
              end;
            end
            else if AManual then
            begin
              if PDFLanguage = 'en' then MsgText := 'You are using the latest version.'
              else MsgText := 'Du verwendest die aktuelle Version.';
              MessageDlg(MsgText, mtInformation, [mbOK], 0);
            end;
          end
          else if AManual then
          begin
            if Pos('GitHub HTTP 503', ErrorText) > 0 then
            begin
              if PDFLanguage = 'en' then
                MsgText := 'The update check could not be completed.' + sLineBreak +
                  sLineBreak + 'GitHub is temporarily unavailable (HTTP 503).' +
                  sLineBreak + sLineBreak + 'Please try again later.'
              else
                MsgText := 'Die Updateprüfung konnte nicht abgeschlossen werden.' +
                  sLineBreak + sLineBreak +
                  'GitHub ist vorübergehend nicht erreichbar (HTTP 503).' +
                  sLineBreak + sLineBreak +
                  'Bitte versuchen Sie es später erneut.';
              MessageDlg(MsgText, mtInformation, [mbOK], 0);
            end
            else
            begin
              if PDFLanguage = 'en' then MsgText := 'Update check failed: '
              else MsgText := 'Updateprüfung fehlgeschlagen: ';
              MessageDlg(MsgText + ErrorText, mtWarning, [mbOK], 0);
            end;
          end;
        end));
    end).Start;
end;

procedure TPDFTabsForm.TabsFormShow(Sender: TObject);
begin

  DragAcceptFiles(Handle, True);
  if not FUpdateStartupTimer.Enabled then
    FUpdateStartupTimer.Enabled := True;
  // Willkommensseite immer initialisieren, auch bei minimiertem Start.
  UpdateWelcomeView;
  if FStartupMinimizePending then
    PostMessage(Handle, WM_APP + 198, 0, 0);
  // Fensterzustand wurde bereits im Konstruktor vor dem ersten Anzeigen
  // aus der INI geladen. Keine erneute Normal-/Maximiert-Umschaltung.
end;

procedure TPDFTabsForm.ApplyShownWindowSettings(var Msg: TMessage);
begin
  if not Visible or FInitialWindowOffscreen then Exit;
  if FStartupMinimizePending then Exit;
  // Ein bereits minimiert gestartetes Fenster darf nicht erneut durch
  // LoadWindowSettings auf Normal/Maximiert gesetzt werden.
  if WindowState = wsMinimized then Exit;
  LoadWindowSettings;
  // Nach der VCL-Initialisierung die tatsächliche Fenstergeometrie setzen.
  if WindowState = wsMaximized then
    ShowWindow(Handle, SW_SHOWMAXIMIZED)
  else
    SetWindowPos(Handle, 0, Left, Top, Width, Height,
      SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure TPDFTabsForm.SaveWindowSettings;
var
  Ini: TIniFile;
  R: TRect;
begin
  R := FLastNormalBounds;
  if (WindowState = wsNormal) and not FInitialWindowOffscreen then
    R := BoundsRect;
  if (R.Right - R.Left < 450) or (R.Bottom - R.Top < 300) then
    R := Rect(Left, Top, Left + 1100, Top + 800);
  Ini := TIniFile.Create(TabsIniFileName);
  try
    Ini.WriteInteger('PDFTabsFenster', 'Links', R.Left);
    Ini.WriteInteger('PDFTabsFenster', 'Oben', R.Top);
    Ini.WriteInteger('PDFTabsFenster', 'Breite', R.Right - R.Left);
    Ini.WriteInteger('PDFTabsFenster', 'Hoehe', R.Bottom - R.Top);
    Ini.WriteBool('PDFTabsFenster', 'Maximiert', WindowState = wsMaximized);
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.OpenPDFClick(Sender: TObject);
var
  Dialog: TFileOpenDialog;
  I: Integer;
  PDF: TPDFBrowserForm;
  LastOpenedPDF: TPDFBrowserForm;
  ActiveTab: TTabSheet;
  ActivePDF: TPDFBrowserForm;
  ActiveDir: string;
  J: Integer;
begin
  LastOpenedPDF := nil;
  ActivePDF := nil;
  ActiveDir := '';
  ActiveTab := FTabs.ActivePage;
  if Assigned(ActiveTab) then
    for J := 0 to ActiveTab.ControlCount - 1 do
      if ActiveTab.Controls[J] is TPDFBrowserForm then
      begin
        ActivePDF := TPDFBrowserForm(ActiveTab.Controls[J]);
        Break;
      end;
  if Assigned(ActivePDF) and (ActivePDF.PDFFileName <> '') then
  begin
    ActiveDir := ExtractFilePath(ActivePDF.PDFFileName);
    if not DirectoryExists(ActiveDir) then
      ActiveDir := '';
  end;
  Dialog := TFileOpenDialog.Create(Self);
  try
    Dialog.Title := Tr('Datei(en) öffnen');
    // Ordner der aktiven PDF; ohne PDF oder bei fehlendem Ordner 'Dieser PC'.
    if ActiveDir <> '' then
      Dialog.DefaultFolder := ActiveDir
    else
      Dialog.DefaultFolder := '::{20D04FE0-3AEA-1069-A2D8-08002B30309D}';
    Dialog.FileName := '';
    with Dialog.FileTypes.Add do
    begin
      DisplayName := 'PDF- und Bilddateien (*.pdf;*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff)';
      FileMask := '*.pdf;*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff';
    end;
    with Dialog.FileTypes.Add do
    begin
      DisplayName := 'Alle Dateien (*.*)';
      FileMask := '*.*';
    end;
    Dialog.Options := Dialog.Options + [fdoFileMustExist, fdoPathMustExist, fdoAllowMultiSelect];
    if not Dialog.Execute then Exit;
    BeginMultiPDFLoad;
    try
      for I := 0 to Dialog.Files.Count - 1 do
    begin
      PDF := TPDFBrowserForm.Create(nil);
      PDF.OnGlobalSearch := GlobalSearchClick;
      try
        PDF.PDFFileName := Dialog.Files[I];
        PDF.StandalonePDFMode := False;
        AddPDF(PDF);
        LastOpenedPDF := PDF;
      except
        PDF.Free;
        raise;
      end;
    end;
    finally
      EndMultiPDFLoad;
    end;
    // Nur bei explizitem "PDF öffnen" zur zuletzt geöffneten PDF wechseln.
    // Stapelimporte aus Suche und Hauptfenster behalten ihre Auswahl.
    if LastOpenedPDF <> nil then
      ActivatePDF(LastOpenedPDF);
  finally
    Dialog.Free;
  end;
end;

procedure TPDFTabsForm.LoadClosedPDFs;
var
  Ini: TIniFile;
  I, Count: Integer;
  FileName: string;
begin
  FClosedPDFs.Clear;
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    Count := Ini.ReadInteger('ClosedPDFs', 'Count', 0);
    if Count < 0 then Count := 0;
    if Count > 20 then Count := 20;
    for I := Count downto 1 do
    begin
      FileName := Trim(Ini.ReadString('ClosedPDFs', 'File' + IntToStr(I), ''));
      if (FileName <> '') and (FClosedPDFs.IndexOf(FileName) < 0) then
        FClosedPDFs.Add(FileName);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.LoadWorkspace;
var
  Ini: TIniFile;
  I, N: Integer;
  S: string;
begin
  FSessionPDFs.Clear;
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    N := Ini.ReadInteger('PDFSession', 'Count', 0);
    if N < 0 then N := 0;
    if N > 200 then N := 200;
    for I := 1 to N do
    begin
      S := Trim(Ini.ReadString('PDFSession', 'File' + IntToStr(I), ''));
      if (S <> '') and (FSessionPDFs.IndexOf(S) < 0) then
        FSessionPDFs.Add(S);
    end;
  finally
    Ini.Free;
  end;
end;

function IsFreePDFTempAttachment(const AFileName: string): Boolean;
begin
  Result := Pos('FreePDF64_Attachment_', ExtractFileName(AFileName)) = 1;
end;

procedure TPDFTabsForm.SaveWorkspace;
var
  Ini: TIniFile;
  Files: TStringList;
  I: Integer;
  S: string;
begin
  Files := TStringList.Create;
  try
    // Registerkarten in ihrer Reihenfolge sichern, auch bei Netzlaufwerken.
    // Keine FileExists-Pruefung: kurzzeitig unerreichbare NAS-Pfade behalten.
    for I := 0 to FTabs.PageCount - 1 do
    begin
      S := Trim(FTabs.Pages[I].Hint);
      if (S <> '') and not IsFreePDFTempAttachment(S) and (Files.IndexOf(S) < 0) then
        Files.Add(S);
    end;
    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      Ini.EraseSection('PDFSession');
      Ini.WriteInteger('PDFSession', 'Count', Files.Count);
      // Aktuelle Seite je Dateipfad speichern; keine Änderung am PDF-Inhalt.
      for I := 0 to FTabs.PageCount - 1 do
        if (Files.IndexOf(FTabs.Pages[I].Hint) >= 0) and
           (WorkspaceBrowserInTab(FTabs.Pages[I]) <> nil) then
          Ini.WriteInteger('PDFSessionPages',
            'Page_' + IntToStr(Files.IndexOf(FTabs.Pages[I].Hint) + 1),
            WorkspaceBrowserInTab(FTabs.Pages[I]).WorkspacePage);
      for I := 0 to Files.Count - 1 do
        Ini.WriteString('PDFSession', 'File' + IntToStr(I + 1), Files[I]);
    finally
      Ini.Free;
    end;
    FSessionPDFs.Assign(Files);
  finally
    Files.Free;
  end;
end;

function TPDFTabsForm.WorkspaceFolder: string;
var
  BaseDir, OldDir, NewDir: string;
begin
  BaseDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  OldDir := BaseDir + 'Arbeitsbereiche';
  NewDir := BaseDir + 'Workspaces';
  // Vorhandene Arbeitsbereiche bei der ersten Verwendung uebernehmen.
  // Falls Workspaces bereits existiert, keine vorhandenen Daten ueberschreiben.
  if DirectoryExists(OldDir) and not DirectoryExists(NewDir) then
    RenameFile(OldDir, NewDir);
  Result := NewDir + PathDelim;
end;

procedure TPDFTabsForm.SaveWorkspaceClick(Sender: TObject);
var
  Name, Path, Id: string;
  Ini: TIniFile;
  G: TGUID;
  I, N: Integer;
  S: string;
  Browser: TPDFBrowserForm;
begin
  if FTabs.PageCount = 0 then
  begin
    WorkspaceDialog(Self, 'Information', 'Es sind keine PDFs geöffnet.', False, False, Name, FDesignIndex);
    Exit;
  end;
  Name := Tr('Arbeitsbereich') + ' ' + FormatDateTime('dd.mm.yyyy hh:nn', Now);
  if WorkspaceDialog(Self, 'Arbeitsbereich speichern', 'Name des Arbeitsbereichs:', False, True, Name, FDesignIndex) <> mrOk then Exit;
  Name := Trim(Name);
  if Name = '' then Exit;
  ForceDirectories(WorkspaceFolder);
  if CreateGUID(G) <> S_OK then Exit;
  Id := GUIDToString(G);
  Id := StringReplace(StringReplace(Id, '{', '', []), '}', '', []);
  Path := WorkspaceFolder + Id + '.ini';
  Ini := TIniFile.Create(Path);
  try
    Ini.WriteString('Info', 'Name', Name);
    Ini.WriteDateTime('Info', 'Created', Now);
    Ini.WriteDateTime('Info', 'Modified', Now);
    N := 0;
    for I := 0 to FTabs.PageCount - 1 do
    begin
      S := Trim(FTabs.Pages[I].Hint);
      if (S = '') or IsFreePDFTempAttachment(S) then Continue;
      Inc(N);
      Ini.WriteString('PDFs', 'File' + IntToStr(N), S);
      Browser := WorkspaceBrowserInTab(FTabs.Pages[I]);
      if Browser <> nil then
      begin
        Ini.WriteInteger('PDFs', 'Page' + IntToStr(N), Browser.WorkspacePage);
        Ini.WriteFloat('PDFs', 'Zoom' + IntToStr(N), Browser.WorkspaceZoom);
        Ini.WriteBool('PDFs', 'Fit' + IntToStr(N), Browser.WorkspaceFit);
        Ini.WriteInteger('PDFs', 'ViewMode' + IntToStr(N), Browser.WorkspaceViewMode);
        Ini.WriteBool('PDFs', 'TwoPage' + IntToStr(N), Browser.WorkspaceTwoPage);
        Ini.WriteBool('PDFs', 'Continuous' + IntToStr(N), Browser.WorkspaceContinuous);
        Ini.WriteBool('PDFs', 'Sidebar' + IntToStr(N), Browser.WorkspaceSidebarVisible);
        Ini.WriteInteger('PDFs', 'ScrollX' + IntToStr(N), Browser.WorkspaceScrollX);
        Ini.WriteInteger('PDFs', 'ScrollY' + IntToStr(N), Browser.WorkspaceScrollY);
        if Browser.IsBasicImage then
        begin
          Ini.WriteFloat('PDFs', 'ImageZoom' + IntToStr(N), Browser.WorkspaceImageZoom);
          Ini.WriteInteger('PDFs', 'ImageFitMode' + IntToStr(N), Browser.WorkspaceImageFitMode);
        end;
      end;
    end;
    Ini.WriteInteger('PDFs', 'Count', N);
    if FTabs.ActivePage <> nil then
      Ini.WriteString('PDFs', 'ActiveFile', FTabs.ActivePage.Hint);
  finally
    Ini.Free;
  end;
  WorkspaceDialog(Self, 'Information', 'Arbeitsbereich „' + Name + '“ gespeichert.', False, False, Name, FDesignIndex);
end;

procedure TPDFTabsForm.OpenWorkspaceFile(const APath: string);
var
  Ini: TIniFile;
  I, N, MissingCount: Integer;
  S, ActiveFile: string;
  PDF: TPDFBrowserForm;
  OpenFiles: TStringList;
  J: Integer;
  LoadErrors: TStringList;
  AddedToTabs: Boolean;
  TargetPDF: TPDFBrowserForm;
  TargetTab: TTabSheet;
begin
  if not FileExists(APath) then Exit;
  Ini := TIniFile.Create(APath);
  OpenFiles := TStringList.Create;
  LoadErrors := TStringList.Create;
  try
    N := Ini.ReadInteger('PDFs', 'Count', 0);
    ActiveFile := Ini.ReadString('PDFs', 'ActiveFile', '');
    if (N < 0) or (N > 200) then Exit;
    for I := 0 to FTabs.PageCount - 1 do
      OpenFiles.Add(FTabs.Pages[I].Hint);
    MissingCount := 0;
    BeginMultiPDFLoad;
    try
    for I := 1 to N do
    begin
      S := Trim(Ini.ReadString('PDFs', 'File' + IntToStr(I), ''));
      if (S = '') or IsFreePDFTempAttachment(S) or (OpenFiles.IndexOf(S) >= 0) then Continue;
      if not FileExists(S) then
      begin
        Inc(MissingCount);
        Continue;
      end;
      PDF := nil;
      AddedToTabs := False;
      try
        PDF := TPDFBrowserForm.Create(nil);
        PDF.OnGlobalSearch := GlobalSearchClick;
        PDF.PDFFileName := S;
        PDF.StartPage := Max(1, Ini.ReadInteger('PDFs', 'Page' + IntToStr(I), 1));
        PDF.SetWorkspaceView(Ini.ReadFloat('PDFs', 'Zoom' + IntToStr(I), 1.0),
          Ini.ReadBool('PDFs', 'Fit' + IntToStr(I), True),
          Ini.ReadInteger('PDFs', 'ScrollX' + IntToStr(I), 0),
          Ini.ReadInteger('PDFs', 'ScrollY' + IntToStr(I), 0));
        PDF.SetWorkspaceLayout(
          Ini.ReadInteger('PDFs', 'ViewMode' + IntToStr(I), 1),
          Ini.ReadBool('PDFs', 'TwoPage' + IntToStr(I), False),
          Ini.ReadBool('PDFs', 'Continuous' + IntToStr(I), True),
          TFreePDF64PDFiumView.GlobalThumbnailsVisible);
        if PDF.IsBasicImage and
           Ini.ValueExists('PDFs', 'ImageZoom' + IntToStr(I)) then
          PDF.SetWorkspaceImageView(
            Ini.ReadFloat('PDFs', 'ImageZoom' + IntToStr(I), 1.0),
            Ini.ReadInteger('PDFs', 'ImageFitMode' + IntToStr(I), 1));

        PDF.StandalonePDFMode := False;
        AddPDF(PDF);
        AddedToTabs := True;
        OpenFiles.Add(S);
      except
        on E: Exception do
        begin
          // Ein Fehler in einem PDF darf den gesamten Arbeitsbereich
          // nicht abbrechen. Bereits eingebettete Formulare gehören
          // der Registerkarte und dürfen hier nicht freigegeben werden.
          if (PDF <> nil) and (PDF.Parent = nil) and not AddedToTabs then
            PDF.Free;
          LoadErrors.Add(ExtractFileName(S) + ': '+ E.Message);
        end;
      end;
    end;
    // Den im Arbeitsbereich gespeicherten aktiven Tab bevorzugen.
    // Nur dieses PDF nach dem Sammelimport initialisieren.
    TargetPDF := nil;
    TargetTab := nil;
    if ActiveFile <> '' then
      for J := 0 to FTabs.PageCount - 1 do
        if SameText(FTabs.Pages[J].Hint, ActiveFile) then
        begin
          TargetTab := FTabs.Pages[J];
          TargetPDF := WorkspaceBrowserInTab(TargetTab);
          Break;
        end;
    if TargetPDF <> nil then
      FMultiPDFLastPDF := TargetPDF;
    finally
      EndMultiPDFLoad;
    end;
    // Ein bereits zuvor geoeffneter aktiver Tab benoetigt keinen
    // erneuten PDF-Start; beim Wechsel startet er nur bei Bedarf.
    if (TargetTab <> nil) and (FTabs.ActivePage <> TargetTab) then
      FTabs.ActivePage := TargetTab;
    if LoadErrors.Count > 0 then
      MessageDlg('Fehler beim Laden des Arbeitsbereichs:' + sLineBreak +
        LoadErrors.Text, mtError, [mbOK], 0);
    if MissingCount > 0 then
      WorkspaceDialog(Self, 'Hinweis', IntToStr(MissingCount) + ' PDF-Datei(en) sind nicht erreichbar.', False, False, S, FDesignIndex);
  finally
    LoadErrors.Free;
    OpenFiles.Free;
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.OpenWorkspaceClick(Sender: TObject);
begin
  ManageWorkspacesClick(Sender);
end;

procedure TPDFTabsForm.WorkspaceListDblClick(Sender: TObject);
begin
  // Ereignisse benötigen eine Methode mit TNotifyEvent-Signatur.
  // Nur bei einer tatsächlichen Auswahl den Öffnen-Dialog bestätigen.
  if (Sender is TListView) and (TListView(Sender).Selected <> nil) and
     (TListView(Sender).Owner is TForm) then
    TForm(TListView(Sender).Owner).ModalResult := mrOk;
end;

procedure TPDFTabsForm.ManageWorkspacesClick(Sender: TObject);
var
  Form: TForm;
  List: TListView;
  Bar, Header, SearchBar: TPanel;
  SearchBox: TEdit;
  ColumnTimer: TTimer;
  Controller: TWorkspaceListController;
  BContents: TButton;
  HeaderTitle, HeaderHint: TLabel;
  BOpen, BReplace, BRename, BDelete, BClose: TButton;
  UIUnit, ButtonH, ButtonY, Gap, LeftPos, CloseWidth: Integer;
  SavedWidth, SavedHeight: Integer;
  WorkArea: TRect;
  SR: TSearchRec;
  Ini: TIniFile;
  Name, Path, NewName: string;
  Modified: TDateTime;
  Action: Integer;
  PendingWorkspacePath: string;
  ReplaceWorkspace: Boolean;
  EntryCount, InsertAt: Integer;
  BackColor, HeadColor, ForeColor: TColor;
  function SelectedPath: string;
  begin
    Result := '';
    if List.Selected <> nil then Result := List.Selected.SubItems[2];
  end;
  procedure ReloadList(Sender: TObject);
  var
    J, K, L, CompareResult: Integer;
    TempEntry: TWorkspaceEntry;
    Item: TListItem;
  begin
      List.Items.BeginUpdate;
      try
      List.Items.Clear;
      SetLength(Controller.Entries, 0);
      EntryCount := 0;
      ForceDirectories(WorkspaceFolder);
      if System.SysUtils.FindFirst(WorkspaceFolder + '*.ini', faAnyFile, SR) = 0 then
      try
        repeat
          if (SR.Attr and faDirectory) <> 0 then Continue;
          Path := WorkspaceFolder + SR.Name;
          Ini := TIniFile.Create(Path);
          try
            Name := Ini.ReadString('Info', 'Name', ChangeFileExt(SR.Name, ''));
            Modified := Ini.ReadDateTime('Info', 'Modified', 0);
            // Direkt nach dem echten Zeitwert sortieren, nicht nach dem
            // lokal formatierten Datumstext. Neueste Speicherung zuerst.
            InsertAt := 0;
            while InsertAt < EntryCount do
            begin
              if Modified > Controller.Entries[InsertAt].SavedAt then Break;
              if (Modified = Controller.Entries[InsertAt].SavedAt) and
                 (CompareText(Name, Controller.Entries[InsertAt].DisplayName) < 0) then Break;
              Inc(InsertAt);
            end;
            SetLength(Controller.Entries, EntryCount + 1);
            for J := EntryCount downto InsertAt + 1 do
              Controller.Entries[J] := Controller.Entries[J - 1];
            Controller.Entries[InsertAt].DisplayName := Name;
            Controller.Entries[InsertAt].FilePath := Path;
            Controller.Entries[InsertAt].SavedAt := Modified;
            Controller.Entries[InsertAt].PDFCount := Ini.ReadInteger('PDFs', 'Count', 0);
            Inc(EntryCount);
          finally
            Ini.Free;
          end;
        until System.SysUtils.FindNext(SR) <> 0;
      finally
        System.SysUtils.FindClose(SR);
      end;
      // Sortieren der eingelesenen Einträge VOR dem Aufbau der sichtbaren Liste.
      // So kann ein Spaltenklick die Liste nicht mehr durch Refresh leeren.
      for K := 0 to EntryCount - 2 do
        for L := K + 1 to EntryCount - 1 do
        begin
          case Controller.SortColumn of
            0: CompareResult := CompareText(Controller.Entries[K].DisplayName,
                                           Controller.Entries[L].DisplayName);
            2: CompareResult := Controller.Entries[K].PDFCount -
                                Controller.Entries[L].PDFCount;
          else
            if Controller.Entries[K].SavedAt < Controller.Entries[L].SavedAt then
              CompareResult := -1
            else if Controller.Entries[K].SavedAt > Controller.Entries[L].SavedAt then
              CompareResult := 1
            else
              CompareResult := CompareText(Controller.Entries[K].DisplayName,
                                           Controller.Entries[L].DisplayName);
          end;
          if not Controller.SortAscending then CompareResult := -CompareResult;
          if CompareResult > 0 then
          begin
            TempEntry := Controller.Entries[K];
            Controller.Entries[K] := Controller.Entries[L];
            Controller.Entries[L] := TempEntry;
          end;
        end;
      for K := 0 to EntryCount - 1 do
      begin
        if (Trim(SearchBox.Text) <> '') and
           (Pos(AnsiLowerCase(Trim(SearchBox.Text)),
                AnsiLowerCase(Controller.Entries[K].DisplayName)) = 0) then
          Continue;
        Item := List.Items.Add;
        Item.Caption := Controller.Entries[K].DisplayName;
        if Controller.Entries[K].SavedAt > 0 then
          Item.SubItems.Add(FormatDateTime('dd.mm.yyyy hh:nn', Controller.Entries[K].SavedAt))
        else
          Item.SubItems.Add('–');
        Item.SubItems.Add(IntToStr(Controller.Entries[K].PDFCount));
        Item.SubItems.Add(Controller.Entries[K].FilePath);
      end;
      if List.Items.Count > 0 then List.Selected := List.Items[0];
      finally
        List.Items.EndUpdate;
      end;

  end;
begin
  Controller := nil;
  Form := TForm.CreateNew(Self);
  try
    Form.Caption := Tr('Arbeitsbereiche verwalten');
    Form.Position := poDesigned;
    Form.BorderStyle := bsSizeable;
    UIUnit := Self.CurrentPPI;
    if UIUnit < 96 then UIUnit := 96;
    // Die zuletzt gewaehlte Dialoggroesse aus der portablen Viewer-INI laden.
    // Bei fehlenden Eintraegen gelten die bisherigen Standardabmessungen.
    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      SavedWidth := Ini.ReadInteger('Arbeitsbereiche', 'WindowWidth',
        MulDiv(780, UIUnit, 96));
      SavedHeight := Ini.ReadInteger('Arbeitsbereiche', 'WindowHeight',
        MulDiv(490, UIUnit, 96));
    finally
      Ini.Free;
    end;
    Form.Constraints.MinWidth := MulDiv(700, UIUnit, 96);
    Form.Constraints.MinHeight := MulDiv(350, UIUnit, 96);
    WorkArea := Screen.MonitorFromWindow(Self.Handle).WorkareaRect;
    Form.ClientWidth := EnsureRange(SavedWidth, Form.Constraints.MinWidth,
      Max(Form.Constraints.MinWidth, WorkArea.Right - WorkArea.Left -
        MulDiv(48, UIUnit, 96)));
    Form.ClientHeight := EnsureRange(SavedHeight, Form.Constraints.MinHeight,
      Max(Form.Constraints.MinHeight, WorkArea.Bottom - WorkArea.Top -
        MulDiv(80, UIUnit, 96)));
    // Bei jeder Oeffnung mittig zum Viewer, nicht zur letzten Dialogposition.
    Form.Left := EnsureRange(Self.Left + (Self.Width - Form.Width) div 2,
      WorkArea.Left, Max(WorkArea.Left, WorkArea.Right - Form.Width));
    Form.Top := EnsureRange(Self.Top + (Self.Height - Form.Height) div 2,
      WorkArea.Top, Max(WorkArea.Top, WorkArea.Bottom - Form.Height));
    Form.Font.Name := 'Segoe UI';
    Form.Font.Size := 10;
    case FDesignIndex of
      1: begin BackColor := RGB(229,236,246); HeadColor := RGB(225,232,241); ForeColor := RGB(35,48,65); end;
      3: begin BackColor := RGB(232,232,232); HeadColor := RGB(220,220,220); ForeColor := clBlack; end;
      5: begin BackColor := RGB(220,233,247); HeadColor := RGB(190,214,237); ForeColor := RGB(24,55,88); end;
    else begin BackColor := $00FAFAFA; HeadColor := clWhite; ForeColor := clWindowText; end;
    end;
    Form.Color := BackColor;
    Form.Font.Color := ForeColor;
    Header := TPanel.Create(Form);
    Header.Parent := Form;
    Header.Align := alTop;
    Header.Height := MulDiv(94, UIUnit, 96);
    Header.BevelOuter := bvNone;
    Header.Color := HeadColor;
    Header.ParentBackground := False;
    HeaderTitle := TLabel.Create(Form);
    HeaderTitle.Parent := Header;
    HeaderTitle.SetBounds(MulDiv(22, UIUnit, 96), MulDiv(16, UIUnit, 96),
      MulDiv(690, UIUnit, 96), MulDiv(30, UIUnit, 96));
    HeaderTitle.Font.Name := 'Segoe UI Semibold';
    HeaderTitle.Font.Size := 16;
    HeaderTitle.Caption := Tr('Meine Arbeitsbereiche');
    HeaderTitle.Font.Color := ForeColor;
    HeaderHint := TLabel.Create(Form);
    HeaderHint.Parent := Header;
    HeaderHint.SetBounds(MulDiv(23, UIUnit, 96), MulDiv(54, UIUnit, 96),
      MulDiv(710, UIUnit, 96), MulDiv(23, UIUnit, 96));
    if FDesignIndex = 0 then HeaderHint.Font.Color := clGray
    else HeaderHint.Font.Color := ForeColor;
    HeaderHint.Caption := Tr('Gespeicherte PDF- und Grafik-Sammlungen öffnen und verwalten');
    HeaderHint.AutoSize := True;
    HeaderTitle.AutoSize := True;
    Header.Height := HeaderHint.Top + HeaderHint.Height + MulDiv(16, UIUnit, 96);
    SearchBar := TPanel.Create(Form);
    SearchBar.Parent := Form;
    SearchBar.Align := alTop;
    SearchBar.Height := MulDiv(44, UIUnit, 96);
    SearchBar.BevelOuter := bvNone;
    SearchBar.Color := BackColor;
    SearchBar.ParentBackground := False;
    SearchBox := TEdit.Create(Form);
    SearchBox.Parent := SearchBar;
    SearchBox.SetBounds(MulDiv(18, UIUnit, 96), MulDiv(7, UIUnit, 96),
      SearchBar.ClientWidth - MulDiv(18 + 245 + 18 + 10, UIUnit, 96),
      MulDiv(29, UIUnit, 96));
    SearchBox.Anchors := [akLeft, akTop, akRight];
    SearchBox.TextHint := Tr('Arbeitsbereich suchen ...');
    Controller := TWorkspaceListController.Create;
    Controller.Search := SearchBox;
    Controller.OwnerForm := Form;
    Controller.DesignIndex := FDesignIndex;
    // Letzte Sortierung beim Öffnen wiederherstellen.
    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      Controller.SortColumn := Ini.ReadInteger('Arbeitsbereiche', 'SortColumn', 1);
      if (Controller.SortColumn < 0) or (Controller.SortColumn > 2) then
        Controller.SortColumn := 1;
      Controller.SortAscending := Ini.ReadBool('Arbeitsbereiche', 'SortAscending', False);
    finally
      Ini.Free;
    end;
    SearchBox.OnChange := Controller.SearchChanged;
    List := TListView.Create(Form);
    List.Parent := Form;
    List.Align := alClient;
    List.ViewStyle := vsReport;
    Controller.List := List;
    List.OnColumnClick := Controller.ColumnClicked;
    // TListView bietet bei vielen Einträgen automatisch eine vertikale
    // Scrollleiste sowie Mausrad- und Tastaturnavigation.
    List.ReadOnly := True;
    List.RowSelect := True;
    List.HideSelection := False;
    List.Color := clWhite;
    List.GridLines := False;
    List.DoubleBuffered := True;
    List.Columns.Add.Caption := Tr('Name');
    List.Columns[0].Width := MulDiv(355, UIUnit, 96);
    List.Columns.Add.Caption := Tr('Gespeichert am');
    List.Columns[1].Width := MulDiv(205, UIUnit, 96);
    List.Columns.Add.Caption := Tr('PDFs');
    List.Columns[2].Width := MulDiv(85, UIUnit, 96);
    // Die zuletzt vom Benutzer gewaehlten Breiten aus der Viewer-INI laden.
    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      List.Columns[1].Width := Ini.ReadInteger('Arbeitsbereiche',
        'DateColumnWidth', List.Columns[1].Width);
      List.Columns[2].Width := Ini.ReadInteger('Arbeitsbereiche',
        'PDFColumnWidth', List.Columns[2].Width);
    finally
      Ini.Free;
    end;
    // Ungueltige oder uebermaessige Werte auf sinnvolle Grenzen setzen.
    if List.Columns[1].Width > MulDiv(600, UIUnit, 96) then
      List.Columns[1].Width := MulDiv(205, UIUnit, 96);
    if List.Columns[2].Width > MulDiv(350, UIUnit, 96) then
      List.Columns[2].Width := MulDiv(85, UIUnit, 96);
    if List.Columns[1].Width < MulDiv(150, UIUnit, 96) then
      List.Columns[1].Width := MulDiv(150, UIUnit, 96);
    if List.Columns[2].Width < MulDiv(65, UIUnit, 96) then
      List.Columns[2].Width := MulDiv(65, UIUnit, 96);
    Controller.LastDateWidth := List.Columns[1].Width;
    Controller.LastPDFWidth := List.Columns[2].Width;
    List.OnResize := Controller.ResizeColumns;
    Controller.ResizeColumns(List);
    // TListView bietet kein in allen Delphi-Versionen einheitliches
    // Ereignis fuer die manuelle Spaltenbreitenaenderung.
    ColumnTimer := TTimer.Create(Form);
    ColumnTimer.Interval := 150;
    ColumnTimer.OnTimer := Controller.CheckColumnWidths;
    ColumnTimer.Enabled := True;
    BContents := TPDFDesignButton.Create(Form);
    BContents.Parent := SearchBar;
    TPDFDesignButton(BContents).SetDesign(FDesignIndex);
    BContents.Caption := Tr('Inhalt anzeigen ...');
    BContents.Anchors := [akRight, akTop];
    BContents.SetBounds(SearchBar.ClientWidth - MulDiv(245 + 18, UIUnit, 96),
      MulDiv(5, UIUnit, 96), MulDiv(245, UIUnit, 96),
      MulDiv(34, UIUnit, 96));
    BContents.OnClick := Controller.ShowContents;
    Bar := TPanel.Create(Form);
    Bar.Parent := Form;
    Bar.Align := alBottom;
    Bar.Height := MulDiv(72, UIUnit, 96);
    Bar.BevelOuter := bvNone;
    Bar.Color := HeadColor;
    Bar.ParentBackground := False;
    ButtonH := MulDiv(38, UIUnit, 96);
    ButtonY := (Bar.Height - ButtonH) div 2;
    Gap := MulDiv(10, UIUnit, 96);
    LeftPos := MulDiv(18, UIUnit, 96);
    BOpen := TPDFDesignButton.Create(Form);
    BOpen.Parent := Bar;
    TPDFDesignButton(BOpen).SetDesign(FDesignIndex);
    BOpen.SetBounds(LeftPos, ButtonY, MulDiv(95, UIUnit, 96), ButtonH);
    BOpen.Caption := Tr('Öffnen'); BOpen.ModalResult := mrOk;
    BOpen.Default := True;
    // Doppelklick nutzt dieselbe Öffnen-Aktion wie der Button.
    // Der Standardbutton erlaubt außerdem Öffnen mit Enter.
    List.OnDblClick := WorkspaceListDblClick;
    // Arbeitsbereich exklusiv laden: bisherige PDFs erst nach
    // erfolgreicher Abfrage ungespeicherter Aenderungen schliessen.
    BReplace := TPDFDesignButton.Create(Form);
    BReplace.Parent := Bar;
    TPDFDesignButton(BReplace).SetDesign(FDesignIndex);
    BReplace.SetBounds(BOpen.Left + BOpen.Width + Gap, ButtonY,
      MulDiv(155, UIUnit, 96), ButtonH);
    BReplace.Caption := Tr('Alle schließen + öffnen');
    BReplace.ModalResult := mrYes;
    BRename := TPDFDesignButton.Create(Form);
    BRename.Parent := Bar;
    TPDFDesignButton(BRename).SetDesign(FDesignIndex);
    BRename.SetBounds(BReplace.Left + BReplace.Width + Gap, ButtonY,
      MulDiv(95, UIUnit, 96), ButtonH);
    BRename.Caption := Tr('Umbenennen'); BRename.ModalResult := mrRetry;
    BDelete := TPDFDesignButton.Create(Form);
    BDelete.Parent := Bar;
    TPDFDesignButton(BDelete).SetDesign(FDesignIndex);
    BDelete.SetBounds(BRename.Left + BRename.Width + Gap, ButtonY,
      MulDiv(115, UIUnit, 96), ButtonH);
    BDelete.Caption := Tr('Löschen'); BDelete.ModalResult := mrIgnore;
    BClose := TPDFDesignButton.Create(Form);
    BClose.Parent := Bar;
    TPDFDesignButton(BClose).SetDesign(FDesignIndex);
    CloseWidth := MulDiv(110, UIUnit, 96);
    BClose.SetBounds(Bar.ClientWidth - MulDiv(20, UIUnit, 96) - CloseWidth,
      ButtonY, CloseWidth, ButtonH);
    BClose.Anchors := [akRight, akTop];
    BClose.Caption := Tr('Schließen'); BClose.ModalResult := mrCancel;
    BClose.Cancel := True;
    Form.ActiveControl := List;
    PendingWorkspacePath := '';
    ReplaceWorkspace := False;
    repeat
      ReloadList(nil);
      Action := Form.ShowModal;
      if Action = mrOk then
      begin
        Path := SelectedPath;
        if Path <> '' then
        begin
          PendingWorkspacePath := Path;
          Break;
        end;
      end
      else if Action = mrYes then
      begin
        Path := SelectedPath;
        if (Path <> '') and FileExists(Path) then
        begin
          // Abbrechen oder fehlgeschlagenes Speichern behaelt alle Tabs.
          if ConfirmCloseUnsavedPDFs(False) then
          begin
            PendingWorkspacePath := Path;
            ReplaceWorkspace := True;
            Break;
          end;
        end;
      end
      else if Action = mrRetry then
      begin
        Path := SelectedPath;
        if Path <> '' then
        begin
          Ini := TIniFile.Create(Path);
          try
            NewName := Ini.ReadString('Info', 'Name', 'Arbeitsbereich');
            if (WorkspaceDialog(Self, 'Arbeitsbereich umbenennen', 'Neuer Name:', False, True, NewName, FDesignIndex) = mrOk) and
               (Trim(NewName) <> '') then
            begin
              Ini.WriteString('Info', 'Name', Trim(NewName));
              Ini.WriteDateTime('Info', 'Modified', Now);
            end;
          finally Ini.Free; end;
        end;
      end
      else if Action = mrIgnore then
      begin
        Path := SelectedPath;
        if (Path <> '') and (WorkspaceDialog(Self, 'Arbeitsbereich löschen', 'Arbeitsbereich wirklich löschen?', True, False, NewName, FDesignIndex) = mrYes) then System.SysUtils.DeleteFile(Path);
      end
      else Break;
    until False;
  finally
    if (Controller <> nil) and (List <> nil) and (List.Columns.Count >= 3) then
    begin
      Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
      try
        Ini.WriteInteger('Arbeitsbereiche', 'DateColumnWidth', List.Columns[1].Width);
        Ini.WriteInteger('Arbeitsbereiche', 'PDFColumnWidth', List.Columns[2].Width);
        Ini.WriteInteger('Arbeitsbereiche', 'WindowWidth', Form.ClientWidth);
        Ini.WriteInteger('Arbeitsbereiche', 'WindowHeight', Form.ClientHeight);
      finally
        Ini.Free;
      end;
    end;
    Form.Free;
    Controller.Free;
  end;
  // Den Arbeitsbereich erst nach dem vollständigen Schließen des modalen
  // Verwaltungsdialogs wechseln. So laufen dessen Nachrichten und
  // Ereignisse nicht parallel zur Freigabe der bisherigen PDF-Controls.
  if PendingWorkspacePath <> '' then
  begin
    if ReplaceWorkspace then
      ClearAllPDFTabs;
    OpenWorkspaceFile(PendingWorkspacePath);
  end;
end;

procedure TPDFTabsForm.SaveClosedPDFs;
var
  Ini: TIniFile;
  I, N: Integer;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    // Nur den eigenen Abschnitt aktualisieren; andere Einstellungen erhalten.
    Ini.EraseSection('ClosedPDFs');
    N := FClosedPDFs.Count;
    if N > 20 then N := 20;
    Ini.WriteInteger('ClosedPDFs', 'Count', N);
    for I := 0 to N - 1 do
      Ini.WriteString('ClosedPDFs', 'File' + IntToStr(I + 1),
        FClosedPDFs[FClosedPDFs.Count - 1 - I]);
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.UpdateClosedPDFHistory(const AFileName: string;
  AAdd: Boolean);
var
  Mutex: THandle;
  WaitResult: DWORD;
  I: Integer;
begin
  if Trim(AFileName) = '' then Exit;
  // Alle Viewer-Prozesse lesen/aendern/schreiben den Verlauf atomar.
  Mutex := CreateMutex(nil, False, 'Local\FreePDF64_ClosedPDFs_Lock');
  if Mutex = 0 then
    RaiseLastOSError;
  try
    WaitResult := WaitForSingleObject(Mutex, INFINITE);
    if (WaitResult <> WAIT_OBJECT_0) and
       (WaitResult <> WAIT_ABANDONED) then
      raise Exception.Create('ClosedPDFs-Sperre konnte nicht erworben werden.');
    try
      LoadClosedPDFs;
      // Windows-Dateipfade ohne Beachtung der Gross-/Kleinschreibung vergleichen.
      for I := FClosedPDFs.Count - 1 downto 0 do
        if SameText(FClosedPDFs[I], AFileName) then
          FClosedPDFs.Delete(I);
      if AAdd then
      begin
        FClosedPDFs.Add(AFileName);
        while FClosedPDFs.Count > 20 do
          FClosedPDFs.Delete(0);
      end;
      SaveClosedPDFs;
    finally
      ReleaseMutex(Mutex);
    end;
  finally
    CloseHandle(Mutex);
  end;
end;

function ViewerExeVersion: string;
var
  InfoSize, Dummy: DWORD;
  Info: TBytes;
  FixedInfo: PVSFixedFileInfo;
  FixedLen: UINT;
begin
  Result := 'nicht verfügbar';
  InfoSize := GetFileVersionInfoSize(PChar(Application.ExeName), Dummy);
  if InfoSize = 0 then Exit;
  SetLength(Info, InfoSize);
  if not GetFileVersionInfo(PChar(Application.ExeName), 0, InfoSize, @Info[0]) then Exit;
  FixedInfo := nil;
  FixedLen := 0;
  if VerQueryValue(@Info[0], '\', Pointer(FixedInfo), FixedLen) and
     (FixedInfo <> nil) and (FixedLen >= SizeOf(TVSFixedFileInfo)) and
     (FixedInfo^.dwSignature = $FEEF04BD) then
    Result := Format('%d.%d.%d.%d',
      [HiWord(FixedInfo^.dwFileVersionMS), LoWord(FixedInfo^.dwFileVersionMS),
       HiWord(FixedInfo^.dwFileVersionLS), LoWord(FixedInfo^.dwFileVersionLS)]);
end;

function TViewerHelpForm.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  NewPos, Step: Integer;
begin
  if HelpScroll = nil then
  begin
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
    Exit;
  end;
  Step := MulDiv(60, HelpScroll.CurrentPPI, 96);
  NewPos := HelpScroll.VertScrollBar.Position - MulDiv(WheelDelta, Step, WHEEL_DELTA);
  HelpScroll.VertScrollBar.Position := EnsureRange(NewPos, 0,
    Max(0, HelpScroll.VertScrollBar.Range - HelpScroll.ClientHeight));
  Result := True;
end;

procedure TViewerHelpForm.OpenProjectLink(Sender: TObject);
begin
  ShellExecute(Handle, 'open',
    PChar('https://github.com/FreePDF64/FreePDF64ViewerPortable'),
    nil, nil, SW_SHOWNORMAL);
end;

procedure TViewerHelpForm.OpenContactMail(Sender: TObject);
begin
  ShellExecute(Handle, 'open',
    PChar('mailto:FreePDF64@outlook.com?subject=Fragen%2FAnregungen%2Fetc.%20zu%20FreePDF64ViewerPortable'),
    nil, nil, SW_SHOWNORMAL);
end;

procedure TViewerHelpForm.JumpToHelpSection(Sender: TObject);
begin
  if (HelpScroll <> nil) and (Sender is TLabel) then
    HelpScroll.VertScrollBar.Position := TLabel(Sender).Tag;
end;

procedure TPDFTabsForm.ShowModernInfo(AAbout, AMergeHelp: Boolean);
var
  D: TForm;
  TopPanel, BottomPanel, BodyPanel: TPanel;
  Scroll: TScrollBox;
  TitleLabel, SubLabel: TLabel;
  Btn: TButton;
  Img: TImage;
  Y, Scale: Integer;
  TOCLabels: array of TLabel;
  TOCCount: Integer;
  function Px(V: Integer): Integer;
  begin
    Result := MulDiv(V, Scale, 96);
  end;
  procedure AddTOC(const AItems: array of string);
  var
    I, H: Integer;
    L: TLabel;
    P: TPanel;
  begin
    TOCCount := Length(AItems);
    SetLength(TOCLabels, TOCCount);
    H := Px(36 + TOCCount * 27);
    P := TPanel.Create(D);
    P.Parent := Scroll;
    P.SetBounds(Px(22), Y + Px(5), Max(Px(320), Scroll.ClientWidth - Px(62)), H);
    P.BevelOuter := bvNone;
    P.ParentBackground := False;
    P.Color := RGB(224, 237, 251);
    for I := 0 to TOCCount - 1 do
    begin
      L := TLabel.Create(D);
      L.Parent := P;
      L.SetBounds(Px(18), Px(12 + I * 27), P.Width - Px(36), Px(24));
      L.Font.Name := 'Segoe UI';
      L.Font.Size := 10;
      L.Font.Color := RGB(0, 85, 170);
      L.Font.Style := [fsUnderline];
      L.ShowAccelChar := False;
      L.Cursor := crHandPoint;
      L.Caption := AItems[I];
      L.OnClick := TViewerHelpForm(D).JumpToHelpSection;
      TOCLabels[I] := L;
    end;
    Inc(Y, H + Px(14));
  end;
  procedure AddSection(const ATitle, ABody: string);
  var
    Card: TPanel;
    Head, Body: TLabel;
    BodyHeight, CardHeight, ContentWidth: Integer;
    ContactHead, ContactLink: TLabel;
    I: Integer;
  begin
    if (ABody = '') and not (AAbout or AMergeHelp) then
      for I := 0 to TOCCount - 1 do
        if SameText(TOCLabels[I].Caption, ATitle) then
          TOCLabels[I].Tag := Y;
    ContentWidth := Max(Px(320), Scroll.ClientWidth - Px(62));
    Card := TPanel.Create(D);
    Card.Parent := Scroll;
    Card.BevelOuter := bvNone;
    Card.ParentBackground := False;
    Card.Color := RGB(244, 248, 253);
    Card.SetBounds(Px(22), Y + Px(5), ContentWidth, Px(65));

    Head := TLabel.Create(D);
    Head.Parent := Card;
    Head.SetBounds(Px(18), Px(8), ContentWidth - Px(36), Px(21));
    Head.Font.Name := 'Segoe UI';
    Head.Font.Size := 11;
    Head.Font.Style := [fsBold];
    Head.Font.Color := RGB(24, 83, 150);
    Head.ShowAccelChar := False;
    Head.Caption := ATitle;
    if ABody = '' then
    begin
      // Themenüberschriften mittig in ihrer eigenen blauen Karte.
      Card.Color := RGB(224, 237, 251);
      Card.Height := Px(47);
      Head.AutoSize := False;
      Head.Alignment := taLeftJustify;
      Head.Layout := tlCenter;
      Head.SetBounds(Px(18), 0, ContentWidth - Px(36), Card.Height);
      Inc(Y, Card.Height + Px(7));
      Exit;
    end;

    Body := TLabel.Create(D);
    Body.Parent := Card;
    Body.AutoSize := False;
    Body.WordWrap := True;
    Body.ShowAccelChar := False; // & ist Text, kein Zugriffstasten-Marker.
    Body.Font.Name := 'Segoe UI';
    Body.Font.Size := 10;
    Body.Font.Color := RGB(44, 55, 70);
    Body.SetBounds(Px(18), Px(32), ContentWidth - Px(36), Px(30));
    Body.Caption := ABody;
    if SameText(ABody, 'https://github.com/FreePDF64/FreePDF64ViewerPortable') then
    begin
      Body.Font.Color := RGB(0, 102, 204);
      Body.Font.Style := [fsUnderline];
      Body.Cursor := crHandPoint;
      Body.Hint := Tr('Projektseite im Webbrowser öffnen');
      Body.ShowHint := True;
      Body.OnClick := TViewerHelpForm(D).OpenProjectLink;
    end;
    // Calculate text wrapping using the label's preferred height.
    Body.AutoSize := True;
    Body.Width := ContentWidth - Px(36);
    BodyHeight := Max(Px(19), Body.Height);
    Body.AutoSize := False;
    Body.Height := BodyHeight;
    CardHeight := Px(36) + BodyHeight + Px(8);
    if AAbout and (SameText(ATitle, 'Projektseite') or
       SameText(ATitle, 'Project page')) then
    begin
      ContactHead := TLabel.Create(D);
      ContactHead.Parent := Card;
      ContactHead.SetBounds(Px(18), CardHeight + Px(3),
        ContentWidth - Px(36), Px(20));
      ContactHead.Font.Name := 'Segoe UI';
      ContactHead.Font.Size := 10;
      ContactHead.Font.Style := [fsBold];
      ContactHead.Font.Color := RGB(24, 83, 150);
      ContactHead.Caption := Tr('Fragen, Anregungen und eventuelle Fehlermeldungen');

      ContactLink := TLabel.Create(D);
      ContactLink.Parent := Card;
      ContactLink.SetBounds(Px(18), CardHeight + Px(25),
        ContentWidth - Px(36), Px(22));
      ContactLink.Font.Name := 'Segoe UI';
      ContactLink.Font.Size := 10;
      ContactLink.Font.Color := RGB(0, 102, 204);
      ContactLink.Font.Style := [fsUnderline];
      ContactLink.Cursor := crHandPoint;
      ContactLink.Caption := Tr('E-Mail an FreePDF64@outlook.com');
      ContactLink.Hint := Tr('E-Mail-Programm öffnen');
      ContactLink.ShowHint := True;
      ContactLink.OnClick := TViewerHelpForm(D).OpenContactMail;
      Inc(CardHeight, Px(53));
    end;
    Card.Height := CardHeight;
    Inc(Y, CardHeight + Px(7));
  end;
begin
  D := TViewerHelpForm.CreateNew(Self);
  try
    Scale := CurrentPPI;
    if Scale < 96 then Scale := 96;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.Color := clWhite;
    D.Position := poOwnerFormCenter;
    D.BorderStyle := bsSizeable;
    if PDFLanguage = 'en' then D.Caption := 'FreePDF64-Viewer Portable - Help'
    else D.Caption := 'FreePDF64-Viewer Portable - Hilfe';
    if AAbout then D.Caption := Tr('Über FreePDF64-Viewer Portable');
    if AMergeHelp then D.Caption := Tr('Hilfe') + ' - ' + Tr('PDFs zusammenführen ...');
    D.ClientWidth := Px(750);
    D.ClientHeight := Px(540);
    D.Constraints.MinWidth := Px(600);
    D.Constraints.MinHeight := Px(400);
    D.KeyPreview := True;

    TopPanel := TPanel.Create(D);
    TopPanel.Parent := D;
    TopPanel.Align := alTop;
    TopPanel.Height := Px(112);
    TopPanel.BevelOuter := bvNone;
    TopPanel.ParentBackground := False;
    TopPanel.Color := RGB(19, 93, 169);

    Img := TImage.Create(D);
    Img.Parent := TopPanel;
    Img.SetBounds(Px(24), Px(24), Px(54), Px(54));
    Img.Picture.Icon.Assign(Application.Icon);
    Img.Stretch := True;

    TitleLabel := TLabel.Create(D);
    TitleLabel.Parent := TopPanel;
    TitleLabel.SetBounds(Px(95), Px(26), Px(555), Px(35));
    TitleLabel.Font.Name := 'Segoe UI';
    TitleLabel.Font.Size := 19;
    TitleLabel.Font.Style := [fsBold];
    TitleLabel.Font.Color := clWhite;
    if AMergeHelp then TitleLabel.Caption := Tr('PDFs zusammenführen ...')
    else if AAbout then TitleLabel.Caption := 'FreePDF64-Viewer Portable'
    else TitleLabel.Caption := Tr('Funktionsübersicht');

    SubLabel := TLabel.Create(D);
    SubLabel.Parent := TopPanel;
    SubLabel.SetBounds(Px(97), Px(68), Px(540), Px(24));
    SubLabel.Font.Size := 10;
    SubLabel.Font.Color := RGB(224, 237, 250);
    if AMergeHelp then
    begin
      if PDFLanguage = 'en' then
        SubLabel.Caption := 'Select PDF files, pages and their order'
      else
        SubLabel.Caption := 'PDF-Dateien, Seiten und Reihenfolge auswählen';
    end
    else if AAbout then
    begin
      if PDFLanguage = 'en' then
        SubLabel.Caption := 'Version ' + ViewerExeVersion + ' · Portable PDF application for Windows 64-bit'
      else
        SubLabel.Caption := 'Version ' + ViewerExeVersion + ' · Portable PDF-Anwendung für Windows 64-Bit';
    end
    else SubLabel.Caption := Tr('Alles Wichtige auf einen Blick');

    BottomPanel := TPanel.Create(D);
    BottomPanel.Parent := D;
    BottomPanel.Align := alBottom;
    BottomPanel.Height := Px(66);
    BottomPanel.BevelOuter := bvNone;
    BottomPanel.ParentBackground := False;
    BottomPanel.Color := RGB(230, 239, 249);

    Btn := TButton.Create(D);
    Btn.Parent := BottomPanel;
    Btn.Caption := Tr('Schließen');
    Btn.ModalResult := mrOk;
    Btn.Default := True;
    Btn.Cancel := True; // ESC schließt beide Dialoge.
    Btn.SetBounds(D.ClientWidth - Px(156), Px(15), Px(125), Px(35));
    Btn.Anchors := [akRight, akTop];

    BodyPanel := TPanel.Create(D);
    BodyPanel.Parent := D;
    BodyPanel.Align := alClient;
    BodyPanel.BevelOuter := bvNone;
    BodyPanel.Color := clWhite;
    BodyPanel.ParentBackground := False;

    Scroll := TScrollBox.Create(D);
    TViewerHelpForm(D).HelpScroll := Scroll;
    Scroll.Parent := BodyPanel;
    Scroll.Align := alClient;
    Scroll.BorderStyle := bsNone;
    Scroll.Color := RGB(250, 252, 255);
    Scroll.ParentBackground := False;
    Scroll.VertScrollBar.Tracking := True;
    Y := Px(6);
    if AMergeHelp then
    begin
      if PDFLanguage = 'en' then
      begin
        AddSection('1. Select PDF files',
          'Use the checkboxes to select open PDF files for merging.');
        AddSection('2. Choose pages',
          'All - All pages' + sLineBreak +
          '3 - Page 3' + sLineBreak +
          '2-5 - Pages 2 through 5' + sLineBreak +
          '1, 4, 8 - Individual pages' + sLineBreak +
          '1-3, 7, 10-12 - Combined ranges');
        AddSection('3. Change the order',
          'Select a file row and use the arrow buttons to move it up or down.');
        AddSection('4. Merge',
          'Click Merge to save the selected files and pages to a new PDF.');
        AddSection('Note',
          'Original files remain unchanged. Unsaved changes in open PDFs are not included.');
      end
      else
      begin
        AddSection('1. PDF-Dateien auswählen',
          'Wählen Sie die geöffneten PDF-Dateien mit den Kontrollkästchen aus.');
        AddSection('2. Seiten festlegen',
          'Alle - Sämtliche Seiten' + sLineBreak +
          '3 - Seite 3' + sLineBreak +
          '2-5 - Seiten 2 bis 5' + sLineBreak +
          '1, 4, 8 - Einzelne Seiten' + sLineBreak +
          '1-3, 7, 10-12 - Kombinierte Seitenbereiche');
        AddSection('3. Reihenfolge ändern',
          'Markieren Sie eine PDF-Zeile und ändern Sie mit den Pfeiltasten ihre Position.');
        AddSection('4. Zusammenführen',
          'Klicken Sie auf „Zusammenführen“, um eine neue PDF-Datei zu speichern.');
        AddSection('Hinweis',
          'Die Originaldateien bleiben unverändert. Ungespeicherte Änderungen werden nicht übernommen.');
      end;
    end
    else if AAbout then
    begin
      AddSection(Tr('Version'), ViewerExeVersion);
      if PDFLanguage = 'en' then
      begin
        AddSection('About the application',
          'A standalone PDF viewer with tabs, document properties, attachment management and PDF tools.');
        AddSection('Copyright and contact',
          'Copyright © 2026 Michael Tesch' + sLineBreak + 'FreePDF64@outlook.com');
        AddSection('License – GNU GPL v3',
          'FreePDF64-Viewer Portable is free and open-source software licensed under the GNU GPL v3 (GPL-3.0-only).' + sLineBreak +
          'Use, modification and redistribution are permitted under the terms of this license.' + sLineBreak +
          'The complete license text is included in the LICENSE_NOTICE_EN.txt file.');
        AddSection('Project page', 'https://github.com/FreePDF64/FreePDF64ViewerPortable');
        AddSection('Third-party software and libraries',
          'PDFium – PDF rendering engine, © The PDFium Authors.' + sLineBreak +
          'V8 – JavaScript engine, © The V8 Project Authors.' + sLineBreak +
          'PDFium and V8 are used under their respective open-source licenses.' + sLineBreak +
          'The complete license terms, copyright notices and notices for bundled third-party libraries ' +
          'are provided in the accompanying PDFium subfolder (LICENSE file and licenses folder).' + sLineBreak +
          'PDFium: https://pdfium.googlesource.com/pdfium/' + sLineBreak +
          'V8: https://v8.dev/' + sLineBreak +
          'Additional tools: QPDF and Xpdf (subject to their respective licenses).' + sLineBreak +
          'FreePDF64-Viewer Portable is not an official PDFium, V8 or Google product.');
        AddSection('Settings file',
          IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'FreePDFViewer.ini');
        AddSection('Application executable', Application.ExeName);
      end
      else
      begin
        AddSection('Über das Programm',
          'Eigenständiger PDF-Viewer mit Registerkarten, Dokumenteigenschaften, Anlagenverwaltung und PDF-Werkzeugen.');
        AddSection('Copyright und Kontakt',
          'Copyright © 2026 Michael Tesch' + sLineBreak + 'FreePDF64@outlook.com');
        AddSection('Lizenz – GNU GPL v3',
          'FreePDF64-Viewer Portable ist freie und quelloffene Software unter der GNU GPL v3 (GPL-3.0-only).' + sLineBreak +
          'Nutzung, Änderung und Weitergabe sind gemäß den Bedingungen dieser Lizenz gestattet.' + sLineBreak +
          'Der vollständige Lizenztext ist in der Datei LIZENZ_DE.txt enthalten.');
        AddSection('Projektseite', 'https://github.com/FreePDF64/FreePDF64ViewerPortable');
        AddSection('Zusatzprogramme und Bibliotheken',
          'PDFium – PDF-Darstellungsbibliothek, © The PDFium Authors.' + sLineBreak +
          'V8 – JavaScript-Engine, © The V8 Project Authors.' + sLineBreak +
          'PDFium und V8 werden unter ihren jeweiligen Open-Source-Lizenzen verwendet.' + sLineBreak +
          'Die vollständigen Lizenzbedingungen, Copyright-Hinweise und Hinweise zu eingebundenen ' +
          'Drittanbieter-Bibliotheken befinden sich im mitgelieferten Unterordner PDFium (Datei LICENSE und Ordner licenses).' + sLineBreak +
          'PDFium: https://pdfium.googlesource.com/pdfium/' + sLineBreak +
          'V8: https://v8.dev/' + sLineBreak +
          'Weitere Werkzeuge: QPDF und Xpdf (jeweils unter eigener Lizenz).' + sLineBreak +
          'FreePDF64-Viewer Portable ist kein offizielles Produkt von PDFium, V8 oder Google.');
        AddSection('Einstellungsdatei',
          IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'FreePDFViewer.ini');
        AddSection('Programmdatei', Application.ExeName);
      end;
    end
    else if PDFLanguage = 'en' then
    begin
      AddTOC(['Customizable user interface (themes)', 'Images and multipage TIFF files',
        'Opening and organizing PDFs', 'Viewing and searching', 'Editing and combining PDFs',
        'Watermarks and hyperlinks', 'Interactive forms', 'Document information and tools',
        'Display and Logging']);
      AddSection('Customizable user interface (themes)', '');
      AddSection('Select a theme',
        'Five themes are available: Standard, Modern Light, Modern Dark, Windows Classic and Classic Blue. '
        + 'Toolbars, buttons and controls use colors matching the selected theme. '
        + 'Select a theme under Options → Theme.');
      AddSection('Images and multipage TIFF files', '');
      AddSection('Open image files',
        'Open JPG, JPEG, PNG, BMP, TIF and TIFF files alongside PDFs. Each file appears in its own tab. '
        + 'Switching between image and PDF tabs does not require reopening the files.');
      AddSection('Image toolbar and zoom',
        'Use the image toolbar to zoom in or out, show the image at 100%, fit the entire image to the viewing area, '
        + 'or fit it to the available width. Fit to page centers the image in the viewing area. '
        + 'Hold Ctrl and turn the mouse wheel to zoom; without Ctrl, the wheel scrolls normally.');
      AddSection('Rotate, save and print images',
        'Rotate images 90 degrees left or right using the toolbar. A changed image is indicated by an orange Save button. '
        + 'Zooming, scrolling and fitting do not mark an image as changed. '
        + 'Use Save as to save a supported single-page image; cancelling keeps the change indicator. '
        + 'Printing is available from the image toolbar.');
      AddSection('Multipage TIFF navigation',
        'Open a multipage TIFF and use the previous/next arrow buttons and page counter to navigate its pages. '
        + 'Zoom and rotation are available for TIFF pages. '
        + 'Use Save as to export all pages as a new multipage TIFF, including individual page rotations. The original file is preserved.');
      AddSection('Opening and organizing PDFs', '');
      AddSection('Open PDF files',
        'Use File → Open PDF…, Ctrl+O, or drag and drop. Each PDF opens in its own tab.');
      AddSection('Recently opened PDFs on the start page',
        'When no PDF is open, the scrollable start page shows the 15 most recently opened PDFs. '
        + 'Entries are arranged in two columns, or one column in a narrow window. A thumbnail of the first page appears beside the file name and path. '
        + 'Click an entry or thumbnail to open the PDF. Right-click an entry to remove it or open its folder. '
        + 'Use Clear history to remove the whole list after confirmation and delete all cached start-page thumbnails. The history is stored in FreePDFViewer.ini; thumbnail BMP files are stored in the Thumbnails folder next to the viewer and are automatically deleted at startup if older than 30 days.');
      AddSection('Reopen closed PDFs',
        'Right-click the empty start page. Recently closed documents are listed under Reopen closed PDFs. Unavailable entries are greyed out.');
      AddSection('Manage tabs',
        'Click × on a tab, use the middle mouse button, or press Ctrl+W to close a PDF. Unsaved changes trigger a confirmation.');
      AddSection('Named PDF workspaces',
        'Use Workspaces > Manage workspaces ... to manage saved workspaces, or Workspaces > Save workspace ... to save the current PDF collection. '
        + 'The workspace button opens management with the left mouse button and saves a workspace with the right mouse button. '
        + 'The management window is centered over the viewer and shows each workspace name, save date and PDF count. '
        + 'Use the search field to filter workspaces by name. Click the Name, Saved on or PDFs column header to sort; click again to reverse the order. '
        + 'The last selected sort column and direction are stored in FreePDFViewer.ini and restored the next time the window opens. '
        + 'Use Show contents ... to inspect the saved PDF file paths without opening the workspace. '
        + 'Double-click a workspace or press Enter to open it, or use Open. Close all and open closes existing PDFs after checking for unsaved changes, then loads the selected workspace. '
        + 'Workspaces can also be renamed or deleted. Already open PDFs remain open and duplicates are not opened again. Missing files are reported. '
        + 'Workspaces are stored as local INI files in the workspace folder beside the EXE; the PDF files themselves are not modified. '
        + 'Each workspace stores the PDFs in tab order, their page, zoom and scroll positions, and the last active tab.');
      AddSection('Split view and thumbnails',
        'Select two PDF tabs with Ctrl+Click, then choose Split view to display them side by side. '
        + 'Drag the divider to adjust the pane widths. Click inside a PDF or press Tab to change the active pane; '
        + 'a blue border identifies it. Each pane has three small buttons at the top left: '
        + 'close split view, search within that pane''s PDF, and show or hide its page thumbnails. '
        + 'In normal view, the thumbnail state (on or off) is saved permanently in FreePDFViewer.ini and applies to all currently open and subsequently opened PDFs, including after restarting the viewer. Split view always starts without thumbnails; each pane can show or hide its thumbnails independently. Returning to normal view restores the saved setting. '
        + 'The thumbnail button disappears when its sidebar is open and reappears when the sidebar is closed. '
        + 'F3 finds the next match in the active pane; Shift+F3 finds the previous match. '
        + 'Choose Split view again or use a split button to return to the single-pane view. '
        + 'The split button is available when two tabs are selected or split view is active. '
        + 'In split view, S toggles synchronized scrolling from the left PDF to the right PDF; '
        + 'Z toggles synchronized zoom. Both functions can be switched on or off independently.');
      AddSection('Visual comparison of two PDFs',
        'Select two open PDF tabs and choose "Visually compare PDFs..." from the split-view menu. '
        + 'A separate comparison window displays both pages side by side with a centered divider. '
        + 'Differences are highlighted in color. Use Previous and Next to navigate between difference regions; '
        + 'Show marks and Hide marks toggle the colored outlines without hiding either PDF. '
        + 'Page navigation changes the compared page pair. The comparison runs in the background, '
        + 'shows progress and can be cancelled. Small text changes are detected while minor rendering '
        + 'and anti-aliasing variations are filtered to reduce false highlights. '
        + 'Both original PDF files remain unchanged.');
      AddSection('Viewing and searching', '');
      AddSection('Display and navigation',
        'Use the arrow buttons to change pages. Zoom in predefined steps or click 100 % for original size. '
        + 'Fit page adjusts the current page to the viewport. Switch between one/two pages and continuous/page-by-page scrolling.');
      AddSection('Table of contents and loading',
        'Use Contents to display embedded PDF bookmarks. The first PDF page is prioritized; “Opening PDF…” disappears as soon as the first page has rendered. Visible toolbars are not unnecessarily redrawn while loading.');
      AddSection('Search features in the Edit menu',
        'Local text search (Ctrl+F) and global PDF search (Ctrl+Shift+F) are available in the Edit menu. '
        + 'These commands are disabled when no PDF is open. F3 finds the next match in the current PDF.');
      AddSection('Select and copy text with the mouse',
        'Drag the left mouse button over PDF text to select it with a light-blue highlight and outline. ' +
        'Double-click to select a word, then press Ctrl+C to copy the selection to the clipboard. ' +
        'Alt + drag pans a zoomed page. The PDF file is not modified. ' +
        'Scanned pages without a text layer cannot be selected this way.');
      AddSection('Search modes and highlights',
        'Search open tabs (Ctrl+Shift+A) locates open PDF tabs by document name; it does not jump to a text match. '
        + 'Search (Ctrl+F) finds text in the current PDF; Search PDFs (Ctrl+Shift+F) searches across all open PDFs. '
        + 'Click inside the PDF page to clear temporary search highlights.');
      AddSection('Search text',
        'Find text searches the current PDF. Press F3 for the next match and Shift+F3 for the previous one. Search all PDFs or press Ctrl+Shift+F to search all open PDF tabs. The button is available directly after opening PDFs from FreePDF64 without switching tabs. The search handler is also assigned to all tabs when PDFs are opened directly. Selecting a result displays the relevant page and closes the global search window.');
      AddSection('Editing and combining PDFs', '');
      AddSection('Thumbnails and editing PDF pages',
        'Click the thumbnail icon at the top left to open the PDF file’s thumbnail view. A normal left-click clears previous selections, selects only the clicked thumbnail and displays that page. Use Ctrl+Click to add or remove individual pages from the selection and Shift+Click to select a range. A blue border indicates the currently displayed page; a red border indicates a selected thumbnail. If the current page is also selected, both borders appear (blue outside, red inside). Press Esc to clear the thumbnail selection without closing the thumbnail view. Right-click to delete or rotate selected pages together, use Extract page(s)… to save them as a separate PDF, or choose Insert PDF before page… / Insert PDF after page… to insert all pages of another PDF at the selected position. '
        + 'Drag a thumbnail with the left mouse button held down to change the PDF page order. Page thumbnails automatically resize when you widen or narrow the left sidebar with the mouse. Save the modified PDF with Save As…. The original remains unchanged when extracting pages.');
      AddSection('Fast rotation without a temporary PDF file',
        'Pages are rotated directly in the open PDFium document in memory. The original file is not overwritten immediately; changes become permanent only when saved.');
      AddSection('Editing and saving',
        'Edit opens the annotation and drawing tools. Visual redaction draws black rectangles over text, but the underlying text is NOT removed and can still be extracted. Do not use this for secure redaction of confidential information. Save changes with Save As….');
      AddSection('Insert text into PDF pages',
        'In Edit mode, enable Insert text and click the desired position on a PDF page. '
        + 'Type in the input field displayed over the page. Hold Ctrl and drag with the left mouse button to move the input field; '
        + 'drag its bottom-right resize handle to adjust its width and height. '
        + 'Press Enter to insert the text or Esc to cancel. '
        + 'Choose the font, font size and text color in the text toolbar. '
        + 'The text is inserted into the PDF page content; save changes with Save As.');
      AddSection('Highlight text and rectangular areas',
        'In Edit mode, enable Highlight text and drag the left mouse button over the desired words or text passages. '
        + 'For selections across multiple lines, the highlighted areas follow the selected text. '
        + 'Hold Shift while dragging with the left mouse button to select a freely sized rectangular area, including image areas. '
        + 'A blue outline shows the selected rectangle while dragging and disappears when the mouse button is released. '
        + 'Choose the highlight color using Color .... Highlights are saved as PDF annotations; save changes with Save As.');
      AddSection('Text comments on PDF pages',
        'Enable Comment in the tools toolbar, click a position on the PDF page and enter your comment '
        + 'in the multiline text field. A yellow speech-bubble icon marks the comment. '
        + 'Move the mouse over the icon to display your comment, including line breaks. '
        + 'Right-click the icon for Edit comment, Move comment or Delete comment. '
        + 'To move it, select Move comment and click the new position on the page; '
        + 'the mouse pointer changes to a crosshair while choosing the position. '
        + 'Comments are stored as PDF annotations when you save the PDF and can be '
        + 'edited again after reopening, provided the document permissions allow it.');
      AddSection('Undo and redo text and highlights',
        'Use the curved arrow buttons in the text toolbar (Undo and Redo) to undo or redo inserted text and highlights '
        + 'in the order they were created. This does not apply to other drawings or page operations. '
        + 'The editing history belongs to the open document and is reset when the document is closed or saved.');
      AddSection('Merge PDF files and selected pages',
        'Choose Edit > Merge PDFs... to combine PDF files already open in tabs. '
        + 'Tick the files to include and enter pages separately for each PDF: All, 3, 2-5, '
        + '1, 4, 8 or 1-3, 7, 10-12. Select a row and use the arrow buttons to change '
        + 'the PDF order; its page selection moves with it. Click the question-mark '
        + 'button in the merge dialog for help. Save the result as a new PDF. '
        + 'Original PDFs are not modified; unsaved changes in open tabs are not included.');
      AddSection('Watermarks and hyperlinks', '');
      AddSection('Text watermarks',
        'Right-click in the PDF thumbnail pane and select Add text watermark. Enter the text, '
        + 'then choose font size, opacity, rotation angle and whether to apply it to the current page '
        + 'or all pages. Save the PDF to keep the watermark.');
      AddSection('Image watermarks',
        'Choose Add image watermark in the PDF thumbnail context menu. Select a JPG or PNG image '
        + 'and set its size, opacity, rotation and page range. Save the PDF to keep the result.');
      AddSection('Add and move hyperlinks',
        'Choose Add hyperlink in the PDF thumbnail context menu, then drag a rectangle on the PDF page. '
        + 'Enter the visible text and a web or email link target. The link appears blue and underlined. '
        + 'Hover to see the link target and a hand cursor. Hold Ctrl and drag with the left mouse button '
        + 'to move the hyperlink text, underline and clickable area together. Save the PDF to keep the changes. '
        + 'These editing features are available for PDF files only, not images.');
      AddSection('Undo and redo watermarks',
        'After inserting a text or image watermark, the Tools toolbar is shown so that Undo and Redo ' +
        'are accessible. A watermark applied to all pages can be undone or restored as one action. ' +
        'Check the result before saving the PDF.');
      AddSection('Correct an invalid hyperlink target',
        'If a hyperlink address is invalid, the input dialog remains available for correction. ' +
        'The entered display text is retained and the link target can be edited.');
      AddSection('Manage hyperlinks',
        'Right-click the PDF thumbnail pane and choose Manage hyperlinks to list URI links ' +
        'with page number, display text and destination. Select a link to jump to its page, ' +
        'change its destination or delete the clickable link annotation. When deleting a link, ' +
        'the visible text remains. Save the PDF to preserve your changes.');
      AddSection('Interactive forms', '');
      AddSection('JavaScript (V8) and automatic calculations',
        'Supported AcroForm JavaScript actions can validate field entries and update calculated values, '
        + 'including totals affected by checkboxes and radio buttons. Calculated results on other pages '
        + 'are refreshed when displayed without having to save and reopen the PDF. '
        + 'JavaScript compatibility depends on the form and the PDFium/V8 implementation.');
      AddSection('Static XFA forms',
        'Supported static XFA forms can be edited using their interactive fields. When saving, '
        + 'the corresponding XFA datasets are synchronized with the AcroForm field values where '
        + 'the form structure allows it. Dynamic XFA and every possible XFA form are not guaranteed to work.');
      AddSection('Interactive PDF forms (AcroForm)',
        'Fill in text fields and multiline notes directly in the PDF. Supported forms include checkboxes, radio buttons, drop-down lists and PDF list boxes. '
        + 'Use Tab to move between editable fields. Hidden, invisible and non-viewable fields are skipped.');
      AddSection('Form choices, required fields and Unicode',
        'Select a single entry or multiple entries in supported list boxes (Ctrl for multiple selection). '
        + 'Field labels and values may contain Unicode characters, including accented letters and German umlauts. '
        + 'Required fields and read-only field properties are respected where supported by the PDF form.');
      AddSection('Multiline form editing',
        'Press Enter or Shift+Enter to insert line breaks in multiline form fields. '
        + 'The editor uses a readable font size while typing.');
      AddSection('Form field highlighting and zoom',
        'Interactive form fields can be highlighted for easier identification. '
        + 'The temporary text editor scales with the PDF zoom level, including during active editing.');
      AddSection('Save As and unsaved changes',
        'Save As suggests the source PDF folder. When closing modified PDFs, the confirmation lists '
        + 'the affected file names and offers Save all, Do not save or Cancel.');
      AddSection('Save completed PDF forms',
        'Save the completed PDF and reopen it to check the entered values and selections. '
        + 'Use Save As to preserve the original document when needed. Some forms may depend on PDF features not supported by this viewer.');
      AddSection('Document information and tools', '');
      AddSection('Attachments and document properties',
        'PDF attachments are files embedded in a PDF, such as invoices, spreadsheets or supplementary documents. This lets related files be shared and archived together. A small asterisk (*) on the paperclip indicates that the currently displayed PDF contains embedded attachments. Without an asterisk, no embedded attachments have been detected. The tooltip always reads “Show PDF attachments” regardless of whether attachments are available. Click the paperclip to show or hide the attachment list and view or extract embedded files. Document properties provide information about the PDF and its security settings.');
      AddSection('Display and Logging', '');
      AddSection('4K and high-DPI dialogs',
        'Global PDF search and saved workspace management use DPI-aware spacing, line heights and buttons. '
        + 'Workspace dialogs for saving, renaming, deleting and displaying messages also scale their window sizes and wrap text.');
      AddSection('Error logging',
        'The viewer automatically records handled program errors in FreePDF_Error.log beside the EXE. ' +
        'Each entry contains the date and time, thread ID, error context, exception type and message. ' +
        'The error message is still displayed in the viewer. The EXE folder must be writable for the log to be saved. ' +
        'This error log is separate from FreePDF64ViewerLog.txt, which records attachment-management actions.');
      AddSection('Log file',
        'The viewer logs attachment-management actions in FreePDF64ViewerLog.txt. The file is stored beside the EXE and is created or appended as needed. The folder must be writable.');
      if not RunningAlongsideFreePDF64 then
        AddSection('Windows startup and minimized startup',
          'Use Options → Start with Windows to launch the viewer automatically when you sign in. A check mark indicates whether startup is enabled. This setting applies only to the current Windows user. '
          + 'Options → Start minimized controls whether the viewer starts minimized when no PDF is open. If Minimize to tray on close is also enabled, it starts in the Windows notification area. '
          + 'The minimized-start setting is stored in FreePDFViewer.ini. If you move the portable EXE, configure the startup path again.');
      if not RunningAlongsideFreePDF64 then
        AddSection('Portable settings',
          'FreePDFViewer.ini is stored beside the EXE. Under Options, choose whether closing the viewer sends it to the notification area. File → Exit closes the viewer without a general confirmation; unsaved changes may still prompt you to save.');
      AddSection('Project page and more information',
        'https://github.com/FreePDF64/FreePDF64ViewerPortable');
    end
    else
    begin
      AddTOC(['Anpassbare Benutzeroberfläche (Designs)', 'Grafiken und mehrseitige TIFF-Dateien',
        'PDFs öffnen und organisieren', 'Anzeige, Navigation und Suche',
        'PDFs bearbeiten und zusammenführen', 'Wasserzeichen und Hyperlinks',
        'Interaktive Formulare', 'Dokumentinformationen und Werkzeuge',
        'Darstellung und Protokollierung']);
      AddSection('Anpassbare Benutzeroberfläche (Designs)', '');
      AddSection('Design auswählen',
        'Fünf Designs stehen zur Auswahl: Standard, Modern Hell, Modern Dunkel, Windows Klassik und Klassisch Blau. '
        + 'Symbolleisten, Schaltflächen und Bedienelemente werden farblich an das gewählte Design angepasst. '
        + 'Wählen Sie das gewünschte Design unter Optionen → Design.');
      AddSection('Grafiken und mehrseitige TIFF-Dateien', '');
      AddSection('Grafikdateien öffnen',
        'JPG-, JPEG-, PNG-, BMP-, TIF- und TIFF-Dateien können zusammen mit PDFs geöffnet werden. '
        + 'Jede Datei erhält eine eigene Registerkarte. Beim Wechsel zwischen Grafik- und PDF-Registerkarten '
        + 'müssen die Dateien nicht erneut geöffnet werden.');
      AddSection('Grafik-Symbolleiste und Zoom',
        'Über die Grafik-Symbolleiste können Sie vergrößern, verkleinern, 100 % wählen, die ganze Grafik '
        + 'an den Anzeigebereich oder an dessen Breite anpassen. Beim Einpassen wird die Grafik zentriert. '
        + 'Mit Strg + Mausrad zoomen Sie die Grafik; ohne Strg wird wie gewohnt gescrollt.');
      AddSection('Grafiken drehen, speichern und drucken',
        'Mit den Symbolen drehen Sie Grafiken um 90° nach links oder rechts. Nach einer Änderung '
        + 'wird der Speichern-Button orange. Zoomen, Scrollen und Einpassen gelten nicht als Änderung. '
        + 'Einzelne Grafiken lassen sich über „Speichern unter ...“ sichern; bei Abbruch bleibt die '
        + 'Änderungsanzeige bestehen. Die Grafik-Symbolleiste bietet auch eine Druckfunktion.');
      AddSection('Mehrseitige TIFF-Dateien',
        'Bei mehrseitigen TIFFs wechseln Sie mit den Pfeilschaltflächen zwischen den Seiten; '
        + 'die Seitenanzeige zeigt die aktuelle Position. Zoomen und Drehen sind auch hier möglich. '
        + 'Über „Speichern unter ...“ werden alle Seiten einschließlich ihrer individuellen Drehungen '
        + 'als neue mehrseitige TIFF-Datei gespeichert. Das Original bleibt unverändert.');
      AddSection('PDFs öffnen und organisieren', '');
      AddSection('PDF-Dateien öffnen',
        'Über „Datei → PDF öffnen …“, Strg+O oder per Drag&Drop. Mehrere PDFs werden in eigenen Tabs geöffnet.');
      AddSection('Zuletzt geöffnete PDF-Dateien auf der Startseite',
        'Wenn kein PDF geöffnet ist, zeigt die scrollbar gestaltete Startseite die letzten 15 geöffneten PDF-Dateien. '
        + 'Die Einträge erscheinen platzsparend in zwei Spalten nebeneinander; bei schmalem Fenster in einer Spalte. '
        + 'Neben dem Dateinamen und Dateipfad wird ein kleines Vorschaubild der ersten PDF-Seite angezeigt. '
        + 'Ein Klick auf den Eintrag oder das Vorschaubild öffnet die PDF-Datei. '
        + 'Per Rechtsklick können Sie einen Eintrag aus der Liste entfernen oder den Dateiordner öffnen. '
        + 'Mit „Verlauf löschen“ entfernen Sie die gesamte Liste nach einer Bestätigung. '
        + 'Der Verlauf wird in FreePDFViewer.ini gespeichert. Vorschaubilder liegen als BMP-Dateien im Ordner Thumbnails neben dem Viewer. Beim Start werden Vorschaubilder gelöscht, die älter als 30 Tage sind; „Verlauf löschen“ entfernt zusätzlich alle gespeicherten Vorschaubilder.');
      AddSection('Geschlossene PDFs wieder öffnen',
        'Klicken Sie auf der leeren Startseite mit der rechten Maustaste. '
        + 'Unter „Geschlossene PDFs wieder öffnen“ finden Sie zuletzt geschlossene Dokumente. '
        + 'Nicht verfügbare Einträge sind ausgegraut.');
      AddSection('Tabs verwalten',
        'Das × im Tab, die mittlere Maustaste oder Strg+W schließen ein PDF. Bei ungespeicherten Änderungen erscheint eine Rückfrage.');
      AddSection('Benannte PDF-Arbeitsbereiche',
        'Über „Arbeitsbereiche > Arbeitsbereiche verwalten ...“ verwalten Sie Ihre gespeicherten Arbeitsbereiche. '
        + 'Mit „Arbeitsbereiche > Arbeitsbereich speichern ...“ speichern Sie die aktuelle PDF-Sammlung. '
        + 'Das Arbeitsbereiche-Symbol öffnet die Verwaltung mit der linken Maustaste und speichert einen Arbeitsbereich mit der rechten Maustaste. '
        + 'Das Verwaltungsfenster erscheint mittig über dem Viewer und zeigt Name, Speicherdatum und PDF-Anzahl. '
        + 'Über das Suchfeld filtern Sie Arbeitsbereiche nach ihrem Namen. Klicken Sie auf die Spaltenüberschriften „Name“, „Gespeichert am“ oder „PDFs“, um zu sortieren; ein weiterer Klick kehrt die Reihenfolge um. '
        + 'Die zuletzt gewählte Sortierspalte und Sortierrichtung werden in der FreePDFViewer.ini gespeichert und beim nächsten Öffnen wiederhergestellt. '
        + 'Mit „Inhalt anzeigen ...“ sehen Sie die gespeicherten PDF-Dateipfade, ohne den Arbeitsbereich zu öffnen. '
        + 'Ein Doppelklick oder Enter öffnet den markierten Arbeitsbereich; alternativ verwenden Sie „Öffnen“. '
        + 'Mit „Alle schließen + öffnen“ werden nach Prüfung ungespeicherter Änderungen die bisher geöffneten PDFs geschlossen und nur der gewählte Arbeitsbereich geladen. '
        + 'Umbenennen und Löschen sind ebenfalls möglich. Bereits geöffnete PDFs bleiben beim normalen Öffnen erhalten; doppelte Dateien werden nicht erneut geöffnet. Fehlende Dateien werden gemeldet. '
        + 'Arbeitsbereiche liegen als lokale INI-Dateien im Arbeitsbereichsordner neben der EXE; die PDF-Dateien selbst bleiben unverändert. '
        + 'Gespeichert werden die PDFs in Tab-Reihenfolge, je PDF Seite, Zoomstufe und Scrollposition sowie der zuletzt aktive Tab.');
      AddSection('Zweifensteransicht und Miniaturen',
        'Mit Strg+Klick zwei PDF-Registerkarten auswählen und über „Ansicht teilen“ nebeneinander anzeigen. '
        + 'Den Mitteltrenner mit der Maus verschieben, um die Fensterbreiten anzupassen. '
        + 'Mit einem Klick in ein PDF oder mit der Tab-Taste zwischen den Teilfenstern wechseln; '
        + 'ein blauer Rahmen kennzeichnet das aktive Fenster. Links oben in jedem Teilfenster befinden sich '
        + 'drei kleine Schaltflächen: Teilung beenden, Text im jeweiligen PDF suchen und dessen '
        + 'Seitenminiaturen ein- oder ausblenden. Bei geöffneter Seitenleiste verschwindet der '
        + 'Miniaturbutton und erscheint nach dem Schließen wieder. '
        + 'In der normalen Ansicht wird der Zustand der Miniaturansicht (eingeschaltet oder ausgeschaltet) dauerhaft in FreePDFViewer.ini gespeichert und gilt für alle bereits geöffneten sowie später geöffneten PDF-Dateien, auch nach einem Neustart. Die Zweifensteransicht startet immer ohne Miniaturansichten; diese lassen sich für beide Teilfenster unabhängig voneinander ein- und ausschalten. Nach dem Beenden der Zweifensteransicht wird die gespeicherte Einstellung der normalen Ansicht wiederhergestellt. '
        + 'F3 sucht im aktiven Teilfenster weiter, Umschalt+F3 rückwärts. '
        + 'Über „Ansicht teilen“ oder einen Teilungsbutton zur Einfensteransicht zurückkehren. '
        + 'Der Teilungsbutton ist bei zwei ausgewählten Registerkarten oder aktiver Teilung verfügbar. '
        + 'In der Zweifensteransicht schaltet S das synchrone Scrollen vom linken zum rechten PDF ein oder aus. '
        + 'Mit Z lässt sich der Zoomfaktor des rechten PDFs an den linken koppeln. '
        + 'Beide Funktionen sind unabhängig voneinander zuschaltbar.');
      AddSection('Visueller Vergleich zweier PDF-Dateien',
        'Wählen Sie zwei geöffnete PDF-Registerkarten aus und rufen Sie im Menü der Zweifensteransicht '
        + '„PDFs visuell vergleichen ...“ auf. Das separate Vergleichsfenster zeigt beide PDF-Seiten '
        + 'nebeneinander mit mittiger Trennlinie. Erkannte Unterschiede werden farbig umrahmt. '
        + 'Mit „Vorheriger“ und „Nächster“ wechseln Sie zwischen den Unterschiedsbereichen. '
        + '„Anzeigen“ und „Ausblenden“ schalten nur die farbigen Markierungen um; beide PDFs bleiben sichtbar. '
        + 'Über die Seitennavigation wählen Sie das nächste Seitenpaar. Der Vergleich wird im Hintergrund '
        + 'berechnet, zeigt den Fortschritt an und lässt sich mit „Abbrechen“ beenden. '
        + 'Auch kleine Textänderungen werden berücksichtigt; geringfügige Darstellungsabweichungen '
        + 'und Antialiasing werden gefiltert, um Fehlmarkierungen zu reduzieren. '
        + 'Die Original-PDF-Dateien bleiben unverändert.');
      AddSection('Anzeige, Navigation und Suche', '');
      AddSection('Zoom, 100 % und Seitennavigation',
        'Mit den Pfeiltasten zur vorherigen oder nächsten Seite wechseln. Der direkte 100-%-Button zeigt die Originalgröße; '
        + 'die Zoomtasten verwenden feste Stufen. „Seite anpassen“ passt die aktuelle Seite an den sichtbaren Bereich an.');
      AddSection('Anzeige und Navigation',
        'Mit der PDF-Werkzeugleiste Seiten wechseln, zoomen, Seiten einpassen, zwei Seiten oder die durchgehende Anzeige wählen.');
      AddSection('Inhaltsverzeichnis und Laden',
        'Über „Inhalte“ zeigen Sie die eingebetteten PDF-Lesezeichen an. ' +
        'Die erste PDF-Seite wird bevorzugt geladen; „PDF wird geöffnet ...“ ' +
        'verschwindet, sobald die erste Seite gerendert ist. ' +
        'Beim Laden werden bereits sichtbare Symbolleisten nicht unnötig neu gezeichnet.');
      AddSection('Suchfunktionen im Menü Bearbeiten',
        'Die lokale Textsuche (Strg+F) und die globale PDF-Suche (Strg+Umschalt+F) ' +
        'finden Sie im Menü „Bearbeiten“. Ohne geöffnete PDF sind die Befehle deaktiviert. ' +
        'F3 sucht die nächste Fundstelle innerhalb der aktuellen PDF.');
      AddSection('Text mit der Maus auswählen und kopieren',
        'Mit gedrückter linker Maustaste über den Text ziehen, um ihn hellblau mit einem Rahmen zu markieren. ' +
        'Ein Doppelklick wählt ein Wort aus. Mit Strg+C kopieren Sie die Auswahl in die Zwischenablage. ' +
        'Alt + Ziehen verschiebt eine vergrößerte Seite. Die PDF-Datei bleibt unverändert. ' +
        'Bei gescannten Seiten ohne Textebene ist keine Textauswahl möglich.');
      AddSection('Sucharten und Markierungen',
        '„Geöffnete Registerkarten suchen“ (Strg+Umschalt+A) sucht nach geöffneten PDF-Tabs, nicht nach Textstellen. '
        + '„Suchen“ (Strg+F) durchsucht die aktuelle PDF, „PDFs durchsuchen“ (Strg+Umschalt+F) alle geöffneten PDFs. '
        + 'Ein Klick in die PDF-Seite entfernt die temporären Suchmarkierungen.');
      AddSection('Text suchen',
        '„Text suchen“ durchsucht die aktuelle PDF. Mit F3 springen Sie zum nächsten Treffer, mit Umschalt+F3 zum vorherigen Treffer. ' +
        '„Alle PDFs durchsuchen“ oder Strg+Umschalt+F durchsucht alle geöffneten PDF-Registerkarten. Die Schaltfläche ist direkt nach dem Öffnen der PDFs aus FreePDF64 verfügbar, ohne Registerwechsel. Auch beim direkten Start mit PDF-Dateien wird der Such-Handler für alle Registerkarten gesetzt. ' +
        'Auswahl eines Treffers zeigt die betreffende Seite und schließt das globale Suchfenster.');
      AddSection('PDFs bearbeiten und zusammenführen', '');
      AddSection('Miniaturansicht und PDF-Seiten bearbeiten',
        'Über Klick auf das Miniaturansicht-Symbol links oben öffnen Sie die Miniaturansicht der PDF-Datei. Ein einfacher Linksklick hebt bisherige Markierungen auf, markiert nur die angeklickte Miniatur und zeigt die entsprechende Seite an. Mit Strg+Klick fügen Sie einzelne Seiten zur Auswahl hinzu oder entfernen sie daraus; mit Umschalt+Klick wählen Sie einen zusammenhängenden Seitenbereich aus. Ein blauer Rahmen kennzeichnet die aktuell angezeigte Seite, ein roter Rahmen eine markierte Miniatur. Ist die aktuelle Seite zugleich markiert, erscheinen beide Rahmen (blau außen, rot innen). Mit Esc heben Sie die Markierung auf, ohne die Miniaturansicht zu schließen. ' +
        'Per Rechtsklick lassen sich mehrere markierte Seiten gemeinsam löschen, drehen oder über „Seite(n) extrahieren ...“ ' +
        'als eigenständige neue PDF-Datei speichern. Mit „PDF einfügen vor Seite ...“ oder „PDF einfügen nach Seite ...“ fügen Sie alle Seiten einer anderen PDF-Datei an der ausgewählten Position ein. ' +
        'Per Ziehen mit gedrückter linker Maustaste können Sie Seiten in der PDF-Reihenfolge verschieben. ' +
        'Die Größe der Seitenminiaturen passt sich automatisch an, wenn Sie die linke Seitenleiste mit der Maus verbreitern oder verkleinern. ' +
        'Die geänderte PDF können Sie über „Speichern unter ...“ sichern. ' +
        'Das Original bleibt beim Extrahieren unverändert.');
      AddSection('Schnelles Drehen ohne temporaere PDF-Datei',
        'Seiten werden im geoeffneten PDFium-Dokument direkt im Speicher gedreht. ' +
        'Das Original wird dadurch nicht sofort ueberschrieben. ' +
        'Die Aenderungen werden erst beim Speichern dauerhaft uebernommen.');
      AddSection('Bearbeiten und Speichern',
        '„Bearbeiten“ öffnet die Markierungs- und Zeichenwerkzeuge. „Schwärzen (optisch)“ zeichnet schwarze Rechtecke über Text. ' +
        'Der darunterliegende Text wird NICHT entfernt und kann weiterhin extrahiert werden. Keine sichere Schwärzung vertraulicher Inhalte. ' +
        'Änderungen mit „Speichern unter ...“ sichern.');
      AddSection('Text in PDF-Seiten einfügen',
        'Im Bearbeitungsmodus „Text einfügen“ aktivieren und auf die gewünschte Stelle der PDF-Seite klicken. '
        + 'Den Text in das eingeblendete Eingabefeld schreiben. Mit gedrückter Strg-Taste und linker Maustaste '
        + 'lässt sich das Eingabefeld verschieben; am Ziehgriff unten rechts können Breite und Höhe verändert werden. '
        + 'Mit Enter den Text einfügen oder mit Esc abbrechen. '
        + 'In der Textwerkzeugleiste Schriftart, Schriftgröße und Textfarbe auswählen. '
        + 'Der Text wird als PDF-Seiteninhalt eingefügt; Änderungen über „Speichern unter ...“ sichern.');
      AddSection('Text und rechteckige Bereiche hervorheben',
        'Im Bearbeitungsmodus „Text hervorheben“ aktivieren und mit gedrückter linker Maustaste '
        + 'über einzelne Wörter oder Textabschnitte ziehen. Bei mehrzeiliger Auswahl folgen die Markierungen dem ausgewählten Text. '
        + 'Mit gedrückter Umschalttaste und linker Maustaste lässt sich auch ein beliebiger rechteckiger Bereich '
        + 'aufziehen, beispielsweise über Bildern. Während des Ziehens zeigt ein blauer Rahmen den gewählten Bereich; '
        + 'beim Loslassen verschwindet er. Die Hervorhebungsfarbe über „Farbe ...“ auswählen. '
        + 'Hervorhebungen werden als PDF-Annotationen gespeichert; Änderungen über „Speichern unter ...“ sichern.');
      AddSection('Textkommentare auf PDF-Seiten',
        'In der Werkzeugleiste „Kommentar“ aktivieren, auf die gewünschte Stelle der PDF-Seite klicken '
        + 'und den Kommentar mehrzeilig eingeben. Eine gelbe Sprechblase kennzeichnet die Notiz. '
        + 'Beim Überfahren des Symbols mit der Maus erscheint der eigene Kommentartext einschließlich Zeilenumbrüchen. '
        + 'Per Rechtsklick stehen „Kommentar bearbeiten“, „Kommentar verschieben“ und „Kommentar löschen“ zur Verfügung. '
        + 'Zum Verschieben „Kommentar verschieben“ wählen und anschließend auf die neue Position der Seite klicken; '
        + 'während der Positionswahl erscheint ein Fadenkreuz. '
        + 'Beim Speichern werden Kommentare als echte PDF-Anmerkungen übernommen und können nach erneutem Öffnen '
        + 'weiter bearbeitet werden, sofern die Dokumentberechtigungen dies zulassen.');
      AddSection('Text und Hervorhebungen rückgängig machen und wiederholen',
        'Mit den gebogenen Pfeilsymbolen „Rückgängig“ und „Wiederholen“ in der Textwerkzeugleiste '
        + 'lassen sich eingefügter PDF-Text und Hervorhebungen in ihrer Bearbeitungsreihenfolge '
        + 'zurücknehmen und wiederherstellen. Andere Zeichnungen und Seitenbearbeitungen sind nicht enthalten. '
        + 'Der Verlauf gehört zum geöffneten Dokument und wird beim Schließen oder Speichern zurückgesetzt.');
      AddSection('PDF-Dateien und ausgewählte Seiten zusammenführen',
        'Über „Bearbeiten > PDFs zusammenführen ...“ können Sie PDF-Dateien aus '
        + 'geöffneten Registerkarten zu einer neuen PDF zusammenführen. '
        + 'Wählen Sie die gewünschten Dateien per Kontrollkästchen und geben Sie '
        + 'für jede PDF eigene Seiten an: Alle, 3, 2-5, 1, 4, 8 oder 1-3, 7, 10-12. '
        + 'Mit den Pfeiltasten ändern Sie die Reihenfolge; die Seitenangabe bleibt '
        + 'der jeweiligen PDF zugeordnet. Über die Schaltfläche mit dem Fragezeichen '
        + 'öffnen Sie die Dialoghilfe. Das Ergebnis wird als neue PDF gespeichert. '
        + 'Die Originaldateien bleiben unverändert; ungespeicherte Änderungen '
        + 'geöffneter PDFs werden nicht übernommen.');
      AddSection('Wasserzeichen und Hyperlinks', '');
      AddSection('Textwasserzeichen hinzufügen',
        'Klicken Sie mit der rechten Maustaste in die PDF-Miniaturansicht und wählen Sie '
        + '„Textwasserzeichen hinzufügen ...“. Geben Sie den Text ein und wählen Sie Schriftgröße, '
        + 'Deckkraft, Drehwinkel sowie die aktuelle oder alle Seiten. Speichern Sie anschließend die PDF.');
      AddSection('Bildwasserzeichen hinzufügen',
        'Wählen Sie „Bildwasserzeichen hinzufügen ...“ im Kontextmenü der PDF-Miniaturansicht. '
        + 'Wählen Sie eine JPG- oder PNG-Datei und stellen Sie Größe, Deckkraft, Drehwinkel und '
        + 'Seitenbereich ein. Speichern Sie anschließend die PDF.');
      AddSection('Hyperlinks hinzufügen und verschieben',
        'Wählen Sie „Hyperlink hinzufügen ...“ im Kontextmenü der PDF-Miniaturansicht und ziehen Sie '
        + 'mit der Maus einen Bereich auf der PDF-Seite auf. Geben Sie den sichtbaren Anzeigetext und '
        + 'eine Webadresse oder E-Mail-Adresse ein. Der Text erscheint blau und unterstrichen. '
        + 'Beim Überfahren zeigt ein Hinweis das Linkziel und der Mauszeiger wird zur Hand. '
        + 'Mit gedrückter Strg-Taste und linker Maustaste verschieben Sie Text, Unterstrich und '
        + 'anklickbaren Linkbereich gemeinsam. Speichern Sie die PDF, um die Änderungen zu übernehmen. '
        + 'Diese Bearbeitungsfunktionen stehen nur für PDF-Dateien zur Verfügung, nicht für Grafiken.');
      AddSection('Wasserzeichen rückgängig machen und wiederholen',
        'Nach dem Einfügen eines Text- oder Bildwasserzeichens wird die Symbolleiste „Werkzeuge“ ' +
        'eingeblendet, damit Rückgängig und Wiederholen erreichbar sind. Ein Wasserzeichen auf ' +
        'allen Seiten kann als gemeinsamer Schritt rückgängig gemacht und wiederhergestellt werden. ' +
        'Prüfen Sie das Ergebnis vor dem Speichern der PDF.');
      AddSection('Ungültige Hyperlink-Adresse korrigieren',
        'Bei einer ungültigen Hyperlink-Adresse bleibt der Eingabedialog zur Korrektur verfügbar. ' +
        'Der eingegebene Anzeigetext bleibt erhalten; das Linkziel kann berichtigt werden.');
      AddSection('Hyperlinks verwalten',
        'Klicken Sie mit der rechten Maustaste in die PDF-Miniaturansicht und wählen Sie ' +
        '„Hyperlinks verwalten ...“. Die Übersicht zeigt URI-Hyperlinks mit Seitenzahl, ' +
        'Anzeigetext und Linkziel. Sie können zur betreffenden Seite springen, das Linkziel ' +
        'ändern oder die anklickbare Linkannotation löschen. Beim Löschen bleibt der sichtbare ' +
        'Text erhalten. Speichern Sie die PDF, um die Änderungen zu übernehmen.');
      AddSection('Interaktive Formulare', '');
      AddSection('JavaScript (V8) und automatische Berechnungen',
        'Unterstützte AcroForm-JavaScript-Aktionen können Eingaben prüfen und berechnete Werte aktualisieren, '
        + 'auch bei Änderungen von Kontrollkästchen und Optionsfeldern. Berechnungsergebnisse auf anderen '
        + 'Seiten werden beim Anzeigen aktualisiert, ohne dass die PDF zuvor gespeichert und erneut '
        + 'geöffnet werden muss. Die JavaScript-Kompatibilität hängt vom Formular und von PDFium/V8 ab.');
      AddSection('Statische XFA-Formulare',
        'Unterstützte statische XFA-Formulare lassen sich über ihre interaktiven Felder bearbeiten. '
        + 'Beim Speichern werden die zugehörigen XFA-Datensätze mit den AcroForm-Feldwerten synchronisiert, '
        + 'soweit die Formularstruktur dies zulässt. Dynamische XFA-Formulare und beliebige XFA-Strukturen '
        + 'werden nicht uneingeschränkt unterstützt.');
      AddSection('Interaktive PDF-Formulare (AcroForm)',
        'Textfelder und mehrzeilige Notizfelder direkt in der PDF ausfüllen. Unterstützt werden außerdem Kontrollkästchen, Optionsfelder, Dropdown-Listen und echte PDF-Listenfelder. '
        + 'Mit Tab wechseln Sie zwischen bearbeitbaren Feldern. Versteckte, unsichtbare und nicht anzeigbare Felder werden übersprungen.');
      AddSection('Auswahlfelder, Pflichtfelder und Unicode',
        'In unterstützten Listenfeldern können Sie einzelne oder mit Strg mehrere Einträge auswählen. '
        + 'Feldbezeichnungen und Werte können Unicode-Zeichen einschließlich Umlauten und Sonderzeichen enthalten. '
        + 'Pflichtfelder und schreibgeschützte Feldeigenschaften werden berücksichtigt, soweit das PDF-Formular dies unterstützt.');
      AddSection('Mehrzeilige Formulareingabe',
        'In mehrzeiligen Formularfeldern erzeugen Enter und Umschalt+Enter Zeilenumbrüche. '
        + 'Die Schrift bleibt während der Eingabe gut lesbar.');
      AddSection('Formularhervorhebung und Zoom',
        'Interaktive Formularfelder können zur leichteren Erkennung hervorgehoben werden. '
        + 'Die Schrift des temporären Eingabeeditors passt sich dem PDF-Zoom an, auch während einer aktiven Bearbeitung.');
      AddSection('Speichern unter und ungespeicherte Änderungen',
        '„Speichern unter“ schlägt den Ordner der ursprünglichen PDF vor. '
        + 'Beim Schließen werden die Namen aller geänderten PDFs angezeigt; '
        + 'zur Auswahl stehen „Alle speichern“, „Nicht speichern“ und „Abbrechen“.');
      AddSection('Ausgefüllte PDF-Formulare speichern',
        'Speichern Sie die ausgefüllte PDF und öffnen Sie sie erneut, um Eingaben und Auswahlen zu kontrollieren. '
        + 'Mit „Speichern unter ...“ können Sie bei Bedarf das Original erhalten. Manche Formulare benötigen PDF-Funktionen, die dieser Viewer nicht unterstützt.');
      AddSection('Dokumentinformationen und Werkzeuge', '');
      AddSection('Anlagen und Dokumenteigenschaften',
        'PDF-Anlagen sind Dateien, die direkt in ein PDF eingebettet sind, zum Beispiel Rechnungen, Tabellen oder ergänzende Dokumente. ' +
        'So lassen sich zusammengehörige Unterlagen gemeinsam weitergeben und archivieren. ' +
        'Ein kleines Sternchen (*) an der Büroklammer zeigt an, dass die aktuell angezeigte PDF eingebettete Anlagen enthält. Ohne Sternchen wurden keine eingebetteten Anlagen erkannt. ' +
        'Der Hinweistext lautet unabhängig vom Vorhandensein von Anlagen immer „PDF-Anlagen anzeigen“. Mit einem Klick auf die Büroklammer können Sie die Anlagenliste ein- oder ausblenden, eingebettete Dateien anzeigen und bei Bedarf extrahieren. ' +
        'Die Dokumenteigenschaften informieren unter anderem über das PDF und seine Sicherheitseinstellungen.');
      AddSection('Darstellung und Protokollierung', '');
      AddSection('4K- und High-DPI-Dialoge',
        'Die globale PDF-Suche und die Verwaltung gespeicherter Arbeitsbereiche verwenden ' +
        'DPI-gerechte Abstände, Zeilenhöhen und Schaltflächen. ' +
        'Auch die Arbeitsbereich-Dialoge zum Speichern, Umbenennen, Löschen und für Hinweise ' +
        'verwenden skalierte Fenstergrößen und umbrechende Texte.');
      AddSection('Fehlerprotokollierung',
        'Der Viewer protokolliert behandelte Programmfehler automatisch in der Datei FreePDF_Error.log neben der EXE. ' +
        'Jeder Eintrag enthält Datum und Uhrzeit, Thread-ID, Fehlerkontext, Fehlertyp und Fehlermeldung. ' +
        'Die Fehlermeldung wird weiterhin im Viewer angezeigt. Damit die Protokolldatei gespeichert werden kann, muss der EXE-Ordner beschreibbar sein. ' +
        'Dieses Fehlerprotokoll ist unabhängig von FreePDF64ViewerLog.txt für Aktionen der Anlagenverwaltung.');
      AddSection('Protokolldatei',
        'Der Viewer protokolliert Aktionen der Anlagenverwaltung in der Datei FreePDF64ViewerLog.txt. ' +
        'Sie liegt im selben Ordner wie die EXE und wird bei Bedarf angelegt oder ergänzt. ' +
        'Der Ordner muss dafür beschreibbar sein.');
      if not RunningAlongsideFreePDF64 then
      AddSection('Windows-Autostart und minimierter Start',
        'Unter „Optionen → Mit Windows starten“ können Sie den Viewer beim Anmelden an Windows automatisch starten lassen. ' +
        'Ein Häkchen zeigt an, ob der Autostart aktiviert ist. Die Registrierung erfolgt nur für den aktuellen Windows-Benutzer. ' +
        'Unter „Optionen → Beim Start minimieren“ legen Sie fest, ob der Viewer beim Start ohne geöffnetes PDF minimiert werden soll. ' +
        'Ist zusätzlich „Beim Schließen in den Infobereich“ aktiviert, startet er im Windows-Infobereich. ' +
        'Die Minimierungseinstellung wird in FreePDFViewer.ini gespeichert. ' +
        'Wenn Sie die portable EXE verschieben, müssen Sie den Autostartpfad erneut einrichten.');
      if not RunningAlongsideFreePDF64 then
      AddSection('Portable Einstellungen',
        'FreePDFViewer.ini liegt neben der EXE. Unter „Optionen“ können Sie festlegen, ob der Viewer beim Schließen in den Infobereich wechseln soll. „Datei → Exit“ beendet den Viewer ohne allgemeine Bestätigungsabfrage; bei ungespeicherten Änderungen kann eine Speicherabfrage erscheinen.');
      AddSection('Projektseite und weitere Informationen',
        'https://github.com/FreePDF64/FreePDF64ViewerPortable');
    end;
    Scroll.VertScrollBar.Range := Y + Px(35);
    D.ShowModal;
  finally
    D.Free;
  end;
end;

procedure TPDFTabsForm.ShowPDFMergeHelp;
begin
  ShowModernInfo(False, True);
end;

procedure TPDFTabsForm.ShowAboutViewer(Sender: TObject);
begin
  ShowModernInfo(True);
end;

procedure TPDFTabsForm.ShowViewerHelp(Sender: TObject);
begin
  ShowModernInfo(False);
end;

procedure TPDFTabsForm.SetTrayIcon(AVisible: Boolean);
var
  Data: TNotifyIconDataW;
begin
  if AVisible = FTrayVisible then Exit;
  FillChar(Data, SizeOf(Data), 0);
  Data.cbSize := SizeOf(Data);
  Data.Wnd := Handle;
  Data.uID := 1;
  if AVisible then
  begin
    Data.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
    Data.uCallbackMessage := WM_APP + 195;
    Data.hIcon := Application.Icon.Handle;
    StringToWideChar('FreePDF64-Viewer', @Data.szTip[0], Length(Data.szTip));
    FTrayVisible := Shell_NotifyIconW(NIM_ADD, @Data);
  end
  else
  begin
    Shell_NotifyIconW(NIM_DELETE, @Data);
    FTrayVisible := False;
  end;
end;

procedure TPDFTabsForm.RestoreFromTray(Sender: TObject);
begin
  // Erst die Fensterdarstellung wiederherstellen, dann Tray-Icon entfernen.
  if WindowState = wsMinimized then WindowState := wsNormal;
  Show;
  ShowWindow(Handle, SW_RESTORE);
  UpdateWelcomeView;
  BringToFront;
  SetForegroundWindow(Handle);
  SetTrayIcon(False);
end;

procedure TPDFTabsForm.ExitFromTray(Sender: TObject);
begin
  // Bewusstes Beenden: anders als beim Fenster-X nicht in den Tray wechseln.
  FExitFromTray := True;
  try
    Close; // TabsFormClose führt die Sicherheitsabfragen aus.
  finally
    // Bei Abbrechen bleibt die Anwendung samt Tray-Funktion benutzbar.
    FExitFromTray := False;
  end;
end;

function ConfirmPDFViewerAssociation(AOwner: TCustomForm; const AAppTitle: string): Boolean;
var
  D: TViewerHelpForm;
  Header, Footer, InfoCard: TPanel;
  Content: TScrollBox;
  IconImage: TImage;
  L: TLabel;
  YesButton, NoButton: TButton;
  Scale: Integer;
  function Px(V: Integer): Integer;
  begin
    Result := MulDiv(V, Scale, 96);
  end;
  procedure TextLine(AParent: TWinControl; const AText: string;
    AX, AY, AWidth, AHeight, ASize: Integer; ABold: Boolean; AColor: TColor);
  begin
    L := TLabel.Create(D);
    L.Parent := AParent;
    L.SetBounds(Px(AX), Px(AY), Px(AWidth), Px(AHeight));
    L.AutoSize := False;
    L.WordWrap := True;
    L.ShowAccelChar := False;
    L.Caption := AText;
    L.Font.Name := 'Segoe UI';
    L.Font.Size := ASize;
    L.Font.Color := AColor;
    if ABold then L.Font.Style := [fsBold];
  end;
begin
  Result := False;
  D := TViewerHelpForm.CreateNew(AOwner);
  try
    Scale := AOwner.CurrentPPI;
    if Scale < 96 then Scale := 96;
    D.Caption := Tr('PDF-Dateien verknüpfen');
    D.Position := poOwnerFormCenter;
    D.BorderStyle := bsDialog;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.Color := clWhite;
    D.ClientWidth := Px(630);
    D.ClientHeight := Px(460);
    D.Constraints.MinWidth := Px(510);
    D.Constraints.MinHeight := Px(300);
    D.KeyPreview := True;

    Header := TPanel.Create(D);
    Header.Parent := D;
    Header.Align := alTop;
    Header.Height := Px(92);
    Header.BevelOuter := bvNone;
    Header.ParentBackground := False;
    Header.Color := RGB(19, 93, 169);

    IconImage := TImage.Create(D);
    IconImage.Parent := Header;
    IconImage.SetBounds(Px(24), Px(24), Px(54), Px(54));
    IconImage.Picture.Icon.Assign(Application.Icon);
    IconImage.Stretch := True;

    TextLine(Header, Tr('PDF-Dateien verknüpfen'), 95, 24, 505, 36,
      19, True, clWhite);
    TextLine(Header, AAppTitle + Tr(' als Standard-App einrichten'),
      97, 67, 500, 23, 10, False, RGB(224, 237, 250));

    Footer := TPanel.Create(D);
    Footer.Parent := D;
    Footer.Align := alBottom;
    Footer.Height := Px(68);
    Footer.BevelOuter := bvNone;
    Footer.ParentBackground := False;
    Footer.Color := RGB(230, 239, 249);

    NoButton := TButton.Create(D);
    NoButton.Parent := Footer;
    NoButton.Caption := Tr('Abbrechen');
    NoButton.ModalResult := mrCancel;
    NoButton.Cancel := True;
    NoButton.SetBounds(Px(475), Px(16), Px(130), Px(36));
    NoButton.Anchors := [akRight, akTop];

    YesButton := TButton.Create(D);
    YesButton.Parent := Footer;
    YesButton.Caption := Tr('Weiter');
    YesButton.ModalResult := mrYes;
    YesButton.Default := True;
    YesButton.SetBounds(Px(325), Px(16), Px(135), Px(36));
    YesButton.Anchors := [akRight, akTop];

    Content := TScrollBox.Create(D);
    Content.Parent := D;
    Content.Align := alClient;
    Content.BorderStyle := bsNone;
    Content.ParentBackground := False;
    Content.Color := RGB(250, 252, 255);
    Content.VertScrollBar.Visible := True;
    Content.VertScrollBar.Tracking := True;
    Content.HorzScrollBar.Visible := False;
    Content.AutoScroll := True;
    D.HelpScroll := Content;

    TextLine(Content, Tr('PDF-Dateien direkt im Viewer öffnen'),
      28, 22, 565, 29, 13, True, RGB(24, 83, 150));
    TextLine(Content,
      AAppTitle + Tr(' wird für Ihr Windows-Benutzerkonto als PDF-Anwendung registriert.'),
      28, 65, 560, 48, 10, False, RGB(44, 55, 70));

    InfoCard := TPanel.Create(D);
    InfoCard.Parent := Content;
    InfoCard.SetBounds(Px(25), Px(127), Px(580), Px(112));
    InfoCard.BevelOuter := bvNone;
    InfoCard.ParentBackground := False;
    InfoCard.Color := RGB(233, 243, 253);
    TextLine(InfoCard, Tr('So geht es weiter'), 18, 13, 530, 26,
      11, True, RGB(24, 83, 150));
    TextLine(InfoCard,
      Tr('1. Der Viewer wird in Windows registriert.') + sLineBreak +
      Tr('2. Die Windows-Einstellungen für Standard-Apps werden geöffnet.') + sLineBreak +
      Tr('3. Dort wählen Sie ') + AAppTitle + Tr(' für PDF-Dateien aus.'),
      18, 43, 540, 65, 10, False, RGB(44, 55, 70));

    TextLine(Content, Tr('Hinweis zur portablen Version'),
      28, 260, 555, 27, 11, True, RGB(24, 83, 150));
    TextLine(Content,
      Tr('Wenn Sie die EXE-Datei verschieben oder den Laufwerksbuchstaben ändern, müssen Sie die Verknüpfung erneut einrichten.'),
      28, 292, 560, 56, 10, False, RGB(44, 55, 70));

    // Inhalt reicht über die sichtbare Fläche hinaus und kann mit
    // Scrollleiste, Mausrad oder Tastatur vollständig gelesen werden.
    Content.VertScrollBar.Range := Px(390);
    Result := D.ShowModal = mrYes;
  finally
    D.Free;
  end;
end;

procedure ShowRegistrationInfoDialog(AOwner: TForm; ASettingsOpened: Boolean); forward;

procedure TPDFTabsForm.PDFVerknuepfungClick(Sender: TObject);
var
  Reg: TRegistry;
  ExePath, CommandLine, ProgId, Capabilities, AppTitle, AppKey: string;
  IsIntegrated: Boolean;

  procedure WriteValue(const KeyName, ValueName, Value: string);
  begin
    if not Reg.OpenKey(KeyName, True) then
      raise Exception.Create('Registry-Schlüssel kann nicht angelegt werden: ' + KeyName);
    try
      Reg.WriteString(ValueName, Value);
    finally
      Reg.CloseKey;
    end;
  end;
begin
  ExePath := ExpandFileName(Application.ExeName);
  IsIntegrated := FileExists(IncludeTrailingPathDelimiter(ExtractFilePath(ExePath)) + 'FreePDF64.exe');
  if IsIntegrated then
  begin
    ProgId := 'FreePDF64ViewerIntegrated.PDF';
    Capabilities := 'Software\FreePDF64ViewerIntegrated\Capabilities';
    AppTitle := 'FreePDF64-Viewer (mit FreePDF64)';
    AppKey := 'FreePDF64-Viewer Integrated';
  end
  else
  begin
    ProgId := 'FreePDF64ViewerPortable.PDF';
    Capabilities := 'Software\FreePDF64ViewerPortable\Capabilities';
    AppTitle := 'FreePDF64-Viewer Portable (Standalone)';
    AppKey := 'FreePDF64-Viewer Portable';
  end;
  if not ConfirmPDFViewerAssociation(Self, AppTitle) then Exit;

  CommandLine := '"' + ExePath + '" "%1"';
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    try
      WriteValue('Software\Classes\' + ProgId, '', AppTitle + ' PDF-Dokument');
      // Explizite Anzeigenamen fuer die Windows-Auswahl und die ProgID.
      WriteValue('Software\Classes\' + ProgId, 'FriendlyTypeName', AppTitle);
      WriteValue('Software\Classes\' + ProgId, 'ApplicationName', AppTitle);
      WriteValue('Software\Classes\' + ProgId, 'ApplicationDescription', AppTitle);
      WriteValue('Software\Classes\' + ProgId + '\DefaultIcon', '', '"' + ExePath + '",0');
      WriteValue('Software\Classes\' + ProgId + '\shell\open', 'FriendlyAppName', AppTitle);
      WriteValue('Software\Classes\' + ProgId + '\shell\open\command', '', CommandLine);
      // Kein Applications\<ExeName>: dieser Schluessel kollidiert bei
      // gleichnamigen EXE-Dateien in unterschiedlichen Verzeichnissen.
      WriteValue(Capabilities, 'ApplicationName', AppTitle);
      WriteValue(Capabilities, 'ApplicationDescription', AppTitle);
      WriteValue(Capabilities, 'ApplicationIcon', '"' + ExePath + '",0');
      WriteValue(Capabilities + '\FileAssociations', '.pdf', ProgId);
      WriteValue('Software\RegisteredApplications', AppKey, Capabilities);
    except
      on E: Exception do
      begin
        PDFModernMessageDlg(Tr('Die Registrierung des PDF-Viewers ist fehlgeschlagen:') +
          sLineBreak + E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    Reg.Free;
  end;

  // Windows ueber geaenderte Dateizuordnungen informieren.
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);

  // Keine direkte Manipulation der geschuetzten Windows-UserChoice-Zuordnung.
  // Windows 10/11 verlangen eine bewusste Auswahl durch den Benutzer.
  ShowRegistrationInfoDialog(Self,
    ShellExecute(Handle, 'open', 'ms-settings:defaultapps', nil, nil,
      SW_SHOWNORMAL) > 32);
end;

procedure ShowRegistrationInfoDialog(AOwner: TForm; ASettingsOpened: Boolean);
var
  D: TViewerHelpForm;
  Header, Footer: TPanel;
  Content: TScrollBox;
  TitleLabel, SubTitle, Heading, BodyText, NoteText: TLabel;
  IconImage: TImage;
  CloseButton: TButton;
  Scale: Integer;

  function Px(V: Integer): Integer;
  begin
    Result := MulDiv(V, Scale, 96);
  end;

  function AddText(AParent: TWinControl; const AText: string;
    AX, AY, AW, AH, ASize: Integer; ABold: Boolean; AColor: TColor): TLabel;
  begin
    Result := TLabel.Create(D);
    Result.Parent := AParent;
    Result.SetBounds(Px(AX), Px(AY), Px(AW), Px(AH));
    Result.AutoSize := False;
    Result.WordWrap := True;
    Result.ShowAccelChar := False;
    Result.Caption := AText;
    Result.Font.Name := 'Segoe UI';
    Result.Font.Size := ASize;
    Result.Font.Color := AColor;
    if ABold then
      Result.Font.Style := [fsBold];
  end;

begin
  D := TViewerHelpForm.CreateNew(AOwner);
  try
    Scale := AOwner.CurrentPPI;
    if Scale < 96 then Scale := 96;
    D.Caption := Tr('PDF-Verknüpfung eingerichtet');
    D.Position := poOwnerFormCenter;
    D.BorderStyle := bsDialog;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.Color := clWhite;
    D.ClientWidth := Px(610);
    D.ClientHeight := Px(305);
    D.KeyPreview := True;

    Header := TPanel.Create(D);
    Header.Parent := D;
    Header.Align := alTop;
    Header.Height := Px(105);
    Header.BevelOuter := bvNone;
    Header.ParentBackground := False;
    Header.Color := RGB(19, 93, 169);

    IconImage := TImage.Create(D);
    IconImage.Parent := Header;
    IconImage.SetBounds(Px(24), Px(20), Px(50), Px(50));
    IconImage.Picture.Icon.Assign(Application.Icon);
    IconImage.Proportional := True;
    IconImage.Stretch := True;

    TitleLabel := AddText(Header, Tr('Registrierung erfolgreich'),
      100, 19, 475, 38, 18, True, clWhite);
    SubTitle := AddText(Header, 'FreePDF64-Viewer Portable',
      102, 58, 465, 25, 10, False, RGB(223, 238, 255));

    Footer := TPanel.Create(D);
    Footer.Parent := D;
    Footer.Align := alBottom;
    Footer.Height := Px(59);
    Footer.BevelOuter := bvNone;
    Footer.ParentBackground := False;
    Footer.Color := RGB(232, 241, 251);

    CloseButton := TButton.Create(D);
    CloseButton.Parent := Footer;
    CloseButton.SetBounds(Px(453), Px(11), Px(130), Px(35));
    CloseButton.Caption := 'OK';
    CloseButton.ModalResult := mrOk;
    CloseButton.Default := True;
    CloseButton.Cancel := True;

    Content := TScrollBox.Create(D);
    Content.Parent := D;
    Content.Align := alClient;
    Content.BorderStyle := bsNone;
    Content.Color := clWhite;
    Content.ParentBackground := False;
    Content.HorzScrollBar.Visible := False;
    Content.AutoScroll := True;
    D.HelpScroll := Content;

    Heading := AddText(Content, Tr('Der Viewer wurde in Windows registriert.'),
      27, 13, 550, 29, 13, True, RGB(24, 83, 150));
    if ASettingsOpened then
      BodyText := AddText(Content,
        Tr('Die Windows-Einstellungen für Standard-Apps wurden geöffnet.') +
        sLineBreak + Tr('Wählen Sie dort den FreePDF64-Viewer Portable für den Dateityp .pdf aus.'),
        27, 50, 545, 55, 11, False, RGB(44, 55, 70))
    else
      BodyText := AddText(Content,
        Tr('Öffnen Sie Windows-Einstellungen > Apps > Standard-Apps.') +
        sLineBreak + Tr('Wählen Sie dort den FreePDF64-Viewer Portable für den Dateityp .pdf aus.'),
        27, 73, 545, 85, 11, False, RGB(44, 55, 70));

    NoteText := AddText(Content,
      Tr('Wichtig: Erst nach Ihrer Bestätigung in Windows wird die Zuordnung wirksam.'),
      27, 111, 545, 42, 11, True, RGB(24, 83, 150));
    AddText(Content,
      Tr('Bei einer portablen Version muss die Verknüpfung nach dem Verschieben der EXE erneut eingerichtet werden.'),
      27, 157, 545, 48, 10, False, RGB(44, 55, 70));
    Content.VertScrollBar.Range := Px(213);
    D.ShowModal;
  finally
    D.Free;
  end;
end;

function TPDFTabsForm.IsWindowsStartEnabled: Boolean;
var
  Reg: TRegistry;
  Command: string;
begin
  Result := False;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('Software\\Microsoft\\Windows\\CurrentVersion\\Run') then
    begin
      if Reg.ValueExists('FreePDF64ViewerPortable') then
      begin
        Command := Reg.ReadString('FreePDF64ViewerPortable');
        Result := SameText(Command, '"' + ParamStr(0) + '" --autostart');
      end;
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TPDFTabsForm.ToggleWindowsStart(Sender: TObject);
var
  Reg: TRegistry;
  Enabled: Boolean;
begin
  Enabled := not IsWindowsStartEnabled;
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey('Software\\Microsoft\\Windows\\CurrentVersion\\Run', False) then
      raise Exception.Create('Der Windows-Autostart konnte nicht geöffnet werden.');
    try
      if Enabled then
        Reg.WriteString('FreePDF64ViewerPortable',
          '"' + ParamStr(0) + '" --autostart')
      else if Reg.ValueExists('FreePDF64ViewerPortable') then
        Reg.DeleteValue('FreePDF64ViewerPortable');
    finally
      Reg.CloseKey;
    end;
    FWindowsStartMenuItem.Checked := IsWindowsStartEnabled;
  except
    on E: Exception do
      PDFModernMessageDlg(Tr('Der Windows-Autostart konnte nicht geändert werden:') +
        sLineBreak + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TPDFTabsForm.ToggleStartMinimized(Sender: TObject);
var
  Ini: TIniFile;
begin
  FStartMinimized := not FStartMinimized;
  FStartMinimizedMenuItem.Checked := FStartMinimized;
  Ini := TIniFile.Create(TabsIniFileName);
  try
    Ini.WriteBool('Viewer', 'BeimStartMinimieren', FStartMinimized);
  finally
    Ini.Free;
  end;
end;

function TPDFTabsForm.PrepareHiddenStartup: Boolean;
begin
  // Der Hauptfensterstart bleibt VCL-konform. Die Minimierung erfolgt
  // ueber die OnShow-Nachricht, nachdem die Startseite aufgebaut ist.
  Result := FStartupMinimizePending;
end;

procedure TPDFTabsForm.ApplyStartupMinimized(var Msg: TMessage);
begin
  if not FStartupMinimizePending then Exit;
  FStartupMinimizePending := False;
  HideAllAttachmentWindows;
  // Erst NACH OnShow minimieren: die VCL hat nun alle Child-Controls
  // und die Willkommensseite korrekt initialisiert.
  UpdateWelcomeView;
  WindowState := wsMinimized;
  ShowWindow(Handle, SW_MINIMIZE);
end;

procedure TPDFTabsForm.ToggleTrayMode(Sender: TObject);
var
  Ini: TIniFile;
begin
  FTrayEnabled := not FTrayEnabled;
  if FTrayMenuItem <> nil then FTrayMenuItem.Checked := FTrayEnabled;
  Ini := TIniFile.Create(TabsIniFileName);
  try
    Ini.WriteBool('Viewer', 'BeimSchliessenInTray', FTrayEnabled);
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.WMTrayCallback(var Msg: TMessage);
var
  P: TPoint;
begin
  case Msg.LParam of
    WM_LBUTTONDBLCLK, WM_LBUTTONUP: RestoreFromTray(nil);
    WM_RBUTTONUP, WM_CONTEXTMENU:
      begin
        GetCursorPos(P);
        SetForegroundWindow(Handle);
        FTrayPopup.Popup(P.X, P.Y);
        PostMessage(Handle, WM_NULL, 0, 0);
      end;
  end;
  Msg.Result := 0;
end;

procedure TPDFTabsForm.UpdateIntegratedOptionsVisibility;
var
  I: Integer;
begin
  if FOptionsMenu = nil then Exit;
  if RunningAlongsideFreePDF64 then
    for I := 0 to FOptionsMenu.Count - 1 do
      FOptionsMenu.Items[I].Visible :=
        (FOptionsMenu.Items[I] = FLanguageMenu) or
        (FOptionsMenu.Items[I] = FDesignMenu);
end;

procedure TPDFTabsForm.DesignClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then Exit;
  if FDesignIndex = TMenuItem(Sender).Tag then Exit;
  FDesignIndex := TMenuItem(Sender).Tag;
  if (FDesignIndex < 0) or (FDesignIndex > 5) or (FDesignIndex = 2) or (FDesignIndex = 4) then Exit;
  FDesignItems[FDesignIndex].Checked := True;
  with TIniFile.Create(TabsIniFileName) do
  try
    WriteInteger('Viewer', 'Design', FDesignIndex);
  finally
    Free;
  end;
  ApplyViewerDesign;
end;

procedure TPDFTabsForm.ApplyViewerDesign;
var
  BaseColor, HeaderColor, TextColor: TColor;
  TabIndex, ControlIndex: Integer;
begin
  // Aufwendige Palettenzuweisung ausschliesslich beim echten Wechsel.
  if FDesignHasBeenApplied and (FAppliedDesignIndex = FDesignIndex) then Exit;
  FAppliedDesignIndex := FDesignIndex;
  FDesignHasBeenApplied := True;
  SetPDFDialogDesign(FDesignIndex);
  // Keine Rekursion durch Komponenten und keine Aenderung am PDF-Renderer.
  // Standard (0) verwendet die bisherigen Originalfarben.
  if FDesignIndex = 0 then
  begin
    Color := clBtnFace;
    if FViewerHeader <> nil then FViewerHeader.Color := clBtnFace;
    if FEmptyTabStrip <> nil then FEmptyTabStrip.Color := clBtnFace;
    if FTabActionsPanel <> nil then FTabActionsPanel.Color := clBtnFace;
    // Auch Schriftfarben der Kopf- und Seitenleisten auf Standard zuruecksetzen.
    if FViewerHeader <> nil then
    begin
      FViewerHeader.Font.Color := clWindowText;
      FViewerHeader.Font.Style := [];
    end;
    if FTabActionsPanel <> nil then FTabActionsPanel.Font.Color := clWindowText;
    if FEmptyTabStrip <> nil then FEmptyTabStrip.Font.Color := clWindowText;
    if FWelcomePanel <> nil then FWelcomePanel.Font.Color := clWindowText;
    if FRecentScroll <> nil then FRecentScroll.Font.Color := clWindowText;
    if FWelcomePanel <> nil then FWelcomePanel.Color := RGB(248, 250, 253);
    if FRecentScroll <> nil then FRecentScroll.Color := RGB(248, 250, 253);
    if FWelcomeTitle <> nil then FWelcomeTitle.Font.Color := RGB(29, 45, 67);
    if FWelcomeHint <> nil then FWelcomeHint.Font.Color := RGB(94, 108, 126);
    if FLeftPDFOverlay <> nil then FLeftPDFOverlay.Color := clBtnFace;
    if FRightPDFOverlay <> nil then FRightPDFOverlay.Color := clBtnFace;
    if FSplitLeft <> nil then FSplitLeft.Color := clBtnFace;
    if FSplitRight <> nil then FSplitRight.Color := clBtnFace;
    if FRecentTitle <> nil then FRecentTitle.Font.Color := clWindowText;
    if FRecentClearButton <> nil then FRecentClearButton.Font.Color := clWindowText;
    if FWelcomeOpenButton <> nil then FWelcomeOpenButton.Font.Color := clWindowText;
    if FWelcomeWorkspaceButton <> nil then FWelcomeWorkspaceButton.Font.Color := clWindowText;
  end
  else
  begin
    case FDesignIndex of
      1: begin BaseColor := RGB(229, 236, 246); HeaderColor := RGB(225, 232, 241); TextColor := RGB(35, 48, 65); end;
      2: begin BaseColor := RGB(42, 45, 51); HeaderColor := RGB(54, 58, 65); TextColor := clWhite; end;
      3: begin BaseColor := RGB(192, 192, 192); HeaderColor := RGB(192, 192, 192); TextColor := clBlack; end;
      4: begin BaseColor := RGB(21, 22, 25); HeaderColor := RGB(34, 36, 40); TextColor := clWhite; end;
    else
      begin BaseColor := RGB(220, 233, 247); HeaderColor := RGB(190, 214, 237); TextColor := RGB(24, 55, 88); end;
    end;
    Color := BaseColor;
    if FViewerHeader <> nil then FViewerHeader.Color := HeaderColor;
    if FEmptyTabStrip <> nil then FEmptyTabStrip.Color := HeaderColor;
    if FTabActionsPanel <> nil then FTabActionsPanel.Color := HeaderColor;
    // Passende Schriftfarben fuer die Symbolleisten- und Startseitencontainer.
    // Nur Darstellung, keine Groessen oder Layoutpositionen veraendern.
    if FViewerHeader <> nil then FViewerHeader.Font.Color := TextColor;
    if FViewerHeader <> nil then
      if FDesignIndex <> 0 then FViewerHeader.Font.Style := [fsBold]
      else FViewerHeader.Font.Style := [];
    if FTabActionsPanel <> nil then FTabActionsPanel.Font.Color := TextColor;
    if FEmptyTabStrip <> nil then FEmptyTabStrip.Font.Color := TextColor;
    if FWelcomePanel <> nil then FWelcomePanel.Font.Color := TextColor;
    if FRecentScroll <> nil then FRecentScroll.Font.Color := TextColor;
    // Windows Klassik: Startseite wie die Zusatzfenster in hellem Grau.
    if FWelcomePanel <> nil then
      if FDesignIndex = 3 then FWelcomePanel.Color := RGB(232, 232, 232)
      else FWelcomePanel.Color := BaseColor;
    if FRecentScroll <> nil then
      if FDesignIndex = 3 then FRecentScroll.Color := RGB(232, 232, 232)
      else FRecentScroll.Color := BaseColor;
    if FLeftPDFOverlay <> nil then FLeftPDFOverlay.Color := BaseColor;
    if FRightPDFOverlay <> nil then FRightPDFOverlay.Color := BaseColor;
    if FSplitLeft <> nil then FSplitLeft.Color := BaseColor;
    if FSplitRight <> nil then FSplitRight.Color := BaseColor;
    if FWelcomeTitle <> nil then FWelcomeTitle.Font.Color := TextColor;
    if FWelcomeHint <> nil then FWelcomeHint.Font.Color := TextColor;
    if FRecentTitle <> nil then FRecentTitle.Font.Color := TextColor;
    if FRecentClearButton <> nil then FRecentClearButton.Font.Color := TextColor;
    if FWelcomeOpenButton <> nil then FWelcomeOpenButton.Font.Color := TextColor;
    if FWelcomeWorkspaceButton <> nil then FWelcomeWorkspaceButton.Font.Color := TextColor;
  end;
  // Klassische erhabene Rahmen nur fuer das Windows-Klassik-Design.
  // Bei allen anderen Designs die urspruenglichen flachen Rahmen verwenden.
  if FViewerHeader <> nil then
    if FDesignIndex = 3 then FViewerHeader.BevelOuter := bvRaised
    else FViewerHeader.BevelOuter := bvNone;
  if FTabActionsPanel <> nil then
    if FDesignIndex = 3 then FTabActionsPanel.BevelOuter := bvRaised
    else FTabActionsPanel.BevelOuter := bvNone;
  // Der freie Bereich neben den Tabs darf auch im Klassik-Design
  // keinen eigenen erhabenen Rahmen erhalten.
  if FEmptyTabStrip <> nil then FEmptyTabStrip.BevelOuter := bvNone;
  // Auch die beiden Split-Ansichten erhalten im Klassik-Modus
  // eine dezente 3D-Einfassung; die PDF-Seiten selbst bleiben unberuehrt.
  if FLeftPDFOverlay <> nil then
    if FDesignIndex = 3 then FLeftPDFOverlay.BevelOuter := bvRaised
    else FLeftPDFOverlay.BevelOuter := bvNone;
  if FRightPDFOverlay <> nil then
    if FDesignIndex = 3 then FRightPDFOverlay.BevelOuter := bvRaised
    else FRightPDFOverlay.BevelOuter := bvNone;
  // Klassische 3D-Einfassung fuer den aeusseren Split-Container.
  if FSplitHost <> nil then
    if FDesignIndex = 3 then FSplitHost.BevelOuter := bvRaised
    else FSplitHost.BevelOuter := bvNone;
  // Trennbereich der Zweifensteransicht farblich angleichen.
  // Die aktiven Rahmen und die PDF-Ansichten bleiben unveraendert.
  if FSplitHost <> nil then
  begin
    if FDesignIndex = 0 then FSplitHost.Color := clBtnFace
    else FSplitHost.Color := Color;
  end;
  if FSplitDivider <> nil then
  begin
    case FDesignIndex of
      2: FSplitDivider.Color := RGB(91, 99, 111);
      3: FSplitDivider.Color := RGB(128, 128, 128);
      4: FSplitDivider.Color := RGB(72, 76, 84);
      5: FSplitDivider.Color := RGB(114, 156, 196);
      1: FSplitDivider.Color := RGB(166, 183, 205);
    else
      FSplitDivider.Color := RGB(135, 150, 169);
    end;
  end;
  // Symbolleisten aller bereits geoeffneten PDFs mit umstellen.
  if FTabs <> nil then
    for TabIndex := 0 to FTabs.PageCount - 1 do
      for ControlIndex := 0 to FTabs.Pages[TabIndex].ControlCount - 1 do
        if FTabs.Pages[TabIndex].Controls[ControlIndex] is TPDFBrowserForm then
          TPDFBrowserForm(FTabs.Pages[TabIndex].Controls[ControlIndex]).ApplyToolbarDesign(FDesignIndex);
  // Die direkt in der Kopfzeile liegenden Schaltflaechen verwenden
  // dieselbe OwnerDraw-Palette wie die PDF-Symbolleiste.
  if FMainProgramButton is TPDFDesignButton then
    TPDFDesignButton(FMainProgramButton).SetDesign(FDesignIndex);
  if FTabTextSearchButton is TPDFDesignButton then
    TPDFDesignButton(FTabTextSearchButton).SetDesign(FDesignIndex);
  if FTabNextButton is TPDFDesignButton then
    TPDFDesignButton(FTabNextButton).SetDesign(FDesignIndex);
  if FTabPrevButton is TPDFDesignButton then
    TPDFDesignButton(FTabPrevButton).SetDesign(FDesignIndex);
  if FTabSearchButton is TPDFDesignButton then
    TPDFDesignButton(FTabSearchButton).SetDesign(FDesignIndex);
  if FDesignIndex <> 0 then
  begin
    if FTabActionsPanel <> nil then FTabActionsPanel.Font.Style := [fsBold];
    if FEmptyTabStrip <> nil then FEmptyTabStrip.Font.Style := [fsBold];
  end
  else
  begin
    if FTabActionsPanel <> nil then FTabActionsPanel.Font.Style := [];
    if FEmptyTabStrip <> nil then FEmptyTabStrip.Font.Style := [];
  end;
  // Bereits geoeffnete Zusatzfenster bei einem Designwechsel aktualisieren.
  for TabIndex := 0 to Screen.FormCount - 1 do
    if (Screen.Forms[TabIndex] is TPDFGlobalSearchForm) or
       (Screen.Forms[TabIndex].Caption = Tr('Dokumenteigenschaften')) or
       (Screen.Forms[TabIndex].Caption = Tr('Eingebettete PDF-Anlagen')) then
      ApplyPDFDialogDesign(Screen.Forms[TabIndex]);
  if FTabs <> nil then FTabs.Invalidate;
  if FEmptyTabStrip <> nil then FEmptyTabStrip.Invalidate;
end;

procedure TPDFTabsForm.RefreshLanguage;
var
  I: Integer;
begin
  // Alle Hauptmenues samt Untermenues gemeinsam aktualisieren. Damit werden
  // auch Menuepunkte erfasst, die nicht zu den vier Standardmenues gehoeren.
  if FHelpMainMenu <> nil then
    for I := 0 to FHelpMainMenu.Items.Count - 1 do
      TranslatePDFMenu(FHelpMainMenu.Items[I]);

  // Hauptmenuebezeichnungen explizit aus der deutschen Referenz setzen.
  if FFileMenu <> nil then FFileMenu.Caption := Tr('Datei');
  if FEditMenu <> nil then
    if SameText(PDFLanguage, 'en') then FEditMenu.Caption := 'Tools'
    else FEditMenu.Caption := 'Werkzeuge';
  if FTabPreviewMenuItem <> nil then
  begin
    if SameText(PDFLanguage, 'en') then
      FTabPreviewMenuItem.Caption := 'Show Tab Previews'
    else
      FTabPreviewMenuItem.Caption := 'Registerkartenvorschau anzeigen';
  end;
  if FWorkspaceMenu <> nil then FWorkspaceMenu.Caption := Tr('Arbeitsbereiche');
  if FOptionsMenu <> nil then FOptionsMenu.Caption := Tr('Optionen');
  if FSplitViewMenuItem <> nil then
  begin
    if SameText(PDFLanguage, 'en') then
      FSplitViewMenuItem.Caption := 'Split view'
    else
      FSplitViewMenuItem.Caption := 'Ansicht teilen';
  end;
  if FVisualCompareMenuItem <> nil then
    if SameText(PDFLanguage, 'en') then
      FVisualCompareMenuItem.Caption := 'Compare PDFs visually ...'
    else
      FVisualCompareMenuItem.Caption := 'PDFs visuell vergleichen ...';
  if FLanguageMenu <> nil then FLanguageMenu.Caption := Tr('Sprache / Language');
  if FHelpRootMenuItem <> nil then FHelpRootMenuItem.Caption := Tr('Hilfe');
  if FDesignMenu <> nil then
  begin
    if SameText(PDFLanguage, 'en') then
      FDesignMenu.Caption := 'Theme'
    else
      FDesignMenu.Caption := 'Design';
    if PDFLanguage = 'en' then
    begin
      FDesignItems[0].Caption := 'Default';
      FDesignItems[1].Caption := 'Modern Light';
      FDesignItems[2].Caption := 'Modern Dark';
      FDesignItems[3].Caption := 'Windows Classic';
      FDesignItems[4].Caption := 'Black';
      FDesignItems[5].Caption := 'Classic Blue';
    end
    else
    begin
      FDesignItems[0].Caption := 'Standard';
      FDesignItems[1].Caption := 'Modern Hell';
      FDesignItems[2].Caption := 'Modern Dunkel';
      FDesignItems[3].Caption := 'Windows Klassik';
      FDesignItems[4].Caption := 'Schwarz';
      FDesignItems[5].Caption := 'Klassisch Blau';
    end;
  end;
  if FUpdateManualMenuItem <> nil then
    if PDFLanguage = 'en' then FUpdateManualMenuItem.Caption := 'Check for updates ...'
    else FUpdateManualMenuItem.Caption := 'Nach Updates suchen ...';
  if FUpdateAutoMenuItem <> nil then
    if PDFLanguage = 'en' then FUpdateAutoMenuItem.Caption := 'Check for updates weekly'
    else FUpdateAutoMenuItem.Caption := 'Automatisch wöchentlich nach Updates suchen';

  // Nach dem Setzen der Hauptpunkte nochmals die jeweiligen Untermenues
  // durchlaufen, damit dynamisch geaenderte Beschriftungen nachziehen.
  if FFileMenu <> nil then TranslatePDFMenu(FFileMenu);
  if FEditMenu <> nil then TranslatePDFMenu(FEditMenu);
  if FWorkspaceMenu <> nil then TranslatePDFMenu(FWorkspaceMenu);
  if FOptionsMenu <> nil then TranslatePDFMenu(FOptionsMenu);
  if FHelpRootMenuItem <> nil then TranslatePDFMenu(FHelpRootMenuItem);

  // Abschließender Durchlauf über alle Hauptmenüs: erfasst auch Unterpunkte,
  // die von anderen Routinen nachträglich erzeugt oder geändert wurden.
  if FHelpMainMenu <> nil then
    for I := 0 to FHelpMainMenu.Items.Count - 1 do
      TranslatePDFMenu(FHelpMainMenu.Items[I]);

  if FTrayPopup <> nil then
    for I := 0 to FTrayPopup.Items.Count - 1 do
      TranslatePDFMenu(FTrayPopup.Items[I]);
  if FUpdateManualMenuItem <> nil then
    if PDFLanguage = 'en' then FUpdateManualMenuItem.Caption := 'Check for updates ...'
    else FUpdateManualMenuItem.Caption := 'Nach Updates suchen ...';
  if FUpdateAutoMenuItem <> nil then
    if PDFLanguage = 'en' then FUpdateAutoMenuItem.Caption := 'Check for updates weekly'
    else FUpdateAutoMenuItem.Caption := 'Automatisch wöchentlich nach Updates suchen';

  // Auch separat erzeugte, bereits geöffnete Dialoge und Hilfsfenster
  // aktualisieren (Dokumenteigenschaften, Textsuche, Anlagenfenster usw.).
  for I := 0 to Screen.FormCount - 1 do
  begin
    if Screen.Forms[I] <> nil then
    begin
      Screen.Forms[I].Caption := Tr(Screen.Forms[I].Caption);
      TranslatePDFControls(Screen.Forms[I]);
      if Screen.Forms[I] is TPDFBrowserForm then
        TPDFBrowserForm(Screen.Forms[I]).RefreshLanguage;
    end;
  end;
  if FTabSplitButton <> nil then
  begin
    if SameText(PDFLanguage, 'en') then
      FTabSplitButton.Hint := 'Split view / Close split view (select two tabs with Ctrl+Click)'
    else
      FTabSplitButton.Hint := 'Ansicht teilen / Teilung beenden (zwei Registerkarten mit Strg+Klick auswählen)';
  end;
  if FTabTextSearchButton <> nil then
    if SameText(PDFLanguage, 'en') then
      FTabTextSearchButton.Hint := 'Search text in the left PDF (Ctrl+F)'
    else
      FTabTextSearchButton.Hint := 'Text im linken PDF suchen (Strg+F)';
  if FLeftPDFOverlay <> nil then
    for I := 0 to FLeftPDFOverlay.ControlCount - 1 do
      if (FLeftPDFOverlay.Controls[I] is TButton) and
         (TButton(FLeftPDFOverlay.Controls[I]).Tag = 0) and
         (TButton(FLeftPDFOverlay.Controls[I]) <> FTabSplitButton) and
         (TButton(FLeftPDFOverlay.Controls[I]) <> FTabTextSearchButton) and
         (FLeftPDFOverlay.Controls[I] <> FSyncScrollButton) and
         (FLeftPDFOverlay.Controls[I] <> FSyncZoomButton) then
        if SameText(PDFLanguage, 'en') then
          TButton(FLeftPDFOverlay.Controls[I]).Hint := 'Show / hide thumbnails in the left PDF'
        else
          TButton(FLeftPDFOverlay.Controls[I]).Hint := 'Miniaturansicht links ein-/ausblenden';
  if FRightPDFOverlay <> nil then
    for I := 0 to FRightPDFOverlay.ControlCount - 1 do
      if FRightPDFOverlay.Controls[I] is TButton then
        with TButton(FRightPDFOverlay.Controls[I]) do
          if SameText(PDFLanguage, 'en') then
          begin
            if Tag = 1 then
            begin
              if Caption = '⌕' then Hint := 'Search text in the right PDF (Ctrl+F)'
              else Hint := 'Show / hide thumbnails in the right PDF';
            end
            else Hint := 'Close split view';
          end
          else
          begin
            if Tag = 1 then
            begin
              if Caption = '⌕' then Hint := 'Text im rechten PDF suchen (Strg+F)'
              else Hint := 'Miniaturansicht rechts ein-/ausblenden';
            end
            else Hint := 'Zweifensteransicht beenden';
          end;
  UpdateSplitSyncButtons;
  if FTabSearchButton <> nil then
    FTabSearchButton.Hint := Tr('Geöffnete Registerkarten suchen (Strg+Umsch+A)');
  if FGermanMenuItem <> nil then FGermanMenuItem.Checked := PDFLanguage = 'de';
  if FEnglishMenuItem <> nil then FEnglishMenuItem.Checked := PDFLanguage = 'en';

  // Hilfe bleibt rechts, unabhängig von der gewählten Sprache.
  AlignHelpMenuRight;
  DrawMenuBar(Handle);

  if FGlobalSearchForm <> nil then
  begin
    FGlobalSearchForm.Close;
    FreeAndNil(FGlobalSearchForm);
  end;
end;

procedure TPDFTabsForm.ChangeLanguageClick(Sender: TObject);
var
  NewLanguage: string;
  Answer: Integer;
begin
  if Sender = FGermanMenuItem then NewLanguage := 'de'
  else if Sender = FEnglishMenuItem then NewLanguage := 'en'
  else Exit;

  if SameText(PDFLanguage, NewLanguage) then Exit;
  // Bis nach der Speicherabfrage die bisherige Dialogsprache beibehalten.
  // Die neue Sprache wird erst bei erfolgreichem Schliessen gespeichert.

  // Windows Task Dialog: moderner, systemeigener Dialog mit nativer
  // High-DPI-/4K-Skalierung. Kein eigenes Formular mit festen Pixelmassen.
  with TTaskDialog.Create(Self) do
  try
    Caption := 'FreePDF64-Viewer Portable';
    MainIcon := tdiInformation;
    CommonButtons := [tcbYes, tcbNo];
    DefaultButton := tcbYes;
    if NewLanguage = 'en' then
    begin
      Title := 'Language change saved';
      Text := 'The new language will be applied after restarting the viewer.' +
        sLineBreak + sLineBreak + 'Would you like to restart now?';
      FooterText := 'Open documents will be checked for unsaved changes before closing.';
    end
    else
    begin
      Title := 'Spracheinstellung gespeichert';
      Text := 'Die neue Sprache wird nach einem Neustart des Viewers aktiviert.' +
        sLineBreak + sLineBreak + 'Möchten Sie das Programm jetzt neu starten?';
      FooterText := 'Vor dem Schließen werden offene Dokumente auf ungespeicherte Änderungen geprüft.';
    end;
    try
      if Execute then
        Answer := ModalResult
      else
        Answer := mrNo;
    except
      // Fallback fuer Umgebungen ohne TaskDialog-Unterstuetzung.
      if NewLanguage = 'en' then
        Answer := MessageDlg('Restart now to apply the new language?',
          mtConfirmation, [mbYes, mbNo], 0)
      else
        Answer := MessageDlg('Jetzt neu starten, um die neue Sprache anzuwenden?',
          mtConfirmation, [mbYes, mbNo], 0);
    end;
  finally
    Free;
  end;

  if Answer <> mrYes then
  begin
    // Kein Neustart: Einstellung fuer den naechsten Programmstart speichern.
    SetPDFLanguage(NewLanguage);
    FGermanMenuItem.Checked := NewLanguage = 'de';
    FEnglishMenuItem.Checked := NewLanguage = 'en';
    Exit;
  end;
  // Die normale Schliessroutine prueft ungespeicherte PDF-Aenderungen
  // noch in der bisherigen Sprache.
  FPendingRestartLanguage := NewLanguage;
  FRestartRequested := True;
  FExitFromTray := True;
  Close;
  // Bei abgebrochenem Schliessen darf ein spaeteres Schliessen
  // nicht versehentlich einen Neustart ausloesen.
  FRestartRequested := False;
  FPendingRestartLanguage := '';
  FExitFromTray := False;
end;

constructor TPDFTabsForm.Create(AOwner: TComponent);
var
  Header: TPanel;
  HelpItem: TMenuItem;
  Ini: TIniFile;
  SearchArea: TPanel;
  TabHost: TPanel;
  Dpi: Integer;
  ButtonHeight: Integer;
  DesignI: Integer;
begin
  inherited CreateNew(AOwner);
  KeyPreview := True;
  OnKeyDown := ViewerKeyDown;
  Dpi := CurrentPPI;
  if Dpi < 96 then Dpi := 96;
  ButtonHeight := Max(MulDiv(26, Dpi, 96), Canvas.TextHeight('Ag') + MulDiv(10, Dpi, 96));
  PDFTabsWindow := Self;
  FPendingPDFDisposals := TList.Create;
  // WM_SIZE wird beim Maximieren/Wiederherstellen mehrfach ausgeloest.
  // Erst nach der letzten Groessenaenderung den PDF-Viewport aktualisieren.
  FWindowResizeTimer := TTimer.Create(Self);
  FWindowResizeTimer.Enabled := False;
  FWindowResizeTimer.Interval := 180;
  FWindowResizeTimer.OnTimer := WindowResizeSettled;
  FPDFDisposalTimer := TTimer.Create(Self);
  FPDFDisposalTimer.Enabled := False;
  FPDFDisposalTimer.Interval := 100;
  FPDFDisposalTimer.OnTimer := PDFDisposalTimerTick;
  FClosedPDFs := TStringList.Create;
  FSessionPDFs := TStringList.Create;
  LoadClosedPDFs;
  // Benannte Arbeitsbereiche werden bei Bedarf aus dem Ordner geladen.
  FRecentPDFs := TStringList.Create;
  LoadRecentPDFs;
  CleanupRecentThumbnails(False);
  InitializePDFLanguage(TabsIniFileName);
  FUpdateStartupTimer := TTimer.Create(Self);
  FUpdateStartupTimer.Enabled := False;
  FUpdateStartupTimer.Interval := 3500;
  FUpdateStartupTimer.OnTimer := UpdateStartupTick;
  // Eigenstaendiges Hilfe-Menue des portablen Viewers.
  FHelpMainMenu := TMainMenu.Create(Self);
  FHomeMenu := TMenuItem.Create(FHelpMainMenu);
  FHomeMenu.Caption := 'Home';
  FHomeMenu.OnClick := HomeMenuClick;
  FHelpMainMenu.Items.Add(FHomeMenu);
  FFileMenu := TMenuItem.Create(FHelpMainMenu);
  FFileMenu.Caption := Tr('Datei');
  FHelpMainMenu.Items.Add(FFileMenu);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('PDFs und Grafiken öffnen ...');
  HelpItem.ShortCut := ShortCut(Ord('O'), [ssCtrl]);
  HelpItem.OnClick := OpenPDFClick;
  FFileMenu.Add(HelpItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('PDF neu laden (Änderungen verwerfen)');
  HelpItem.OnClick := ReloadActivePDFClick;
  FFileMenu.Add(HelpItem);
  if RunningAlongsideFreePDF64 then
  begin
    HelpItem := TMenuItem.Create(FHelpMainMenu);
    HelpItem.Caption := '-';
    FFileMenu.Add(HelpItem);
    HelpItem := TMenuItem.Create(FHelpMainMenu);
    HelpItem.Caption := Tr('FreePDF64 öffnen');
    HelpItem.OnClick := OpenMainProgramClick;
    FFileMenu.Add(HelpItem);
  end;
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := '-';
  FFileMenu.Add(HelpItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('Beenden');
  HelpItem.ShortCut := ShortCut(VK_F4, [ssAlt]);
  HelpItem.OnClick := ExitFromTray;
  FFileMenu.Add(HelpItem);
  // Suchfunktionen gehoeren in Bearbeiten, nicht in Datei.
  // Vorbereitung der geteilten Ansicht. Bis zur Einbindung zweier
  // unabhaengiger PDF-Hosts bewusst deaktiviert (kein Schein-Feature).
  FSplitShiftTab := -1;
  FSplitLastSelectedTab := nil;
  FSplitSelectedTab := nil;
  FSplitViewMenuItem := TMenuItem.Create(FHelpMainMenu);
  FSplitViewMenuItem.Caption := 'Ansicht teilen';
  FSplitViewMenuItem.Enabled := False;
  FSplitViewMenuItem.OnClick := SplitMenuClick;
  // Der Menuepunkt wird weiter unten in Werkzeuge eingefuegt.
  FVisualCompareMenuItem := TMenuItem.Create(FHelpMainMenu);
  FVisualCompareMenuItem.Caption := 'PDFs visuell vergleichen ...';
  // Beim Erzeugen ist noch keine Zweifensteransicht aktiv.
  FVisualCompareMenuItem.Enabled := False;
  FVisualCompareMenuItem.Visible := False;
  FVisualCompareMenuItem.OnClick := VisualCompareClick;
  FHelpMainMenu.Items.Add(FVisualCompareMenuItem);
  FEditMenu := TMenuItem.Create(FHelpMainMenu);
  FEditMenu.Caption := 'Werkzeuge';
  FEditMenu.OnClick := EditMenuClick;
  FHelpMainMenu.Items.Add(FEditMenu);
  // Geteilte Ansicht als eigener Abschnitt in Werkzeuge.
  FEditMenu.Add(FSplitViewMenuItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := '-';
  FEditMenu.Add(HelpItem);
  FLocalSearchMenuItem := TMenuItem.Create(FHelpMainMenu);
  FLocalSearchMenuItem.Caption := Tr('Text suchen');
  FLocalSearchMenuItem.ShortCut := ShortCut(Ord('F'), [ssCtrl]);
  FLocalSearchMenuItem.OnClick := LocalSearchMenuClick;
  FEditMenu.Add(FLocalSearchMenuItem);
  FGlobalSearchMenuItem := TMenuItem.Create(FHelpMainMenu);
  FGlobalSearchMenuItem.Caption := Tr('Globale PDF-Suche');
  FGlobalSearchMenuItem.ShortCut := ShortCut(Ord('F'), [ssCtrl, ssShift]);
  FGlobalSearchMenuItem.OnClick := GlobalSearchClick;
  FEditMenu.Add(FGlobalSearchMenuItem);
  // Trennlinie zwischen Suchfunktionen und PDF-Zusammenfuehrung.
  FEditMenu.Add(TMenuItem.Create(FHelpMainMenu));
  FEditMenu.Items[FEditMenu.Count - 1].Caption := '-';
  FMergePDFMenuItem := TMenuItem.Create(FHelpMainMenu);
  FMergePDFMenuItem.Caption := Tr('PDFs zusammenführen ...');
  FMergePDFMenuItem.OnClick := MergePDFClick;
  FMergePDFMenuItem.Enabled := False;
  FEditMenu.Add(FMergePDFMenuItem);
  FEditMenu.Add(TMenuItem.Create(FHelpMainMenu));
  FEditMenu.Items[FEditMenu.Count - 1].Caption := '-';
  FTabPreviewMenuItem := TMenuItem.Create(FHelpMainMenu);
  FTabPreviewMenuItem.Caption := 'Registerkartenvorschau anzeigen';
  FTabPreviewMenuItem.OnClick := TabPreviewMenuClick;
  FEditMenu.Add(FTabPreviewMenuItem);
  with TIniFile.Create(TabsIniFileName) do
  try
    FTabPreviewEnabled := ReadBool('Viewer', 'TabPreviewEnabled', True);
  finally
    Free;
  end;
  FTabPreviewMenuItem.Checked := FTabPreviewEnabled;
  FLocalSearchMenuItem.Enabled := False;
  FGlobalSearchMenuItem.Enabled := False;
  FWorkspaceMenu := TMenuItem.Create(FHelpMainMenu);
  FWorkspaceMenu.Caption := Tr('Arbeitsbereiche');
  // Direkt rechts neben Datei, unabhaengig vom Erzeugungszeitpunkt.
  FHelpMainMenu.Items.Insert(FHelpMainMenu.Items.IndexOf(FFileMenu) + 1, FWorkspaceMenu);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('Arbeitsbereiche verwalten ...');
  HelpItem.OnClick := ManageWorkspacesClick;
  FWorkspaceMenu.Add(HelpItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('Arbeitsbereich speichern ...');
  HelpItem.OnClick := SaveWorkspaceClick;
  FWorkspaceMenu.Add(HelpItem);
  // Einstellungen in einem eigenen Hauptmenü bündeln.
  FOptionsMenu := TMenuItem.Create(FHelpMainMenu);
  FOptionsMenu.Caption := Tr('Optionen');
  FHelpMainMenu.Items.Add(FOptionsMenu);
  FOptionsMenu.Visible := True;
  // Umschaltbare Viewer-Farbdesigns; 0 bewahrt den bisherigen Zustand.
  FDesignMenu := TMenuItem.Create(FHelpMainMenu);
  FDesignMenu.Caption := 'Design';
  for DesignI := 0 to 5 do
  begin
    FDesignItems[DesignI] := TMenuItem.Create(FHelpMainMenu);
    FDesignItems[DesignI].Tag := DesignI;
    FDesignItems[DesignI].RadioItem := True;
    FDesignItems[DesignI].GroupIndex := 23;
    FDesignItems[DesignI].OnClick := DesignClick;
    // Designs 2 (Modern Dunkel) und 4 (Schwarz) bleiben intern reserviert.
    if (DesignI <> 2) and (DesignI <> 4) then
      FDesignMenu.Add(FDesignItems[DesignI]);
  end;
  with TIniFile.Create(TabsIniFileName) do
  try
    FDesignIndex := ReadInteger('Viewer', 'Design', 0);
  finally
    Free;
  end;
  if (FDesignIndex < 0) or (FDesignIndex > 5) or (FDesignIndex = 2) or (FDesignIndex = 4) then
    FDesignIndex := 0;
  FDesignItems[FDesignIndex].Checked := True;
  // Sprache: Windows-UI-Sprache beim ersten Start, danach INI-Auswahl.
  FLanguageMenu := TMenuItem.Create(FHelpMainMenu);
  FLanguageMenu.Caption := Tr('Sprache / Language');
  FOptionsMenu.Add(FLanguageMenu);
  FGermanMenuItem := TMenuItem.Create(FHelpMainMenu);
  FGermanMenuItem.Caption := Tr('Deutsch');
  FGermanMenuItem.RadioItem := True;
  FGermanMenuItem.GroupIndex := 1;
  FGermanMenuItem.OnClick := ChangeLanguageClick;
  FLanguageMenu.Add(FGermanMenuItem);
  FEnglishMenuItem := TMenuItem.Create(FHelpMainMenu);
  FEnglishMenuItem.Caption := 'English';
  FEnglishMenuItem.RadioItem := True;
  FEnglishMenuItem.GroupIndex := 1;
  FEnglishMenuItem.OnClick := ChangeLanguageClick;
  FLanguageMenu.Add(FEnglishMenuItem);
  FGermanMenuItem.Checked := PDFLanguage = 'de';
  FEnglishMenuItem.Checked := PDFLanguage = 'en';
  // Design direkt unterhalb der Sprachauswahl anzeigen.
  FOptionsMenu.Add(FDesignMenu);
  // Sprachwahl optisch von den restlichen Optionen trennen.
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := '-';
  FOptionsMenu.Add(HelpItem);
  // Programmstart: zusammengehörige Optionen direkt untereinander.
  FWindowsStartMenuItem := TMenuItem.Create(FHelpMainMenu);
  FWindowsStartMenuItem.Caption := Tr('Mit Windows starten');
  FWindowsStartMenuItem.OnClick := ToggleWindowsStart;
  FOptionsMenu.Add(FWindowsStartMenuItem);
  FStartMinimizedMenuItem := TMenuItem.Create(FHelpMainMenu);
  FStartMinimizedMenuItem.Caption := Tr('Beim Start minimieren');
  FStartMinimizedMenuItem.OnClick := ToggleStartMinimized;
  FOptionsMenu.Add(FStartMinimizedMenuItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := '-';
  FOptionsMenu.Add(HelpItem);
  // Fensterverhalten beim Schließen.
  FTrayMenuItem := TMenuItem.Create(FHelpMainMenu);
  FTrayMenuItem.Caption := Tr('Beim Schließen in den Infobereich');
  FTrayMenuItem.AutoCheck := False;
  FTrayMenuItem.OnClick := ToggleTrayMode;
  FOptionsMenu.Add(FTrayMenuItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := '-';
  FOptionsMenu.Add(HelpItem);
  // Windows-Dateizuordnung.
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('PDF-Dateien mit dem FreePDF64-Viewer verknüpfen ...');
  HelpItem.OnClick := PDFVerknuepfungClick;
  FOptionsMenu.Add(HelpItem);
  FHelpRootMenuItem := TMenuItem.Create(FHelpMainMenu);
  FHelpRootMenuItem.Caption := Tr('Hilfe');
  FHelpMainMenu.Items.Add(FHelpRootMenuItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('Funktionsübersicht');
  HelpItem.ShortCut := ShortCut(VK_F1, []);
  HelpItem.OnClick := ShowViewerHelp;
  FHelpRootMenuItem.Add(HelpItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := '-';
  FHelpRootMenuItem.Add(HelpItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := 'Nach Updates suchen ...';
  HelpItem.OnClick := UpdateManualClick;
  FHelpRootMenuItem.Add(HelpItem);
  FUpdateManualMenuItem := HelpItem;
  FUpdateAutoMenuItem := TMenuItem.Create(FHelpMainMenu);
  FUpdateAutoMenuItem.Caption := 'Automatisch wöchentlich nach Updates suchen';
  FUpdateAutoMenuItem.OnClick := UpdateAutoClick;
  FHelpRootMenuItem.Add(FUpdateAutoMenuItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := '-';
  FHelpRootMenuItem.Add(HelpItem);
  HelpItem := TMenuItem.Create(FHelpMainMenu);
  HelpItem.Caption := Tr('Über FreePDF64-Viewer ...');
  HelpItem.OnClick := ShowAboutViewer;
  FHelpRootMenuItem.Add(HelpItem);
  Ini := TIniFile.Create(TabsIniFileName);
  try
    FUpdateAutoMenuItem.Checked := Ini.ReadBool('Updates', 'Automatic', True);
    FTrayEnabled := Ini.ReadBool('Viewer', 'BeimSchliessenInTray', False);
    FStartMinimized := Ini.ReadBool('Viewer', 'BeimStartMinimieren', False);
  finally
    Ini.Free;
  end;
  FTrayMenuItem.Checked := FTrayEnabled;
  FWindowsStartMenuItem.Checked := IsWindowsStartEnabled;
  FStartMinimizedMenuItem.Checked := FStartMinimized;
  // Startverhalten gilt fuer jeden Programmstart, unabhaengig vom
  // Windows-Autostart. Die Tray-Option gilt ausschliesslich beim X.
  FStartupMinimizePending := FStartMinimized;
  // Beim Start aus FreePDF64 nur Sprache und Design unter Optionen anbieten.
  UpdateIntegratedOptionsVisibility;
  // Erst nach dem Ein-/Ausblenden von Optionen das fertige Menue zuweisen.
  // So wird die Rechtsbuendigkeit nicht durch einen spaeteren Neuaufbau
  // des Windows-Menues wieder verworfen.
  Menu := FHelpMainMenu;
  AlignHelpMenuRight;

  FTrayPopup := TPopupMenu.Create(Self);
  HelpItem := TMenuItem.Create(FTrayPopup);
  HelpItem.Caption := Tr('FreePDF64-Viewer anzeigen');
  HelpItem.Default := True;
  HelpItem.OnClick := RestoreFromTray;
  FTrayPopup.Items.Add(HelpItem);
  HelpItem := TMenuItem.Create(FTrayPopup);
  HelpItem.Caption := '-';
  FTrayPopup.Items.Add(HelpItem);
  HelpItem := TMenuItem.Create(FTrayPopup);
  HelpItem.Caption := Tr('FreePDF64-Viewer beenden');
  HelpItem.OnClick := ExitFromTray;
  FTrayPopup.Items.Add(HelpItem);
  FTabContextMenu := TPopupMenu.Create(Self);
  FTabContextMenu.OnPopup := TabContextPopup;
  FReopenClosedItem := TMenuItem.Create(FTabContextMenu);
  // Untermenü wird bei jedem Öffnen aus den letzten 20 PDFs aufgebaut.
  FTabContextMenu.Items.Add(FReopenClosedItem);
  // Normales Fenster, keine TopMost-Eigenschaft.
  FormStyle := fsNormal;
  BorderStyle := bsSizeable;
  Constraints.MinWidth := 450;
  Constraints.MinHeight := 300;
  PopupMode := pmNone;
  Caption := 'FreePDF64-Viewer Portable';
  Width := 1100;
  Height := 800;
  Position := poDesigned;
  DoubleBuffered := True;
  Header := TPanel.Create(Self);
  FViewerHeader := Header;
  Header.Parent := Self;
  Header.Align := alTop;
  Header.Height := 0;
  Header.Visible := False;
  Header.BevelOuter := bvNone;
  FWelcomePanel := TScrollBox.Create(Self);
  FWelcomePanel.Parent := Self;
  FWelcomePanel.Align := alClient;
  FWelcomePanel.BorderStyle := bsNone;
  FWelcomePanel.AutoScroll := True;
  FWelcomePanel.VertScrollBar.Visible := True;
  FWelcomePanel.VertScrollBar.Tracking := True;
  FWelcomePanel.HorzScrollBar.Visible := False;
  FWelcomePanel.Color := RGB(248, 250, 253);
  FWelcomePanel.ParentBackground := False;
  // Auch ohne geöffnete PDF steht der vorhandene Wiederherstellungsverlauf
  // über das Kontextmenü zur Verfügung.
  FWelcomePanel.PopupMenu := FTabContextMenu;

  // Das Startbild liegt portabel neben der EXE.
  FWelcomeImage := TImage.Create(Self);
  FWelcomeImage.Parent := FWelcomePanel;
  FWelcomeImage.PopupMenu := FTabContextMenu;
  FWelcomeImage.Proportional := True;
  FWelcomeImage.Stretch := True;
  FWelcomeImage.Center := True;
  FWelcomeImage.Transparent := True;
  if FileExists(ExtractFilePath(ParamStr(0)) + 'FreePDF64Viewer_Startbild.jpg') then
    try
      FWelcomeImage.Picture.LoadFromFile(
        ExtractFilePath(ParamStr(0)) + 'FreePDF64Viewer_Startbild.jpg');
    except
      FWelcomeImage.Visible := False;
    end
  else
    FWelcomeImage.Visible := False;

  FWelcomeTitle := TLabel.Create(Self);
  FWelcomeTitle.Parent := FWelcomePanel;
  FWelcomeTitle.PopupMenu := FTabContextMenu;
  FWelcomeTitle.AutoSize := True;
  FWelcomeTitle.Font.Size := 19;
  FWelcomeTitle.Font.Name := 'Segoe UI';
  FWelcomeTitle.Font.Color := RGB(29, 45, 67);
  FWelcomeTitle.Font.Style := [fsBold];
  FWelcomeTitle.Caption := Tr('Willkommen beim FreePDF64-Viewer Portable');

  FWelcomeHint := TLabel.Create(Self);
  FWelcomeHint.Parent := FWelcomePanel;
  FWelcomeHint.PopupMenu := FTabContextMenu;
  FWelcomeHint.AutoSize := True;
  FWelcomeHint.Font.Size := 11;
  FWelcomeHint.Font.Name := 'Segoe UI';
  FWelcomeHint.Font.Color := RGB(94, 108, 126);
  FWelcomeHint.Caption := Tr('PDFs und Grafiken öffnen oder hierher ziehen (Strg+O)');

  FWelcomeOpenButton := TButton.Create(Self);
  FWelcomeOpenButton.Parent := FWelcomePanel;
  FWelcomeOpenButton.PopupMenu := FTabContextMenu;
  FWelcomeOpenButton.Caption := Tr('PDFs und Grafiken öffnen ...');
  FWelcomeOpenButton.Width := MulDiv(260, Dpi, 96);
  FWelcomeOpenButton.Height := MulDiv(44, Dpi, 96);
  FWelcomeOpenButton.Font.Name := 'Segoe UI';
  FWelcomeOpenButton.Font.Style := [fsBold];
  FWelcomeOpenButton.Hint := Tr('Eine oder mehrere PDFs und Grafiken öffnen (Strg+O)');
  FWelcomeOpenButton.ShowHint := True;
  FWelcomeOpenButton.OnClick := OpenPDFClick;
  FWelcomeWorkspaceButton := TButton.Create(Self);
  FWelcomeWorkspaceButton.Parent := FWelcomePanel;
  FWelcomeWorkspaceButton.Caption := Tr('Arbeitsbereich öffnen ...');
  FWelcomeWorkspaceButton.Width := MulDiv(260, Dpi, 96);
  FWelcomeWorkspaceButton.Height := MulDiv(44, Dpi, 96);
  FWelcomeWorkspaceButton.Font.Name := 'Segoe UI';
  FWelcomeWorkspaceButton.Font.Style := [fsBold];
  FWelcomeWorkspaceButton.Hint := Tr('Gespeicherte Arbeitsbereiche mit Name und Datum auswählen');
  FWelcomeWorkspaceButton.ShowHint := True;
  FWelcomeWorkspaceButton.OnClick := OpenWorkspaceClick;
  FRecentTitle := TLabel.Create(Self);
  FRecentTitle.Parent := FWelcomePanel;
  FRecentTitle.Font.Name := 'Segoe UI';
  FRecentTitle.Font.Size := 12;
  FRecentTitle.Font.Style := [fsBold];
  FRecentTitle.Caption := Tr('Zuletzt geöffnete Dateien');

  FRecentScroll := TRecentPDFScrollBox.Create(Self);
  FRecentScroll.Parent := FWelcomePanel;
  FRecentScroll.BorderStyle := bsNone;
  FRecentScroll.Color := RGB(248, 250, 253);
  FRecentScroll.ParentBackground := False;
  // Nur die äußere Startseite scrollt. Die innere Liste darf beim
  // Umordnen von 10 Zeilen auf 2 Spalten keinen Scroll-Offset behalten.
  FRecentScroll.AutoScroll := False;
  FRecentScroll.VertScrollBar.Tracking := True;
  FRecentScroll.HorzScrollBar.Visible := False;
  FRecentScroll.VertScrollBar.Visible := False;

  FRecentClearButton := TButton.Create(Self);
  FRecentClearButton.Parent := FWelcomePanel;
  FRecentClearButton.Caption := Tr('Verlauf löschen');
  FRecentClearButton.OnClick := RecentPDFClear;

  FRecentPopup := TPopupMenu.Create(Self);
  HelpItem := TMenuItem.Create(FRecentPopup);
  HelpItem.Caption := Tr('Aus Liste entfernen');
  HelpItem.OnClick := RecentPDFRemove;
  FRecentPopup.Items.Add(HelpItem);
  HelpItem := TMenuItem.Create(FRecentPopup);
  HelpItem.Caption := Tr('Dateiordner öffnen');
  HelpItem.OnClick := RecentPDFShowFolder;
  FRecentPopup.Items.Add(HelpItem);
  RefreshRecentPDFList;
  FWelcomePanel.OnResize := WelcomeResize;

  // Tabs und Bedienelemente teilen sich denselben horizontalen Bereich.
  // Rechts wird eine feste Spalte reserviert, ohne zusaetzliche Zeile.
  TabHost := TPanel.Create(Self);
  TabHost.Parent := Self;
  TabHost.Align := alClient;
  TabHost.BevelOuter := bvNone;
  // Test: Registerkarten-Container gepuffert zeichnen.
  TabHost.ParentDoubleBuffered := False;
  TabHost.DoubleBuffered := True;
  TabHost.Caption := '';
  // Eigener reservierter Bereich links: keine Ueberlagerung der ersten Registerkarte.
  FLeftPDFOverlay := TPanel.Create(Self);
  FLeftPDFOverlay.Parent := TabHost;
  // Overlay auf der vorhandenen PDF-Symbolleistenzeile, keine zusaetzliche
  // Kopfzeile und kein alLeft-Streifen. Die Tabs behalten ihre volle Breite.
  FLeftPDFOverlay.Align := alNone;
  FLeftPDFOverlay.SetBounds(2, 2,
    MulDiv(79, Dpi, 96), MulDiv(24, Dpi, 96));
  FLeftPDFOverlay.BevelOuter := bvNone;
  FLeftPDFOverlay.Caption := '';
  FLeftPDFOverlay.ParentBackground := False;
  FLeftPDFOverlay.Color := clBtnFace;
  FLeftPDFOverlay.Visible := False;
  FTabs := TPageControl.Create(Self);
  FTabs.Parent := TabHost;
  // Das native Register-Control verarbeitet den freien Streifen selbst.
  // WM_CONTEXTMENU erfasst deshalb auch Rechtsklicks neben den Tabs.
  FOriginalTabsWindowProc := FTabs.WindowProc;
  FTabs.WindowProc := TabsWindowProc;
  Header.PopupMenu := FTabContextMenu;
  FTabs.DoubleBuffered := True;
  FTabs.Align := alClient;
  FDragTabIndex := -1;
  FDraggingTab := False;
  FTabs.OnMouseDown := TabMouseDown;
  FTabs.OnMouseUp := TabMouseUp;
  FTabs.ShowHint := False; // Pfad niemals als vererbbarer VCL-Hint
  FTabHintWindow := THintWindow.Create(Self);
  FHintTabIndex := -1;
  FTrackingTabsMouseLeave := False;
  FTabHintWatchTimer := TTimer.Create(Self);
  FTabHintWatchTimer.Enabled := False;
  FTabHintWatchTimer.Interval := 50;
  FTabHintWatchTimer.OnTimer := TabHintWatchTimerTick;
  FTabPreviewIndex := -1;
  FTabPreviewTimer := TTimer.Create(Self);
  FTabPreviewTimer.Interval := 75;
  FTabPreviewTimer.Enabled := False;
  FTabPreviewTimer.OnTimer := TabPreviewTimerTick;
  FHoverCloseTabIndex := -1;
  FTabs.OnMouseMove := TabsMouseMove;
  FTabs.OnMouseLeave := TabsMouseLeave;
  FTabs.OnChanging := TabsChanging;
  FTabs.OnChange := TabsChange;
  FTabs.OnResize := TabsResized;
  FTabs.OwnerDraw := True;
  FTabs.OnDrawTab := DrawPDFTab;
  // Die freie Registerleiste ist bei TPageControl nicht in allen
  // Windows/VCL-Versionen zuverlässig über dessen Mausereignisse erreichbar.
  // Ein eigenes Steuerelement deckt ausschließlich den freien Bereich ab.
  FEmptyTabStrip := TPanel.Create(Self);
  FEmptyTabStrip.Parent := FTabs;
  FEmptyTabStrip.BevelOuter := bvNone;
  FEmptyTabStrip.Caption := '';
  FEmptyTabStrip.Color := clBtnFace;
  FEmptyTabStrip.Cursor := crDefault;
  FEmptyTabStrip.OnMouseUp := EmptyTabStripMouseUp;
  UpdateEmptyTabStrip;
  // Hauptprogramm im selben Prozess sichtbar machen.
  FMainProgramButton := TPDFDesignButton.Create(Self);
  FMainProgramButton.Parent := Header;
  FMainProgramButton.Align := alLeft;
  FMainProgramButton.Width := Max(MulDiv(170, Dpi, 96),
    Canvas.TextWidth('FreePDF64 öffnen') + MulDiv(28, Dpi, 96));
  FMainProgramButton.Caption := Tr('FreePDF64 öffnen');
  FMainProgramButton.Hint := Tr('FreePDF64-Hauptprogramm öffnen');
  FMainProgramButton.ShowHint := True;
  FMainProgramButton.OnClick := OpenMainProgramClick;
  FMainProgramButton.Visible := False; // Portable: kein Hauptprogramm
  // Rechts im Tabstreifen: Pfeile | PDF-Anzahl | Suche.
  // Eigenes Overlay reserviert einen festen Bereich fuer die Bedienung.
  SearchArea := TPanel.Create(Self);
  SearchArea.Parent := TabHost;
  // Als Geschwister-Control liegt die Aktionsleiste oberhalb der nativen
  // Windows-UpDown-Pfeile des TPageControl.
  SearchArea.Align := alNone;
  SearchArea.Width := MulDiv(205, Dpi, 96);
  SearchArea.Height := MulDiv(27, Dpi, 96);
  SearchArea.BevelOuter := bvNone;
  SearchArea.Color := clBtnFace;
  FTabActionsPanel := SearchArea;
  // Fester eigener Platz fuer den Split-Button, analog zu den Aktionen rechts.
  // Die Registerkarten beginnen rechts davon; kein Button liegt ueber Tab 1.
  FTabSplitButton := TOutlinedSplitButton.Create(Self);
  FTabSplitButton.Parent := FLeftPDFOverlay;
  FTabSplitButton.Align := alNone;
  // Gleiche Abmessungen wie der Button "PDF öffnen" in der Hauptsymbolleiste.
  FTabSplitButton.SetBounds(1, 1, MulDiv(32, Dpi, 96),
    MulDiv(28, Dpi, 96));
  // Orangefarbener Rahmen statt einer nicht zugänglichen TButton.Color-Eigenschaft.
  FTabSplitButton.Font.Style := [fsBold];
  FTabSplitButton.Visible := True;
  FTabSplitButton.Caption := '◫';
  FTabSplitButton.Hint := Tr('Ansicht teilen / Teilung beenden (zwei Registerkarten mit Strg+Klick auswählen)');
  if SameText(PDFLanguage, 'en') then
    FTabSplitButton.Hint := 'Split view / Close split view (select two tabs with Ctrl+Click)';
  FTabSplitButton.ShowHint := True;
  FTabSplitButton.OnClick := SplitMenuClick;
  FTabTextSearchButton := TPDFDesignButton.Create(Self);
  FTabTextSearchButton.Parent := FLeftPDFOverlay;
  FTabTextSearchButton.Align := alNone;
  FTabTextSearchButton.SetBounds(1 + MulDiv(25, Dpi, 96), 1,
    MulDiv(25, Dpi, 96), MulDiv(22, Dpi, 96));
  FTabTextSearchButton.Width := MulDiv(25, Dpi, 96);
  FTabTextSearchButton.Caption := '⌕';
  FTabTextSearchButton.Hint := 'Text im linken PDF suchen (Strg+F)';
  FTabTextSearchButton.ShowHint := True;
  FTabTextSearchButton.OnClick := LocalSearchMenuClick;
  FLeftPDFOverlay.BringToFront;
  FSplitButtonPopup := TPopupMenu.Create(Self);
  HelpItem := TMenuItem.Create(FSplitButtonPopup);
  HelpItem.Caption := 'Linke Ansicht schließen';
  HelpItem.OnClick := SplitPopupCloseLeft;
  FSplitButtonPopup.Items.Add(HelpItem);
  HelpItem := TMenuItem.Create(FSplitButtonPopup);
  HelpItem.Caption := 'Rechte Ansicht schließen';
  HelpItem.OnClick := SplitPopupCloseRight;
  FSplitButtonPopup.Items.Add(HelpItem);
  HelpItem := TMenuItem.Create(FSplitButtonPopup);
  HelpItem.Caption := '-';
  FSplitButtonPopup.Items.Add(HelpItem);
  HelpItem := TMenuItem.Create(FSplitButtonPopup);
  HelpItem.Caption := 'Tab-Positionen austauschen';
  HelpItem.OnClick := SplitPopupSwap;
  FSplitButtonPopup.Items.Add(HelpItem);
  FSplitButtonPopup.OnPopup := SplitButtonPopup;
  FTabSplitButton.PopupMenu := FSplitButtonPopup;
  FTabSplitButton.BringToFront;
  FTabNextButton := TPDFDesignButton.Create(Self);
  FTabNextButton.Parent := SearchArea;
  FTabNextButton.Align := alLeft;
  FTabNextButton.Width := MulDiv(25, Dpi, 96);
  FTabNextButton.Caption := '‹';
  FTabNextButton.Hint := '';
  FTabNextButton.ShowHint := False;
  FTabNextButton.OnClick := TabArrowClick;
  FTabPrevButton := TPDFDesignButton.Create(Self);
  FTabPrevButton.Parent := SearchArea;
  FTabPrevButton.Align := alLeft;
  FTabPrevButton.Width := MulDiv(25, Dpi, 96);
  FTabPrevButton.Caption := '›'; // VCL alLeft ordnet zuletzt eingefuegte Controls links ein
  FTabPrevButton.Hint := '';
  FTabPrevButton.ShowHint := False;
  FTabPrevButton.OnClick := TabArrowClick;
  FTabSearchButton := TPDFDesignButton.Create(Self);
  FTabSearchButton.Parent := SearchArea;
  FTabSearchButton.Align := alRight;
  FTabSearchButton.Width := MulDiv(39, Dpi, 96);
  FTabSearchButton.Caption := '▤';
  FTabSearchButton.Font.Name := 'Segoe UI Symbol';
  FTabSearchButton.Font.Size := 12;
  FTabSearchButton.Hint := Tr('Geöffnete Registerkarten suchen (Strg+Umsch+A)');
  FTabSearchButton.ShowHint := True;
  FTabSearchButton.OnClick := TabSearchClick;
  FTabCountBadge := TPaintBox.Create(Self);
  FTabCountBadge.Parent := SearchArea;
  FTabCountBadge.Align := alClient;
  FTabCountBadge.Hint := Tr('Anzahl geöffneter PDF-Registerkarten');
  FTabCountBadge.ShowHint := True;
  FTabCountBadge.OnPaint := PaintTabCountBadge;
  PositionTabActions;
  FTabSearchForm := TForm.CreateNew(Self);
  FTabSearchForm.Scaled := False;
  // Suchfenster dem PDF-Anzeiger zuordnen, nicht dem FreePDF64-Hauptfenster.
  FTabSearchForm.PopupMode := pmExplicit;
  FTabSearchForm.PopupParent := Self;
  FTabSearchForm.BorderStyle := bsToolWindow;
  FTabSearchForm.Position := poDesigned;
  FTabSearchForm.Caption := Tr('PDF-Registerkartensuche');
  // Bei hoher DPI braucht die Suchliste mehr Platz für die Schrift.
  // Der Dialog wird explizit skaliert; die Fontgröße bleibt in Punkten.
  FTabSearchForm.Font.Assign(Self.Font);
  // Die Registerkartensuche braucht bei hoher DPI mehr nutzbare Flaeche.
  // Die Werte sind logische 96-DPI-Einheiten und werden genau einmal skaliert.
  FTabSearchForm.Font.Size := 9;
  FTabSearchForm.ClientWidth := MulDiv(560, Dpi, 96);
  FTabSearchForm.ClientHeight := MulDiv(420, Dpi, 96);
  // Kein automatisches Ausblenden bei Fokuswechsel: sonst oeffnet der
  // Bei Fokuswechsel ausserhalb der Suche ausblenden.
  // Klick auf die Lupe wird gesondert behandelt (Toggle).
  FTabSearchForm.OnDeactivate := TabSearchDeactivate;
  FTabSearchEdit := TEdit.Create(FTabSearchForm);
  FTabSearchEdit.Parent := FTabSearchForm;
  FTabSearchEdit.Align := alTop;
  FTabSearchEdit.ParentFont := True;
  FTabSearchEdit.AutoSize := False;
  FTabSearchEdit.Height := MulDiv(44, Dpi, 96);
  FTabSearchEdit.Font.Size := 10;
  FTabSearchEdit.TextHint := Tr('Dateiname eingeben ...');
  FTabSearchEdit.OnChange := TabSearchChanged;
  FTabSearchEdit.OnKeyDown := TabSearchKeyDown;
  FTabSearchList := TListBox.Create(FTabSearchForm);
  FTabSearchList.Parent := FTabSearchForm;
  FTabSearchList.Align := alClient;
  FTabSearchList.ParentFont := True;
  FTabSearchList.Font.Size := 10;
  FTabSearchList.ItemHeight := Max(MulDiv(32, Dpi, 96),
    FTabSearchList.Canvas.TextHeight('Ag') + MulDiv(8, Dpi, 96));
  FTabSearchList.OnDblClick := TabSearchChoose;
  FTabSearchList.OnMouseMove := TabSearchListMouseMove;
  FTabSearchList.OnKeyDown := TabSearchKeyDown;
  FTabSearchList.ShowHint := True;
  FPendingExplorerFiles := TStringList.Create;
  FExplorerBatchTimer := TTimer.Create(Self);
  FExplorerBatchTimer.Enabled := False;
  FExplorerBatchTimer.Interval := 350;
  FExplorerBatchTimer.OnTimer := ExplorerBatchTimerTick;
  FCreatedPDFForegroundTimer := TTimer.Create(Self);
  FCreatedPDFForegroundTimer.Enabled := False;
  FCreatedPDFForegroundTimer.Interval := 450;
  FCreatedPDFForegroundTimer.OnTimer := CreatedPDFForegroundTimerTick;
  FDeferredActivePDF := nil;
  FInitialWindowOffscreen := False;
  FTabFitTimer := TTimer.Create(Self);
  FTabFitTimer.Enabled := False;
  FTabFitTimer.Interval := 75;
  FTabFitTimer.OnTimer := TabFitTimerTick;
  FActivationTimer := TTimer.Create(Self);
  FActivationTimer.Enabled := False;
  FActivationTimer.Interval := 250;
  FActivationTimer.OnTimer := ActivationTimerTick;
  LoadWindowSettings;
  OnClose := TabsFormClose;
  RefreshLanguage;
  ApplyViewerDesign;
  OnShow := TabsFormShow;
  RefreshLanguage;
end;

procedure TPDFTabsForm.PaintTabCountBadge(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
  S: string;
  TextX, TextY, Radius, Pad: Integer;
begin
  if (FTabCountBadge = nil) or (FTabs = nil) then Exit;
  C := FTabCountBadge.Canvas;
  if FDesignIndex = 3 then
    C.Brush.Color := RGB(192, 192, 192)
  else
    C.Brush.Color := FTabCountBadge.Parent.Brush.Color;
  C.FillRect(FTabCountBadge.ClientRect);

  Pad := MulDiv(6, CurrentPPI, 96);
  R := Rect(Pad, MulDiv(7, CurrentPPI, 96),
    FTabCountBadge.Width - Pad, FTabCountBadge.Height - MulDiv(7, CurrentPPI, 96));
  if FDesignIndex = 3 then
  begin
    // Windows Klassik: keine zusaetzliche Plakette und kein zweiter
    // 3D-Rahmen. Die Zahl steht direkt auf dem Hintergrund der Tab-Leiste.
    R := FTabCountBadge.ClientRect;
  end
  else
  begin
    Radius := MulDiv(14, CurrentPPI, 96);
    C.Pen.Style := psClear;
    C.Brush.Color := RGB(225, 236, 250);
    C.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Radius, Radius);
  end;
  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  if FDesignIndex = 3 then
    C.Font.Color := clBlack
  else
    C.Font.Color := RGB(35, 85, 145);
  S := IntToStr(FTabs.PageCount);
  TextX := R.Left + (R.Right - R.Left - C.TextWidth(S)) div 2;
  TextY := R.Top + (R.Bottom - R.Top - C.TextHeight(S)) div 2;
  C.TextOut(TextX, TextY, S);
  C.Brush.Style := bsSolid;
  C.Pen.Style := psSolid;
end;

procedure TPDFTabsForm.LoadRecentPDFs;
var
  Ini: TIniFile;
  I, N: Integer;
  S: string;
begin
  FRecentPDFs.Clear;
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    N := EnsureRange(Ini.ReadInteger('RecentPDFs', 'Count', 0), 0, 15);
    for I := 1 to N do
    begin
      S := Trim(Ini.ReadString('RecentPDFs', 'File' + IntToStr(I), ''));
      if (S <> '') and (FRecentPDFs.IndexOf(S) < 0) then
        FRecentPDFs.Add(S);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.SaveRecentPDFs;
var
  Ini: TIniFile;
  I: Integer;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    Ini.EraseSection('RecentPDFs');
    Ini.WriteInteger('RecentPDFs', 'Count', FRecentPDFs.Count);
    for I := 0 to FRecentPDFs.Count - 1 do
      Ini.WriteString('RecentPDFs', 'File' + IntToStr(I + 1), FRecentPDFs[I]);
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.RememberRecentPDF(const AFileName: string);
var
  I: Integer;
  S: string;
begin
  S := Trim(AFileName);
  if (S = '') or IsFreePDFTempAttachment(S) or
     not (SameText(ExtractFileExt(S), '.pdf') or
          SameText(ExtractFileExt(S), '.jpg') or
          SameText(ExtractFileExt(S), '.jpeg') or
          SameText(ExtractFileExt(S), '.png') or
          SameText(ExtractFileExt(S), '.bmp') or
          SameText(ExtractFileExt(S), '.tif') or
          SameText(ExtractFileExt(S), '.tiff')) then Exit;
  S := ExpandFileName(S);
  for I := FRecentPDFs.Count - 1 downto 0 do
    if SameText(FRecentPDFs[I], S) then FRecentPDFs.Delete(I);
  FRecentPDFs.Insert(0, S);
  while FRecentPDFs.Count > 15 do FRecentPDFs.Delete(FRecentPDFs.Count - 1);
  SaveRecentPDFs;
  if FRecentScroll <> nil then RefreshRecentPDFList;
end;

procedure TPDFTabsForm.CleanupRecentThumbnails(const AClearAll: Boolean);
var
  CacheDir, CacheFile: string;
  Search: TSearchRec;
  Cutoff: TDateTime;
begin
  // Ausschliesslich die vom Viewer erzeugten BMP-Vorschaubilder entfernen.
  // Andere Dateien und Unterordner im portablen Verzeichnis bleiben erhalten.
  CacheDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
    'Thumbnails';
  if not DirectoryExists(CacheDir) then Exit;
  Cutoff := Now - 30;
  if System.SysUtils.FindFirst(IncludeTrailingPathDelimiter(CacheDir) + '*.bmp', faAnyFile, Search) <> 0 then
    Exit;
  try
    repeat
      if (Search.Attr and faDirectory) <> 0 then Continue;
      if (not AClearAll) and
         (Search.TimeStamp >= Cutoff) then Continue;
      CacheFile := IncludeTrailingPathDelimiter(CacheDir) + Search.Name;
      try
        System.SysUtils.DeleteFile(CacheFile);
      except
        // Gesperrte oder schreibgeschuetzte Dateien nicht erzwingen.
      end;
    until System.SysUtils.FindNext(Search) <> 0;
  finally
    System.SysUtils.FindClose(Search);
  end;
end;

// TIFF-Vorschau ueber Windows GDI+ (wie in uPDFBrowserForm), ohne WICImage.
type
  TRecentGDIStartupInput = record
    GdiplusVersion: Cardinal;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: LongBool;
    SuppressExternalCodecs: LongBool;
  end;
function RecentGDIStartup(out Token: NativeUInt; const Input: TRecentGDIStartupInput;
  Output: Pointer): Integer; stdcall; external 'gdiplus.dll' name 'GdiplusStartup';
procedure RecentGDIShutdown(Token: NativeUInt); stdcall;
  external 'gdiplus.dll' name 'GdiplusShutdown';
function RecentGDILoadImage(Filename: PWideChar; out Image: Pointer): Integer;
  stdcall; external 'gdiplus.dll' name 'GdipLoadImageFromFile';
function RecentGDIDisposeImage(Image: Pointer): Integer; stdcall;
  external 'gdiplus.dll' name 'GdipDisposeImage';
function RecentGDICreateHBitmap(Image: Pointer; out Bitmap: HBITMAP;
  Background: Cardinal): Integer; stdcall;
  external 'gdiplus.dll' name 'GdipCreateHBITMAPFromBitmap';

procedure TPDFTabsForm.LoadRecentThumbnail(const AFileName: string; AImage: TImage);
var
  Doc: TFreePDF64PDFiumCore;
  Bmp: TBitmap;
  CacheDir, CacheFile: string;
  Hash: UInt64;
  I: Integer;
  Key: string;
  Picture: TPicture;
  Token: NativeUInt;
  GImage: Pointer;
  HB: HBITMAP;
  Input: TRecentGDIStartupInput;
begin
  if (AImage = nil) or not FileExists(AFileName) then Exit;
  // Pfad und Änderungsdatum bilden den Cache-Schlüssel. Bei Änderungen
  // am Dokument wird eine neue Vorschau erzeugt.
  Key := LowerCase(AFileName) + ':' + IntToStr(FileAge(AFileName));
  Hash := UInt64($CBF29CE484222325);
  for I := 1 to Length(Key) do
    Hash := (Hash xor Ord(Key[I])) * UInt64($100000001B3);
  CacheDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'Thumbnails';
  CacheFile := IncludeTrailingPathDelimiter(CacheDir) + IntToHex(Hash, 16) + '.bmp';
  if FileExists(CacheFile) then
  begin
    try
      AImage.Picture.Bitmap.LoadFromFile(CacheFile);
      Exit;
    except
      // Beschädigten Cache-Eintrag neu erstellen.
    end;
  end;
  // Grafikvorschauen ohne PDFium erzeugen; TIFF (auch mehrseitig) zeigt
  // die erste Seite. Derselbe BMP-Cache bleibt fuer alle Dateitypen nutzbar.
  if not SameText(ExtractFileExt(AFileName), '.pdf') then
  begin
    Bmp := TBitmap.Create;
    Picture := TPicture.Create;
    Token := 0;
    GImage := nil;
    HB := 0;
    try
      try
        if SameText(ExtractFileExt(AFileName), '.tif') or
           SameText(ExtractFileExt(AFileName), '.tiff') then
        begin
          FillChar(Input, SizeOf(Input), 0);
          Input.GdiplusVersion := 1;
          if RecentGDIStartup(Token, Input, nil) <> 0 then
            raise Exception.Create('GDI+ initialization failed');
          if (RecentGDILoadImage(PWideChar(AFileName), GImage) <> 0) or
             (GImage = nil) then
            raise Exception.Create('TIFF image could not be loaded');
          if (RecentGDICreateHBitmap(GImage, HB, $FFFFFFFF) <> 0) or
             (HB = 0) then
            raise Exception.Create('TIFF bitmap could not be created');
          Bmp.Handle := HB;
          HB := 0;
          Picture.Assign(Bmp);
        end
        else
          Picture.LoadFromFile(AFileName);
        // Direkt in eine kleine Bitmap rendern, ohne eine zweite
        // Bitmap in Originalaufloesung anzulegen.
        Bmp.PixelFormat := pf24bit;
        Bmp.SetSize(240, 320);
        Bmp.Canvas.Brush.Color := clWhite;
        Bmp.Canvas.FillRect(Rect(0, 0, 240, 320));
        if (Picture.Width > 0) and (Picture.Height > 0) then
        begin
          if Int64(Picture.Width) * 320 > Int64(Picture.Height) * 240 then
            Bmp.Canvas.StretchDraw(Rect(0, (320 - MulDiv(Picture.Height, 240, Picture.Width)) div 2,
              240, (320 + MulDiv(Picture.Height, 240, Picture.Width)) div 2), Picture.Graphic)
          else
            Bmp.Canvas.StretchDraw(Rect((240 - MulDiv(Picture.Width, 320, Picture.Height)) div 2, 0,
              (240 + MulDiv(Picture.Width, 320, Picture.Height)) div 2, 320), Picture.Graphic);
        end;
        AImage.Picture.Bitmap.Assign(Bmp);
        try
          ForceDirectories(CacheDir);
          AImage.Picture.Bitmap.SaveToFile(CacheFile);
        except
        end;
      except
        // Nicht lesbare Grafiken ohne Vorschau belassen.
      end;
    finally
      if HB <> 0 then DeleteObject(HB);
      if GImage <> nil then RecentGDIDisposeImage(GImage);
      if Token <> 0 then RecentGDIShutdown(Token);
      Picture.Free;
      Bmp.Free;
    end;
    Exit;
  end;
  Doc := nil;
  Bmp := TBitmap.Create;
  try
    try
      Doc := TFreePDF64PDFiumCore.Create;
      Doc.OpenFile(AFileName);
      if Doc.PageCount < 1 then Exit;
      Bmp.PixelFormat := pf24bit;
      Doc.RenderPage(0, Bmp, 72, 96);
      AImage.Picture.Bitmap.Assign(Bmp);
      try
        ForceDirectories(CacheDir);
        Bmp.SaveToFile(CacheFile);
      except
        // Ein schreibgeschützter USB-Stick darf die Anzeige nicht verhindern.
      end;
    except
      // Passwortgeschützte oder beschädigte PDFs ohne Vorschau anzeigen.
    end;
  finally
    Doc.Free;
    Bmp.Free;
  end;
end;

function TRecentPDFScrollBox.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Outer: TWinControl;
  Step: Integer;
begin
  Outer := Parent;
  while (Outer <> nil) and not (Outer is TScrollBox) do
    Outer := Outer.Parent;
  if Outer is TScrollBox then
  begin
    Step := MulDiv(60, TScrollBox(Outer).CurrentPPI, 96);
    if WheelDelta > 0 then
      TScrollBox(Outer).VertScrollBar.Position :=
        Max(0, TScrollBox(Outer).VertScrollBar.Position - Step)
    else if WheelDelta < 0 then
      TScrollBox(Outer).VertScrollBar.Position :=
        TScrollBox(Outer).VertScrollBar.Position + Step;
    Result := True;
  end
  else
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

function TPDFTabsForm.RecentPDFPageCount(const AFileName: string): Integer;
var
  Ini: TIniFile;
  Doc: TFreePDF64PDFiumCore;
  Key, Fingerprint: string;
  Hash: UInt64;
  I: Integer;
begin
  Result := 0;
  if not FileExists(AFileName) then Exit;
  Hash := UInt64($CBF29CE484222325);
  Key := LowerCase(AFileName);
  for I := 1 to Length(Key) do
    Hash := (Hash xor Ord(Key[I])) * UInt64($100000001B3);
  Key := IntToHex(Hash, 16);
  Fingerprint := IntToStr(FileAge(AFileName));
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    if Ini.ReadString('RecentPDFPageCount', Key + '_Stamp', '') = Fingerprint then
    begin
      Result := Ini.ReadInteger('RecentPDFPageCount', Key, 0);
      if Result > 0 then Exit;
    end;
    // Keine PDFium-Dokumente waehrend des Starts fuer die Startseite
    // erzeugen. Ein nicht zwischengespeicherter Wert bleibt unbekannt.
    Result := 0;
  finally
    Ini.Free;
  end;
end;

procedure TPDFTabsForm.RefreshRecentPDFList;
var
  I, Y, H, Dpi: Integer;
  Row: TPanel;
  Link, PathLabel, CountLabel: TLabel;
  PageTotal: Integer;
  Thumb: TImage;
  FileName: string;
begin
  if FRecentScroll = nil then Exit;
  FRecentScroll.DisableAlign;
  try
    while FRecentScroll.ControlCount > 0 do
      FRecentScroll.Controls[0].Free;
    Dpi := CurrentPPI;
    H := MulDiv(110, Dpi, 96);
    Y := 0;
    for I := 0 to FRecentPDFs.Count - 1 do
    begin
      FileName := FRecentPDFs[I];
      Row := TPanel.Create(Self);
      Row.Parent := FRecentScroll;
      Row.SetBounds(0, Y, Max(100, FRecentScroll.ClientWidth - MulDiv(20, Dpi, 96)), H);
      Row.Anchors := [akLeft, akTop, akRight];
      Row.BevelOuter := bvNone;
      Row.ParentBackground := False;
      // Alle zuletzt geöffneten PDFs erhalten dieselbe hellblaue Karte.
      Row.Color := RGB(246, 249, 253);
      Row.Tag := I;
      Row.OnContextPopup := RecentPDFContext;
      Thumb := TImage.Create(Self);
      Thumb.Parent := Row;
      Thumb.SetBounds(MulDiv(7,Dpi,96), MulDiv(4,Dpi,96),
        MulDiv(72,Dpi,96), MulDiv(100,Dpi,96));
      Thumb.Center := True;
      Thumb.Proportional := True;
      Thumb.Stretch := True;
      Thumb.Tag := I;
      Thumb.Hint := FileName;
      Thumb.ShowHint := True;
      Thumb.OnClick := RecentPDFClick;
      Thumb.OnContextPopup := RecentPDFContext;
      LoadRecentThumbnail(FileName, Thumb);
      if SameText(ExtractFileExt(FileName), '.pdf') then
        PageTotal := RecentPDFPageCount(FileName)
      else
        PageTotal := 0;
      if FileExists(FileName) then Thumb.Cursor := crHandPoint;
      Link := TLabel.Create(Self);
      Link.Parent := Row;
      Link.SetBounds(MulDiv(88,Dpi,96), MulDiv(25,Dpi,96),
        Row.Width - MulDiv(96,Dpi,96), MulDiv(22,Dpi,96));
      Link.Anchors := [akLeft, akTop, akRight];
      Link.AutoSize := False;
      Link.WordWrap := False;
      Link.EllipsisPosition := epEndEllipsis;
      Link.Font.Name := 'Segoe UI';
      Link.Font.Size := 10;
      Link.Font.Color := RGB(0, 99, 190);
      Link.Font.Style := [fsUnderline];
      Link.Caption := ExtractFileName(FileName);
      Link.Hint := FileName;
      Link.ShowHint := True;
      Link.Tag := I;
      Link.OnClick := RecentPDFClick;
      Link.OnContextPopup := RecentPDFContext;
      if FileExists(FileName) then Link.Cursor := crHandPoint
      else
      begin
        Link.Enabled := False;
        Link.Font.Color := clGrayText;
      end;
      PathLabel := TLabel.Create(Row);
      PathLabel.Name := 'RecentPathLabel';
      PathLabel.Parent := Row;
      PathLabel.SetBounds(MulDiv(88,Dpi,96), MulDiv(62,Dpi,96),
        Row.Width - MulDiv(96,Dpi,96), MulDiv(18,Dpi,96));
      PathLabel.Anchors := [akLeft, akTop, akRight];
      PathLabel.AutoSize := False;
      PathLabel.EllipsisPosition := epPathEllipsis;
      PathLabel.Font.Name := 'Segoe UI';
      PathLabel.Font.Size := 8;
      PathLabel.Font.Color := clGrayText;
      PathLabel.Caption := ExtractFilePath(FileName);
      PathLabel.Hint := FileName;
      PathLabel.ShowHint := True;
      PathLabel.Tag := I;
      PathLabel.OnContextPopup := RecentPDFContext;
      if PageTotal > 0 then
      begin
        CountLabel := TLabel.Create(Row);
        CountLabel.Name := 'RecentCountLabel';
        CountLabel.Parent := Row;
        CountLabel.SetBounds(MulDiv(88,Dpi,96), MulDiv(85,Dpi,96),
          Row.Width - MulDiv(96,Dpi,96), MulDiv(18,Dpi,96));
        CountLabel.Anchors := [akLeft, akTop, akRight];
        CountLabel.AutoSize := False;
        CountLabel.Font.Name := 'Segoe UI';
        CountLabel.Font.Size := 8;
        CountLabel.Font.Color := clGrayText;
        if SameText(PDFLanguage, 'en') then
        begin
          if PageTotal = 1 then CountLabel.Caption := '1 page'
          else CountLabel.Caption := IntToStr(PageTotal) + ' pages';
        end
        else if PageTotal = 1 then CountLabel.Caption := '1 Seite'
        else CountLabel.Caption := IntToStr(PageTotal) + ' Seiten';
        CountLabel.Tag := I;
        CountLabel.OnContextPopup := RecentPDFContext;
      end;
      Inc(Y, H + MulDiv(3,Dpi,96));
    end;
  finally
    FRecentScroll.EnableAlign;
  end;
  FRecentClearButton.Enabled := FRecentPDFs.Count > 0;
  // Gesamthöhe für die äußere scrollbar nutzbar machen.
  if FWelcomePanel <> nil then WelcomeResize(nil);
end;

procedure TPDFTabsForm.RecentPDFClick(Sender: TObject);
var
  I: Integer;
  S: string;
  PDF: TPDFBrowserForm;
begin
  if not (Sender is TControl) then Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FRecentPDFs.Count) then Exit;
  S := FRecentPDFs[I];
  if not FileExists(S) then
  begin
    PDFModernMessageDlg(Tr('Diese Datei ist nicht mehr vorhanden:') + sLineBreak + S,
      mtInformation, [mbOK], 0);
    RefreshRecentPDFList;
    Exit;
  end;
  if ActivateExistingPDF(S) then Exit;
  PDF := TPDFBrowserForm.Create(nil);
      PDF.OnGlobalSearch := GlobalSearchClick;
  try
    PDF.PDFFileName := S;
    PDF.StandalonePDFMode := False;
    AddPDF(PDF);
    ActivatePDF(PDF);
  except
    PDF.Free;
    raise;
  end;
end;

procedure TPDFTabsForm.RecentPDFContext(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
var
  P: TPoint;
begin
  if not (Sender is TControl) then Exit;
  FRecentPopupIndex := TControl(Sender).Tag;
  if (FRecentPopupIndex < 0) or (FRecentPopupIndex >= FRecentPDFs.Count) then Exit;
  P := TControl(Sender).ClientToScreen(MousePos);
  FRecentPopup.Popup(P.X, P.Y);
  Handled := True;
end;

procedure TPDFTabsForm.RecentPDFRemove(Sender: TObject);
begin
  if (FRecentPopupIndex < 0) or (FRecentPopupIndex >= FRecentPDFs.Count) then Exit;
  FRecentPDFs.Delete(FRecentPopupIndex);
  SaveRecentPDFs;
  RefreshRecentPDFList;
end;

procedure TPDFTabsForm.RecentPDFShowFolder(Sender: TObject);
var
  S: string;
begin
  if (FRecentPopupIndex < 0) or (FRecentPopupIndex >= FRecentPDFs.Count) then Exit;
  S := FRecentPDFs[FRecentPopupIndex];
  if DirectoryExists(ExtractFilePath(S)) then
    ShellExecute(Handle, 'open', 'explorer.exe',
      PChar('/select,"' + S + '"'), nil, SW_SHOWNORMAL)
  else
    PDFModernMessageDlg(Tr('Der Ordner ist nicht mehr vorhanden:') + sLineBreak +
      ExtractFilePath(S), mtInformation, [mbOK], 0);
end;

procedure TPDFTabsForm.RecentPDFClear(Sender: TObject);
begin
  if FRecentPDFs.Count = 0 then Exit;
  if PDFModernMessageDlg(Tr('Möchten Sie den Verlauf der zuletzt geöffneten Dateien löschen?'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FRecentPDFs.Clear;
  SaveRecentPDFs;
  CleanupRecentThumbnails(True);
  RefreshRecentPDFList;
end;

procedure TPDFTabsForm.WelcomeResize(Sender: TObject);
var
  C, Y, LogoSize, Gap, Available, ListTop, Dpi: Integer;
  ButtonWidth, TextWidth: Integer;
  MeasureBitmap: TBitmap;
  ColCount, CardWidth, CardHeight, CardGap, ListWidth, I, J: Integer;
  Card: TPanel;
  Child: TControl;
begin
  if FWelcomePanel = nil then Exit;
  Dpi := CurrentPPI;
  C := FWelcomePanel.ClientWidth div 2;
  Gap := MulDiv(6, Dpi, 96);
  LogoSize := MulDiv(88, Dpi, 96);
  LogoSize := Min(LogoSize, Max(0, FWelcomePanel.ClientWidth - MulDiv(40,Dpi,96)));
  if not FWelcomeImage.Visible then LogoSize := 0;
  Y := MulDiv(8, Dpi, 96);
  FWelcomeImage.SetBounds(C - LogoSize div 2, Y, LogoSize, LogoSize);
  FWelcomeTitle.Left := C - FWelcomeTitle.Width div 2;
  FWelcomeTitle.Top := Y + LogoSize + Gap;
  FWelcomeHint.Left := C - FWelcomeHint.Width div 2;
  FWelcomeHint.Top := FWelcomeTitle.Top + FWelcomeTitle.Height + Gap;
  // Bei 4K/DPI-Skalierung muessen die nativen Button-Breiten zum
  // tatsaechlich gerenderten Text passen (nicht nur 260 Designpixel).
  // TPanel besitzt keine Canvas-Eigenschaft. Mit einem kleinen
  // Speicherbitmap messen wir die tatsaechlichen Textbreiten.
  MeasureBitmap := TBitmap.Create;
  try
    MeasureBitmap.SetSize(1, 1);
    MeasureBitmap.Canvas.Font.Assign(FWelcomeWorkspaceButton.Font);
    TextWidth := MeasureBitmap.Canvas.TextWidth(FWelcomeWorkspaceButton.Caption);
    ButtonWidth := Max(MulDiv(260, Dpi, 96),
      TextWidth + MulDiv(44, Dpi, 96));
    MeasureBitmap.Canvas.Font.Assign(FWelcomeOpenButton.Font);
    ButtonWidth := Max(ButtonWidth,
      MeasureBitmap.Canvas.TextWidth(FWelcomeOpenButton.Caption) + MulDiv(44, Dpi, 96));
  finally
    MeasureBitmap.Free;
  end;
  ButtonWidth := Min(ButtonWidth, Max(MulDiv(140, Dpi, 96),
    FWelcomePanel.ClientWidth - MulDiv(24, Dpi, 96)));
  FWelcomeOpenButton.Width := ButtonWidth;
  FWelcomeWorkspaceButton.Width := ButtonWidth;
  FWelcomeOpenButton.Left := C - FWelcomeOpenButton.Width div 2;
  FWelcomeOpenButton.Top := FWelcomeHint.Top + FWelcomeHint.Height + Gap;
  FWelcomeWorkspaceButton.Left := C - FWelcomeWorkspaceButton.Width div 2;
  FWelcomeWorkspaceButton.Top := FWelcomeOpenButton.Top + FWelcomeOpenButton.Height + Gap;
  // Etwas mehr Abstand zwischen den Oeffnen-Schaltflaechen und dem Verlauf.
  ListTop := FWelcomeWorkspaceButton.Top + FWelcomeWorkspaceButton.Height + MulDiv(28,Dpi,96);
  // Breite Startseite: drei Spalten, mittlere: zwei, schmale: eine.
  ListWidth := Max(0, FWelcomePanel.ClientWidth - MulDiv(40,Dpi,96));
  CardGap := MulDiv(6,Dpi,96);
  CardHeight := MulDiv(110,Dpi,96);
  ColCount := 1;
  if ListWidth >= MulDiv(1050,Dpi,96) then ColCount := 3
  else if ListWidth >= MulDiv(650,Dpi,96) then ColCount := 2;
  CardWidth := Max(100, (ListWidth - (ColCount - 1) * CardGap) div ColCount);
  Available := ((FRecentPDFs.Count + ColCount - 1) div ColCount) *
    (CardHeight + CardGap) + MulDiv(6,Dpi,96);
  FRecentTitle.SetBounds(MulDiv(20,Dpi,96), ListTop,
    Max(0, FWelcomePanel.ClientWidth - MulDiv(190,Dpi,96)), MulDiv(23,Dpi,96));
  FRecentClearButton.SetBounds(Max(0, FWelcomePanel.ClientWidth - MulDiv(155,Dpi,96)),
    ListTop, MulDiv(135,Dpi,96), MulDiv(25,Dpi,96));
  FRecentScroll.SetBounds(MulDiv(20,Dpi,96), ListTop + MulDiv(29,Dpi,96),
    Max(0,FWelcomePanel.ClientWidth - MulDiv(40,Dpi,96)),
    Max(0,Available));
  // Vorhandene Karten beim Vergrößern/Verkleinern neu anordnen.
  // Kein Neuladen der PDF-Thumbnails bei jedem Resize.
  for I := 0 to FRecentScroll.ControlCount - 1 do
    if FRecentScroll.Controls[I] is TPanel then
    begin
      Card := TPanel(FRecentScroll.Controls[I]);
      Card.Anchors := [akLeft, akTop];
      Card.SetBounds((I mod ColCount) * (CardWidth + CardGap),
        (I div ColCount) * (CardHeight + CardGap), CardWidth, CardHeight);
      for J := 0 to Card.ControlCount - 1 do
      begin
        Child := Card.Controls[J];
        if Child is TLabel then
        begin
          Child.Anchors := [akLeft, akTop];
          // The path and page count use the same font size, but need
          // separate rows. Do not infer their positions from Font.Size.
          if Child.Name = 'RecentCountLabel' then
            Child.SetBounds(MulDiv(92,Dpi,96), MulDiv(85,Dpi,96),
              Max(MulDiv(30,Dpi,96), CardWidth - MulDiv(100,Dpi,96)),
              MulDiv(18,Dpi,96))
          else if Child.Name = 'RecentPathLabel' then
            Child.SetBounds(MulDiv(92,Dpi,96), MulDiv(62,Dpi,96),
              Max(MulDiv(30,Dpi,96), CardWidth - MulDiv(100,Dpi,96)),
              MulDiv(18,Dpi,96))
          else
            Child.SetBounds(MulDiv(92,Dpi,96), MulDiv(25,Dpi,96),
              Max(MulDiv(30,Dpi,96), CardWidth - MulDiv(100,Dpi,96)),
              MulDiv(22,Dpi,96));
        end;
      end;
    end;
  FWelcomePanel.VertScrollBar.Range := ListTop + MulDiv(29,Dpi,96) + Available + MulDiv(16,Dpi,96);
end;

procedure TPDFTabsForm.UpdateWelcomeView;
var
  Empty: Boolean;
begin
  if (FTabs = nil) or (FWelcomePanel = nil) then Exit;
  Empty := FTabs.PageCount = 0;
  FWelcomePanel.Visible := Empty;
  FTabs.Visible := not Empty;
  if FTabSearchButton <> nil then FTabSearchButton.Enabled := not Empty;
  if Empty then
  begin
    FWelcomePanel.BringToFront;
    WelcomeResize(nil);
  end;
end;

procedure TPDFTabsForm.WMDropFiles(var Msg: TWMDropFiles);
var
  I, Count, Len: UINT;
  FileName: string;
  PDF: TPDFBrowserForm;
begin
  Count := DragQueryFile(Msg.Drop, $FFFFFFFF, nil, 0);
  try
    for I := 0 to Count - 1 do
    begin
      Len := DragQueryFile(Msg.Drop, I, nil, 0);
      SetLength(FileName, Len + 1);
      if Len > 0 then
        DragQueryFile(Msg.Drop, I, PChar(FileName), Len + 1);
      SetLength(FileName, Len);
      if (SameText(ExtractFileExt(FileName), '.pdf') or
          SameText(ExtractFileExt(FileName), '.jpg') or
          SameText(ExtractFileExt(FileName), '.jpeg') or
          SameText(ExtractFileExt(FileName), '.png') or
          SameText(ExtractFileExt(FileName), '.bmp') or
          SameText(ExtractFileExt(FileName), '.tif') or
          SameText(ExtractFileExt(FileName), '.tiff')) and FileExists(FileName) then
      begin
        PDF := TPDFBrowserForm.Create(nil);
      PDF.OnGlobalSearch := GlobalSearchClick;
        try
          PDF.PDFFileName := FileName;
          PDF.StandalonePDFMode := False;
          AddPDF(PDF);
        except
          PDF.Free;
          raise;
        end;
      end;
    end;
  finally
    DragFinish(Msg.Drop);
  end;
end;

procedure TPDFTabsForm.UpdateTabCount;
begin
  EditMenuClick(nil);
  UpdateWelcomeView;
  UpdateEmptyTabStrip;
  if FTabCountBadge <> nil then
    FTabCountBadge.Invalidate;
end;

procedure TPDFTabsForm.EditMenuClick(Sender: TObject);
var
  HasPDF: Boolean;
begin
  HasPDF := (FTabs <> nil) and (FTabs.PageCount > 0);
  if FLocalSearchMenuItem <> nil then FLocalSearchMenuItem.Enabled := HasPDF;
  if FGlobalSearchMenuItem <> nil then FGlobalSearchMenuItem.Enabled := HasPDF;
  if FMergePDFMenuItem <> nil then
    FMergePDFMenuItem.Enabled := HasPDF and (FTabs.PageCount > 1) and
      (FSplitHost = nil);
end;

procedure TPDFTabsForm.MergePDFClick(Sender: TObject);
var
  Files: TStringList;
begin
  Files := TStringList.Create;
  try
    GetOpenPDFFileNames(Files);
    MergeOpenPDFTabs(Self, Files);
  finally
    Files.Free;
  end;
end;

procedure TPDFTabsForm.LocalSearchMenuClick(Sender: TObject);
var
  Tab: TTabSheet;
  I: Integer;
begin
  if (FTabs = nil) or (FTabs.PageCount = 0) then Exit;
  Tab := FTabs.ActivePage;
  if (FSplitHost <> nil) and
     (FSplitActiveRight or
      ((Sender is TControl) and (TControl(Sender).Tag = 1))) then
    Tab := FSplitRightTab;
  if Tab = nil then Exit;
  if PDFInTab(Tab) <> nil then
    PDFInTab(Tab).ShowPDFSearch;
end;

procedure TPDFTabsForm.GlobalSearchClick(Sender: TObject);
begin
  if (FTabs = nil) or (FTabs.PageCount = 0) then Exit;
  if FGlobalSearchForm = nil then
    FGlobalSearchForm := TPDFGlobalSearchForm.CreateForTabs(Self, FTabs);
  FGlobalSearchForm.ShowSearch;
end;

procedure TPDFTabsForm.TabSearchClick(Sender: TObject);
var
  P: TPoint;
begin
  if FTabSearchForm.Visible then
  begin
    FTabSearchForm.Hide;
    Exit;
  end;
  FTabSearchEdit.Clear;
  TabSearchChanged(nil);
  P := FTabSearchButton.ClientToScreen(Point(FTabSearchButton.Width, FTabSearchButton.Height));
  FTabSearchForm.Left := EnsureRange(P.X - FTabSearchForm.Width,
    Screen.MonitorFromPoint(P).WorkareaRect.Left,
    Max(Screen.MonitorFromPoint(P).WorkareaRect.Left,
      Screen.MonitorFromPoint(P).WorkareaRect.Right - FTabSearchForm.Width));
  FTabSearchForm.Top := EnsureRange(P.Y,
    Screen.MonitorFromPoint(P).WorkareaRect.Top,
    Max(Screen.MonitorFromPoint(P).WorkareaRect.Top,
      Screen.MonitorFromPoint(P).WorkareaRect.Bottom - FTabSearchForm.Height));
  FTabSearchForm.Show;
  FTabSearchEdit.SetFocus;
end;

procedure TPDFTabsForm.TabSearchChanged(Sender: TObject);
var
  I: Integer;
  Tab: TTabSheet;
  Filter: string;
begin
  Filter := Trim(FTabSearchEdit.Text);
  FTabSearchList.Items.BeginUpdate;
  try
    FTabSearchList.Clear;
    for I := 0 to FTabs.PageCount - 1 do
    begin
      Tab := FTabs.Pages[I];
      if (Filter = '') or (Pos(UpperCase(Filter), UpperCase(Tab.Caption)) > 0) then
        FTabSearchList.Items.AddObject(Tab.Caption, Tab);
    end;
    // Den aktiven PDF-Tab in der Suchliste vorauswaehlen.
    // Bei einem Filter ohne Treffer fuer den aktiven Tab den ersten Treffer nehmen.
    FTabSearchList.ItemIndex := -1;
    for I := 0 to FTabSearchList.Count - 1 do
      if FTabSearchList.Items.Objects[I] = FTabs.ActivePage then
      begin
        FTabSearchList.ItemIndex := I;
        Break;
      end;
    if (FTabSearchList.ItemIndex < 0) and (FTabSearchList.Count > 0) then
      FTabSearchList.ItemIndex := 0;
  finally
    FTabSearchList.Items.EndUpdate;
  end;
end;

procedure TPDFTabsForm.TabSearchListMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  Index: Integer;
  Tab: TTabSheet;
  FullName: string;
begin
  Index := FTabSearchList.ItemAtPos(Point(X, Y), True);
  if Index >= 0 then
  begin
    Tab := TTabSheet(FTabSearchList.Items.Objects[Index]);
    FullName := '';
    if Tab <> nil then
      FullName := ExtractFileName(Tab.Hint);
    if FullName = '' then
      FullName := FTabSearchList.Items[Index];
  end
  else
    FullName := '';

  if FTabSearchList.Hint <> FullName then
  begin
    FTabSearchList.Hint := FullName;
    // Bereits angezeigte Hinweise beim Wechsel auf einen anderen Eintrag aktualisieren.
    Application.CancelHint;
  end;
end;

procedure TPDFTabsForm.TabSearchChoose(Sender: TObject);
var
  Tab, PreviousTab: TTabSheet;
  J: Integer;
  PreviousPDF: TPDFBrowserForm;
begin
  if FTabSearchList.ItemIndex < 0 then Exit;
  Tab := TTabSheet(FTabSearchList.Items.Objects[FTabSearchList.ItemIndex]);
  FTabSearchForm.Hide;
  if (Tab <> nil) and (Tab.PageControl = FTabs) then
  begin
    PreviousTab := FTabs.ActivePage;
    // Bei einem Wechsel ueber die Lupensuche die Anlagenliste der
    // bisher aktiven PDF sofort ausblenden (vor dem Registerwechsel).
    if (PreviousTab <> nil) and (PreviousTab <> Tab) then
      for J := 0 to PreviousTab.ControlCount - 1 do
        if PreviousTab.Controls[J] is TPDFBrowserForm then
        begin
          PreviousPDF := TPDFBrowserForm(PreviousTab.Controls[J]);
          if IsWindow(PreviousPDF.AttachmentWindowHandle) then
            ShowWindow(PreviousPDF.AttachmentWindowHandle, SW_HIDE);
          Break;
        end;
    FTabs.ActivePage := Tab;
    // Registersuche: Anzeige explizit synchronisieren, auch wenn der
    // Reiter bereits aktiv ist und deshalb kein OnChange ausgeloest wird.
    // Keinen PDF-Ladevorgang synchron starten: das kann beim
    // anschliessenden Schliessen in die Freigabe hineinlaufen.
    if (Tab.PageControl = FTabs) and (PDFInTab(Tab) <> nil) then
      PDFInTab(Tab).Show;
    RefreshAttachmentPositions;
    // Laden erst nach der aktuellen UI-Nachricht; der Handler prueft
    // den dann tatsaechlich aktiven Tab und den Zerstoerungszustand.
    PostMessage(Handle, WM_APP + 193, 0, 0);
    FTabs.SetFocus;
  end;
end;

procedure TPDFTabsForm.TabSearchKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE:
      begin
        FTabSearchForm.Hide;
        Key := 0;
      end;
    VK_RETURN:
      begin
        TabSearchChoose(Sender);
        Key := 0;
      end;
    VK_DOWN:
      if Sender = FTabSearchEdit then
      begin
        if FTabSearchList.Count > 0 then FTabSearchList.SetFocus;
        Key := 0;
      end;
  end;
end;

procedure TPDFTabsForm.TabSearchDeactivate(Sender: TObject);
var
  CursorPos: TPoint;
  ButtonRect: TRect;
begin
  if (FTabSearchForm = nil) or not FTabSearchForm.Visible then
    Exit;

  // Beim Klick auf die Lupe nicht vorzeitig schliessen: Der folgende
  // OnClick-Handler soll die noch sichtbare Suche selbst ausblenden.
  GetCursorPos(CursorPos);
  ButtonRect.TopLeft := FTabSearchButton.ClientToScreen(Point(0, 0));
  ButtonRect.BottomRight := FTabSearchButton.ClientToScreen(
    Point(FTabSearchButton.Width, FTabSearchButton.Height));
  if PtInRect(ButtonRect, CursorPos) then
    Exit;

  FTabSearchForm.Hide;
end;

procedure TPDFTabsForm.WMViewerActivate(var Msg: TWMActivate);
begin
  inherited;
  if Msg.Active <> WA_INACTIVE then
  begin
    if (FTabSearchButton <> nil) and not FLocalTabSearchHotkeyRegistered then
      FLocalTabSearchHotkeyRegistered := RegisterHotKey(Handle,
        LOCAL_TAB_SEARCH_HOTKEY_ID, MOD_CONTROL or MOD_SHIFT or MOD_NOREPEAT,
        Ord('A'));
    if not FLocalTextSearchHotkeyRegistered then
      FLocalTextSearchHotkeyRegistered := RegisterHotKey(Handle,
        LOCAL_TEXT_SEARCH_HOTKEY_ID, MOD_CONTROL or MOD_NOREPEAT, Ord('F'));
  end
  else
  begin
    // Strg+Umsch+A bleibt registriert, wenn das Suchfenster den Fokus
    // bekommt. Sonst geht der zweite Tastendruck zum Schliessen verloren.
    if FLocalTextSearchHotkeyRegistered then
    begin
      UnregisterHotKey(Handle, LOCAL_TEXT_SEARCH_HOTKEY_ID);
      FLocalTextSearchHotkeyRegistered := False;
    end;
  end;
end;

procedure TPDFTabsForm.WMViewerHotKey(var Msg: TMessage);
var
  Tab: TTabSheet;
  I: Integer;
begin
  if (Msg.WParam = LOCAL_TAB_SEARCH_HOTKEY_ID) or
     (Msg.WParam = LOCAL_TEXT_SEARCH_HOTKEY_ID) then
  begin
    if Visible and
       ((GetForegroundWindow = Handle) or
        ((FTabSearchForm <> nil) and
         (GetForegroundWindow = FTabSearchForm.Handle))) then
    begin
      if Msg.WParam = LOCAL_TAB_SEARCH_HOTKEY_ID then
        TabSearchClick(FTabSearchButton)
      else
      begin
        Tab := FTabs.ActivePage;
        if Tab <> nil then
          for I := 0 to Tab.ControlCount - 1 do
            if Tab.Controls[I] is TPDFBrowserForm then
            begin
              TPDFBrowserForm(Tab.Controls[I]).ShowPDFSearch;
              Break;
            end;
      end;
    end;
    Msg.Result := 0;
  end
  else
    inherited;
end;

destructor TPDFTabsForm.Destroy;
begin
  if Assigned(FUpdateStartupTimer) then FUpdateStartupTimer.Enabled := False;
  SetTrayIcon(False);
  if FLocalTextSearchHotkeyRegistered then
  begin
    UnregisterHotKey(Handle, LOCAL_TEXT_SEARCH_HOTKEY_ID);
    FLocalTextSearchHotkeyRegistered := False;
  end;
  if FLocalTabSearchHotkeyRegistered then
  begin
    UnregisterHotKey(Handle, LOCAL_TAB_SEARCH_HOTKEY_ID);
    FLocalTabSearchHotkeyRegistered := False;
  end;
  FExplorerBatchTimer.Enabled := False;
  FActivationTimer.Enabled := False;
  // Vor dem Zerstoeren der Tabs alle eingebetteten PDF-Formulare
  // aus den Split-Panels in ihre urspruenglichen Tabs zurueckhaengen.
  // Sonst wird ein PDF-Formular beim Zerstoeren seines Parent-Panels
  // freigegeben und danach erneut ueber die Tab-Verwaltung angesprochen.
  if FSplitHost <> nil then
    StopSplit;
  // Vor dem Freigeben eingebetteter Formulare den Vollbildmodus beenden.
  if FFullScreen then ToggleFullScreen;
  RestoreInitialWindow;
  FPendingExplorerFiles.Free;
  FPDFDisposalTimer.Enabled := False;
  ClearAllPDFTabs;
  while FPendingPDFDisposals.Count > 0 do
  begin
    if IsFreePDFTempAttachment(TPDFBrowserForm(FPendingPDFDisposals[0]).PDFFileName) then
    begin
      // Dateiname vor dem Zerstoeren sichern.
      PDFDisposalTimerTick(Self);
    end
    else
    begin
      TObject(FPendingPDFDisposals[0]).Free;
      FPendingPDFDisposals.Delete(0);
    end;
  end;
  FPendingPDFDisposals.Free;
  if FTabs <> nil then
    FTabs.WindowProc := FOriginalTabsWindowProc;
  FSessionPDFs.Free;
  FClosedPDFs.Free;
  FRecentPDFs.Free;
  if PDFTabsWindow = Self then
    PDFTabsWindow := nil;
  inherited Destroy;
end;

procedure TPDFTabsForm.BringViewerToForeground;
begin
  // Explorer-Aufruf: Fenster sichtbar machen, ohne dauerhaft TopMost zu sein.
  if FInitialWindowOffscreen then
    RestoreInitialWindow;
  if IsIconic(Handle) then
    ShowWindow(Handle, SW_RESTORE)
  else if not Visible then
    Show;
  // Windows kann SetForegroundWindow bei fremden Prozessen verweigern.
  // Kurzes Anheben in der Z-Reihenfolge stellt die Sichtbarkeit sicher.
  SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  BringToFront;
  SetForegroundWindow(Handle);
end;

procedure TPDFTabsForm.ShowCreatedPDFInForeground;
begin
  // Nach der PDF-Erstellung das Registerfenster auch dann sichtbar machen,
  // wenn FreePDF64 inzwischen wieder den Vordergrund erhalten hat.
  BringViewerToForeground;
end;

procedure TPDFTabsForm.RestoreInitialWindow;
begin
  if not FInitialWindowOffscreen then Exit;
  FInitialWindowOffscreen := False;
  FRestoringWindowSettings := True;
  try
    WindowState := wsNormal;
    SetBounds(FInitialWindowBounds.Left, FInitialWindowBounds.Top,
      FInitialWindowBounds.Right - FInitialWindowBounds.Left,
      FInitialWindowBounds.Bottom - FInitialWindowBounds.Top);
    if FInitialWindowMaximized then WindowState := wsMaximized;
  finally
    FRestoringWindowSettings := False;
  end;
  ShowWindow(Handle, SW_SHOWNORMAL);
  if FInitialWindowMaximized then ShowWindow(Handle, SW_SHOWMAXIMIZED);
  SetForegroundWindow(Handle);
end;

procedure TPDFTabsForm.ActivationTimerTick(Sender: TObject);
var
  FirstPDF: TPDFBrowserForm;
  FirstTab: TTabSheet;
  I: Integer;
begin
  if (FTabs = nil) or (FTabs.PageCount = 0) then
  begin
    FActivationTimer.Enabled := False;
    FDeferredActivePDF := nil;
    RestoreInitialWindow;
    Exit;
  end;
  FirstPDF := nil;
  FirstTab := FTabs.Pages[0];
  for I := 0 to FirstTab.ControlCount - 1 do
    if FirstTab.Controls[I] is TPDFBrowserForm then
    begin
      FirstPDF := TPDFBrowserForm(FirstTab.Controls[I]);
      Break;
    end;
  Inc(FActivationChecks);
  // Die erste PDF muss mindestens ihren ersten PDFium-Navigationsaufruf
  // erhalten haben, bevor wir zu einer anderen Registerkarte wechseln.
  if (FirstPDF <> nil) and (not FirstPDF.PDFNavigationSucceeded) and
     (FActivationChecks < 80) then
  begin
    FirstPDF.RequestPDFLoad;
    Exit;
  end;
  FActivationTimer.Enabled := False;
  // Die Startinitialisierung gilt nur fuer das erste PDF dieses Fensters.
  FFirstPDFInitialized := True;
  if (FDeferredActivePDF <> nil) and
     (FDeferredActivePDF.Parent is TTabSheet) and
     (TTabSheet(FDeferredActivePDF.Parent).PageControl = FTabs) then
  begin
    FAddingPDF := True;
    try
      FTabs.ActivePage := TTabSheet(FDeferredActivePDF.Parent);
    finally
      FAddingPDF := False;
    end;
    PostMessage(Handle, WM_APP + 193, 0, 0);
  end;
  FDeferredActivePDF := nil;
  FTabs.Invalidate;
  RestoreInitialWindow;
end;

procedure TPDFTabsForm.ClearAllPDFTabs;
var
  Tab: TTabSheet;
  I: Integer;
  PDF: TPDFBrowserForm;
  TempPDFFile: string;
begin
  if FTabs = nil then Exit;

  // Vor dem Schließen müssen alle Split-Verweise auf die alten
  // PDF-Formulare aufgelöst werden.
  if FSplitHost <> nil then
    StopSplit;
  if FSplitFocusTimer <> nil then
    FSplitFocusTimer.Enabled := False;
  FActivationTimer.Enabled := False;
  // Bereits vorgemerkte Freigaben nicht während des Registerabbaus ausführen.
  FPDFDisposalTimer.Enabled := False;
  FDeferredActivePDF := nil;
  FSplitAnchorTab := nil;
  FSplitSelectedTab := nil;
  FSplitLastSelectedTab := nil;
  FSplitShiftTab := -1;

  // Das Overlay ist Eigentum des Hauptformulars und darf beim
  // Freigeben der Registerkarten nicht mit zerstört werden.
  if FLeftPDFOverlay <> nil then
  begin
    FLeftPDFOverlay.Visible := False;
    FLeftPDFOverlay.Parent := FTabs;
  end;

  FAddingPDF := True;
  try
    while FTabs.PageCount > 0 do
    begin
      Tab := FTabs.Pages[FTabs.PageCount - 1];
      for I := Tab.ControlCount - 1 downto 0 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(Tab.Controls[I]);
          TempPDFFile := PDF.PDFFileName;
          PDF.Hide;
          // Das PDF-Formular vor Tab.Free vom Tab trennen.
          // Die Freigabe erfolgt wie bei CloseActive verzögert auf dem UI-Thread.
          // Damit werden beim gleichzeitigen Schließen mehrerer PDFs keine
          // noch laufenden Ereignisse innerhalb des Tab-Abbaus zerstört.
          PDF.Parent := Self;
          FPendingPDFDisposals.Add(PDF);
        end;
      Tab.Free;
    end;
  finally
    FAddingPDF := False;
  end;
  // Erst nach dem vollständigen Entfernen aller Registerkarten freigeben.
  // Die bereits vorhandene Freigaberoutine übernimmt auch temporäre Anlagen.
  if FPendingPDFDisposals.Count > 0 then
    FPDFDisposalTimer.Enabled := True;
  UpdateTabCount;
end;

procedure TPDFTabsForm.GetOpenPDFFileNames(AFiles: TStrings);
var
  I: Integer;
  FileName: string;
begin
  if AFiles = nil then Exit;
  for I := 0 to FTabs.PageCount - 1 do
  begin
    FileName := FTabs.Pages[I].Hint;
    if SameText(ExtractFileExt(FileName), '.pdf') and FileExists(FileName) then
      AFiles.Add(FileName);
  end;
end;

procedure TPDFTabsForm.OpenMainProgramClick(Sender: TObject);
var
  MainExe: string;
  WorkDir: string;
  ExecResult: HINST;
begin
  // Nur die Hauptprogramm-EXE aus demselben Verzeichnis starten.
  MainExe := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'FreePDF64.exe';
  if not FileExists(MainExe) then
  begin
    PDFModernMessageDlg(Tr('FreePDF64.exe wurde im Viewer-Verzeichnis nicht gefunden.'),
      mtError, [mbOK], 0);
    Exit;
  end;
  if ActivateRunningMainProgram then Exit;
  WorkDir := ExtractFilePath(MainExe);
  ExecResult := ShellExecute(Handle, 'open', PChar(MainExe), nil,
    PChar(WorkDir), SW_SHOWNORMAL);
  if NativeInt(ExecResult) <= 32 then
    PDFModernMessageDlg(Tr('Das FreePDF64-Hauptprogramm konnte nicht gestartet werden.'),
      mtError, [mbOK], 0);
end;

function ConfirmPDFChangesModern(AOwner: TCustomForm; ACount: Integer; const AFiles: string): Integer;
var
  D: TForm;
  Head, Description: TLabel;
  FileList: TMemo;
  Footer: TPanel;
  B: TButton;
  P, Margin, ButtonW, ButtonH, Gap: Integer;

  procedure AddButton(const AText: string; AResult, ARight: Integer);
  begin
    B := TButton.Create(D);
    B.Parent := Footer;
    B.ParentFont := False;
    B.Font.Name := 'Segoe UI';
    B.Font.Size := 10;
    B.Caption := AText;
    B.ModalResult := AResult;
    B.SetBounds(ARight - ButtonW, (Footer.Height - ButtonH) div 2,
      ButtonW, ButtonH);
    B.Anchors := [akRight, akBottom];
    if AResult = mrYes then D.ActiveControl := B;
  end;
begin
  D := TForm.CreateNew(AOwner);
  try
    D.BorderStyle := bsDialog;
    D.Position := poOwnerFormCenter;
    D.Caption := Tr('Ungespeicherte PDF-Änderungen');
    D.Scaled := False;
    P := 96;
    if (AOwner <> nil) and (AOwner.CurrentPPI > 0) then
      P := AOwner.CurrentPPI
    else if Screen.PixelsPerInch > 0 then
      P := Screen.PixelsPerInch;
    if P < 96 then P := 96;
    D.PixelsPerInch := P;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.Color := clWhite;
    Margin := MulDiv(24, P, 96);
    Gap := MulDiv(12, P, 96);
    ButtonW := MulDiv(180, P, 96);
    ButtonH := MulDiv(40, P, 96);
    D.ClientWidth := MulDiv(720, P, 96);
    D.ClientHeight := MulDiv(405, P, 96);
    Head := TLabel.Create(D);
    Head.Parent := D;
    Head.ParentFont := False;
    Head.Font.Name := 'Segoe UI Semibold';
    Head.Font.Size := 13;
    Head.AutoSize := False;
    Head.SetBounds(Margin, Margin, D.ClientWidth - 2 * Margin,
      MulDiv(38, P, 96));
    Head.Font.Name := 'Segoe UI Semibold';
    Head.Font.Size := 13;
    Head.Font.Color := $00C47A20;
    Head.Caption := Tr('Änderungen vor dem Schließen speichern?');
    Description := TLabel.Create(D);
    Description.Parent := D;
    Description.ParentFont := False;
    Description.Font.Name := 'Segoe UI';
    Description.Font.Size := 10;
    Description.AutoSize := False;
    Description.WordWrap := True;
    Description.SetBounds(Margin, Head.Top + Head.Height + Gap,
      D.ClientWidth - 2 * Margin, MulDiv(72, P, 96));
    if SameText(PDFLanguage, 'en') then
      Description.Caption := Format(
        '%d PDF file(s) contain unsaved changes.' + sLineBreak +
        'Save the changes or close without saving:', [ACount])
    else
      Description.Caption := Format(
        '%d PDF-Datei(en) enthalten ungespeicherte Änderungen.' + sLineBreak +
        'Änderungen speichern oder ohne Speichern schließen:', [ACount]);
    FileList := TMemo.Create(D);
    FileList.Parent := D;
    FileList.ParentFont := False;
    FileList.Font.Name := 'Segoe UI';
    FileList.Font.Size := 10;
    FileList.SetBounds(Margin, Description.Top + Description.Height + Gap,
      D.ClientWidth - 2 * Margin, MulDiv(165, P, 96));
    FileList.ReadOnly := True;
    FileList.ScrollBars := ssVertical;
    FileList.TabStop := False;
    FileList.WordWrap := False;
    FileList.Lines.Text := AFiles;
    Footer := TPanel.Create(D);
    Footer.Parent := D;
    Footer.Align := alBottom;
    Footer.Height := MulDiv(70, P, 96);
    Footer.BevelOuter := bvNone;
    Footer.ParentBackground := False;
    Footer.Color := $00F8F1E8;
    AddButton(Tr('Abbrechen'), mrCancel, D.ClientWidth - Margin);
    AddButton(Tr('Nicht speichern'), mrNo,
      D.ClientWidth - Margin - ButtonW - Gap);
    AddButton(Tr('Alle speichern'), mrYes,
      D.ClientWidth - Margin - 2 * (ButtonW + Gap));
    D.ActiveControl := nil;
    Result := D.ShowModal;
  finally
    D.Free;
  end;
end;

function TPDFTabsForm.ConfirmCloseUnsavedPDFs(AOnlyActive: Boolean): Boolean;
var
  I, J, Count, Choice: Integer;
  FileNames: string;
  Tab: TTabSheet;
  PDF: TPDFBrowserForm;
begin
  Result := True;
  if FTabs = nil then Exit;
  Count := 0;
  FileNames := '';
  for I := 0 to FTabs.PageCount - 1 do
  begin
    Tab := FTabs.Pages[I];
    if AOnlyActive and (Tab <> FCloseTargetTab) and
       ((FCloseTargetTab <> nil) or (Tab <> FTabs.ActivePage)) then Continue;
    for J := 0 to Tab.ControlCount - 1 do
      if (Tab.Controls[J] is TPDFBrowserForm) and
        TPDFBrowserForm(Tab.Controls[J]).HasUnsavedPDFChanges then
      begin
        Inc(Count);
        FileNames := FileNames + ExtractFileName(
          TPDFBrowserForm(Tab.Controls[J]).PDFFileName) + sLineBreak;
      end;
  end;
  if Count = 0 then Exit;
  Choice := ConfirmPDFChangesModern(Self, Count, FileNames);
  if Choice = mrCancel then Exit(False);
  if Choice = mrNo then Exit(True);
  if Choice <> mrYes then Exit(False);
  for I := 0 to FTabs.PageCount - 1 do
  begin
    Tab := FTabs.Pages[I];
    if AOnlyActive and (Tab <> FCloseTargetTab) and
       ((FCloseTargetTab <> nil) or (Tab <> FTabs.ActivePage)) then Continue;
    for J := 0 to Tab.ControlCount - 1 do
      if Tab.Controls[J] is TPDFBrowserForm then
      begin
        PDF := TPDFBrowserForm(Tab.Controls[J]);
        if PDF.HasUnsavedPDFChanges and not PDF.SaveUnsavedPDFChanges then
          Exit(False);
      end;
  end;
end;

procedure TPDFTabsForm.TabsFormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  if FTrayEnabled and not FExitFromTray then
  begin
    SetTrayIcon(True);
    if FTrayVisible then
    begin
      SaveWindowSettings;
      HideAllAttachmentWindows;
      if FTabSearchForm <> nil then FTabSearchForm.Hide;
      // Sichtbares Hauptfenster und Taskleisteneintrag ausblenden.
      // Die Form bleibt bestehen und wird ueber das Tray-Icon restauriert.
      Hide;
      ShowWindow(Handle, SW_HIDE);
      Action := caNone;
      Exit;
    end;
  end;
  if not ConfirmCloseUnsavedPDFs(False) then
  begin
    Action := caNone;
    Exit;
  end;
  if FRestartRequested then
  begin
    // Erst NACH erfolgreicher Speicherabfrage die Zielsprache aktivieren.
    // Bei einem fehlgeschlagenen Neustart wird sie zurueckgesetzt.
    if FPendingRestartLanguage <> '' then
      SetPDFLanguage(FPendingRestartLanguage);
    // Der neue Prozess wartet auf die Freigabe des Single-Instance-Mutex.
    // Dadurch geht der Neustart auch bei langsamer PDF-Freigabe nicht verloren.
    if ShellExecute(Handle, 'open', PChar(ParamStr(0)), '--restart',
      PChar(ExtractFilePath(ParamStr(0))), SW_SHOWNORMAL) <= 32 then
    begin
      if FPendingRestartLanguage <> '' then
      begin
        if FPendingRestartLanguage = 'de' then
          SetPDFLanguage('en')
        else
          SetPDFLanguage('de');
      end;
      Action := caNone;
      PDFModernMessageDlg('Der Neustart konnte nicht gestartet werden. / Restart failed.',
        mtError, [mbOK], 0);
      Exit;
    end;
  end;
  StopSplit;
  // Fenster zuerst ausblenden, dann die PDFium-Registerkarten
  // unsichtbar abbauen. Sonst flackert der Viewer bei vielen PDFs.
  SaveWindowSettings;
  HideAllAttachmentWindows;
  // Im Vollbild ist das PDF direkt dem Hauptfenster zugeordnet.
  // Vor ClearAllPDFTabs wieder in seine Registerkarte verschieben.
  if FFullScreen then ToggleFullScreen;
  Action := caHide;
  if FTabSearchForm <> nil then
    FTabSearchForm.Hide;
  Hide;
  ClearAllPDFTabs;
  if FExitFromTray or
     (PDFTabsExplorerOnlyProcess and not PDFTabsMainFormWasShown) then
  begin
    SetTrayIcon(False);
    Application.Terminate;
  end;
end;

procedure TPDFTabsForm.WMLoadActivePDF(var Msg: TMessage);
begin
  // Erst nach dem aktuellen Stapel von AddPDF-Aufrufen laden.
  // Dadurch wird nicht fuer jede kurzzeitig aktive Seite ein Browser gestartet.
  if not (csDestroying in ComponentState) then
    LoadSelectedPDF;
end;

function TPDFTabsForm.PDFInTab(ATab: TTabSheet): TPDFBrowserForm;
var I: Integer;
begin
  Result := nil;
  if ATab = nil then Exit;
  // Im Split sind die PDF-Formulare nicht mehr direkte Kinder ihrer Tabs.
  if (FSplitHost <> nil) then
  begin
    if ATab = FSplitLeftTab then
    begin
      for I := 0 to FSplitLeft.ControlCount - 1 do
        if FSplitLeft.Controls[I] is TPDFBrowserForm then
          Exit(TPDFBrowserForm(FSplitLeft.Controls[I]));
    end
    else if ATab = FSplitRightTab then
    begin
      for I := 0 to FSplitRight.ControlCount - 1 do
        if FSplitRight.Controls[I] is TPDFBrowserForm then
          Exit(TPDFBrowserForm(FSplitRight.Controls[I]));
    end;
  end;
  for I := 0 to ATab.ControlCount - 1 do
    if ATab.Controls[I] is TPDFBrowserForm then
    begin
      Result := TPDFBrowserForm(ATab.Controls[I]);
      Exit;
    end;
end;

procedure TPDFTabsForm.SetSplitPDFToolbars(APDF: TPDFBrowserForm;
  AShow: Boolean; var ATopWasVisible, ANavWasVisible: Boolean);
var
  I, J, K: Integer;
  TopBar: TComponent;
  Viewer: TWinControl;
  NavBar: TControl;
  HasPageEditor: Boolean;
begin
  if APDF = nil then Exit;
  // Die Registerkarten und das Hauptmenue bleiben unveraendert.
  // Nur die PDF-eigenen Symbolleisten werden im Split ausgeblendet.
  TopBar := APDF.FindComponent('PDFNavigationToolbar');
  if TopBar is TControl then
  begin
    if not AShow then ATopWasVisible := TControl(TopBar).Visible;
    TControl(TopBar).Visible := AShow and ATopWasVisible;
  end;

  // Die eigentliche PDFium-Leiste ist das obere Panel, das das Seitenfeld
  // (TEdit) enthaelt. Nicht einfach das erste alTop-Panel nehmen: davor kann
  // z.B. die Bearbeitungsleiste liegen. Sonst bleibt die Navigationsleiste
  // mit Seitenzahl, Vor/Zurueck, Zoom und Ansichtsmodus im linken Splitfenster
  // sichtbar, obwohl nur das kleine Split-Overlay stehen bleiben soll.
  for I := 0 to APDF.ControlCount - 1 do
    if Pos('TFreePDF64PDFiumView', APDF.Controls[I].ClassName) > 0 then
    begin
      Viewer := TWinControl(APDF.Controls[I]);
      for J := 0 to Viewer.ControlCount - 1 do
      begin
        NavBar := Viewer.Controls[J];
        if (NavBar is TPanel) and (NavBar.Align = alTop) and
           (NavBar.Height > 0) then
        begin
          HasPageEditor := False;
          for K := 0 to TWinControl(NavBar).ControlCount - 1 do
            if TWinControl(NavBar).Controls[K] is TEdit then
            begin
              HasPageEditor := True;
              Break;
            end;

          if HasPageEditor then
          begin
            if not AShow then ANavWasVisible := NavBar.Visible;
            NavBar.Visible := AShow and ANavWasVisible;
            Break;
          end;
        end;
      end;
      Break;
    end;

  APDF.Realign;
  // Nach dem Rueckwechsel die Toolbar- und Viewer-Geometrie neu berechnen.
  // Die Controls wurden zuvor in einem nur halb so breiten Host angeordnet.
  if AShow then
  begin
    APDF.Perform(WM_SIZE, SIZE_RESTORED,
      MakeLParam(APDF.ClientWidth, APDF.ClientHeight));
    if TopBar is TWinControl then
      TWinControl(TopBar).Perform(WM_SIZE, SIZE_RESTORED,
        MakeLParam(TControl(TopBar).Width, TControl(TopBar).Height));
    APDF.Realign;
    APDF.Invalidate;
  end;
end;

procedure TPDFTabsForm.UpdateSplitBorders;
begin
  if (FSplitLeft = nil) or (FSplitRight = nil) then Exit;
  if FSplitActiveRight then
  begin
    FSplitLeft.Color := RGB(220, 225, 233);
    FSplitRight.Color := RGB(0, 96, 255);
  end
  else
  begin
    FSplitLeft.Color := RGB(0, 96, 255);
    FSplitRight.Color := RGB(220, 225, 233);
  end;
  // Rahmen sichtbar halten, auch nach Reparenting/Align und Zoom.
  FSplitLeft.Invalidate;
  FSplitRight.Invalidate;
end;

procedure TPDFTabsForm.UpdateSplitSyncButtons;
begin
  if FSyncScrollButton <> nil then
  begin
    FSyncScrollButton.Down := FSyncScrollEnabled;
    if FSyncScrollEnabled then FSyncScrollButton.Font.Style := [fsBold]
    else FSyncScrollButton.Font.Style := [];
    if SameText(PDFLanguage, 'en') then
      if FSyncScrollEnabled then FSyncScrollButton.Hint := 'Synchronized scrolling: on (click to turn off)'
      else FSyncScrollButton.Hint := 'Synchronized scrolling: off (click to turn on)'
    else
      if FSyncScrollEnabled then FSyncScrollButton.Hint := 'Synchrones Scrollen: ein (zum Ausschalten klicken)'
      else FSyncScrollButton.Hint := 'Synchrones Scrollen: aus (zum Einschalten klicken)';
  end;
  if FSyncZoomButton <> nil then
  begin
    FSyncZoomButton.Down := FSyncZoomEnabled;
    if FSyncZoomEnabled then FSyncZoomButton.Font.Style := [fsBold]
    else FSyncZoomButton.Font.Style := [];
    if SameText(PDFLanguage, 'en') then
      if FSyncZoomEnabled then FSyncZoomButton.Hint := 'Synchronized zoom: on (click to turn off)'
      else FSyncZoomButton.Hint := 'Synchronized zoom: off (click to turn on)'
    else
      if FSyncZoomEnabled then FSyncZoomButton.Hint := 'Synchroner Zoom: ein (zum Ausschalten klicken)'
      else FSyncZoomButton.Hint := 'Synchroner Zoom: aus (zum Einschalten klicken)';
  end;
end;

procedure TPDFTabsForm.VisualCompareClick(Sender: TObject);
var
  L, R: TPDFBrowserForm;
begin
  if FSplitHost = nil then
  begin
    if SameText(PDFLanguage, 'en') then
      MessageDlg('Open two PDFs in split view first.', mtInformation, [mbOK], 0)
    else
      MessageDlg('Öffnen Sie zuerst zwei PDFs in der Zweifensteransicht.', mtInformation, [mbOK], 0);
    Exit;
  end;
  L := PDFInTab(FSplitLeftTab);
  R := PDFInTab(FSplitRightTab);
  if (L = nil) or (R = nil) or not FileExists(L.PDFFileName) or
     not FileExists(R.PDFFileName) then Exit;
  try
    ShowPDFVisualComparison(Self, L.PDFFileName, R.PDFFileName,
      SameText(PDFLanguage, 'en'));
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TPDFTabsForm.SplitSyncClick(Sender: TObject);
begin
  if Sender = FSyncScrollButton then FSyncScrollEnabled := not FSyncScrollEnabled
  else if Sender = FSyncZoomButton then FSyncZoomEnabled := not FSyncZoomEnabled;
  FSyncSampleValid := False;
  UpdateSplitSyncButtons;
end;

procedure TPDFTabsForm.CheckSplitSynchronization;
var
  L, R: TPDFBrowserForm;
  LX, LY, RX, RY: Integer;
  LZ, RZ: Double;
  LScroll, LZoom, RScroll, RZoom: Boolean;
  SourceIsRight: Boolean;
begin
  if (FSplitHost = nil) or (not FSyncScrollEnabled and not FSyncZoomEnabled) then Exit;
  L := PDFInTab(FSplitLeftTab);
  R := PDFInTab(FSplitRightTab);
  if (L = nil) or (R = nil) or not L.PDFNavigationSucceeded or
     not R.PDFNavigationSucceeded then
  begin
    FSyncSampleValid := False;
    Exit;
  end;

  LX := L.WorkspaceScrollX;
  LY := L.WorkspaceScrollY;
  LZ := L.WorkspaceZoom;
  RX := R.WorkspaceScrollX;
  RY := R.WorkspaceScrollY;
  RZ := R.WorkspaceZoom;

  if not FSyncSampleValid then
  begin
    FSyncLastX := LX;
    FSyncLastY := LY;
    FSyncLastZoom := LZ;
    FSyncRightLastX := RX;
    FSyncRightLastY := RY;
    FSyncRightLastZoom := RZ;
    FSyncSampleValid := True;
    Exit;
  end;

  LScroll := FSyncScrollEnabled and
    ((LX <> FSyncLastX) or (LY <> FSyncLastY));
  LZoom := FSyncZoomEnabled and (Abs(LZ - FSyncLastZoom) > 0.0001);
  RScroll := FSyncScrollEnabled and
    ((RX <> FSyncRightLastX) or (RY <> FSyncRightLastY));
  RZoom := FSyncZoomEnabled and (Abs(RZ - FSyncRightLastZoom) > 0.0001);

  // Wenn beide Seiten Änderungen melden, entscheidet der Fokus.
  // Ansonsten wird ausschließlich die tatsächlich geänderte Seite Quelle.
  SourceIsRight := (RScroll or RZoom) and not (LScroll or LZoom);
  if (RScroll or RZoom) and (LScroll or LZoom) then
    SourceIsRight := (GetFocus = R.Handle) or IsChild(R.Handle, GetFocus);

  if SourceIsRight then
  begin
    if RScroll or RZoom then
      L.ApplySplitSync(RZ, RZoom, RX, RY, RScroll);
  end
  else if LScroll or LZoom then
    R.ApplySplitSync(LZ, LZoom, LX, LY, LScroll);

  // Nach der Übertragung beide Ist-Werte erneut erfassen. So wird
  // eine programmatische Änderung nicht als Benutzereingriff zurückgespiegelt.
  FSyncLastX := L.WorkspaceScrollX;
  FSyncLastY := L.WorkspaceScrollY;
  FSyncLastZoom := L.WorkspaceZoom;
  FSyncRightLastX := R.WorkspaceScrollX;
  FSyncRightLastY := R.WorkspaceScrollY;
  FSyncRightLastZoom := R.WorkspaceZoom;
end;

procedure TPDFTabsForm.SplitFocusTimerTick(Sender: TObject);
var
  P: TPoint;
  W: HWND;
  DownNow: Boolean;
  I: Integer;
  LeftPDF, RightPDF: TPDFBrowserForm;
begin
  if (FSplitHost = nil) or (FSplitLeft = nil) or (FSplitRight = nil) then Exit;
  CheckSplitSynchronization;
  DownNow := (GetAsyncKeyState(VK_LBUTTON) and $8000) <> 0;
  if DownNow and not FSplitMouseWasDown then
  begin
    GetCursorPos(P);
    W := WindowFromPoint(P);
    // Auch Klicks auf die PDF-Kindcontrols aktivieren die entsprechende Seite.
    if (W = FSplitRight.Handle) or IsChild(FSplitRight.Handle, W) then
    begin
      FSplitActiveRight := True;
      UpdateSplitBorders;
    end
    else if (W = FSplitLeft.Handle) or IsChild(FSplitLeft.Handle, W) then
    begin
      FSplitActiveRight := False;
      UpdateSplitBorders;
    end;
  end;
  FSplitMouseWasDown := DownNow;
  // Die Overlay-Schaltflaeche nur bei geschlossener Seitenleiste zeigen.
  // Das periodische Pruefen erfasst auch das Schliessen ueber das X
  // innerhalb der PDFium-Seitenleiste, ohne deren interne Events zu aendern.
  if FLeftPDFOverlay <> nil then
    for I := 0 to FLeftPDFOverlay.ControlCount - 1 do
      if (FLeftPDFOverlay.Controls[I] is TButton) and
         ((Pos('Miniaturansicht', TButton(FLeftPDFOverlay.Controls[I]).Hint) = 1) or
          (Pos('Show / hide thumbnails', TButton(FLeftPDFOverlay.Controls[I]).Hint) = 1)) then
      begin
        LeftPDF := PDFInTab(FSplitLeftTab);
        if LeftPDF <> nil then
          TButton(FLeftPDFOverlay.Controls[I]).Visible :=
            not LeftPDF.WorkspaceSidebarVisible;
        Break;
      end;
  // Bei geoeffneter Miniatur-Seitenleiste die Bediengruppe rechts oben
  // im jeweiligen PDF-Fenster anzeigen, statt sie ueber die Seitenleiste zu legen.
  LeftPDF := PDFInTab(FSplitLeftTab);
  if (LeftPDF <> nil) and (FLeftPDFOverlay <> nil) and (FSplitLeft <> nil) then
  begin
    if LeftPDF.WorkspaceSidebarVisible then
      FLeftPDFOverlay.Left := Max(FSplitLeft.BorderWidth + 2,
        FSplitLeft.ClientWidth - FLeftPDFOverlay.Width - FSplitLeft.BorderWidth - 4)
    else
      FLeftPDFOverlay.Left := FSplitLeft.BorderWidth + 2;
  end;
  RightPDF := PDFInTab(FSplitRightTab);
  if (RightPDF <> nil) and (FSplitRight <> nil) then
    for I := 0 to FSplitRight.ControlCount - 1 do
      if (FSplitRight.Controls[I] is TButton) and
         (TButton(FSplitRight.Controls[I]).Tag = 1) and
         (Pos('Text im rechten PDF suchen', TButton(FSplitRight.Controls[I]).Hint) = 1) then
      begin
        if RightPDF.WorkspaceSidebarVisible then
          TButton(FSplitRight.Controls[I]).Left := Max(FSplitRight.BorderWidth + 2,
            FSplitRight.ClientWidth - TButton(FSplitRight.Controls[I]).Width - FSplitRight.BorderWidth - 4)
        else
          TButton(FSplitRight.Controls[I]).Left := FSplitRight.BorderWidth + 2;
        Break;
      end;
  // Die rechte Bediengruppe als Einheit verschieben; keine verschachtelte
  // Wiederverwendung der Schleifenvariablen I.
  RightPDF := PDFInTab(FSplitRightTab);
  if (RightPDF <> nil) and (FRightPDFOverlay <> nil) and
     (FSplitRight <> nil) then
  begin
    if RightPDF.WorkspaceSidebarVisible then
      FRightPDFOverlay.Left := Max(FSplitRight.BorderWidth + 2,
        FSplitRight.ClientWidth - FRightPDFOverlay.Width -
        FSplitRight.BorderWidth - 4)
    else
      FRightPDFOverlay.Left := FSplitRight.BorderWidth + 2;
    for I := 0 to FRightPDFOverlay.ControlCount - 1 do
      if (FRightPDFOverlay.Controls[I] is TButton) and
         (Pos('Miniaturansicht',
           TButton(FRightPDFOverlay.Controls[I]).Hint) = 1) then
        TButton(FRightPDFOverlay.Controls[I]).Visible :=
          not RightPDF.WorkspaceSidebarVisible;
  end;
end;

procedure TPDFTabsForm.SplitThumbClick(Sender: TObject);
var
  PDF: TPDFBrowserForm;
begin
  PDF := nil;
  if (Sender is TControl) and (TControl(Sender).Tag = 1) then
  begin
    if FSplitRightTab <> nil then PDF := PDFInTab(FSplitRightTab);
    FSplitActiveRight := True;
  end
  else
  begin
    if FSplitLeftTab <> nil then PDF := PDFInTab(FSplitLeftTab);
    FSplitActiveRight := False;
  end;
  UpdateSplitBorders;
  if PDF <> nil then
  begin
    PDF.TogglePageThumbnails;
    if Sender is TButton then
      TButton(Sender).Visible := not PDF.WorkspaceSidebarVisible;
  end;
end;

procedure TPDFTabsForm.SplitPaneClick(Sender: TObject);
begin
  FSplitActiveRight := Sender = FSplitRight;
  UpdateSplitBorders;
end;

procedure TPDFTabsForm.StopSplit;
var
  L, R: TPDFBrowserForm;
  ReturnTab: TTabSheet;
  I: Integer;
begin
  if FSplitHost = nil then Exit;
  // Die zuletzt aktive Teilansicht wird wieder als volle Registerkarte gezeigt.
  if FSplitActiveRight then
    ReturnTab := FSplitRightTab
  else
    ReturnTab := FSplitLeftTab;

  FAddingPDF := True;
  try
    if FSplitFocusTimer <> nil then FSplitFocusTimer.Enabled := False;
    L := nil;
    R := nil;
    if FSplitLeft <> nil then
      for I := 0 to FSplitLeft.ControlCount - 1 do
        if FSplitLeft.Controls[I] is TPDFBrowserForm then
        begin
          L := TPDFBrowserForm(FSplitLeft.Controls[I]);
          Break;
        end;
    if FSplitRight <> nil then
      for I := 0 to FSplitRight.ControlCount - 1 do
        if FSplitRight.Controls[I] is TPDFBrowserForm then
        begin
          R := TPDFBrowserForm(FSplitRight.Controls[I]);
          Break;
        end;

    if (L <> nil) and (FSplitLeftTab <> nil) then
    begin
      L.Align := alNone;
      L.Parent := FSplitLeftTab;
      L.Align := alClient;
      L.Show;
    end;
    if (R <> nil) and (FSplitRightTab <> nil) then
    begin
      R.Align := alNone;
      R.Parent := FSplitRightTab;
      R.Align := alClient;
      R.Show;
    end;
    // DPI-Autoskalierung beim Umhaengen unterbinden und anschliessend
    // den urspruenglichen Zustand der PDF-Formulare wiederherstellen.
    if L <> nil then L.Scaled := FSplitLeftScaled;
    if R <> nil then R.Scaled := FSplitRightScaled;
    // Die Leisten erst NACH dem Entfernen des Split-Hosts und dem
    // Rueckwechsel auf die volle Tab-Breite wieder sichtbar machen.
    // Sonst berechnet die Toolbar ihre Anordnung mit halber Breite.
    FreeAndNil(FSplitFocusTimer);
    // Das Overlay gehoert Self; vor dem Freigeben des Split-Hosts
    // unbedingt aus dessen Control-Hierarchie herausnehmen.
    if FLeftPDFOverlay <> nil then
    begin
      FLeftPDFOverlay.Visible := False;
      FreeAndNil(FSyncScrollButton);
      FreeAndNil(FSyncZoomButton);
      FLeftPDFOverlay.Width := 2 + 3 * MulDiv(25, CurrentPPI, 96);
      // Der Miniaturbutton wird pro Split neu angelegt, beim Schliessen loeschen.
      for I := FLeftPDFOverlay.ControlCount - 1 downto 0 do
        if (FLeftPDFOverlay.Controls[I] is TButton) and
           ((Pos('Miniaturansicht', TButton(FLeftPDFOverlay.Controls[I]).Hint) = 1) or
          (Pos('Show / hide thumbnails', TButton(FLeftPDFOverlay.Controls[I]).Hint) = 1)) then
          FLeftPDFOverlay.Controls[I].Free;
      FLeftPDFOverlay.Parent := FTabs;
    end;
     FRightPDFOverlay := nil;
     FSyncScrollButton := nil;
     FSyncZoomButton := nil;
     FSyncSampleValid := False;
    FreeAndNil(FSplitHost);
    FSplitLeft := nil;
    FSplitRight := nil;
    FSplitDivider := nil;
    FSplitLeftTab := nil;
    FSplitRightTab := nil;

    // Die Doppelmarkierung ist nach dem Schliessen nicht mehr gueltig.
    FSplitAnchorTab := nil;
    FSplitSelectedTab := nil;
    FSplitShiftTab := -1;
    if (ReturnTab <> nil) and (ReturnTab.PageControl = FTabs) then
      FTabs.ActivePage := ReturnTab;
    FSplitLastSelectedTab := FTabs.ActivePage;
    FTabs.Realign;
    if (L <> nil) and (L.Parent <> nil) then L.Parent.Realign;
    if (R <> nil) and (R.Parent <> nil) then R.Parent.Realign;
    // Die Leisten zuerst wieder einblenden. Ein Layout bei noch
    // ausgeblendeter Navigation berechnet falsche Zeilenpositionen.
    SetSplitPDFToolbars(L, True, FSplitLeftTopBarVisible,
      FSplitLeftNavBarVisible);
    SetSplitPDFToolbars(R, True, FSplitRightTopBarVisible,
      FSplitRightNavBarVisible);
    if (FTabs.ActivePage <> nil) then
    begin
      FTabs.ActivePage.Realign;
      if (ReturnTab <> nil) and (ReturnTab.PageControl = FTabs) then
        for I := 0 to ReturnTab.ControlCount - 1 do
          if ReturnTab.Controls[I] is TPDFBrowserForm then
          begin
            TPDFBrowserForm(ReturnTab.Controls[I]).Align := alClient;
            TPDFBrowserForm(ReturnTab.Controls[I]).Realign;
            TPDFBrowserForm(ReturnTab.Controls[I]).Perform(
              WM_SIZE, SIZE_RESTORED,
              MakeLParam(ReturnTab.ClientWidth, ReturnTab.ClientHeight));
            Break;
          end;
    end;
  finally
    FAddingPDF := False;
  end;
  TFreePDF64PDFiumView.SetGlobalThumbnailSplitMode(False);
  if FSplitViewMenuItem <> nil then
    FSplitViewMenuItem.Checked := False;
  UpdateSplitMenuState;
  FTabs.Realign;
  // Erst nach dem vollstaendigen Rueckbau des Split-Hosts ist die
  // endgueltige Breite bekannt. Beide PDF-Viewer jetzt erneut layouten.
  if L <> nil then L.RefreshToolbarAfterSplit;
  if R <> nil then R.RefreshToolbarAfterSplit;
  FTabs.Invalidate;
end;

// Nur echte PDF-Register duerfen an der Zweifensteransicht teilnehmen.
function IsSplitPDFTab(const ATab: TTabSheet): Boolean;
begin
  Result := (ATab <> nil) and SameText(ExtractFileExt(ATab.Hint), '.pdf');
end;

procedure TPDFTabsForm.StartSplit(ALeft, ARight: TTabSheet);
var L, R: TPDFBrowserForm;
begin
  if (ALeft = nil) or (ARight = nil) or (ALeft = ARight) then Exit;
  if not IsSplitPDFTab(ALeft) or not IsSplitPDFTab(ARight) then Exit;
  StopSplit;
  L := PDFInTab(ALeft);
  R := PDFInTab(ARight);
  if (L = nil) or (R = nil) then Exit;
  TFreePDF64PDFiumView.SetGlobalThumbnailSplitMode(True);
  FSplitLeftScaled := L.Scaled;
  FSplitRightScaled := R.Scaled;
  L.Scaled := False;
  R.Scaled := False;
  FSplitLeftTab := ALeft;
  FSplitRightTab := ARight;
  FSplitAnchorTab := ALeft;
  FSplitSelectedTab := ARight;
  FAddingPDF := True;
  try FTabs.ActivePage := ALeft; finally FAddingPDF := False; end;
  FSplitHost := TPanel.Create(Self);
  FSplitHost.Parent := ALeft;
  FSplitHost.Align := alClient;
  FSplitHost.BevelOuter := bvNone;
  FSplitHost.Caption := '';
  FSplitHost.OnResize := SplitHostResized;
  FSplitLeft := TPanel.Create(Self);
  FSplitLeft.Parent := FSplitHost;
  FSplitLeft.Align := alLeft;
  FSplitLeft.Width := Max(100, FSplitHost.ClientWidth div 2);
  FSplitLeft.BevelOuter := bvNone;
  FSplitLeft.ParentBackground := False;
  FSplitLeft.BorderWidth := 2;
  FSplitLeft.Caption := '';
  FSplitLeft.OnClick := SplitPaneClick;
  FSplitDivider := TSplitter.Create(Self);
  FSplitDivider.Parent := FSplitHost;
  FSplitDivider.Align := alLeft;
  // Sichtbarer, mit der Maus verschiebbarer Mittel-Splitter.
  FSplitDivider.Width := Max(3, MulDiv(3, CurrentPPI, 96));
  FSplitDivider.MinSize := 100;
  FSplitDivider.Cursor := crHSplit;
  FSplitDivider.Beveled := False;
  FSplitDivider.Color := RGB(135, 150, 169);
  FSplitRight := TPanel.Create(Self);
  FSplitRight.Parent := FSplitHost;
  FSplitRight.Align := alClient;
  FSplitRight.BevelOuter := bvNone;
  FSplitRight.ParentBackground := False;
  FSplitRight.BorderWidth := 2;
  FSplitRight.Caption := '';
  FSplitRight.OnClick := SplitPaneClick;
  // Nur die neu angelegten Split-Container initialisieren; keine globale
  // Neuanwendung der Palette beim Wechsel in die Zweifensteransicht.
  if FDesignIndex = 3 then
  begin
    FSplitLeft.Color := RGB(192, 192, 192);
    FSplitRight.Color := RGB(192, 192, 192);
    FSplitHost.BevelOuter := bvRaised;
  end
  else if FDesignIndex = 1 then
  begin
    FSplitLeft.Color := RGB(229, 236, 246);
    FSplitRight.Color := RGB(229, 236, 246);
  end
  else if FDesignIndex = 5 then
  begin
    FSplitLeft.Color := RGB(220, 233, 247);
    FSplitRight.Color := RGB(220, 233, 247);
  end;
  // Die VCL sortiert gleich ausgerichtete Controls nach ihrer Position.
  // Der Splitter muss rechts neben dem linken Panel beginnen, nicht bei x=0.
  FSplitLeft.Left := 0;
  FSplitDivider.Left := FSplitLeft.Width;
  FSplitDivider.Visible := True;
  L.Parent := FSplitLeft;
  L.Align := alClient;
  R.Parent := FSplitRight;
  R.Align := alClient;
   L.Show; R.Show;
   SetSplitPDFToolbars(L, False, FSplitLeftTopBarVisible,
     FSplitLeftNavBarVisible);
   SetSplitPDFToolbars(R, False, FSplitRightTopBarVisible,
     FSplitRightNavBarVisible);
  // Der Teilungsbutton wird ausserhalb der Teilung in die Hauptsymbolleiste
  // umgehaengt. Vor dem Einblenden des linken Overlays zurueckholen,
  // damit das Kontextmenue und die Schliessen-Funktion erhalten bleiben.
  if (FLeftPDFOverlay <> nil) and (FTabSplitButton <> nil) then
  begin
    FTabSplitButton.Parent := FLeftPDFOverlay;
    FTabSplitButton.SetBounds(1, 1,
      MulDiv(25, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
    FTabSplitButton.Visible := True;
    FTabSplitButton.BringToFront;
  end;
  // Drei gleich hohe Buttons bilden im linken PDF-Fenster eine Einheit:
  // Ansicht teilen, Textsuche, Miniaturen. Keine weitere Kopfzeile.
  if FLeftPDFOverlay <> nil then
  begin
    FLeftPDFOverlay.Parent := FSplitLeft;
    FLeftPDFOverlay.ParentBackground := False;
    FLeftPDFOverlay.Color := clBtnFace;
    FLeftPDFOverlay.SetBounds(FSplitLeft.BorderWidth + 2,
      FSplitLeft.BorderWidth + 2, 2 + MulDiv(75, CurrentPPI, 96),
      2 + MulDiv(22, CurrentPPI, 96));
    // Nach dem Umhaengen alle Schaltflaechen mit derselben DPI-Basis
    // wie rechts ausrichten. Reparenting kann sonst VCL-Autoskalierung ausloesen.
    FLeftPDFOverlay.SetBounds(FSplitLeft.BorderWidth + 2,
      FSplitLeft.BorderWidth + 2, 2 + 3 * MulDiv(25, CurrentPPI, 96),
      2 + MulDiv(22, CurrentPPI, 96));

    if FTabTextSearchButton <> nil then
      FTabTextSearchButton.SetBounds(1 + MulDiv(25, CurrentPPI, 96), 1,
        MulDiv(25, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
    FLeftPDFOverlay.Visible := True;
    FLeftPDFOverlay.BringToFront;
  end;
  // Zwei zuschaltbare Synchronisationsfunktionen, nur in der Zweifensteransicht.
  FSyncScrollButton := TSpeedButton.Create(FLeftPDFOverlay);
  FSyncScrollButton.Parent := FLeftPDFOverlay;
  FSyncScrollButton.SetBounds(1 + 3 * MulDiv(25, CurrentPPI, 96), 1,
    MulDiv(25, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
  FSyncScrollButton.Caption := 'S';
  FSyncScrollButton.GroupIndex := 101;
  FSyncScrollButton.AllowAllUp := True;
  FSyncScrollButton.ShowHint := True;
  FSyncScrollButton.OnClick := SplitSyncClick;
  FSyncZoomButton := TSpeedButton.Create(FLeftPDFOverlay);
  FSyncZoomButton.Parent := FLeftPDFOverlay;
  FSyncZoomButton.SetBounds(1 + 4 * MulDiv(25, CurrentPPI, 96), 1,
    MulDiv(25, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
  FSyncZoomButton.Caption := 'Z';
  FSyncZoomButton.GroupIndex := 102;
  FSyncZoomButton.AllowAllUp := True;
  FSyncZoomButton.ShowHint := True;
  FSyncZoomButton.OnClick := SplitSyncClick;
  FLeftPDFOverlay.Width := 2 + 5 * MulDiv(25, CurrentPPI, 96);
  FSyncSampleValid := False;
  UpdateSplitSyncButtons;
  // Kleine Overlay-Buttons links oben ueber jedem PDF statt einer
  // durchgehenden Miniatur-Symbolleiste. Sie verbrauchen keine PDF-Hoehe.
  // Dritter Button gehoert in dasselbe Panel wie Teilen und Suche.
  // Gleiche Groesse und identische obere Kante fuer alle drei.
  with TButton.Create(FLeftPDFOverlay) do
  begin
    Parent := FLeftPDFOverlay;
    Align := alNone;
    SetBounds(1 + MulDiv(50, CurrentPPI, 96), 1,
      MulDiv(25, CurrentPPI, 96),
      MulDiv(22, CurrentPPI, 96));
    Caption := '☷';
    Font.Style := [fsBold];
    Hint := 'Miniaturansicht links ein-/ausblenden';
    ShowHint := True;
    Tag := 0;
    OnClick := SplitThumbClick;
    BringToFront;
  end;
   // Rechte Ansicht: dieselbe kompakte Dreiergruppe wie links.
   // Ein gemeinsames Panel verhindert ungleichmaessige Abstaende und
   // Ueberlagerungen mit der Miniatur-Seitenleiste.
   FRightPDFOverlay := TPanel.Create(Self);
   FRightPDFOverlay.Parent := FSplitRight;
   FRightPDFOverlay.Align := alNone;
   FRightPDFOverlay.ParentBackground := False;
   FRightPDFOverlay.Color := clBtnFace;
   FRightPDFOverlay.BevelOuter := bvNone;
   FRightPDFOverlay.Caption := '';
   FRightPDFOverlay.SetBounds(FSplitRight.BorderWidth + 2,
     FSplitRight.BorderWidth + 2, 2 + 2 * MulDiv(25, CurrentPPI, 96),
     2 + MulDiv(22, CurrentPPI, 96));
   with TButton.Create(FRightPDFOverlay) do
   begin
     Parent := FRightPDFOverlay;
     SetBounds(1, 1,
       MulDiv(25, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
     Caption := '⌕';
     Hint := 'Text im rechten PDF suchen (Strg+F)';
     ShowHint := True;
     Tag := 1;
     OnClick := LocalSearchMenuClick;
   end;
   with TButton.Create(FRightPDFOverlay) do
   begin
     Parent := FRightPDFOverlay;
     SetBounds(1 + MulDiv(25, CurrentPPI, 96), 1,
       MulDiv(25, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
     Caption := '☷';
     Font.Style := [fsBold];
     Hint := 'Miniaturansicht rechts ein-/ausblenden';
     ShowHint := True;
     Tag := 1;
     OnClick := SplitThumbClick;
   end;
   FRightPDFOverlay.BringToFront;
  FSplitActiveRight := False;
  FSplitMouseWasDown := False;
  UpdateSplitBorders;
  RefreshLanguage;
  FSplitHost.BringToFront;
  FSplitHost.Realign;
  // Erst nach dem Layout ist die echte Breite des Tab-Inhalts bekannt.
  // Der linke Bereich belegt genau die halbe Restbreite neben dem Splitter.
  FSplitLeft.Width := Max(100,
    (FSplitHost.ClientWidth - FSplitDivider.Width) div 2);
  FSplitHost.Realign;
  // Explizite Position nach dem finalen Breitenabgleich; keine
  // BringToFront-Aufrufe, die die Align-Reihenfolge veraendern.
  FSplitDivider.Left := FSplitLeft.Left + FSplitLeft.Width;
  FSplitHost.Realign;
  FSplitDivider.Invalidate;
  FSplitFocusTimer := TTimer.Create(Self);
  FSplitFocusTimer.Interval := 40;
  FSplitFocusTimer.OnTimer := SplitFocusTimerTick;
  FSplitFocusTimer.Enabled := True;
  FSplitViewMenuItem.Checked := True;
  UpdateSplitMenuState;
  // Nach Reparenting, Sprachwechsel und finalem Layout die beiden
  // Miniaturansichten erneut schliessen. Ein spaeteres Layout darf
  // insbesondere rechts keinen zuvor gespeicherten Zustand aktivieren.
  TFreePDF64PDFiumView.SetGlobalThumbnailSplitMode(True);
  FTabs.Invalidate;
end;

procedure TPDFTabsForm.UpdateSplitMenuState;
begin
  
  if FSplitViewMenuItem = nil then Exit;

  // In der Zweifensteransicht nur die beiden relevanten Hauptmenues anzeigen.
  // Beim Verlassen werden die uebrigen Hauptmenues wieder eingeblendet.
  if FHomeMenu <> nil then FHomeMenu.Visible := FSplitHost = nil;
  if FFileMenu <> nil then FFileMenu.Visible := FSplitHost = nil;
  if FEditMenu <> nil then FEditMenu.Visible := FSplitHost = nil;
  if FWorkspaceMenu <> nil then FWorkspaceMenu.Visible := FSplitHost = nil;
  if FOptionsMenu <> nil then
    FOptionsMenu.Visible := FSplitHost = nil;
  if FHelpRootMenuItem <> nil then
    FHelpRootMenuItem.Visible := FSplitHost = nil;
  FSplitViewMenuItem.Visible := True;
  if FVisualCompareMenuItem <> nil then
    FVisualCompareMenuItem.Visible := FSplitHost <> nil;
  if FHomeMenu <> nil then FHomeMenu.Enabled := FSplitHost = nil;
  if FFileMenu <> nil then FFileMenu.Enabled := FSplitHost = nil;
  if FEditMenu <> nil then FEditMenu.Enabled := FSplitHost = nil;
  if FWorkspaceMenu <> nil then FWorkspaceMenu.Enabled := FSplitHost = nil;
  if FOptionsMenu <> nil then FOptionsMenu.Enabled := FSplitHost = nil;
  if FHelpRootMenuItem <> nil then
    FHelpRootMenuItem.Enabled := FSplitHost = nil;
  // Bei Rueckkehr zur normalen Ansicht den bisherigen Zustand der
  // einzelnen Bearbeiten-Funktionen wiederherstellen.
  if FFileMenu <> nil then
    if FFileMenu.Count > 1 then
      FFileMenu.Items[1].Enabled := FSplitHost = nil;
  EditMenuClick(nil);
  // Der visuelle Vergleich ist nur bei aktiver Zweifensteransicht moeglich.
  // Sein Menuezustand darf niemals von der Teilungsfunktion abweichen,
  // wenn diese selbst nicht zur Verfuegung steht.
  if FVisualCompareMenuItem <> nil then
    begin
      FVisualCompareMenuItem.Visible := FSplitHost <> nil;
      FVisualCompareMenuItem.Enabled := (FSplitHost <> nil) and
        FSplitViewMenuItem.Enabled;
    end;

  // Die Registerkartensuche ist in der Zweifensteransicht deaktiviert.
  // StartSplit und StopSplit rufen UpdateSplitMenuState auf, sodass der
  // Zustand beim Eintritt und Verlassen der Teilansicht sofort wechselt.
  if FTabSearchButton <> nil then
    FTabSearchButton.Enabled := (FSplitHost = nil);

  // Die Overlay-Buttons erst bei zwei gewaehlten Tabs einblenden.
  if FLeftPDFOverlay <> nil then
  begin
    if False then
    begin
      
      FLeftPDFOverlay.Parent := FTabs.ActivePage;
      
      // Unterhalb der PDF-Werkzeugleisten im grauen Dokumentbereich.
      
      
      FLeftPDFOverlay.SetBounds(MulDiv(4, CurrentPPI, 96),
        MulDiv(85, CurrentPPI, 96), 2 + 2 * MulDiv(25, CurrentPPI, 96),
        2 + MulDiv(22, CurrentPPI, 96));
      FTabSplitButton.SetBounds(1, 1, MulDiv(25, CurrentPPI, 96),
        MulDiv(22, CurrentPPI, 96));
      FTabTextSearchButton.SetBounds(1 + MulDiv(25, CurrentPPI, 96), 1,
        MulDiv(25, CurrentPPI, 96), MulDiv(22, CurrentPPI, 96));
    end;
    
    if (FSplitHost = nil) and (FLeftPDFOverlay.Parent = FTabs.ActivePage) then
      FLeftPDFOverlay.Top := MulDiv(85, CurrentPPI, 96);
    
    FLeftPDFOverlay.Visible := FSplitHost <> nil;
    
    if FLeftPDFOverlay.Visible then FLeftPDFOverlay.BringToFront;
  end;
  // Teilungsbutton nur bei zwei markierten Registerkarten in der
  // normalen PDF-Symbolleiste links vor "PDF öffnen" anzeigen.
  if (FTabSplitButton <> nil) and (FTabs.ActivePage <> nil) then
  begin
    // Bei laufender Teilung bleibt die Schaltfläche im linken PDF verfügbar.
    if FSplitHost <> nil then
    begin
      // In der Zweifensteransicht gehört der Teilungsbutton in das
      // linke Overlay, nicht in die Hauptsymbolleiste des PDF-Viewers.
      if FLeftPDFOverlay <> nil then
      begin
        if FTabSplitButton.Parent <> FLeftPDFOverlay then
          FTabSplitButton.Parent := FLeftPDFOverlay;
        FTabSplitButton.SetBounds(1, 1, MulDiv(25, CurrentPPI, 96),
          MulDiv(22, CurrentPPI, 96));
        FTabSplitButton.Visible := True;
        FTabSplitButton.BringToFront;
        FLeftPDFOverlay.Visible := True;
        FLeftPDFOverlay.BringToFront;
      end;
    end
    else if PDFInTab(FTabs.ActivePage) <> nil then
    begin
      
      PDFInTab(FTabs.ActivePage).PlaceSplitButton(FTabSplitButton,
        (FSplitAnchorTab <> nil) and (FSplitSelectedTab <> nil) and
        (FSplitAnchorTab <> FSplitSelectedTab) and
        (FSplitAnchorTab.PageControl = FTabs) and
        (FSplitSelectedTab.PageControl = FTabs) and
        IsSplitPDFTab(FSplitAnchorTab) and
        IsSplitPDFTab(FSplitSelectedTab));
      
    end;
  end;
  // Eine bereits offene Teilansicht muss immer wieder schliessbar sein.
  
  if FTabSplitButton <> nil then
  begin
    FTabSplitButton.Enabled := (FSplitHost <> nil) or
      ((FSplitAnchorTab <> nil) and (FSplitSelectedTab <> nil) and
       (FSplitAnchorTab <> FSplitSelectedTab) and
       (FSplitAnchorTab.PageControl = FTabs) and
       (FSplitSelectedTab.PageControl = FTabs));
  end;
  
  FSplitViewMenuItem.Enabled := (FSplitHost <> nil) or
    ((FSplitAnchorTab <> nil) and (FSplitSelectedTab <> nil) and
     (FSplitAnchorTab <> FSplitSelectedTab) and
     (FSplitAnchorTab.PageControl = FTabs) and
     (FSplitSelectedTab.PageControl = FTabs));
  // Nach der abschliessenden Aktualisierung der Teilungsfreigabe
  // auch den Vergleichsmenuepunkt synchron halten.
  if FVisualCompareMenuItem <> nil then
    begin
      FVisualCompareMenuItem.Visible := FSplitHost <> nil;
      FVisualCompareMenuItem.Enabled := (FSplitHost <> nil) and
        FSplitViewMenuItem.Enabled;
    end;
  // VCL kann beim Umschalten der Menuepunkte das native Menue neu aufbauen.
  // Danach die rechtsbuendige Position von "Hilfe" wiederherstellen.
  AlignHelpMenuRight;
end;

procedure TPDFTabsForm.SplitButtonPopup(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FSplitButtonPopup.Items.Count - 1 do
    if FSplitButtonPopup.Items[I].Caption <> '-' then
      FSplitButtonPopup.Items[I].Enabled := FSplitHost <> nil;
end;

procedure TPDFTabsForm.SplitPopupCloseLeft(Sender: TObject);
begin
  if FSplitHost = nil then Exit;
  FSplitActiveRight := True;
  StopSplit;
end;

procedure TPDFTabsForm.SplitPopupCloseRight(Sender: TObject);
begin
  if FSplitHost = nil then Exit;
  FSplitActiveRight := False;
  StopSplit;
end;

procedure TPDFTabsForm.SplitPopupSwap(Sender: TObject);
var
  LeftTab, RightTab: TTabSheet;
  WasRight: Boolean;
begin
  if FSplitHost = nil then Exit;
  LeftTab := FSplitLeftTab;
  RightTab := FSplitRightTab;
  WasRight := FSplitActiveRight;
  StopSplit;
  StartSplit(RightTab, LeftTab);
  FSplitActiveRight := not WasRight;
  UpdateSplitBorders;
end;

procedure TPDFTabsForm.ReplaceSplitPane(ANewTab: TTabSheet);
var
  OldTab, LeftTab, RightTab: TTabSheet;
  WasRight: Boolean;
begin
  if not IsSplitPDFTab(ANewTab) then Exit;
  if (FSplitHost = nil) or (ANewTab = nil) or
     (ANewTab.PageControl <> FTabs) then Exit;
  WasRight := FSplitActiveRight;
  LeftTab := FSplitLeftTab;
  RightTab := FSplitRightTab;
  if WasRight then OldTab := RightTab else OldTab := LeftTab;
  if (ANewTab = OldTab) or
     (ANewTab = LeftTab) or (ANewTab = RightTab) then Exit;
  // Rueckhaengen verhindert verwaiste PDF-Fenster beim Austausch.
  StopSplit;
  if WasRight then RightTab := ANewTab else LeftTab := ANewTab;
  StartSplit(LeftTab, RightTab);
  FSplitActiveRight := WasRight;
  UpdateSplitBorders;
end;

procedure TPDFTabsForm.SplitMenuClick(Sender: TObject);
begin
  if FSplitHost <> nil then
    StopSplit
  else if (FSplitAnchorTab <> nil) and (FSplitSelectedTab <> nil) and
          (FSplitAnchorTab.PageControl = FTabs) and
          (FSplitSelectedTab.PageControl = FTabs) and
          (FSplitAnchorTab <> FSplitSelectedTab) and
          IsSplitPDFTab(FSplitAnchorTab) and
          IsSplitPDFTab(FSplitSelectedTab) then
    StartSplit(FSplitAnchorTab, FSplitSelectedTab);
end;

procedure TPDFTabsForm.BeginMultiPDFLoad;
begin
  if FMultiPDFLoadDepth = 0 then
    FMultiPDFLastPDF := nil;
  Inc(FMultiPDFLoadDepth);
end;

procedure TPDFTabsForm.EndMultiPDFLoad;
var
  PDF: TPDFBrowserForm;
begin
  if FMultiPDFLoadDepth <= 0 then Exit;
  Dec(FMultiPDFLoadDepth);
  if FMultiPDFLoadDepth <> 0 then Exit;
  PDF := FMultiPDFLastPDF;
  FMultiPDFLastPDF := nil;
  if PDF = nil then Exit;
  // Nur die letzte PDF aktivieren und initialisieren. Alle vorherigen
  // Register wurden ohne Viewer-Start im Hintergrund angelegt.
  ActivatePDF(PDF);
  PDF.Show;
  if not PDF.PDFNavigationSucceeded then
    PDF.RequestPDFLoadFast;
end;

procedure TPDFTabsForm.AddPDF(APDF: TPDFBrowserForm);
var
  Tab: TTabSheet;
begin
  // Beim Oeffnen einer neuen PDF vorhandene Anlagenfenster schliessen.
  HideAllAttachmentWindows;
  // Die komplette synchrone Einbettung einschliesslich der ersten
  // PDF-Initialisierung atomar zeichnen. Eine Sperre nur um APDF.Show
  // ist zu kurz: ActivePage und RequestPDFLoad loesen weitere
  // Toolbar-Reflows aus, die sonst als Zwischenzeile sichtbar werden.
  // Nur die Registerkarten gegen Zwischenzeichnungen sperren.
  // Das Hauptfenster darf nicht mit WM_SETREDRAW behandelt werden:
  // sonst kann Windows das Taskleistensymbol grau darstellen.
  SendMessage(FTabs.Handle, WM_SETREDRAW, 0, 0);
  try
    Tab := TTabSheet.Create(FTabs);
  Tab.DoubleBuffered := True;
  Tab.ControlStyle := Tab.ControlStyle + [csOpaque];
  Tab.PageControl := FTabs;
  Tab.DoubleBuffered := True;
  Tab.Caption := ExtractFileName(APDF.PDFFileName);
  UpdateEmptyTabStrip;
  RememberRecentPDF(APDF.PDFFileName);
  Tab.Hint := APDF.PDFFileName;
  Tab.ShowHint := False; // Kein geerbter Dateipfad-Hint im PDF-Inhaltsbereich
  // Jeder Oeffnungsweg (auch die DPR und FreePDF64) erhaelt den Such-Handler.
  APDF.OnGlobalSearch := GlobalSearchClick;
  APDF.OnOpenPDF := OpenPDFClick;
  APDF.OnOpenWorkspaces := OpenWorkspaceClick;
  APDF.OnSaveWorkspace := SaveWorkspaceClick;
  APDF.TabbedPDFMode := True;
  APDF.BorderStyle := bsNone;
  APDF.Parent := Tab;
  APDF.Align := alClient;
  APDF.ApplyToolbarDesign(FDesignIndex);
  // Lazy Loading: Alle Register anlegen, aber ausschliesslich das
  // jeweils aktive PDF initialisieren. Kein unsichtbarer Erst-Tab-Start.
  FAddingPDF := True;
  try
    if FMultiPDFLoadDepth = 0 then
      FTabs.ActivePage := Tab
    else
      FMultiPDFLastPDF := APDF;
  finally
    FAddingPDF := False;
  end;
  if FLeftPDFOverlay <> nil then
  begin
    FLeftPDFOverlay.Parent := Tab;
    FLeftPDFOverlay.SetBounds(MulDiv(4, CurrentPPI, 96),
      MulDiv(85, CurrentPPI, 96), MulDiv(79, CurrentPPI, 96),
      MulDiv(24, CurrentPPI, 96));
    FLeftPDFOverlay.Visible := False;
    FLeftPDFOverlay.BringToFront;
  end;
  // Erst jetzt sind Registerkarte und PDF-Formular vollständig zugeordnet.
  // Insbesondere beim Öffnen mehrerer PDFs aus FreePDF64 muss die
  // globale Suche sofort aktiviert werden, ohne vorherigen Tabwechsel.
  UpdateTabCount;
  if not Visible then
    Show;

  // Endgueltige Breite vor dem ersten sichtbaren Zeichnen festlegen.
  if FMultiPDFLoadDepth = 0 then
    APDF.Show;
  // Die automatische VCL-Ausrichtung genuegt; zusaetzliche Realign-
  // Durchlaeufe zeichnen die Symbolleiste unnoetig mehrfach.
  // Das erste PDF explizit anfordern: ein Tabwechsel-Ereignis
  // wird beim erstmaligen Anlegen nicht immer ausgeloest.

  if FMultiPDFLoadDepth = 0 then
    APDF.RequestPDFLoad;

  FFirstPDFInitialized := True;
  FDeferredActivePDF := nil;
  FActivationTimer.Enabled := False;

  if FMultiPDFLoadDepth = 0 then
    PostMessage(Handle, WM_APP + 193, 0, 0);

  if Assigned(PDFTabAttachmentsInitializer) then
    PDFTabAttachmentsInitializer(APDF.PDFFileName, APDF);
  // Auch ein waehrend der PDF-Initialisierung erzeugtes Anlagenfenster
  // soll erst durch einen ausdruecklichen Klick sichtbar werden.
  HideAllAttachmentWindows;


  if FMultiPDFLoadDepth = 0 then
    APDF.UpdateAttachmentWindowPosition;

  // Bei nur einer PDF darf das Fenster nicht ausserhalb des Monitors
  // verbleiben. Die erste Registerkarte ist bereits eingebettet und
  // sichtbar; fuer sie ist kein Registerwechsel abzuwarten.
  if (FTabs.PageCount = 1) and FInitialWindowOffscreen then
  begin
    FActivationTimer.Enabled := False;
    FDeferredActivePDF := nil;

    RestoreInitialWindow;

  end;
  finally
    SendMessage(FTabs.Handle, WM_SETREDRAW, 1, 0);
    // Keine erzwungene Vollfenster-Neuzeichnung und kein RDW_ALLCHILDREN.
    // Die VCL aktualisiert die sichtbaren Kinder bei Bedarf selbst.
    FTabs.Invalidate;
  end;
end;

procedure TPDFTabsForm.AddAttachmentPDF(APDF: TPDFBrowserForm; ASource: TPDFBrowserForm);
var
  SourceIndex: Integer;
begin
  SourceIndex := -1;
  if (ASource <> nil) and (ASource.Parent is TTabSheet) then
    if TTabSheet(ASource.Parent).PageControl = FTabs then
      SourceIndex := TTabSheet(ASource.Parent).PageIndex;
  AddPDF(APDF);
  if (SourceIndex >= 0) and (APDF.Parent is TTabSheet) then
  begin
    TTabSheet(APDF.Parent).PageIndex := SourceIndex + 1;
    UpdateEmptyTabStrip;
  end;
end;

procedure TPDFTabsForm.ActivatePDF(APDF: TPDFBrowserForm);
begin
  if (APDF = nil) or not (APDF.Parent is TTabSheet) or
     (TTabSheet(APDF.Parent).PageControl <> FTabs) then Exit;
  FActivationTimer.Enabled := False;
  FDeferredActivePDF := nil;
  FFirstPDFInitialized := True;
  FAddingPDF := True;
  try
    FTabs.ActivePage := TTabSheet(APDF.Parent);
  finally
    FAddingPDF := False;
  end;
  PostMessage(Handle, WM_APP + 193, 0, 0);
end;

procedure TPDFTabsForm.HideAllAttachmentWindows;
var
  I, J: Integer;
  Tab: TTabSheet;
  Wnd: HWND;
begin
  if FTabs = nil then Exit;
  for I := 0 to FTabs.PageCount - 1 do
  begin
    Tab := FTabs.Pages[I];
    for J := 0 to Tab.ControlCount - 1 do
      if Tab.Controls[J] is TPDFBrowserForm then
      begin
        Wnd := TPDFBrowserForm(Tab.Controls[J]).AttachmentWindowHandle;
        if IsWindow(Wnd) then
        begin
          ShowWindow(Wnd, SW_HIDE);
          SetWindowPos(Wnd, HWND_NOTOPMOST, 0, 0, 0, 0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
        end;
      end;
  end;
end;


procedure TPDFTabsForm.RefreshAttachmentPositions;
var
  I, J: Integer;
  Tab: TTabSheet;
begin
  if FTabs = nil then Exit;
  for I := 0 to FTabs.PageCount - 1 do
  begin
    Tab := FTabs.Pages[I];
    for J := 0 to Tab.ControlCount - 1 do
      if Tab.Controls[J] is TPDFBrowserForm then
      begin
        if Tab <> FTabs.ActivePage then
        begin
          // Die Anlagenliste gehoert zur vorherigen PDF und darf nicht
          // ueber der neu aktivierten Registerkarte sichtbar bleiben.
          if IsWindow(TPDFBrowserForm(Tab.Controls[J]).AttachmentWindowHandle) then
          begin
            ShowWindow(TPDFBrowserForm(Tab.Controls[J]).AttachmentWindowHandle,
              SW_HIDE);
            SetWindowPos(
              TPDFBrowserForm(Tab.Controls[J]).AttachmentWindowHandle,
              HWND_NOTOPMOST, 0, 0, 0, 0,
              SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
          end;
        end
        else
        begin
          
          TPDFBrowserForm(Tab.Controls[J]).RefreshActiveTabPDF;
          
          TPDFBrowserForm(Tab.Controls[J]).UpdateAttachmentWindowPosition;
          
        end;
      end;
  end;
end;

procedure TPDFTabsForm.ReloadActivePDFClick(Sender: TObject);
var
  Tab: TTabSheet;
  I: Integer;
begin
  if FTabs = nil then Exit;
  Tab := FTabs.ActivePage;
  if Tab = nil then Exit;
  for I := 0 to Tab.ControlCount - 1 do
    if Tab.Controls[I] is TPDFBrowserForm then
    begin
      TPDFBrowserForm(Tab.Controls[I]).ReloadCurrentPDF;
      Break;
    end;
end;

// Grafiktyp anhand der Registerkarten-Metadaten bestimmen.
// Nicht die PDFFileName-Eigenschaft einer eventuell gerade wechselnden
// BrowserForm abfragen (Fehlerpfad LoadSelectedPDF/IsBasicImage).
function IsImageTabFile(const ATab: TTabSheet): Boolean;
var
  Ext: string;
begin
  Result := False;
  if ATab = nil then Exit;
  Ext := LowerCase(ExtractFileExt(ATab.Hint));
  Result := (Ext = '.jpg') or (Ext = '.jpeg') or
    (Ext = '.png') or (Ext = '.bmp') or (Ext = '.tif') or (Ext = '.tiff');
end;

procedure TPDFTabsForm.LoadSelectedPDF;
var
  I: Integer;
  Tab: TTabSheet;
begin
  if FAddingPDF or (FTabs = nil) then Exit;
  Tab := FTabs.ActivePage;
  if Tab = nil then Exit;
  for I := 0 to Tab.ControlCount - 1 do
    if Tab.Controls[I] is TPDFBrowserForm then
    begin
      if IsImageTabFile(Tab) then
      begin
        if not TPDFBrowserForm(Tab.Controls[I]).Visible then
          TPDFBrowserForm(Tab.Controls[I]).Show;
        Exit;
      end;
      // Ein bisher inaktiver Tab kann noch unsichtbar sein. Der
      // Ladetimer wartet auf einen sichtbaren PDF-Browser.
      TPDFBrowserForm(Tab.Controls[I]).Show;
      if not TPDFBrowserForm(Tab.Controls[I]).PDFNavigationSucceeded then
        TPDFBrowserForm(Tab.Controls[I]).RequestPDFLoadFast;
      Break;
    end;
end;

function TPDFTabsForm.TabCloseRect(AIndex: Integer): TRect;
var
  R: TRect;
  Size, Padding: Integer;
begin
  Result := System.Types.Rect(0, 0, 0, 0);
  if (FTabs = nil) or (AIndex < 0) or (AIndex >= FTabs.PageCount) then Exit;
  R := FTabs.TabRect(AIndex);
  // Chrome-aehnliche 18px Klickflaeche, skaliert mit Monitor-DPI.
  Size := Max(18, MulDiv(18, CurrentPPI, 96));
  Padding := Max(5, MulDiv(6, CurrentPPI, 96));
  Result := System.Types.Rect(R.Right - Padding - Size,
    R.Top + (R.Bottom - R.Top - Size) div 2,
    R.Right - Padding,
    R.Top + (R.Bottom - R.Top - Size) div 2 + Size);
end;

procedure TPDFTabsForm.CloseTabAt(AIndex: Integer);
begin
  if FTabCloseInProgress then Exit;
  // Der Splitter gehoert ausschliesslich zur Zweifensteransicht.
  // Beim normalen Tab-Schliessen keine Split-Controls anfassen.
  if FSplitHost <> nil then
    StopSplit;
  if (AIndex < 0) or (AIndex >= FTabs.PageCount) then
  begin
    FCloseRestoreTab := nil;
    Exit;
  end;
  // FCloseRestoreTab wurde bereits in TabMouseDown gesichert. Zu diesem
  // Zeitpunkt kann das native TabControl den angeklickten Tab schon
  // aktiviert haben; deshalb hier keinesfalls erneut ActivePage auslesen.
  try
    // Beim Schliessen eines noch nie angezeigten Tabs keine PDF-Ladung
    // durch den rein technischen Wechsel der aktiven Registerkarte ausloesen.
    // Die zu schliessende Registerkarte NICHT aktivieren: Bei noch nicht
    // geladenen PDFs kann der native Seitenwechsel eine Initialisierung
    // ausloesen, die mit der anschliessenden Freigabe kollidiert.
    FCloseTargetTab := FTabs.Pages[AIndex];
    try
      CloseActive(Self); // vorhandene Sicherheitsabfrage beibehalten
    finally
      FCloseTargetTab := nil;
    end;
  finally
    FCloseRestoreTab := nil;
  end;
end;

procedure TPDFTabsForm.TabMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  
  if Button = mbLeft then
  begin
    if (ssShift in Shift) and (FSplitShiftTab >= 0) then
    begin
      if (FSplitAnchorTab <> nil) and
         (FSplitShiftTab < FTabs.PageCount) and
         (FSplitAnchorTab <> FTabs.Pages[FSplitShiftTab]) then
      begin
        if not IsSplitPDFTab(FSplitAnchorTab) or
           not IsSplitPDFTab(FTabs.Pages[FSplitShiftTab]) then
        begin
          FSplitShiftTab := -1;
          Exit;
        end;
        FSplitSelectedTab := FTabs.Pages[FSplitShiftTab];
        UpdateSplitMenuState;
        FTabs.Invalidate;
      end;
      FSplitShiftTab := -1;
      FCloseRestoreTab := nil;
      Exit;
    end;
    // Nur bei einem echten Klick auf das X schliessen, nicht nach Tab-Drag.
    if not FDraggingTab then
    begin
      var CloseIndex: Integer;
      CloseIndex := FTabs.IndexOfTabAt(X, Y);
      if (CloseIndex >= 0) and PtInRect(TabCloseRect(CloseIndex), Point(X, Y)) then
      begin
        FDragTabIndex := -1;
        FDraggingTab := False;
        FHoverCloseTabIndex := -1;
        CloseTabAt(CloseIndex);
        Exit;
      end;
    end;
    FDragTabIndex := -1;
    FDraggingTab := False;
    FCloseRestoreTab := nil;
    PostMessage(Handle, WM_APP + 193, 0, 0);
  end;
end;

procedure TPDFTabsForm.SplitHostResized(Sender: TObject);
var
  NewLeftWidth: Integer;
begin
  // Bei jeder Aenderung der Hostbreite die beiden PDF-Bereiche gleich breit
  // halten. Ein manuelles Verschieben des Splitters loest dieses Ereignis
  // nicht aus und bleibt daher bis zur naechsten Fenstergroessenaenderung erhalten.
  if (FSplitHost = nil) or (FSplitLeft = nil) or
     (FSplitDivider = nil) or (FSplitRight = nil) then Exit;
  NewLeftWidth := (FSplitHost.ClientWidth - FSplitDivider.Width) div 2;
  if NewLeftWidth < FSplitDivider.MinSize then Exit;
  if FSplitHost.ClientWidth - FSplitDivider.Width - NewLeftWidth <
     FSplitDivider.MinSize then Exit;
  if FSplitLeft.Width <> NewLeftWidth then
    FSplitLeft.Width := NewLeftWidth;
end;

procedure TPDFTabsForm.TabsResized(Sender: TObject);
begin
  UpdateEmptyTabStrip;
  PositionTabActions;
end;

procedure TPDFTabsForm.TabArrowClick(Sender: TObject);
var
  NewIndex: Integer;
begin
  if (FTabs = nil) or (FTabs.PageCount = 0) then Exit;

  // Der Wechsel loest TabsChange aus; dort erfolgt die PDF-Aktivierung.
  if Sender = FTabNextButton then
    NewIndex := Max(0, FTabs.ActivePageIndex - 1)
  else
    NewIndex := Min(FTabs.PageCount - 1, FTabs.ActivePageIndex + 1);

  if NewIndex = FTabs.ActivePageIndex then Exit;
  FTabs.ActivePageIndex := NewIndex;
  FTabs.Invalidate;
  // TabsChange fordert die PDF-Ladung bereits an. Kein zweiter Aufruf
  // waehrend der asynchronen Initialisierung durch die Pfeilnavigation.
  // Bei nativer Pfeilnavigation wird OnChange nicht in jedem Fall
  // erneut ausgeloest. Sicherstellen, dass die neue Seite geprueft wird.
  if (FTabFitTimer <> nil) and
     (FTabFitPendingPage <> FTabs.ActivePage) then
  begin
    FTabFitTimer.Enabled := False;
    FTabFitPendingPage := FTabs.ActivePage;
    FTabFitRetryCount := 0;
    FTabFitTimer.Enabled := True;
  end;
  // Nach dem VCL-Registerwechsel erneut im Nachrichtenzyklus pruefen.
  // Zu diesem Zeitpunkt ist auch das TabSheet sichtbar und bemessen.
  PostMessage(Handle, WM_APP + 193, 0, 0);
  RefreshAttachmentPositions;
  UpdateTabCount;
end;

procedure TPDFTabsForm.PositionTabActions;
var
  NeedArrows: Boolean;
  ArrowWidth, BarHeight, TopOffset, CountWidth, SearchWidth: Integer;
  NativeScroll: HWND;
begin
  if (FTabActionsPanel = nil) or (FTabs = nil) then Exit;
  // Alle Abmessungen DPI-skaliert; kein ungenutzter Zwischenraum.
  ArrowWidth := MulDiv(23, CurrentPPI, 96);
  CountWidth := MulDiv(35, CurrentPPI, 96);
  SearchWidth := MulDiv(35, CurrentPPI, 96);
  NeedArrows := (FTabs.PageCount > 0) and
    (Int64(FTabs.PageCount) * MulDiv(120, CurrentPPI, 96) >
     Max(1, FTabs.ClientWidth - CountWidth - SearchWidth - MulDiv(8, CurrentPPI, 96)));
  FTabPrevButton.Visible := True;
  FTabNextButton.Visible := True;
  FTabPrevButton.Width := ArrowWidth;
  FTabNextButton.Width := ArrowWidth;
  FTabSearchButton.Width := SearchWidth;
  FTabActionsPanel.Width := CountWidth + SearchWidth + 2 * ArrowWidth;
  BarHeight := MulDiv(22, CurrentPPI, 96);
  TopOffset := MulDiv(2, CurrentPPI, 96);
  // Die Aktionsleiste ist ein Geschwister des TPageControl, damit das
  // native UpDown-Kindfenster sie nicht ueberzeichnen kann.
  // Keinesfalls alRight: das wuerde eine Spalte ueber die gesamte
  // Fensterhoehe reservieren und die PDF-Anzeige schmaler machen.
  // Die Bedienelemente liegen nur in der Kopfzeile des TabHosts.
  FTabActionsPanel.Align := alNone;
  FTabActionsPanel.SetBounds(
    Max(0, FTabActionsPanel.Parent.ClientWidth - FTabActionsPanel.Width),
    TopOffset, FTabActionsPanel.Width, BarHeight);
  // Die nativen Windows-Scrollpfeile nicht zusaetzlich anzeigen.
  // Scrollen erfolgt ueber die eigenen Schaltflaechen.
  if FTabs.HandleAllocated then
  begin
    NativeScroll := FindWindowEx(FTabs.Handle, 0, 'msctls_updown32', nil);
    if NativeScroll <> 0 then
      ShowWindow(NativeScroll, SW_HIDE);
  end;
  FTabActionsPanel.Visible := True;
  FTabActionsPanel.BringToFront;
  // Pfeilschaltflaechen bleiben auch an den Tab-Grenzen anklickbar.
  // TabArrowClick verhindert bereits einen Wechsel ausserhalb des Bereichs.
  FTabNextButton.Enabled := True;
  FTabPrevButton.Enabled := True;
end;

procedure TPDFTabsForm.UpdateEmptyTabStrip;
var
  R: TRect;
  LeftEdge, StripHeight: Integer;
  AvailableWidth, MaxTabWidth, NewTabWidth: Integer;
  ActionWidth, SafetyGap: Integer;
begin
  if (FTabs = nil) or (FEmptyTabStrip = nil) or FUpdatingTabLayout then Exit;
  FUpdatingTabLayout := True;
  try
    // Die Tab-Leiste und die Aktionen teilen sich dieselbe Kopfzeile.
    // WICHTIG: Die Gesamtbreite aller Tabs darf den linken Bereich
    // NIEMALS ueberschreiten. Eine Mindestbreite von 120 px hatte
    // zuvor das native TabControl unter die Aktionsbuttons geschoben.
    SafetyGap := MulDiv(8, CurrentPPI, 96);
    ActionWidth := MulDiv(116, CurrentPPI, 96);
    AvailableWidth := Max(1, FTabs.ClientWidth - ActionWidth - SafetyGap);
    if FTabs.PageCount > 0 then
    begin
      MaxTabWidth := MulDiv(260, CurrentPPI, 96);
      // Auch bei vielen PDFs auf die verfuegbare Breite begrenzen.
      // Dadurch gibt es weder eine zusaetzliche Zeile/Spalte noch
      // verdeckte Tabs unter Pfeilen, Zaehler oder Suchbutton.
      NewTabWidth := Max(1, Min(MaxTabWidth,
        (AvailableWidth - MulDiv(4, CurrentPPI, 96)) div FTabs.PageCount));
      if FTabs.TabWidth <> NewTabWidth then
        FTabs.TabWidth := NewTabWidth;
    end;
  StripHeight := MulDiv(28, CurrentPPI, 96);
  LeftEdge := 0;
  if FTabs.PageCount > 0 then
  begin
    if SendMessage(FTabs.Handle, TCM_GETITEMRECT,
      WPARAM(FTabs.PageCount - 1), LPARAM(@R)) <> 0 then
    begin
      LeftEdge := R.Right + 1;
      StripHeight := R.Bottom;
    end;
  end;
  if StripHeight < 1 then Exit;
  PositionTabActions;

  // Bei zu vielen Registerkarten blendet Windows rechts die beiden
  // Navigationspfeile ein. Das Overlay darf diese nicht ueberdecken.
  // Sobald die letzte Registerkarte den rechten Rand erreicht oder
  // darueber hinausreicht, den freien Streifen ganz ausblenden.
  if (FTabs.PageCount > 0) and
     (LeftEdge >= FTabs.ClientWidth - ActionWidth - SafetyGap) then
  begin
    FEmptyTabStrip.Visible := False;
    Exit;
  end;

  FEmptyTabStrip.SetBounds(LeftEdge, 0,
    Max(0, FTabs.ClientWidth - LeftEdge - ActionWidth - SafetyGap), StripHeight);
  FEmptyTabStrip.Visible := FEmptyTabStrip.Width > 0;
  if FEmptyTabStrip.Visible then
    FEmptyTabStrip.BringToFront;
  PositionTabActions;
  finally
    FUpdatingTabLayout := False;
  end;
end;

procedure TPDFTabsForm.EmptyTabStripMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  if Button <> mbRight then Exit;
  P := FEmptyTabStrip.ClientToScreen(Point(X, Y));
  FTabContextMenu.Popup(P.X, P.Y);
end;

procedure TPDFTabsForm.TabsWindowProc(var Msg: TMessage);
var
  P: TPoint;
  LocalP: TPoint;
  TabStripBottom: Integer;
  TabRect: TRect;
  CloseIndex: Integer;
begin
  // WM_MOUSELEAVE fuer das native TabControl explizit anfordern.
  // Das VCL-OnMouseLeave kommt bei TPageControl je nach Mausbewegung,
  // Kindfenster und Windows-Version nicht zuverlaessig an. Ohne diese
  // Nachricht kann unser eigener THintWindow am Mauszeiger stehenbleiben.
  if Msg.Msg = WM_MOUSEMOVE then
  begin
    if not FTrackingTabsMouseLeave then
    begin
      var TrackInfo: TTrackMouseEvent;
      TrackInfo.cbSize := SizeOf(TrackInfo);
      TrackInfo.dwFlags := TME_LEAVE;
      TrackInfo.hwndTrack := FTabs.Handle;
      TrackInfo.dwHoverTime := HOVER_DEFAULT;
      if TrackMouseEvent(TrackInfo) then
        FTrackingTabsMouseLeave := True;
    end;
  end
  else if Msg.Msg = WM_MOUSELEAVE then
  begin
    FTrackingTabsMouseLeave := False;
    TabsMouseLeave(FTabs);
  end;

  // Das native TabControl kann den angeklickten Reiter bereits vor den
  // VCL-Mausereignissen aktivieren. Deshalb den bisher aktiven Tab direkt
  // im WindowProc sichern, solange WM_LBUTTONDOWN noch nicht weitergereicht ist.
  if Msg.Msg = WM_LBUTTONDOWN then
  begin
    LocalP := Point(SmallInt(LOWORD(Msg.LParam)),
                    SmallInt(HIWORD(Msg.LParam)));
    CloseIndex := FTabs.IndexOfTabAt(LocalP.X, LocalP.Y);
    if (CloseIndex >= 0) and
       PtInRect(TabCloseRect(CloseIndex), LocalP) then
    begin
      if (FTabs.ActivePage <> nil) and
         (FTabs.Pages[CloseIndex] <> FTabs.ActivePage) then
        FCloseRestoreTab := FTabs.ActivePage
      else
        FCloseRestoreTab := nil;
    end
    else
      FCloseRestoreTab := nil;
  end;

  // Das native Windows-Tabcontrol verarbeitet den Mausklick selbst.
  // OnMouseDown/OnMouseUp werden bei einem Klick auf den Reiter nicht
  // zuverlaessig ausgeloest. Strg+Klick deshalb direkt hier abfangen,
  // bevor Windows die aktive Registerkarte wechselt (TabsChange wuerde
  // sonst die bestehende Split-Ansicht wieder schliessen).
  if (Msg.Msg = WM_LBUTTONDOWN) and (GetKeyState(VK_CONTROL) < 0) then
  begin
    LocalP := Point(SmallInt(LOWORD(Msg.LParam)),
                    SmallInt(HIWORD(Msg.LParam)));
    var TargetIndex: Integer;
    TargetIndex := FTabs.IndexOfTabAt(LocalP.X, LocalP.Y);
    if (TargetIndex >= 0) and (TargetIndex < FTabs.PageCount) then
    begin
      // Strg+Klick auf eine bereits markierte Registerkarte hebt die
      // Markierung wieder auf (ohne den aktiven Tab zu wechseln).
      if FSplitHost = nil then
      begin
        if FTabs.Pages[TargetIndex] = FSplitSelectedTab then
        begin
          FSplitSelectedTab := nil;
          UpdateSplitMenuState;
          FTabs.Invalidate;
          Msg.Result := 0;
          Exit;
        end;
        if FTabs.Pages[TargetIndex] = FSplitAnchorTab then
        begin
          FSplitAnchorTab := FSplitSelectedTab;
          FSplitSelectedTab := nil;
          UpdateSplitMenuState;
          FTabs.Invalidate;
          Msg.Result := 0;
          Exit;
        end;
        if FTabs.Pages[TargetIndex] = FTabs.ActivePage then
        begin
          FSplitAnchorTab := nil;
          FSplitSelectedTab := nil;
          UpdateSplitMenuState;
          FTabs.Invalidate;
          Msg.Result := 0;
          Exit;
        end;
      end;
      // Grafiken niemals fuer eine Teilung markieren oder einsetzen.
      if not IsSplitPDFTab(FTabs.Pages[TargetIndex]) or
         ((FSplitHost = nil) and not IsSplitPDFTab(FTabs.ActivePage)) then
      begin
        Msg.Result := 0;
        Exit;
      end;
      // In einer bestehenden Teilung ersetzt Strg+Klick das aktive PDF.
      if FSplitHost <> nil then
      begin
        ReplaceSplitPane(FTabs.Pages[TargetIndex]);
        Msg.Result := 0;
        Exit;
      end;
      FSplitAnchorTab := FTabs.ActivePage;
      FSplitSelectedTab := FTabs.Pages[TargetIndex];
      UpdateSplitMenuState;
      FSplitShiftTab := -1;
      FTabs.Invalidate;
      Msg.Result := 0;
      Exit;
    end;
  end;
  // Normaler Klick beginnt stets eine neue Auswahl. Auch ein Klick auf
  // die bereits aktive Registerkarte loest kein OnChange aus; daher hier.
  if (Msg.Msg = WM_LBUTTONDOWN) and (GetKeyState(VK_CONTROL) >= 0) and
     (FSplitHost = nil) then
  begin
    LocalP := Point(SmallInt(LOWORD(Msg.LParam)),
                    SmallInt(HIWORD(Msg.LParam)));
    if FTabs.IndexOfTabAt(LocalP.X, LocalP.Y) >= 0 then
    begin
      FSplitAnchorTab := nil;
      FSplitSelectedTab := nil;
      UpdateSplitMenuState;
      FTabs.Invalidate;
    end;
  end;
  // TPageControl.OnDblClick ist protected. Den Doppelklick daher
  // direkt im bereits vorhandenen WindowProc-Hook behandeln.
  if Msg.Msg = WM_LBUTTONDBLCLK then
  begin
    LocalP := Point(SmallInt(LOWORD(Msg.LParam)),
                    SmallInt(HIWORD(Msg.LParam)));
    if FTabs.IndexOfTabAt(LocalP.X, LocalP.Y) >= 0 then
    begin
      TabDoubleClick(FTabs);
      Msg.Result := 0;
      Exit;
    end;
  end;
  if (Msg.Msg = WM_CONTEXTMENU) or (Msg.Msg = WM_RBUTTONUP) then
  begin
    // WM_CONTEXTMENU kommt vom nativen Windows-Tabcontrol auch dann,
    // wenn der Mauszeiger rechts von der letzten Registerkarte steht.
    if Msg.Msg = WM_RBUTTONUP then
    begin
      LocalP := Point(SmallInt(LOWORD(Msg.LParam)),
                      SmallInt(HIWORD(Msg.LParam)));
      P := FTabs.ClientToScreen(LocalP);
    end
    else
    begin
      GetCursorPos(P);
      LocalP := FTabs.ScreenToClient(P);
    end;
    // Nur der obere Registerstreifen, nicht die PDF-Anzeigeflaeche.
    // Die native Tab-Steuerung liefert die untere Kante des ersten Reiters.
    // Kein Zugriff auf die protected Eigenschaft DisplayRect.
    TabStripBottom := MulDiv(30, Screen.PixelsPerInch, 96);
    if (FTabs.PageCount > 0) and
       (SendMessage(FTabs.Handle, TCM_GETITEMRECT, 0, LPARAM(@TabRect)) <> 0) then
      TabStripBottom := TabRect.Bottom;
    if (LocalP.X >= 0) and (LocalP.X < FTabs.ClientWidth) and
       (LocalP.Y >= 0) and (LocalP.Y < TabStripBottom) then
    begin
      FTabContextMenu.Popup(P.X, P.Y);
      Msg.Result := 0;
      Exit;
    end;
  end;
  FOriginalTabsWindowProc(Msg);
end;

procedure TPDFTabsForm.DrawPDFTab(Control: TCustomTabControl;
  TabIndex: Integer; const Rect: TRect; Active: Boolean);
var
  R: TRect;
  S: string;
  VisualActive: Boolean;
  CloseR, TextR: TRect;
  CX, CY, Arm: Integer;
  Hovered: Boolean;
  SplitTab: Boolean;
  OldBkMode: Integer;
  OtherR: TRect;
  BorderColor: TColor;
begin
  if (TabIndex < 0) or (TabIndex >= FTabs.PageCount) then Exit;
  R := Rect;
  VisualActive := Active;
  // Während die erste PDF technisch aktiv bleibt, zeigen die Reiter
  // bereits den später vorgesehenen aktiven Tab an. Nur Darstellung.
  if (FDeferredActivePDF <> nil) and
     (FDeferredActivePDF.Parent is TTabSheet) and
     (FTabs.PageCount > 1) then
    VisualActive := FTabs.Pages[TabIndex] = TTabSheet(FDeferredActivePDF.Parent);
  // Beide fuer die Zweifensteransicht markierten Registerkarten
  // erhalten dieselbe aktive Darstellung des gewaehlten Designs.
  // Auch nach StartSplit und beim Austausch eines Teilfensters gilt
  // die Markierung fuer beide tatsaechlich angezeigten PDFs.
  if FSplitHost <> nil then
    SplitTab := (FTabs.Pages[TabIndex] = FSplitLeftTab) or
                (FTabs.Pages[TabIndex] = FSplitRightTab)
  else
    SplitTab := (FSplitAnchorTab <> nil) and
                (FSplitSelectedTab <> nil) and
                ((FTabs.Pages[TabIndex] = FSplitAnchorTab) or
                 (FTabs.Pages[TabIndex] = FSplitSelectedTab));
  VisualActive := VisualActive or SplitTab;
  // Die native aktive Registerkarte ist einige Pixel hoeher als die
  // zweite Strg-markierte. Beide Auswahlreiter auf dieselbe sichtbare
  // Ober- und Unterkante zeichnen, ohne ihre Breite zu veraendern.
  if SplitTab then
  begin
    if (FSplitHost <> nil) and (FSplitLeftTab <> nil) and
       (FSplitRightTab <> nil) then
    begin
      if FTabs.Pages[TabIndex] = FSplitLeftTab then
        OtherR := FTabs.TabRect(FSplitRightTab.PageIndex)
      else
        OtherR := FTabs.TabRect(FSplitLeftTab.PageIndex);
    end
    else if (FSplitAnchorTab <> nil) and (FSplitSelectedTab <> nil) then
    begin
      if FTabs.Pages[TabIndex] = FSplitAnchorTab then
        OtherR := FTabs.TabRect(FSplitSelectedTab.PageIndex)
      else
        OtherR := FTabs.TabRect(FSplitAnchorTab.PageIndex);
    end
    else
      OtherR := R;
    // OwnerDraw receives different rectangles for the native selected tab.
    // Use the same vertical extent for both selected tabs without changing widths.
    R.Top := Min(R.Top, OtherR.Top);
    R.Bottom := Max(R.Bottom, OtherR.Bottom);
  end;
  if VisualActive then
  begin
    if FDesignIndex = 3 then
    begin
      FTabs.Canvas.Brush.Color := RGB(192, 192, 192);
      FTabs.Canvas.Font.Color := clBlack;
    end
    else if FDesignIndex = 2 then
    begin
      FTabs.Canvas.Brush.Color := RGB(72, 83, 101);
      FTabs.Canvas.Font.Color := clWhite;
    end
    else if FDesignIndex = 4 then
    begin
      FTabs.Canvas.Brush.Color := RGB(53, 57, 65);
      FTabs.Canvas.Font.Color := clWhite;
    end
    else if FDesignIndex = 5 then
    begin
      FTabs.Canvas.Brush.Color := RGB(176, 207, 235);
      FTabs.Canvas.Font.Color := RGB(24, 55, 88);
    end
    else if FDesignIndex = 1 then
    begin
      FTabs.Canvas.Brush.Color := RGB(219, 232, 247);
      FTabs.Canvas.Font.Color := RGB(35, 48, 65);
    end
    else
    begin
      FTabs.Canvas.Brush.Color := RGB(211, 231, 249);
      FTabs.Canvas.Font.Color := RGB(25, 63, 99);
    end;
    FTabs.Canvas.Font.Style := [fsBold];
  end
  else
  begin
    if FDesignIndex = 3 then
    begin
      FTabs.Canvas.Brush.Color := RGB(212, 208, 200);
      FTabs.Canvas.Font.Color := clBlack;
    end
    else if FDesignIndex = 2 then
    begin
      FTabs.Canvas.Brush.Color := RGB(51, 55, 62);
      FTabs.Canvas.Font.Color := clWhite;
    end
    else if FDesignIndex = 4 then
    begin
      FTabs.Canvas.Brush.Color := RGB(30, 32, 37);
      FTabs.Canvas.Font.Color := clWhite;
    end
    else if FDesignIndex = 5 then
    begin
      FTabs.Canvas.Brush.Color := RGB(190, 214, 237);
      FTabs.Canvas.Font.Color := RGB(37, 70, 102);
    end
    else if FDesignIndex = 1 then
    begin
      FTabs.Canvas.Brush.Color := RGB(230, 236, 245);
      FTabs.Canvas.Font.Color := RGB(65, 79, 97);
    end
    else
    begin
      FTabs.Canvas.Brush.Color := RGB(229, 233, 238);
      FTabs.Canvas.Font.Color := RGB(69, 78, 88);
    end;
    FTabs.Canvas.Font.Style := [];
  end;
  FTabs.Canvas.FillRect(R);
  // Statt einer zusaetzlichen Akzentlinie erhalten beide markierten
  // Registerkarten dieselbe geschlossene Kontur. Die Tab-Breite bleibt
  // unveraendert und die Beschriftung wird transparent gezeichnet.
  if SplitTab then
  begin
    if FDesignIndex in [2, 4] then
      BorderColor := RGB(133, 153, 179)
    else if FDesignIndex = 3 then
      BorderColor := RGB(115, 115, 115)
    else
      BorderColor := RGB(107, 142, 174);
    FTabs.Canvas.Brush.Style := bsClear;
    FTabs.Canvas.Pen.Style := psSolid;
    FTabs.Canvas.Pen.Width := 1;
    FTabs.Canvas.Pen.Color := BorderColor;
    FTabs.Canvas.Rectangle(R.Left, R.Top, R.Right, R.Bottom);
    FTabs.Canvas.Brush.Style := bsSolid;
  end
  else if FDesignIndex = 3 then
    DrawEdge(FTabs.Canvas.Handle, R, BDR_RAISEDINNER or BDR_RAISEDOUTER, BF_RECT);
  S := FTabs.Pages[TabIndex].Caption;
  CloseR := TabCloseRect(TabIndex);
  TextR := R;
  Inc(TextR.Left, MulDiv(9, CurrentPPI, 96));
  TextR.Right := CloseR.Left - MulDiv(5, CurrentPPI, 96);
  // DrawText darf keine weisse Windows-Hintergrundflaeche hinter
  // der Beschriftung zeichnen. Die Tab-Farbe bleibt durchgehend sichtbar.
  OldBkMode := SetBkMode(FTabs.Canvas.Handle, TRANSPARENT);
  try
    DrawText(FTabs.Canvas.Handle, PChar(S), Length(S), TextR,
      DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_END_ELLIPSIS);
  finally
    SetBkMode(FTabs.Canvas.Handle, OldBkMode);
  end;
  // Chrome-aehnliches Schliessen-X: dezentes X, bei Hover runder
  // Hintergrund und Hand-Cursor. Der gesamte Bereich ist klickbar.
  Hovered := TabIndex = FHoverCloseTabIndex;
  if Hovered then
  begin
    if FDesignIndex = 3 then
      FTabs.Canvas.Brush.Color := RGB(192, 192, 192)
    else
      FTabs.Canvas.Brush.Color := RGB(204, 210, 218);
    FTabs.Canvas.Pen.Style := psClear;
    if FDesignIndex = 3 then
    begin
      FTabs.Canvas.FillRect(CloseR);
      DrawEdge(FTabs.Canvas.Handle, CloseR, EDGE_RAISED, BF_RECT);
    end
    else
    begin
      if FDesignIndex in [2, 4] then
        FTabs.Canvas.Brush.Color := RGB(100, 107, 119)
      else if FDesignIndex = 5 then
        FTabs.Canvas.Brush.Color := RGB(151, 188, 222);
      FTabs.Canvas.RoundRect(CloseR.Left, CloseR.Top, CloseR.Right,
        CloseR.Bottom, MulDiv(7, CurrentPPI, 96), MulDiv(7, CurrentPPI, 96));
    end;
    FTabs.Canvas.Pen.Style := psSolid;
  end;
  CX := (CloseR.Left + CloseR.Right) div 2;
  CY := (CloseR.Top + CloseR.Bottom) div 2;
  Arm := Max(4, MulDiv(5, CurrentPPI, 96));
  if FDesignIndex in [2, 4] then
    FTabs.Canvas.Pen.Color := clWhite
  else if Hovered then
    FTabs.Canvas.Pen.Color := RGB(35, 42, 50)
  else
    FTabs.Canvas.Pen.Color := RGB(93, 101, 111);
  FTabs.Canvas.Pen.Width := Max(1, MulDiv(1, CurrentPPI, 96));
  FTabs.Canvas.MoveTo(CX - Arm, CY - Arm);
  FTabs.Canvas.LineTo(CX + Arm, CY + Arm);
  FTabs.Canvas.MoveTo(CX + Arm, CY - Arm);
  FTabs.Canvas.LineTo(CX - Arm, CY + Arm);
end;

procedure TPDFTabsForm.TabsMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  TabIndex: Integer;
  HintText: string;
  P: TPoint;
  R: TRect;
begin
  // Registerkarten mit linker Maustaste verschieben (erst nach Ziehschwelle).
  if (FDragTabIndex >= 0) and (ssLeft in Shift) then
  begin
    if not FDraggingTab then
      FDraggingTab :=
        (Abs(X - FDragStartPoint.X) >= GetSystemMetrics(SM_CXDRAG)) or
        (Abs(Y - FDragStartPoint.Y) >= GetSystemMetrics(SM_CYDRAG));

    if FDraggingTab then
    begin
      TabsMouseLeave(Sender);
      TabIndex := FTabs.IndexOfTabAt(X, Y);
      if (TabIndex >= 0) and (TabIndex < FTabs.PageCount) and
         (TabIndex <> FDragTabIndex) then
      begin
        // Das TabSheet (und damit die zugehoerige PDF) bleibt erhalten.
        FTabs.Pages[FDragTabIndex].PageIndex := TabIndex;
        FDragTabIndex := TabIndex;
        FTabs.Invalidate;
      end;
      Exit;
    end;
  end;

  // Kein FTabs.Hint: Dieser wuerde auf die PDF-Navigationsleiste vererbt.
  TabIndex := FTabs.IndexOfTabAt(X, Y);
  if (TabIndex < 0) or (TabIndex >= FTabs.PageCount) then
  begin
    TabsMouseLeave(Sender);
    Exit;
  end;

  // Hover nur beim Ueberfahren der X-Klickflaeche aktualisieren.
  var NewHoverCloseTabIndex: Integer;
  NewHoverCloseTabIndex := -1;
  if PtInRect(TabCloseRect(TabIndex), Point(X, Y)) then
    NewHoverCloseTabIndex := TabIndex;
  if NewHoverCloseTabIndex <> FHoverCloseTabIndex then
  begin
    FHoverCloseTabIndex := NewHoverCloseTabIndex;
    FTabs.Invalidate;
  end;
  if FHoverCloseTabIndex >= 0 then
  begin
    FTabs.Cursor := crHandPoint;
    HideTabHint;
    FHintTabIndex := -1;
    Exit;
  end;
  FTabs.Cursor := crDefault;

  if TabIndex = FHintTabIndex then
    Exit;

  HideTabHint;
  FHintTabIndex := TabIndex;
  FTabPreviewIndex := TabIndex;
  FTabPreviewStarted := GetTickCount;
  if FTabPreviewEnabled then
    FTabPreviewTimer.Enabled := True
  else
  begin
    HintText := FTabs.Pages[TabIndex].Hint;
    if HintText = '' then Exit;
    HintText := ExtractFileName(HintText) + sLineBreak + ExtractFilePath(HintText);
    P := FTabs.ClientToScreen(Point(X, Y + MulDiv(20, CurrentPPI, 96)));
    R := FTabHintWindow.CalcHintRect(700, HintText, nil);
    OffsetRect(R, P.X, P.Y);
    FTabHintWindow.ActivateHint(R, HintText);
    FTabHintWatchTimer.Enabled := True;
  end;
end;

procedure TPDFTabsForm.HideTabHint;
begin
  HideTabPreview;
  // THintWindow.Hide allein reicht in der aktuellen Konstellation nicht
  // immer aus, um das Popup-Fenster sofort vom Desktop zu entfernen.
  if Assigned(FTabHintWatchTimer) then
    FTabHintWatchTimer.Enabled := False;
  FHintTabIndex := -1;
  if Assigned(FTabHintWindow) then
  begin
    FTabHintWindow.Hide;
    if FTabHintWindow.HandleAllocated then
      Winapi.Windows.ShowWindow(FTabHintWindow.Handle, SW_HIDE);
  end;
end;

procedure TPDFTabsForm.HideTabPreview;
begin
  if FTabPreviewTimer <> nil then FTabPreviewTimer.Enabled := False;
  FTabPreviewIndex := -1;
  FTabPreviewRequested := '';
  if FTabPreviewForm <> nil then
  begin
    // SetWindowPos(SWP_SHOWWINDOW) does not update VCL's Visible state.
    // Hide the native HWND explicitly so the preview disappears reliably.
    if FTabPreviewForm.HandleAllocated then
      Winapi.Windows.ShowWindow(FTabPreviewForm.Handle, SW_HIDE);
    FTabPreviewForm.Hide;
  end;
end;

procedure TPDFTabsForm.TabPreviewMenuClick(Sender: TObject);
var
  Ini: TIniFile;
begin
  FTabPreviewEnabled := not FTabPreviewEnabled;
  FTabPreviewMenuItem.Checked := FTabPreviewEnabled;
  Ini := TIniFile.Create(TabsIniFileName);
  try
    Ini.WriteBool('Viewer', 'TabPreviewEnabled', FTabPreviewEnabled);
  finally
    Ini.Free;
  end;
  HideTabHint;
end;

procedure TPDFTabsForm.TabPreviewTimerTick(Sender: TObject);
var
  P: TPoint;
  I: Integer;
  FileName, CacheDir, CacheFile, Key: string;
  Hash: UInt64;
  PreviewFile: string;
  PreviewCache: string;
  R: TRect;
  ScreenPos: TPoint;
  WorkArea: TRect;
  GraphicTab: TPDFBrowserForm;
  C: Integer;
begin
  if not FTabPreviewEnabled or (FTabs = nil) or
     (FTabPreviewIndex < 0) or (FTabPreviewIndex >= FTabs.PageCount) then
  begin
    HideTabPreview;
    Exit;
  end;
  GetCursorPos(P);
  P := FTabs.ScreenToClient(P);
  if FTabs.IndexOfTabAt(P.X, P.Y) <> FTabPreviewIndex then
  begin
    HideTabPreview;
    Exit;
  end;
  if GetTickCount - FTabPreviewStarted < 450 then Exit;
  FileName := FTabs.Pages[FTabPreviewIndex].Hint;
  if (FileName = '') or not FileExists(FileName) then
  begin
    HideTabPreview;
    Exit;
  end;
  // Grafikregisterkarten nutzen das bereits angezeigte Bild (inkl. TIFF-Seite
  // und Drehung), ohne PDFium zu starten oder die Originaldatei neu zu laden.
  GraphicTab := nil;
  for C := 0 to FTabs.Pages[FTabPreviewIndex].ControlCount - 1 do
    if FTabs.Pages[FTabPreviewIndex].Controls[C] is TPDFBrowserForm then
    begin
      GraphicTab := TPDFBrowserForm(FTabs.Pages[FTabPreviewIndex].Controls[C]);
      Break;
    end;
  if (GraphicTab <> nil) and not GraphicTab.IsBasicImage then GraphicTab := nil;
  Key := 'TabPreviewAspectV2:' + LowerCase(FileName) + ':' + IntToStr(FileAge(FileName));
  if GraphicTab <> nil then
    Key := Key + ':Graphic:' + GraphicTab.GraphicPreviewKey;
  Hash := UInt64($CBF29CE484222325);
  for I := 1 to Length(Key) do
    Hash := (Hash xor Ord(Key[I])) * UInt64($100000001B3);
  CacheDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'Thumbnails';
  CacheFile := IncludeTrailingPathDelimiter(CacheDir) + IntToHex(Hash, 16) + '.bmp';
  if (GraphicTab <> nil) and not FileExists(CacheFile) then
  begin
    // Nur einmal bei Bedarf eine maximal 200x200 grosse Vorschau erzeugen.
    // VCL-Grafikobjekte duerfen nicht aus dem PDF-Renderthread gelesen werden.
    try
      if not GraphicTab.SaveGraphicPreview(CacheFile) then Exit;
    except
      Exit; // Vorschau optional; niemals die Anzeige unterbrechen.
    end;
  end;
  if not FileExists(CacheFile) then
  begin
    if FTabPreviewRequested <> FileName then
    begin
      FTabPreviewRequested := FileName;
      PreviewFile := FileName;
      PreviewCache := CacheFile;
      TThread.CreateAnonymousThread(
        procedure
        var
          Doc: TFreePDF64PDFiumCore;
          Bmp: TBitmap;
          PageW, PageH: Single;
          RenderW, RenderH: Integer;
        begin
          Doc := nil;
          Bmp := TBitmap.Create;
          try
            try
              Doc := TFreePDF64PDFiumCore.Create;
              Doc.OpenFile(PreviewFile);
              if Doc.PageCount > 0 then
              begin
                Bmp.PixelFormat := pf24bit;
                // PDF-Seitenverhaeltnis wie bei den Miniaturansichten erhalten.
                if not Doc.PageSize(0, PageW, PageH) then Exit;
                if (PageW <= 0) or (PageH <= 0) then Exit;
                RenderW := 200;
                RenderH := Max(1, Round(RenderW * PageH / PageW));
                if RenderH > 200 then
                begin
                  RenderH := 200;
                  RenderW := Max(1, Round(RenderH * PageW / PageH));
                end;
                Doc.RenderPage(0, Bmp, RenderW, RenderH);
                ForceDirectories(ExtractFilePath(PreviewCache));
                Bmp.SaveToFile(PreviewCache + '.' + IntToStr(GetCurrentThreadId) + '.tmp.bmp');
                RenameFile(PreviewCache + '.' + IntToStr(GetCurrentThreadId) + '.tmp.bmp', PreviewCache);
              end;
            except
              // Preview is optional and must never interrupt the viewer.
            end;
          finally
            Doc.Free;
            Bmp.Free;
          end;
        end).Start;
    end;
    Exit;
  end;
  if FTabPreviewForm = nil then
  begin
    FTabPreviewForm := TForm.CreateNew(Self);
    // Prevent VCL from selecting a default position on the first Show.
    FTabPreviewForm.Position := poDesigned;
    FTabPreviewForm.BorderStyle := bsNone;
    FTabPreviewForm.FormStyle := fsStayOnTop;
    FTabPreviewForm.Width := MulDiv(152, CurrentPPI, 96);
    FTabPreviewForm.Height := MulDiv(210, CurrentPPI, 96);
    FTabPreviewForm.Color := clWhite;
    FTabPreviewTitle := TLabel.Create(FTabPreviewForm);
    FTabPreviewTitle.Parent := FTabPreviewForm;
    FTabPreviewTitle.SetBounds(MulDiv(8, CurrentPPI, 96), MulDiv(6, CurrentPPI, 96),
      FTabPreviewForm.Width - MulDiv(16, CurrentPPI, 96), MulDiv(20, CurrentPPI, 96));
    FTabPreviewTitle.AutoSize := False;
    FTabPreviewTitle.EllipsisPosition := epEndEllipsis;
    FTabPreviewImage := TImage.Create(FTabPreviewForm);
    FTabPreviewImage.Parent := FTabPreviewForm;
    FTabPreviewImage.SetBounds(MulDiv(8, CurrentPPI, 96), MulDiv(49, CurrentPPI, 96),
      FTabPreviewForm.Width - MulDiv(16, CurrentPPI, 96),
      FTabPreviewForm.Height - MulDiv(57, CurrentPPI, 96));
    FTabPreviewImage.Proportional := True;
    FTabPreviewImage.Center := True;
    FTabPreviewImage.Stretch := True;
    FTabPreviewPath := TLabel.Create(FTabPreviewForm);
    FTabPreviewPath.Parent := FTabPreviewForm;
    FTabPreviewPath.AutoSize := False;
    FTabPreviewPath.EllipsisPosition := epPathEllipsis;
    FTabPreviewPath.ShowHint := True;
    FTabPreviewPath.SetBounds(MulDiv(8, CurrentPPI, 96),
      MulDiv(27, CurrentPPI, 96),
      FTabPreviewForm.Width - MulDiv(16, CurrentPPI, 96), MulDiv(18, CurrentPPI, 96));
  end;
  if not Winapi.Windows.IsWindowVisible(FTabPreviewForm.Handle) then
  begin
    try
      FTabPreviewImage.Picture.LoadFromFile(CacheFile);
    except
      Exit;
    end;
    // Browser-like compact preview; adapt its shape to the first PDF page.
    if FTabPreviewImage.Picture.Width > FTabPreviewImage.Picture.Height then
    begin
      FTabPreviewForm.Width := MulDiv(200, CurrentPPI, 96);
      FTabPreviewForm.Height := MulDiv(166, CurrentPPI, 96);
    end
    else
    begin
      FTabPreviewForm.Width := MulDiv(152, CurrentPPI, 96);
      FTabPreviewForm.Height := MulDiv(210, CurrentPPI, 96);
    end;
    FTabPreviewTitle.SetBounds(MulDiv(8, CurrentPPI, 96), MulDiv(6, CurrentPPI, 96),
      FTabPreviewForm.Width - MulDiv(16, CurrentPPI, 96), MulDiv(20, CurrentPPI, 96));
    FTabPreviewImage.SetBounds(MulDiv(8, CurrentPPI, 96), MulDiv(49, CurrentPPI, 96),
      FTabPreviewForm.Width - MulDiv(16, CurrentPPI, 96),
      FTabPreviewForm.Height - MulDiv(57, CurrentPPI, 96));
    FTabPreviewPath.SetBounds(MulDiv(8, CurrentPPI, 96),
      MulDiv(27, CurrentPPI, 96),
      FTabPreviewForm.Width - MulDiv(16, CurrentPPI, 96), MulDiv(18, CurrentPPI, 96));
    FTabPreviewPath.Caption := ExtractFilePath(FileName);
    FTabPreviewPath.Hint := ExtractFilePath(FileName);
    FTabPreviewTitle.Caption := ExtractFileName(FileName);
    R := FTabs.TabRect(FTabPreviewIndex);
    ScreenPos := FTabs.ClientToScreen(Point(R.Left, R.Bottom));
    // Position on the monitor containing the hovered tab; clamp on all sides.
    WorkArea := Screen.MonitorFromPoint(ScreenPos).WorkareaRect;
    // Set the final screen coordinates on the actual HWND, including the
    // first display. Do not call Visible := True beforehand: that triggers
    // VCL's initial placement and may move the popup to the monitor corner.
    SetWindowPos(FTabPreviewForm.Handle, HWND_TOPMOST,
      Max(WorkArea.Left, Min(ScreenPos.X, WorkArea.Right - FTabPreviewForm.Width)),
      Max(WorkArea.Top, Min(ScreenPos.Y, WorkArea.Bottom - FTabPreviewForm.Height)),
      FTabPreviewForm.Width, FTabPreviewForm.Height,
      SWP_NOACTIVATE or SWP_SHOWWINDOW);
  end;
  FTabPreviewTimer.Enabled := False;
  FTabHintWatchTimer.Enabled := True;
end;

procedure TPDFTabsForm.TabHintWatchTimerTick(Sender: TObject);
var
  CursorPos: TPoint;
  I: Integer;
  TabRect: TRect;
  TopLeft, BottomRight: TPoint;
  CursorOverTab: Boolean;
begin
  if (not Assigned(FTabHintWindow)) or (not Assigned(FTabs)) or
     (not FTabs.HandleAllocated) then
  begin
    HideTabHint;
    Exit;
  end;

  if not GetCursorPos(CursorPos) then Exit;
  CursorOverTab := False;
  for I := 0 to FTabs.PageCount - 1 do
  begin
    TabRect := FTabs.TabRect(I);
    TopLeft := FTabs.ClientToScreen(Point(TabRect.Left, TabRect.Top));
    BottomRight := FTabs.ClientToScreen(Point(TabRect.Right, TabRect.Bottom));
    TabRect := Rect(TopLeft.X, TopLeft.Y, BottomRight.X, BottomRight.Y);
    if PtInRect(TabRect, CursorPos) then
    begin
      CursorOverTab := True;
      Break;
    end;
  end;

  if not CursorOverTab then
  begin
    HideTabHint;
    if FHoverCloseTabIndex <> -1 then
    begin
      FHoverCloseTabIndex := -1;
      FTabs.Invalidate;
    end;
    FTabs.Cursor := crDefault;
    FTrackingTabsMouseLeave := False;
  end;
end;

procedure TPDFTabsForm.TabsMouseLeave(Sender: TObject);
begin
  HideTabHint;
  if FHoverCloseTabIndex <> -1 then
  begin
    FHoverCloseTabIndex := -1;
    FTabs.Invalidate;
  end;
  FTabs.Cursor := crDefault;
end;

procedure TPDFTabsForm.TabsChanging(Sender: TObject; var AllowChange: Boolean);
begin
  
  
end;

procedure TPDFTabsForm.TabFitTimerTick(Sender: TObject);
var
  PDF: TPDFBrowserForm;
begin
  FTabFitTimer.Enabled := False;
  if (FTabs = nil) or (FTabs.ActivePage = nil) or
     (FTabs.ActivePage <> FTabFitPendingPage) or
     ((FSplitHost <> nil) and FSplitHost.Visible) or FAddingPDF then
  begin
    FTabFitPendingPage := nil;
    FTabFitRetryCount := 0;
    Exit;
  end;

  // Kein erzwungenes Realign beim normalen Registerwechsel.
  // RefitPDFOnTabActivation prueft die Viewport-Groesse selbst.
  PDF := PDFInTab(FTabs.ActivePage);
  if IsImageTabFile(FTabs.ActivePage) then
  begin
    FTabFitPendingPage := nil;
    FTabFitRetryCount := 0;
    Exit;
  end;
  if (PDF = nil) or not PDF.PDFNavigationSucceeded then
  begin
    // Ein neu aktivierter Tab kann nach 75 ms noch asynchron laden.
    // Die Anpassung nicht verwerfen, sondern begrenzt nachholen.
    Inc(FTabFitRetryCount);
    if FTabFitRetryCount < 40 then
      FTabFitTimer.Enabled := True
    else
    begin
      FTabFitPendingPage := nil;
      FTabFitRetryCount := 0;
    end;
    Exit;
  end;

  FTabFitPendingPage := nil;
  FTabFitRetryCount := 0;
  PDF.RefitPDFOnTabActivation;
end;

procedure TPDFTabsForm.TabsChange(Sender: TObject);
var
  TabIndex, ControlIndex: Integer;
  Tab: TTabSheet;
begin
  // Technischer Registerwechsel beim Schliessen: keine Initialisierung
  // oder Anzeige eines bislang ungeladenen PDF-Viewers.
  if FAddingPDF then Exit;
  
  // Grafikregister sind eigenstaendige Bildansichten. Beim Wechsel keine
  // PDF-spezifischen Aktualisierungen, Ladeauftraege oder Refit-Timer ausfuehren.
  // Die vorhandene TImage-Instanz bleibt dabei im jeweiligen Tab erhalten.
  if (FTabs <> nil) and (FTabs.ActivePage <> nil) and
     IsImageTabFile(FTabs.ActivePage) then
  begin
    if FActivationTimer <> nil then FActivationTimer.Enabled := False;
    FDeferredActivePDF := nil;
    if FTabFitTimer <> nil then FTabFitTimer.Enabled := False;
    FTabFitPendingPage := nil;
    FTabFitRetryCount := 0;
    for TabIndex := 0 to FTabs.PageCount - 1 do
    begin
      Tab := FTabs.Pages[TabIndex];
      if Tab <> FTabs.ActivePage then
        for ControlIndex := 0 to Tab.ControlCount - 1 do
          if Tab.Controls[ControlIndex] is TPDFBrowserForm then
            TPDFBrowserForm(Tab.Controls[ControlIndex]).HideLoadingHintForInactiveTab;
    end;
    if (PDFInTab(FTabs.ActivePage) <> nil) and
       not PDFInTab(FTabs.ActivePage).Visible then
      PDFInTab(FTabs.ActivePage).Show;
    FSplitLastSelectedTab := FTabs.ActivePage;
    UpdateSplitMenuState;
    UpdateWelcomeView;
    Exit;
  end;

  // Fallback fuer native Windows-Tabcontrols: Der Reiterwechsel kann
  // stattfinden, ohne dass FTabs.WindowProc ein WM_LBUTTONDOWN sieht.
  // OnChange wird jedoch nach der nativen Auswahl ausgeloest.
  if not FAddingPDF then
  begin
    if (GetKeyState(VK_CONTROL) < 0) and
       (FSplitLastSelectedTab <> nil) and
       (FSplitLastSelectedTab.PageControl = FTabs) and
       (FTabs.ActivePage <> nil) and
       (FTabs.ActivePage <> FSplitLastSelectedTab) then
    begin
      Tab := FTabs.ActivePage;
      if not IsSplitPDFTab(FSplitLastSelectedTab) or
         not IsSplitPDFTab(Tab) then
      begin
        FSplitLastSelectedTab := Tab;
        FSplitAnchorTab := nil;
        FSplitSelectedTab := nil;
        UpdateSplitMenuState;
        Exit;
      end;
      FSplitAnchorTab := FSplitLastSelectedTab;
      FSplitSelectedTab := Tab;
      UpdateSplitMenuState;
      // Die erste Registerkarte bleibt aktiv; beide werden gleich markiert.
      FAddingPDF := True;
      try FTabs.ActivePage := FSplitAnchorTab;
      finally FAddingPDF := False; end;
      FTabs.Invalidate;
      Exit;
    end;
    FSplitLastSelectedTab := FTabs.ActivePage;
    if (FSplitHost = nil) and (GetKeyState(VK_CONTROL) >= 0) then
    begin
      FSplitAnchorTab := FTabs.ActivePage;
      FSplitSelectedTab := nil;
      UpdateSplitMenuState;
      FTabs.Invalidate;
    end;
  end;

  // Ein normaler Tabwechsel beendet die geteilte Ansicht sicher.
  if (FSplitHost <> nil) and (FTabs.ActivePage <> FSplitLeftTab) then
    StopSplit;
  // Beim Wechsel ALLE Popups der inaktiven PDF-Tabs sofort entfernen.
  // WS_POPUP-Fenster werden sonst unabhaengig von den Tabs angezeigt.
  for TabIndex := 0 to FTabs.PageCount - 1 do
  begin
    Tab := FTabs.Pages[TabIndex];
    if Tab = FTabs.ActivePage then Continue;
    for ControlIndex := 0 to Tab.ControlCount - 1 do
      if Tab.Controls[ControlIndex] is TPDFBrowserForm then
        TPDFBrowserForm(Tab.Controls[ControlIndex]).HideLoadingHintForInactiveTab;
  end;
  if not FAddingPDF then
  begin
    FActivationTimer.Enabled := False;
    FDeferredActivePDF := nil;
  end;
  if (FLeftPDFOverlay <> nil) then
  begin
    if FTabs.ActivePage <> nil then
    begin
      // Overlay direkt im aktiven PDF-Inhaltsbereich, nicht auf der Toolbar.
      
      FLeftPDFOverlay.Parent := FTabs.ActivePage;
      
      // Unter den beiden PDF-Werkzeugleisten, nicht auf deren Buttons.
      FLeftPDFOverlay.SetBounds(MulDiv(4, CurrentPPI, 96),
        MulDiv(85, CurrentPPI, 96), MulDiv(79, CurrentPPI, 96),
        MulDiv(24, CurrentPPI, 96));
      
      
      FLeftPDFOverlay.BringToFront;
      
    end
    else
      FLeftPDFOverlay.Visible := False;
  end;
  
  UpdateSplitMenuState;

  // Beim Mehrfachimport wurden inaktive Tabs absichtlich noch nicht
  // initialisiert. Beim ersten Anwählen muss deshalb der Viewer erzeugt
  // und das PDF-Laden für genau diesen Tab angefordert werden.
  // Bereits erfolgreich geladene PDFs werden nicht erneut geladen.
  if (not FAddingPDF) and (FTabs.ActivePage <> nil) then
    for ControlIndex := 0 to FTabs.ActivePage.ControlCount - 1 do
      if FTabs.ActivePage.Controls[ControlIndex] is TPDFBrowserForm then
      begin
        with TPDFBrowserForm(FTabs.ActivePage.Controls[ControlIndex]) do
        begin
          // Bereits initialisierte Viewer beim Tabwechsel nicht erneut
          // sichtbar schalten oder einen Ladevorgang anfordern.
          if not Visible then
            Show;
          if not PDFNavigationSucceeded then
            RequestPDFLoadFast;
        end;
        Break;
      end;

  RefreshAttachmentPositions;

  UpdateWelcomeView;

  // Erst nach der Aktivierung und dem VCL-Align die Ziel-PDF pruefen.
  // Bei unveraendertem Zoom wird kein Seitenlayout neu aufgebaut.
  // Wiederholte OnChange-Ereignisse derselben Registerkarte duerfen
  // die ausstehende Anpassung nicht staendig neu verzögern.
  if not (FTabFitTimer.Enabled and
          (FTabFitPendingPage = FTabs.ActivePage)) then
  begin
    FTabFitTimer.Enabled := False;
    FTabFitPendingPage := nil;
    if (FTabs.ActivePage <> nil) and
       ((FSplitHost = nil) or not FSplitHost.Visible) and
       (PDFInTab(FTabs.ActivePage) <> nil) then
    begin
      FTabFitPendingPage := FTabs.ActivePage;
      FTabFitRetryCount := 0;
      FTabFitTimer.Enabled := True;
    end;
  end;

  // Nur noch ungeladene PDFs an den asynchronen Lader uebergeben.
  // Ein bereits geladener Tab benoetigt keinen weiteren Lade-Post.
  if (FTabs.ActivePage <> nil) and
     (PDFInTab(FTabs.ActivePage) <> nil) and
     (not PDFInTab(FTabs.ActivePage).PDFNavigationSucceeded) then
    PostMessage(Handle, WM_APP + 193, 0, 0); // Tastaturwechsel.

end;

procedure TPDFTabsForm.WindowMoved(var Msg: TWMMove);
begin
  inherited;
  RememberNormalBounds;
  if WindowState <> wsMinimized then
    RefreshAttachmentPositions;
end;

procedure TPDFTabsForm.WindowResizeSettled(Sender: TObject);
var
  I: Integer;
  Tab: TTabSheet;
  PDF: TPDFBrowserForm;
begin
  FWindowResizeTimer.Enabled := False;
  if (WindowState = wsMinimized) or FFullScreen or (FTabs = nil) then Exit;

  // Im Split-Modus liegen die PDF-Formulare in den beiden Host-Panels.
  if (FSplitHost <> nil) and FSplitHost.Visible then
  begin
    if FSplitLeft <> nil then
      for I := 0 to FSplitLeft.ControlCount - 1 do
        if FSplitLeft.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(FSplitLeft.Controls[I]);
          PDF.RefreshPDFViewport;
          Break;
        end;
    if FSplitRight <> nil then
      for I := 0 to FSplitRight.ControlCount - 1 do
        if FSplitRight.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(FSplitRight.Controls[I]);
          PDF.RefreshPDFViewport;
          Break;
        end;
    Exit;
  end;

  Tab := FTabs.ActivePage;
  if Tab = nil then Exit;
  for I := 0 to Tab.ControlCount - 1 do
    if Tab.Controls[I] is TPDFBrowserForm then
    begin
      TPDFBrowserForm(Tab.Controls[I]).RefreshPDFViewport;
      Break;
    end;
end;

procedure TPDFTabsForm.WindowSized(var Msg: TWMSize);
begin
  inherited;
  RememberNormalBounds;
  if Msg.SizeType = SIZE_MINIMIZED then
  begin
    FWindowResizeTimer.Enabled := False;
    HideAllAttachmentWindows;
  end
  else
  begin
    RefreshAttachmentPositions;
    if (FTabs <> nil) and (FTabs.ActivePage <> nil) and
       (FWindowResizeTimer <> nil) then
    begin
      FWindowResizeTimer.Enabled := False;
      FWindowResizeTimer.Enabled := True;
    end;
  end;
end;

procedure TPDFTabsForm.TabContextPopup(Sender: TObject);
var
  I: Integer;
  Item: TMenuItem;
begin
  // Gemeinsamen Verlauf vor jeder Anzeige neu einlesen.
  LoadClosedPDFs;
  FReopenClosedItem.Clear;
  FReopenClosedItem.Caption := Tr('Geschlossene PDFs wieder öffnen');
  FReopenClosedItem.Enabled := FClosedPDFs.Count > 0;
  for I := FClosedPDFs.Count - 1 downto 0 do
  begin
    Item := TMenuItem.Create(FReopenClosedItem);
    Item.Caption := ExtractFileName(FClosedPDFs[I]);
    Item.Hint := FClosedPDFs[I];
    Item.Tag := I;
    Item.OnClick := ReopenSelectedClosedPDF;
    FReopenClosedItem.Add(Item);
  end;
end;

procedure TPDFTabsForm.ReopenSelectedClosedPDF(Sender: TObject);
var
  Index: Integer;
  FileName: string;
begin
  if not (Sender is TMenuItem) then Exit;
  Index := TMenuItem(Sender).Tag;
  if (Index < 0) or (Index >= FClosedPDFs.Count) then Exit;
  // Bestehende Wiederherstellungsroutine weiterverwenden.
  // Erst nach erfolgreichem Öffnen wird der Eintrag entfernt.
  FileName := FClosedPDFs[Index];
  FClosedPDFs.Delete(Index);
  FClosedPDFs.Add(FileName);
  ReopenLastClosedPDF(Sender);
end;

procedure TPDFTabsForm.ReopenLastClosedPDF(Sender: TObject);
var
  FileName: string;
  PDF: TPDFBrowserForm;
begin
  if FClosedPDFs.Count = 0 then Exit;
  FileName := FClosedPDFs[FClosedPDFs.Count - 1];
  if not FileExists(FileName) then
  begin
    // Fehlenden Eintrag auch dauerhaft aus der Wiederherstellungsliste entfernen.
    UpdateClosedPDFHistory(FileName, False);
    PDFModernMessageDlg(Tr('Die PDF-Datei existiert nicht mehr und wurde aus der Liste entfernt:') +
      sLineBreak + FileName, mtWarning, [mbOK], 0);
    Exit;
  end;
  PDF := TPDFBrowserForm.Create(nil);
      PDF.OnGlobalSearch := GlobalSearchClick;
  try
    PDF.PDFFileName := FileName;
    PDF.StandalonePDFMode := False;
    AddPDF(PDF);
    UpdateClosedPDFHistory(FileName, False);
    BringViewerToForeground;
  except
    PDF.Free;
    raise;
  end;
end;

procedure TPDFTabsForm.CMDialogKey(var Message: TCMDialogKey);
var
  Tab: TTabSheet;
  I: Integer;
  PDF: TPDFBrowserForm;
begin
  // TAB wechselt in der Zweifensteransicht direkt zwischen den PDF-Fenstern.
  if (FSplitHost <> nil) and (Message.CharCode = VK_TAB) and
     (GetKeyState(VK_CONTROL) >= 0) and (GetKeyState(VK_MENU) >= 0) then
  begin
    FSplitActiveRight := not FSplitActiveRight;
    UpdateSplitBorders;
    if FSplitActiveRight then
      PDF := PDFInTab(FSplitRightTab)
    else
      PDF := PDFInTab(FSplitLeftTab);
    if (PDF <> nil) and PDF.CanFocus then PDF.SetFocus;
    Message.Result := 1;
    Exit;
  end;
  if (Message.CharCode = VK_TAB) or (Message.CharCode = VK_SPACE) then
  begin
    if FTabs <> nil then
    begin
      Tab := FTabs.ActivePage;
      if Tab <> nil then
        for I := 0 to Tab.ControlCount - 1 do
          if (Tab.Controls[I] is TPDFBrowserForm) and
             TPDFBrowserForm(Tab.Controls[I]).HandleFormDialogKey(Message.CharCode) then
          begin
            Message.Result := 1;
            Exit;
          end;
    end;
  end;
  inherited;
end;

function TPDFTabsForm.IsShortCut(var Message: TWMKey): Boolean;
var
  Tab: TTabSheet;
  I: Integer;
  PDF: TPDFBrowserForm;
begin
  // Auch dann umschalten, wenn der PDF-Viewer selbst den Tastaturfokus hat.
  if (FSplitHost <> nil) and (Message.CharCode = VK_TAB) and
     (GetKeyState(VK_CONTROL) >= 0) and (GetKeyState(VK_MENU) >= 0) then
  begin
    FSplitActiveRight := not FSplitActiveRight;
    UpdateSplitBorders;
    if FSplitActiveRight then
      PDF := PDFInTab(FSplitRightTab)
    else
      PDF := PDFInTab(FSplitLeftTab);
    if (PDF <> nil) and PDF.CanFocus then PDF.SetFocus;
    Exit(True);
  end;

  // ESC bricht eine vorbereitete Zweifenster-Auswahl ab, ohne Tabs zu schliessen.
  if (Message.CharCode = VK_ESCAPE) and (FSplitHost = nil) and
     (FSplitAnchorTab <> nil) and (FSplitSelectedTab <> nil) and
     (GetKeyState(VK_CONTROL) >= 0) and (GetKeyState(VK_MENU) >= 0) and
     (GetKeyState(VK_SHIFT) >= 0) then
  begin
    FSplitSelectedTab := nil;
    FSplitAnchorTab := FTabs.ActivePage;
    UpdateSplitMenuState;
    FTabs.Invalidate;
    Exit(True);
  end;

  // ESC entfernt zuerst Suchmarkierungen, statt die PDF-Registerkarte zu schliessen.
  if (Message.CharCode = VK_ESCAPE) and not FFullScreen and
     (GetForegroundWindow = Handle) and
     (GetKeyState(VK_CONTROL) >= 0) and (GetKeyState(VK_MENU) >= 0) and
     (GetKeyState(VK_SHIFT) >= 0) then
  begin
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(Tab.Controls[I]);
          if PDF.HasPDFSearchHighlights then
          begin
            PDF.ClearPDFSearchHighlights;
            Exit(True);
          end;
          Break;
        end;
  end;
  if (Message.CharCode = VK_F1) and (GetForegroundWindow = Handle) and
     (GetKeyState(VK_CONTROL) >= 0) and (GetKeyState(VK_MENU) >= 0) and
     (GetKeyState(VK_SHIFT) >= 0) then
  begin
    ShowViewerHelp(Self);
    Exit(True);
  end;
  if (Message.CharCode = Ord('W')) and (GetForegroundWindow = Handle) and
     (GetKeyState(VK_CONTROL) < 0) and (GetKeyState(VK_MENU) >= 0) and
     (GetKeyState(VK_SHIFT) >= 0) then
  begin
    CloseActive(Self);
    Exit(True);
  end;
  // Im Vollbild ist das PDF-Formular direkt an Self angehaengt,
  // nicht mehr an das TabSheet. Deshalb separat behandeln.
  if FFullScreen and (FFullScreenPDF <> nil) and
     (GetForegroundWindow = Handle) and (GetKeyState(VK_CONTROL) < 0) and
     (GetKeyState(VK_MENU) >= 0) and
     (Message.CharCode in [VK_OEM_PLUS, VK_ADD, VK_OEM_MINUS, VK_SUBTRACT]) then
  begin
    FFullScreenPDF.ZoomPDF(Message.CharCode in [VK_OEM_PLUS, VK_ADD]);
    Exit(True);
  end;
  // Browser-typischer Zoom: Strg+Plus, Strg+Minus und Ziffernblock.
  if (GetForegroundWindow = Handle) and (GetKeyState(VK_CONTROL) < 0) and
     (GetKeyState(VK_MENU) >= 0) and
     (Message.CharCode in [VK_OEM_PLUS, VK_ADD, VK_OEM_MINUS, VK_SUBTRACT]) then
  begin
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(Tab.Controls[I]);
          PDF.ZoomPDF(Message.CharCode in [VK_OEM_PLUS, VK_ADD]);
          Exit(True);
        end;
  end;
  // F11 auch dann erfassen, wenn eine Schaltfläche oder PDF-Seite den Fokus hat.
  if (Message.CharCode = VK_F11) and (GetForegroundWindow = Handle) then
  begin
    ToggleFullScreen;
    Exit(True);
  end;
  // ESC verlässt im Vollbild zuerst den Vollbildmodus, statt den Tab zu schließen.
  if (Message.CharCode = VK_ESCAPE) and FFullScreen and
     (GetForegroundWindow = Handle) then
  begin
    ToggleFullScreen;
    Exit(True);
  end;
  // F3/Shift+F3 zentral behandeln, auch wenn eine Toolbar-Schaltfläche
  // oder die Registerkarte den Tastaturfokus hat.
  if (Message.CharCode = VK_F3) and (GetForegroundWindow = Handle) and
     (GetKeyState(VK_CONTROL) >= 0) and (GetKeyState(VK_MENU) >= 0) then
  begin
    // Im geteilten Modus ist das PDF unter dem aktiven Teilfenster
    // massgeblich; die PDF-Formulare liegen dort nicht direkt im Tab.
    if FSplitHost <> nil then
    begin
      if FSplitActiveRight then
        PDF := PDFInTab(FSplitRightTab)
      else
        PDF := PDFInTab(FSplitLeftTab);
      if PDF <> nil then
      begin
        if GetKeyState(VK_SHIFT) < 0 then
          PDF.NextPDFSearchMatch(-1)
        else
          PDF.NextPDFSearchMatch(1);
        Exit(True);
      end;
    end;
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(Tab.Controls[I]);
          if GetKeyState(VK_SHIFT) < 0 then
            PDF.NextPDFSearchMatch(-1)
          else
            PDF.NextPDFSearchMatch(1);
          Exit(True);
        end;
  end;
  // Nur die aktive PDF-Anzeige darf diese Kürzel behandeln.
  // Keine globale Registrierung für Strg+A: so bleibt das Hauptprogramm unabhängig.
  if (GetForegroundWindow = Handle) and
     (GetKeyState(VK_CONTROL) < 0) and
     (GetKeyState(VK_MENU) >= 0) and
     (Message.CharCode in [Ord('A'), Ord('C'), Ord('F')]) then
  begin
    // In Eingabefeldern haben Strg+A/Strg+C die normalen Windows-Funktionen.
    if (Message.CharCode in [Ord('A'), Ord('C')]) and
       (Screen.ActiveControl is TCustomEdit) then
      Exit(inherited IsShortCut(Message));
    // Strg+A bleibt für die übliche Funktion "Alles auswählen" reserviert.
    // Nur Strg+Umschalt+A öffnet die Registerkartensuche.
    if Message.CharCode = Ord('A') then
    begin
      if GetKeyState(VK_SHIFT) < 0 then
      begin
        // Bei erfolgreicher Hotkey-Registrierung verarbeitet WM_HOTKEY
        // die Kombination auch bei Fokus im separaten Suchfenster.
        if not FLocalTabSearchHotkeyRegistered then
          TabSearchClick(FTabSearchButton);
        Exit(True);
      end;
      Tab := FTabs.ActivePage;
      if Tab <> nil then
        for I := 0 to Tab.ControlCount - 1 do
          if Tab.Controls[I] is TPDFBrowserForm then
          begin
            TPDFBrowserForm(Tab.Controls[I]).SelectAllPDFText;
            Exit(True);
          end;
      Exit(True);
    end;
    if Message.CharCode = Ord('C') then
    begin
      Tab := FTabs.ActivePage;
      if Tab <> nil then
        for I := 0 to Tab.ControlCount - 1 do
          if Tab.Controls[I] is TPDFBrowserForm then
          begin
            TPDFBrowserForm(Tab.Controls[I]).CopyPDFText;
            Exit(True);
          end;
      Exit(True);
    end;
    if GetKeyState(VK_SHIFT) < 0 then
      Exit(inherited IsShortCut(Message));
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(Tab.Controls[I]);
          PDF.ShowPDFSearch;
          Exit(True);
        end;
  end;
  Result := inherited IsShortCut(Message);
end;

procedure TPDFTabsForm.WMRefreshAfterFullScreen(var Msg: TMessage);
var
  Tab: TTabSheet;
  I: Integer;
begin
  // Erst nach der Wiederherstellung der Fenster-/Tab-Geometrie rendern.
  if FFullScreen then
  begin
    if FFullScreenPDF <> nil then
      FFullScreenPDF.RefreshPDFViewport;
    Exit;
  end;
  Tab := FTabs.ActivePage;
  if Tab = nil then Exit;
  for I := 0 to Tab.ControlCount - 1 do
    if Tab.Controls[I] is TPDFBrowserForm then
    begin
      TPDFBrowserForm(Tab.Controls[I]).RefreshPDFViewport;
      Break;
    end;
end;

procedure TPDFTabsForm.ToggleFullScreen;
var
  M: TMonitor;
  I: Integer;
  Tab: TTabSheet;
  PDF: TPDFBrowserForm;
begin
  // Beim F11-Wechsel werden Parent, Tabs, Toolbar und Fensterrahmen
  // mehrfach geaendert. Die Zwischenzustaende nicht sichtbar zeichnen.
  SendMessage(Handle, WM_SETREDRAW, 0, 0);
  try
    if not FFullScreen then
  begin
    FFullScreenBounds := BoundsRect;
    FFullScreenWindowState := WindowState;
    FFullScreenBorderStyle := BorderStyle;
    FFullScreenTabsVisible := FTabs.Visible;
    FFullScreenEmptyStripVisible := FEmptyTabStrip.Visible;
    FFullScreenPDF := nil;
    FFullScreenPDFTab := nil;
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          FFullScreenPDF := TPDFBrowserForm(Tab.Controls[I]);
          FFullScreenPDFTab := Tab;
          Break;
        end;
    if FFullScreenPDF = nil then Exit;
    M := Screen.MonitorFromWindow(Handle);
    if M = nil then M := Screen.PrimaryMonitor;
    FFullScreen := True;
    // Das PageControl samt Reiterleiste komplett ausblenden. Ein
    // TabHeight von 1 laesst bei 4K/DPI einen sichtbaren Rest stehen.
    PDF := FFullScreenPDF;
    // Die VCL darf das eingebettete PDF-Formular beim Wechsel
    // zwischen TabSheet und Hauptfenster nicht erneut skalieren.
    // Sonst werden Toolbar-Schriften und Schaltflaechen nach F11 kleiner.
    FFullScreenPDFScaled := PDF.Scaled;
    PDF.Scaled := False;
    PDF.DisableAlign;
    try
      PDF.Align := alNone;
      PDF.Parent := Self;
    finally
      PDF.EnableAlign;
    end;
    FViewerHeader.Visible := False;
    FEmptyTabStrip.Visible := False;
    FTabs.Visible := False;
    WindowState := wsNormal;
    BorderStyle := bsNone;
    SetBounds(M.BoundsRect.Left, M.BoundsRect.Top,
      M.BoundsRect.Right - M.BoundsRect.Left,
      M.BoundsRect.Bottom - M.BoundsRect.Top);
    PDF.Align := alClient;
    PDF.BringToFront;
    PDF.SetFullScreenDisplay(True);
    // Erst nach dem Reparenting sind die neuen Clientmasse stabil.
    PostMessage(Handle, WM_APP + 210, 0, 0);
  end
  else
  begin
    FFullScreen := False;
    PDF := FFullScreenPDF;
    if (PDF <> nil) and (FFullScreenPDFTab <> nil) then
    begin
      PDF.SetFullScreenDisplay(False);
      PDF.DisableAlign;
      try
        PDF.Align := alNone;
        PDF.Parent := FFullScreenPDFTab;
        PDF.Align := alClient;
      finally
        PDF.EnableAlign;
      end;
      // Erst nach dem Rueckwechsel den urspruenglichen Zustand
      // wiederherstellen. Keine weitere DPI-Konvertierung ausloesen.
      PDF.Scaled := FFullScreenPDFScaled;
    end;
    BorderStyle := FFullScreenBorderStyle;
    FViewerHeader.Visible := True;
    FEmptyTabStrip.Visible := FFullScreenEmptyStripVisible;
    FTabs.Visible := FFullScreenTabsVisible;
    BoundsRect := FFullScreenBounds;
    WindowState := FFullScreenWindowState;
    // Nach dem Reparenting und der Rueckkehr zu den normalen Bounds
    // sind die Clientmasse erst im naechsten Nachrichtenzyklus stabil.
    PostMessage(Handle, WM_APP + 210, 0, 0);
    FFullScreenPDF := nil;
    FFullScreenPDFTab := nil;
  end;
  finally
    SendMessage(Handle, WM_SETREDRAW, 1, 0);
    // Erst die fertige Vollbild-/Normalansicht neu zeichnen.
    RedrawWindow(Handle, nil, 0,
      RDW_INVALIDATE or RDW_ALLCHILDREN or RDW_NOERASE or RDW_UPDATENOW);
  end;
end;

procedure TPDFTabsForm.ViewerKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Tab: TTabSheet;
  I: Integer;
  PDF: TPDFBrowserForm;
begin
  if (Key = VK_F8) and
     ((Shift = []) or (Shift = [ssShift])) then
  begin
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          if ssShift in Shift then
            TPDFBrowserForm(Tab.Controls[I]).FocusAdjacentFormWidget(-1)
          else
            TPDFBrowserForm(Tab.Controls[I]).FocusAdjacentFormWidget(1);
          Key := 0;
          Exit;
        end;
  end;
  if (Key = VK_F7) and (Shift = []) then
  begin
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          TPDFBrowserForm(Tab.Controls[I]).ShowRequiredFieldsReport;
          Key := 0;
          Exit;
        end;
  end;
  if (Key = Ord('F')) and (Shift = [ssCtrl, ssShift]) then
  begin
    GlobalSearchClick(Self);
    Key := 0;
    Exit;
  end;
  if (Key = VK_F1) and (Shift = []) then
  begin
    ShowViewerHelp(Self);
    Key := 0;
    Exit;
  end;
  // Strg+D oeffnet den vorhandenen PDFium-Dialog fuer Dokumenteigenschaften.
  if (Key = Ord('D')) and (Shift = [ssCtrl]) then
  begin
    Tab := FTabs.ActivePage;
    if (FSplitHost <> nil) and FSplitActiveRight then
      Tab := FSplitRightTab;
    PDF := PDFInTab(Tab);
    if PDF <> nil then
      PDF.ShowDocumentProperties;
    Key := 0;
    Exit;
  end;
  if (Key = Ord('W')) and (Shift = [ssCtrl]) then
  begin
    CloseActive(Self);
    Key := 0;
    Exit;
  end;
  if (Key = Ord('O')) and (Shift = [ssCtrl]) then
  begin
    OpenPDFClick(Self);
    Key := 0;
    Exit;
  end;
  if (Key = VK_F11) and (Shift = []) then
  begin
    ToggleFullScreen;
    Key := 0;
    Exit;
  end;
  if (Key = VK_ESCAPE) and FFullScreen then
  begin
    ToggleFullScreen;
    Key := 0;
    Exit;
  end;
  if (Key = VK_ESCAPE) and (Shift = []) and (FSplitHost = nil) and
     (FSplitAnchorTab <> nil) and (FSplitSelectedTab <> nil) then
  begin
    FSplitSelectedTab := nil;
    FSplitAnchorTab := FTabs.ActivePage;
    UpdateSplitMenuState;
    FTabs.Invalidate;
    Key := 0;
    Exit;
  end;
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Tab := FTabs.ActivePage;
    if Tab <> nil then
      for I := 0 to Tab.ControlCount - 1 do
        if Tab.Controls[I] is TPDFBrowserForm then
        begin
          PDF := TPDFBrowserForm(Tab.Controls[I]);
          if PDF.HasPDFSearchHighlights then
          begin
            PDF.ClearPDFSearchHighlights;
            Key := 0;
            Exit;
          end;
          Break;
        end;
  end;
  if (Key <> VK_ESCAPE) or (Shift <> []) then Exit;
  // Erst eine sichtbare Anlagenliste schließen, danach den PDF-Tab.
  Tab := FTabs.ActivePage;
  if Tab = nil then Exit;
  for I := 0 to Tab.ControlCount - 1 do
    if Tab.Controls[I] is TPDFBrowserForm then
    begin
      PDF := TPDFBrowserForm(Tab.Controls[I]);
      if (PDF.AttachmentWindowHandle <> 0) and
         IsWindow(PDF.AttachmentWindowHandle) and
         IsWindowVisible(PDF.AttachmentWindowHandle) then
      begin
        ShowWindow(PDF.AttachmentWindowHandle, SW_HIDE);
        SetWindowPos(PDF.AttachmentWindowHandle, HWND_NOTOPMOST,
          0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
        Key := 0;
        Exit;
      end;
      Break;
    end;
  CloseActive(Self);
  Key := 0;
end;

procedure TPDFTabsForm.PDFDisposalTimerTick(Sender: TObject);
var
  PDF: TPDFBrowserForm;

  TempPDFFile: string;
  ButtonAncestor: TWinControl;
begin
  FPDFDisposalTimer.Enabled := False;
  if FTabCloseInProgress then
  begin
    if FPendingPDFDisposals.Count > 0 then
      FPDFDisposalTimer.Enabled := True;
    Exit;
  end;
  if FPendingPDFDisposals.Count = 0 then Exit;
  
  PDF := TPDFBrowserForm(FPendingPDFDisposals[0]);
  FPendingPDFDisposals.Delete(0);
  TempPDFFile := PDF.PDFFileName;

  try
    
    
    // Der gemeinsame Split-Button darf nicht mit der Toolbar des
    // zu zerstoerenden PDF-Formulars freigegeben werden.
    if (FTabSplitButton <> nil) and (FLeftPDFOverlay <> nil) then
    begin
      ButtonAncestor := FTabSplitButton.Parent;
      while (ButtonAncestor <> nil) and (ButtonAncestor <> PDF) do
        ButtonAncestor := ButtonAncestor.Parent;
      
      if ButtonAncestor = PDF then
      begin
        
        FTabSplitButton.Parent := FLeftPDFOverlay;
        
      end;
    end;
    PDF.Free;
    
    
    if IsFreePDFTempAttachment(TempPDFFile) then
      ReleasePDFAttachmentTemp(TempPDFFile);
  finally
    if FPendingPDFDisposals.Count > 0 then
      FPDFDisposalTimer.Enabled := True;
  end;
end;

procedure TPDFTabsForm.HomeMenuClick(Sender: TObject);
var
  Question: string;
begin
  // Die Startseite wird bereits angezeigt: nichts schliessen.
  if (FTabs = nil) or (FTabs.PageCount = 0) or FTabCloseInProgress then Exit;

  if SameText(PDFLanguage, 'en') then
    Question := 'Do you want to close all open tabs and return to the start page?'
  else
    Question := 'Möchten Sie alle geöffneten Registerkarten schließen ' +
      'und zur Startseite zurückkehren?';

  if PDFModernMessageDlg(Question, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  // Die bestehende Speicherabfrage bietet Speichern, Nicht speichern
  // und Abbrechen. Bei Abbrechen oder Speicherfehler bleibt alles offen.
  if not ConfirmCloseUnsavedPDFs(False) then Exit;

  if FTabSearchForm <> nil then FTabSearchForm.Hide;
  HideAllAttachmentWindows;
  ClearAllPDFTabs;
  RefreshRecentPDFList;
  UpdateWelcomeView;
end;

procedure TPDFTabsForm.CloseActive(Sender: TObject);
var
  Tab: TTabSheet;
  PDF: TPDFBrowserForm;
  I: Integer;
  ClosedIndex, NextIndex: Integer;
  KeepTab: TTabSheet;

begin

  if FTabCloseInProgress then Exit;
  FTabCloseInProgress := True;
  try
  if (FCloseTargetTab <> nil) and (FCloseTargetTab.PageControl = FTabs) then
    Tab := FCloseTargetTab
  else
    Tab := FTabs.ActivePage;
  if Tab = nil then Exit;

  if not ConfirmCloseUnsavedPDFs(True) then
  begin
    if (FCloseRestoreTab <> nil) and
       (FCloseRestoreTab.PageControl = FTabs) then
      FTabs.ActivePage := FCloseRestoreTab;
    Exit;
  end;
  
  // Beim Schliessen per X auf einem inaktiven Tab die zuvor sichtbare
  // PDF erhalten. Beim Schliessen des aktiven Tabs bleibt die Nachbarwahl.
  if (FTabs.ActivePage <> Tab) then
    KeepTab := FTabs.ActivePage
  else if (FCloseRestoreTab <> nil) and (FCloseRestoreTab <> Tab) and
          (FCloseRestoreTab.PageControl = FTabs) then
    KeepTab := FCloseRestoreTab
  else
    KeepTab := nil;
  ClosedIndex := Tab.PageIndex;
  // Ein noch ausstehender Wechsel darf nicht auf ein geschlossenes PDF zeigen.
  FActivationTimer.Enabled := False;
  FDeferredActivePDF := nil;
  PDF := nil;
  for I := 0 to Tab.ControlCount - 1 do
    if Tab.Controls[I] is TPDFBrowserForm then
    begin
      PDF := TPDFBrowserForm(Tab.Controls[I]);
      Break;
    end;
  if PDF <> nil then
  begin
    if (PDF.PDFFileName <> '') and not IsFreePDFTempAttachment(PDF.PDFFileName) then
    begin

      UpdateClosedPDFHistory(PDF.PDFFileName, True);
      
    end;
    // Vor dem Entfernen des Parent unsichtbar machen. Sonst wird
    // das eingebettete Formular kurz ein eigenstaendiges Fenster
    // und kann das Registerkartenfenster nach hinten verdraengen.

    PDF.Hide;
    
    // Das sichtbare Register sofort entfernen; PDFium wird erst nach
    // Rueckkehr zur Windows-Nachrichtenschleife auf dem UI-Thread freigegeben.
    // Niemals VCL/PDFium-Controls in einem Worker-Thread zerstoeren.
    // Ein eingebettetes Formular darf bis zu seiner Freigabe nicht
    // ohne übergeordnetes Fenster bleiben (VCL: InvalidOperation).
    // Verstecktes PDF-Formular vom Parent loesen.
    // Bei einer VCL-Ausnahme auf das bisherige Verhalten zurueckfallen.
    
    // Eingebettete, noch nie aktivierte PDF-Formulare nicht parentlos machen:
    // Parent := nil kann einen Handle-Wechsel und VCL-Nachrichten ausloesen,
    // waehrend die PDF-Ansicht noch nicht initialisiert wurde.
    // Bis zur verzoegerten Freigabe bleibt Self ein gueltiger Parent.
    PDF.Parent := Self;
    PDF.Visible := False;
    if FPendingPDFDisposals.IndexOf(PDF) < 0 then
      FPendingPDFDisposals.Add(PDF);
    FPDFDisposalTimer.Enabled := True;
    
    // Temporaere Anlagen erst beim tatsaechlichen Freigeben bereinigen.

  end;

  // Reparatur: Das Overlay ist mit Self als Owner erstellt, kann aber
  // als Child des zu schliessenden Tabs durch Tab.Free mitzerstoert werden.
  // Vor dem Freigeben an das langlebige PageControl umhaengen.
  if (FLeftPDFOverlay <> nil) and (FLeftPDFOverlay.Parent = Tab) then
  begin
    
    FLeftPDFOverlay.Visible := False;
    FLeftPDFOverlay.Parent := FTabs;
    
  end;
  // Zielseite aktivieren, solange die zu schliessende Seite noch lebt.
  // FAddingPDF verhindert die normale, hier unerwuenschte Wechsel-Nacharbeit.
  if (FTabs.PageCount > 1) and (FTabs.ActivePage = Tab) then
  begin
    if KeepTab <> nil then
      NextIndex := KeepTab.PageIndex
    else if ClosedIndex < FTabs.PageCount - 1 then
      NextIndex := ClosedIndex + 1
    else
      NextIndex := ClosedIndex - 1;
    
    FAddingPDF := True;
    try
      FTabs.ActivePageIndex := NextIndex;
    finally
      FAddingPDF := False;
    end;
    
  end;
  // Lebensdauer-Fix: vor Tab.Free alle gespeicherten
  // TTabSheet-Zeiger auf die zu zerstoerende Seite entfernen.
  // Nur Zeiger vergleichen; keine potenziell toten Objekte dereferenzieren.
  
  if FSplitLeftTab = Tab then
  begin
    FSplitLeftTab := nil;
    
  end;
  if FSplitRightTab = Tab then
  begin
    FSplitRightTab := nil;
    
  end;
  if FSplitAnchorTab = Tab then
  begin
    FSplitAnchorTab := nil;
    
  end;
  if FSplitSelectedTab = Tab then
  begin
    FSplitSelectedTab := nil;
    
  end;
  if FSplitLastSelectedTab = Tab then
  begin
    FSplitLastSelectedTab := nil;
    
  end;
  if FFullScreenPDFTab = Tab then
  begin
    FFullScreenPDFTab := nil;
    
  end;
  
  
  Tab.Free;

  UpdateTabCount;
  
  if FTabs.PageCount > 0 then
  begin
    // Rechten Nachbarn bevorzugen. Nach Tab.Free rueckt er auf
    // den bisherigen Index nach. Nur beim letzten Tab nach links.
    if KeepTab <> nil then
      NextIndex := KeepTab.PageIndex
    else if ClosedIndex < FTabs.PageCount then
      NextIndex := ClosedIndex
    else
      NextIndex := FTabs.PageCount - 1;
    FAddingPDF := True;
    try
      FTabs.ActivePageIndex := NextIndex;
    finally
      FAddingPDF := False;
    end;

    // Keine PDF-Initialisierung innerhalb des Schliessereignisses.
    // PDFium/VCL kann dabei noch Nachrichten der entfernten Registerkarte
    // verarbeiten. Die Anzeige erfolgt nach Rueckkehr zur Message-Queue
    // ueber die bereits vorhandene WM_APP + 193-Aktivierung.
    // Falls das Overlay zum Schutz vor Tab.Free umgehaengt wurde,
    // nach dem Seitenwechsel wieder an die aktive, lebende Seite binden.
    // Beim Schliessen kein Overlay auf die neue Seite umhaengen:
    // das erzeugt VCL-Parent/Resize-Nachrichten, waehrend Tab.Free
    // und die Seitenaktivierung noch abgewickelt werden.
    // Das Overlay bleibt voruebergehend am langlebigen FTabs.
    // Die normale Aktivierungsnachricht richtet die PDF-Ansicht ein.
    PostMessage(Handle, WM_APP + 193, 0, 0);
    // Nach dem Schliessen die verbleibende PDF wieder aktivieren.
    
    RefreshAttachmentPositions;
    
    // Beim Schliessen eines inaktiven Tabs keinen Fokus erzwingen.
    if (KeepTab = nil) and Visible and HandleAllocated then
    begin
      BringToFront;
      SetForegroundWindow(Handle);
    end;
  end;
  if FTabs.PageCount = 0 then
  begin
    FFirstPDFInitialized := False;
    if PDFTabsExplorerOnlyProcess then
    begin
      if PDFTabsMainFormWasShown then
        Hide
      else
        Close;
    end
    else if Application.MainForm = Self then
      UpdateWelcomeView
    else
      Hide;
  end;
  
  finally
    FTabCloseInProgress := False;
  end;
end;

procedure TPDFTabsForm.TabDoubleClick(Sender: TObject);
var
  P: TPoint;
  TabIndex: Integer;
begin
  // Nur Doppelklick direkt auf einem Register, nicht auf der freien Leiste.
  GetCursorPos(P);
  P := FTabs.ScreenToClient(P);
  TabIndex := FTabs.IndexOfTabAt(P.X, P.Y);
  if (TabIndex < 0) or (TabIndex >= FTabs.PageCount) then Exit;
  FTabs.ActivePageIndex := TabIndex;
  CloseActive(Sender);
end;

procedure TPDFTabsForm.TabMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  
  if Button = mbLeft then
  begin
    FSplitShiftTab := -1;
    if not (ssShift in Shift) then
      FSplitLastSelectedTab := FTabs.ActivePage;
    if ssShift in Shift then
    begin
      FSplitShiftTab := FTabs.IndexOfTabAt(X, Y);
      if not IsSplitPDFTab(FSplitAnchorTab) or
         (FSplitShiftTab < 0) or
         not IsSplitPDFTab(FTabs.Pages[FSplitShiftTab]) then
        FSplitShiftTab := -1;
      FSplitAnchorTab := FTabs.ActivePage;
      FDragTabIndex := -1;
      Exit;
    end;
    FDragTabIndex := FTabs.IndexOfTabAt(X, Y);
    if (FDragTabIndex >= 0) and
       PtInRect(TabCloseRect(FDragTabIndex), Point(X, Y)) then
    begin
      // Fallback, falls das native MouseDown nicht ueber den WindowProc-Hook
      // erfasst wurde. Eine bereits gesicherte Referenz niemals ueberschreiben.
      if (FCloseRestoreTab = nil) and (FTabs.ActivePage <> nil) and
         (FTabs.Pages[FDragTabIndex] <> FTabs.ActivePage) then
        FCloseRestoreTab := FTabs.ActivePage;
      FDragTabIndex := -1;
    end
    else
      FCloseRestoreTab := nil;
    FDragStartPoint := Point(X, Y);
    FDraggingTab := False;
    Exit;
  end;
  if Button <> mbMiddle then Exit;
  for I := 0 to FTabs.PageCount - 1 do
    if PtInRect(FTabs.TabRect(I), Point(X, Y)) then
    begin
      FAddingPDF := True;
      try
        FTabs.ActivePageIndex := I;
      finally
        FAddingPDF := False;
      end;
      CloseActive(Sender);
      Break;
    end;
end;

procedure ShowEmptyPDFViewer;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  CmdLine: string;
begin
  // Vom Hauptprogramm aus einen unabhaengigen Viewer starten. Dieser
  // ueberlebt das Beenden des Hauptprogramms (auch ohne geoeffnete PDF).
  if not PDFTabsExplorerOnlyProcess and
     ((PDFTabsWindow = nil) or not PDFTabsWindow.Visible) then
  begin
    CmdLine := '"' + ParamStr(0) + '" --viewer-empty';
    FillChar(SI, SizeOf(SI), 0);
    SI.cb := SizeOf(SI);
    FillChar(PI, SizeOf(PI), 0);
    if CreateProcess(PChar(ParamStr(0)), PChar(CmdLine), nil, nil,
      False, 0, nil, nil, SI, PI) then
    begin
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
      Exit;
    end;
    PDFModernMessageDlg(Tr('Der eigenständige PDF-Anzeiger konnte nicht gestartet werden.'),
      mtError, [mbOK], 0);
    Exit;
  end;
  if PDFTabsWindow = nil then
    PDFTabsWindow := TPDFTabsForm.Create(Application);
  if not PDFTabsWindow.Visible then
  begin
    PDFTabsWindow.Show;
  end
  else
  begin
    if PDFTabsWindow.WindowState = wsMinimized then
      PDFTabsWindow.WindowState := wsNormal;
    PDFTabsWindow.BringToFront;
  end;
end;

procedure ShowPDFInTabs(APDF: TPDFBrowserForm);
var
  I, J: Integer;
  Existing: TPDFBrowserForm;
  Tab: TTabSheet;
  RequestedFile, RequestedSearch: string;
begin
  if APDF = nil then Exit;
  if PDFTabsWindow = nil then
    PDFTabsWindow := TPDFTabsForm.Create(Application);

  // Zentraler Einstieg fuer ALLE Aufrufer: vorhandenes Viewerfenster
  // wiederverwenden und bereits geoeffnete PDF-Dateien aktivieren.
  RequestedFile := ExpandFileName(APDF.PDFFileName);
  RequestedSearch := APDF.SearchTerm;
  Existing := nil;
  if PDFTabsWindow.FTabs <> nil then
    for I := 0 to PDFTabsWindow.FTabs.PageCount - 1 do
    begin
      Tab := PDFTabsWindow.FTabs.Pages[I];
      if SameText(ExpandFileName(Tab.Hint), RequestedFile) then
      begin
        for J := 0 to Tab.ControlCount - 1 do
          if Tab.Controls[J] is TPDFBrowserForm then
          begin
            Existing := TPDFBrowserForm(Tab.Controls[J]);
            Break;
          end;
        if Existing <> nil then Break;
      end;
    end;

  if Existing <> nil then
  begin
    PDFTabsWindow.ActivatePDF(Existing);
    if RequestedSearch <> '' then
      Existing.SearchTerm := RequestedSearch;
    // Der uebergebene Formularentwurf wird nicht mehr benoetigt.
    APDF.Free;
  end
  else
    PDFTabsWindow.AddPDF(APDF);

  // Auch beim Aufruf aus Hauptprogramm/Suche den PDF-Anzeiger aktivieren.
  // Keine dauerhafte TopMost-Einstellung: andere Fenster bleiben nutzbar.
  if not PDFTabsWindow.FInitialWindowOffscreen then
  begin
    if IsIconic(PDFTabsWindow.Handle) then
      ShowWindow(PDFTabsWindow.Handle, SW_RESTORE);
    PDFTabsWindow.BringToFront;
    SetForegroundWindow(PDFTabsWindow.Handle);
  end;
end;

end.

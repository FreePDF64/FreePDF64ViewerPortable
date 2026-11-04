unit uPDFVisualCompare;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Math, System.Types,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Dialogs,
  Vcl.ComCtrls,
  uFreePDF64PDFiumCore;

// Visueller Seitenvergleich. Veraendert die Original-PDFs nicht.
procedure ShowPDFVisualComparison(AOwner: TComponent;
  const ALeftFile, ARightFile: string; AEnglish: Boolean);

implementation

type
  TCompareWorker = class;

  TCompareForm = class(TForm)
  private
    FLeftCore, FRightCore: TFreePDF64PDFiumCore;
    FLeftImage, FRightImage: TImage;
    FLeftPane, FRightPane: TPanel;
    FLeftBitmap, FRightBitmap: TBitmap;
    FPage: Integer;
    FEnglish: Boolean;
    FInfo: TLabel;
    FPrev, FNext, FPreviousDifference, FNextDifference, FToggle: TButton;
    FRegions: TArray<TRect>;
    FSelectedRegion: Integer;
    FShowMarks: Boolean;
    FBaseLeft, FBaseRight: TBitmap;
    // Keep the last three page comparisons in memory.
    FCachePages: array[0..2] of Integer;
    FCacheLeft, FCacheRight: array[0..2] of TBitmap;
    FCacheRegions: array[0..2] of TArray<TRect>;
    FCacheStamp: array[0..2] of Integer;
    FStamp: Integer;
    FUpdatingLayout: Boolean;
    FWorker: TCompareWorker;
    FCancelButton: TButton;
    FProgress: TProgressBar;
    FClosingAfterCancel: Boolean;
    FLeftFile, FRightFile: string;
    procedure WorkerFinished(Sender: TObject);
    procedure CancelCompare(Sender: TObject);
    procedure CompareCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ShowProgress(AValue: Integer);
    procedure StartComparison;
    procedure ApplyCachedPage;
    procedure SelectDifference(Sender: TObject);
    procedure ToggleMarks(Sender: TObject);
    procedure PaintMarks;
    procedure UpdateSelectedMarks(AOldSelected: Integer);
    procedure ChangePage(Sender: TObject);
    procedure Render;
    procedure LayoutToolbar;
    procedure CompareResize(Sender: TObject);
  public
    constructor CreateCompare(AOwner: TComponent; const ALeftFile,
      ARightFile: string; AEnglish: Boolean);
    destructor Destroy; override;
  end;

  TCompareWorker = class(TThread)
  private
    FForm: TCompareForm;
    FLeftFile, FRightFile: string;
    FPage: Integer;
    FLeft, FRight: TBitmap;
    FRegions: TArray<TRect>;
    FError: string;
    FProgressValue: Integer;
    procedure UpdateProgress;
    procedure ReportProgress(AValue: Integer);
  protected
    procedure Execute; override;
  public
    constructor Create(AForm: TCompareForm; const ALeftFile, ARightFile: string;
      APage: Integer);
    destructor Destroy; override;
  end;

constructor TCompareWorker.Create(AForm: TCompareForm;
  const ALeftFile, ARightFile: string; APage: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FForm := AForm;
  FLeftFile := ALeftFile;
  FRightFile := ARightFile;
  FPage := APage;
  FLeft := TBitmap.Create;
  FRight := TBitmap.Create;
end;

destructor TCompareWorker.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

procedure TCompareWorker.UpdateProgress;
begin
  if FForm <> nil then FForm.ShowProgress(FProgressValue);
end;

procedure TCompareWorker.ReportProgress(AValue: Integer);
begin
  if Terminated then Exit;
  FProgressValue := EnsureRange(AValue, 0, 100);
  Synchronize(UpdateProgress);
end;

constructor TCompareForm.CreateCompare(AOwner: TComponent;
  const ALeftFile, ARightFile: string; AEnglish: Boolean);
var
  TopBar: TPanel;
  CacheIndex: Integer;
begin
  inherited CreateNew(AOwner);
  FEnglish := AEnglish;
  FLeftFile := ALeftFile;
  FRightFile := ARightFile;
  OnCloseQuery := CompareCloseQuery;
  Caption := 'PDF comparison';
  if not FEnglish then Caption := 'PDF-Vergleich';
  // Form dimensions are logical 96-DPI values converted to monitor pixels.
  // Limit the initial window to the available work area on smaller screens.
  Width := Min(Winapi.Windows.MulDiv(1200, CurrentPPI, 96),
    Screen.WorkAreaWidth);
  Constraints.MinWidth := Min(Winapi.Windows.MulDiv(640, CurrentPPI, 96),
    Screen.WorkAreaWidth);
  Constraints.MinHeight := Min(Winapi.Windows.MulDiv(440, CurrentPPI, 96),
    Screen.WorkAreaHeight);
  FShowMarks := True;
  FSelectedRegion := -1;
  Height := Min(Winapi.Windows.MulDiv(850, CurrentPPI, 96),
    Screen.WorkAreaHeight);
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  // Avoid background erasure between scaled TImage repaints on 4K/maximized windows.
  DoubleBuffered := True;
  TopBar := TPanel.Create(Self);
  TopBar.Parent := Self;
  TopBar.Align := alTop;
  TopBar.Height := Winapi.Windows.MulDiv(74, CurrentPPI, 96);
  TopBar.BevelOuter := bvNone;
  FPrev := TButton.Create(Self);
  FPrev.Parent := TopBar;
  FPrev.SetBounds(8, 8, 120, 28);
  FPrev.Caption := '<<';
  FPrev.Hint := 'Previous page';
  if not FEnglish then FPrev.Hint := 'Vorherige Seite';
  FPrev.ShowHint := True;
  FPrev.OnClick := ChangePage;
  FNext := TButton.Create(Self);
  FNext.Parent := TopBar;
  FNext.SetBounds(136, 8, 120, 28);
  FNext.Caption := '>>';
  FNext.Hint := 'Next page';
  if not FEnglish then FNext.Hint := 'Nächste Seite';
  FNext.ShowHint := True;
  FNext.OnClick := ChangePage;
  FPreviousDifference := TButton.Create(Self);
  FPreviousDifference.Parent := TopBar;
  FPreviousDifference.SetBounds(270, 8, 145, 28);
  FPreviousDifference.Caption := 'Previous diff.';
  FPreviousDifference.Hint := 'Previous difference';
  if not FEnglish then
  begin
    FPreviousDifference.Caption := 'Vorheriger';
    FPreviousDifference.Hint := 'Vorheriger Unterschied';
  end;
  FPreviousDifference.ShowHint := True;
  FPreviousDifference.OnClick := SelectDifference;
  FNextDifference := TButton.Create(Self);
  FNextDifference.Parent := TopBar;
  FNextDifference.SetBounds(423, 8, 145, 28);
  FNextDifference.Caption := 'Next diff.';
  FNextDifference.Hint := 'Next difference';
  if not FEnglish then
  begin
    FNextDifference.Caption := 'Nächster';
    FNextDifference.Hint := 'Nächster Unterschied';
  end;
  FNextDifference.ShowHint := True;
  FNextDifference.OnClick := SelectDifference;
  FToggle := TButton.Create(Self);
  FToggle.Parent := TopBar;
  FToggle.SetBounds(576, 8, 155, 28);
  FToggle.OnClick := ToggleMarks;
  FToggle.ShowHint := True;
  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := TopBar;
  FCancelButton.Caption := 'Cancel';
  if not FEnglish then FCancelButton.Caption := 'Abbrechen';
  FCancelButton.OnClick := CancelCompare;
  FCancelButton.Enabled := False;
  FProgress := TProgressBar.Create(Self);
  FProgress.Parent := TopBar;
  FProgress.Min := 0;
  FProgress.Max := 100;
  FProgress.Position := 0;
  FProgress.Visible := False;
  FInfo := TLabel.Create(Self);
  FInfo.Parent := TopBar;
  FInfo.Left := 10;
  FInfo.Top := 48;
  FInfo.AutoSize := False;
  FInfo.EllipsisPosition := epEndEllipsis;
  FLeftPane := TPanel.Create(Self);
  FLeftPane.Parent := Self;
  FLeftPane.Align := alNone;
  FLeftPane.Caption := '';
  FLeftPane.ParentDoubleBuffered := False;
  FLeftPane.DoubleBuffered := True;
  FRightPane := TPanel.Create(Self);
  FRightPane.Parent := Self;
  FRightPane.Align := alNone;
  FRightPane.Caption := '';
  FRightPane.ParentDoubleBuffered := False;
  FRightPane.DoubleBuffered := True;
  FLeftPane.SetBounds(0, TopBar.Height, ClientWidth div 2, ClientHeight - TopBar.Height);
  FRightPane.SetBounds(ClientWidth div 2, TopBar.Height, ClientWidth - ClientWidth div 2, ClientHeight - TopBar.Height);
  FLeftImage := TImage.Create(Self);
  FLeftImage.Parent := FLeftPane;
  FLeftImage.Align := alClient;
  FLeftImage.Proportional := True;
  FLeftImage.Center := True;
  FRightImage := TImage.Create(Self);
  FRightImage.Parent := FRightPane;
  FRightImage.Align := alClient;
  FRightImage.Proportional := True;
  FRightImage.Center := True;
  FLeftBitmap := TBitmap.Create;
  FRightBitmap := TBitmap.Create;
  FBaseLeft := TBitmap.Create;
  FBaseRight := TBitmap.Create;
  for CacheIndex := 0 to 2 do
  begin
    FCachePages[CacheIndex] := -1;
    FCacheLeft[CacheIndex] := TBitmap.Create;
    FCacheRight[CacheIndex] := TBitmap.Create;
    FCacheStamp[CacheIndex] := 0;
  end;
  FLeftCore := TFreePDF64PDFiumCore.Create;
  FRightCore := TFreePDF64PDFiumCore.Create;
  FLeftCore.OpenFile(ALeftFile);
  FRightCore.OpenFile(ARightFile);
  FPage := 0;
  OnResize := CompareResize;
  CompareResize(Self);
  Render;
end;

destructor TCompareForm.Destroy;
var
  CacheIndex: Integer;
begin
  for CacheIndex := 0 to 2 do
  begin
    FCacheLeft[CacheIndex].Free;
    FCacheRight[CacheIndex].Free;
  end;
  FLeftCore.Free;
  FRightCore.Free;
  FBaseLeft.Free;
  FBaseRight.Free;
  FLeftBitmap.Free;
  FRightBitmap.Free;
  inherited;
end;

procedure TCompareForm.CompareResize(Sender: TObject);
var
  MidX, PaneHeight, BarHeight: Integer;
begin
  if FUpdatingLayout then Exit;
  LayoutToolbar;
  if (FLeftPane <> nil) and (FRightPane <> nil) then
  begin
    BarHeight := 0;
    if FPrev <> nil then
      if FPrev.Parent is TWinControl then
        BarHeight := TWinControl(FPrev.Parent).Height;
    MidX := ClientWidth div 2;
    PaneHeight := Max(0, ClientHeight - BarHeight);
    FLeftPane.SetBounds(0, BarHeight, MidX, PaneHeight);
    FRightPane.SetBounds(MidX, BarHeight,
      ClientWidth - MidX, PaneHeight);
  end;
end;

procedure TCompareForm.LayoutToolbar;
var
  Gap, Margin, ButtonH, RowY, LeftPos, BarH, InfoH: Integer;
  WPrev, WNext, WBack, WForward, WToggle, WCancel: Integer;
  TotalWidth: Integer;
  TopBar: TWinControl;

  function ButtonWidth(B: TButton; MinimumLogicalWidth: Integer): Integer;
  begin
    // Use the actual font metrics: translated captions must never be clipped.
    Canvas.Font.Assign(B.Font);
    Result := Max(Winapi.Windows.MulDiv(MinimumLogicalWidth, CurrentPPI, 96),
      Canvas.TextWidth(B.Caption) + Winapi.Windows.MulDiv(24, CurrentPPI, 96));
  end;

  procedure PutButton(B: TButton; AWidth: Integer);
  begin
    B.SetBounds(LeftPos, RowY, AWidth, ButtonH);
    Inc(LeftPos, AWidth + Gap);
  end;
begin
  if (FPrev = nil) or FUpdatingLayout then Exit;
  FUpdatingLayout := True;
  try
    TopBar := FPrev.Parent;
    Gap := Winapi.Windows.MulDiv(6, CurrentPPI, 96);
    Margin := Winapi.Windows.MulDiv(8, CurrentPPI, 96);
    ButtonH := Max(Winapi.Windows.MulDiv(30, CurrentPPI, 96),
      Canvas.TextHeight('Ägjy') + Winapi.Windows.MulDiv(12, CurrentPPI, 96));
    InfoH := Max(Winapi.Windows.MulDiv(22, CurrentPPI, 96),
      Canvas.TextHeight('Ägjy') + Winapi.Windows.MulDiv(5, CurrentPPI, 96));
    WPrev := ButtonWidth(FPrev, 34);
    WNext := ButtonWidth(FNext, 34);
    WBack := ButtonWidth(FPreviousDifference, 90);
    WForward := ButtonWidth(FNextDifference, 90);
    WToggle := ButtonWidth(FToggle, 90);
    WCancel := ButtonWidth(FCancelButton, 90);
    TotalWidth := WPrev + WNext + WBack + WForward + WToggle + WCancel + 5 * Gap;
    RowY := Margin;
    LeftPos := Margin;
    PutButton(FPrev, WPrev);
    PutButton(FNext, WNext);
    if TotalWidth + 2 * Margin > TopBar.ClientWidth then
    begin
      // At narrow widths the controls use a second row, without shrinking text.
      RowY := Margin + ButtonH + Gap;
      LeftPos := Margin;
    end;
    PutButton(FPreviousDifference, WBack);
    PutButton(FNextDifference, WForward);
    if LeftPos + WToggle > TopBar.ClientWidth - Margin then
    begin
      RowY := RowY + ButtonH + Gap;
      LeftPos := Margin;
    end;
    PutButton(FToggle, WToggle);
    if LeftPos + WCancel > TopBar.ClientWidth - Margin then
    begin
      RowY := RowY + ButtonH + Gap;
      LeftPos := Margin;
    end;
    PutButton(FCancelButton, WCancel);
    FProgress.SetBounds(Margin, RowY + ButtonH + Gap,
      Max(1, TopBar.ClientWidth - 2 * Margin),
      Winapi.Windows.MulDiv(9, CurrentPPI, 96));
    BarH := RowY + ButtonH + Gap + Winapi.Windows.MulDiv(11, CurrentPPI, 96) + InfoH + Margin;
    if TopBar.Height <> BarH then TopBar.Height := BarH;
    FInfo.SetBounds(Margin, RowY + ButtonH + Gap + Winapi.Windows.MulDiv(11, CurrentPPI, 96),
      Max(0, TopBar.ClientWidth - 2 * Margin), InfoH);
  finally
    FUpdatingLayout := False;
  end;
end;

procedure TCompareForm.ChangePage(Sender: TObject);
begin
  if FWorker <> nil then Exit;
  if Sender = FPrev then Dec(FPage) else Inc(FPage);
  Render;
end;

procedure TCompareForm.SelectDifference(Sender: TObject);
var
  OldSelected: Integer;
begin
  if Length(FRegions) = 0 then Exit;
  OldSelected := FSelectedRegion;
  if Sender = FPreviousDifference then
    FSelectedRegion := (FSelectedRegion + Length(FRegions) - 1) mod Length(FRegions)
  else
    FSelectedRegion := (FSelectedRegion + 1) mod Length(FRegions);
  UpdateSelectedMarks(OldSelected);
end;

procedure TCompareForm.UpdateSelectedMarks(AOldSelected: Integer);
var
  K, J, N, Y: Integer;
  R: TRect;
  Src, Dst: TBitmap;
  Target: TImage;
  C: TColor;
  Pages: Integer;
begin
  // Bei der Navigation niemals die kompletten PDF-Bitmaps neu kopieren.
  // Nur die zwei betroffenen Rahmen aus der unveraenderten Seite restaurieren.
  if FShowMarks and (AOldSelected <> FSelectedRegion) then
    for K := 0 to 1 do
    begin
      if K = 0 then
      begin
        Src := FBaseLeft;
        Target := FLeftImage;
        C := clTeal;
      end
      else
      begin
        Src := FBaseRight;
        Target := FRightImage;
        C := clRed;
      end;
      Dst := Target.Picture.Bitmap;
      if (Src.PixelFormat <> pf32bit) or (Dst.PixelFormat <> pf32bit) then Continue;
      if (Src.Width <> Dst.Width) or (Src.Height <> Dst.Height) or
         (Src.Width = 0) or (Src.Height = 0) then Continue;
      Dst.Canvas.Lock;
      try
        for J := 0 to 1 do
        begin
          if J = 0 then N := AOldSelected else N := FSelectedRegion;
          if (N < 0) or (N >= Length(FRegions)) then Continue;
          R := FRegions[N];
          // Der breite Rahmen reicht bis zu zwei Pixel ueber seine Kanten.
          InflateRect(R, 3, 3);
          IntersectRect(R, R, Rect(0, 0, Src.Width, Src.Height));
          if (R.Right > R.Left) and (R.Bottom > R.Top) then
            // Nur die betroffenen Pixel kopieren, ohne GDI-BitBlt.
            for Y := R.Top to R.Bottom - 1 do
              Move(PByte(NativeUInt(Src.ScanLine[Y]) + NativeUInt(R.Left * 4))^,
                   PByte(NativeUInt(Dst.ScanLine[Y]) + NativeUInt(R.Left * 4))^,
                   (R.Right - R.Left) * 4);
        end;
        // Die zwei betroffenen Rahmen erneut zeichnen, ohne andere
        // Bereiche der Bitmap anzufassen.
        Dst.Canvas.Brush.Style := bsClear;
        Dst.Canvas.Pen.Color := C;
        for J := 0 to 1 do
        begin
          if J = 0 then N := AOldSelected else N := FSelectedRegion;
          if (N < 0) or (N >= Length(FRegions)) then Continue;
          if N = FSelectedRegion then Dst.Canvas.Pen.Width := 3
          else Dst.Canvas.Pen.Width := 1;
          Dst.Canvas.Rectangle(FRegions[N]);
        end;
      finally
        Dst.Canvas.Unlock;
      end;
    end;
  Pages := Max(FLeftCore.PageCount, FRightCore.PageCount);
  if FEnglish then
    FInfo.Caption := Format('Page %d / %d - %d difference regions (%d/%d)',
      [FPage + 1, Pages, Length(FRegions), FSelectedRegion + 1, Length(FRegions)])
  else
    FInfo.Caption := Format('Seite %d / %d - %d Unterschiedsbereiche (%d/%d)',
      [FPage + 1, Pages, Length(FRegions), FSelectedRegion + 1, Length(FRegions)]);
end;

procedure TCompareForm.ToggleMarks(Sender: TObject);
begin
  FShowMarks := not FShowMarks;
  PaintMarks;
  // Die Bitmaps werden direkt aktualisiert; TImage muss sie neu zeichnen.
  FLeftImage.Invalidate;
  FRightImage.Invalidate;
end;

procedure TCompareForm.PaintMarks;
var
  I: Integer;
  Box: TRect;
  Pages: Integer;
begin
  // Update the existing displayed bitmaps in place: assigning a new Picture
  // on every difference navigation can briefly clear the TImage controls.
  // Copy the PDFium BGRA pixels without GDI alpha blending.
  // Canvas.Draw can treat the alpha byte as transparency and turn a
  // perfectly valid rendered page white, while the overlays remain visible.
  FLeftImage.Picture.Bitmap.PixelFormat := pf32bit;
  if (FLeftImage.Picture.Bitmap.Width <> FBaseLeft.Width) or
     (FLeftImage.Picture.Bitmap.Height <> FBaseLeft.Height) then
    FLeftImage.Picture.Bitmap.SetSize(FBaseLeft.Width, FBaseLeft.Height);
  if (FBaseLeft.Width > 0) and (FBaseLeft.Height > 0) then
    for I := 0 to FBaseLeft.Height - 1 do
      Move(FBaseLeft.ScanLine[I]^, FLeftImage.Picture.Bitmap.ScanLine[I]^,
        FBaseLeft.Width * 4);
  FRightImage.Picture.Bitmap.PixelFormat := pf32bit;
  if (FRightImage.Picture.Bitmap.Width <> FBaseRight.Width) or
     (FRightImage.Picture.Bitmap.Height <> FBaseRight.Height) then
    FRightImage.Picture.Bitmap.SetSize(FBaseRight.Width, FBaseRight.Height);
  if (FBaseRight.Width > 0) and (FBaseRight.Height > 0) then
    for I := 0 to FBaseRight.Height - 1 do
      Move(FBaseRight.ScanLine[I]^, FRightImage.Picture.Bitmap.ScanLine[I]^,
        FBaseRight.Width * 4);
  if FShowMarks then
    for I := 0 to High(FRegions) do
    begin
      Box := FRegions[I];
      FLeftImage.Picture.Bitmap.Canvas.Brush.Style := bsClear;
      FRightImage.Picture.Bitmap.Canvas.Brush.Style := bsClear;
      if I = FSelectedRegion then
      begin
        FLeftImage.Picture.Bitmap.Canvas.Pen.Width := 3;
        FRightImage.Picture.Bitmap.Canvas.Pen.Width := 3;
      end
      else
      begin
        FLeftImage.Picture.Bitmap.Canvas.Pen.Width := 1;
        FRightImage.Picture.Bitmap.Canvas.Pen.Width := 1;
      end;
      FLeftImage.Picture.Bitmap.Canvas.Pen.Color := clTeal;
      FRightImage.Picture.Bitmap.Canvas.Pen.Color := clRed;
      FLeftImage.Picture.Bitmap.Canvas.Rectangle(Box);
      FRightImage.Picture.Bitmap.Canvas.Rectangle(Box);
    end;
  FToggle.Caption := 'Show marks';
  FToggle.Hint := 'Show differences';
  if FShowMarks then
  begin
    FToggle.Caption := 'Hide marks';
    FToggle.Hint := 'Hide differences';
  end;
  if not FEnglish then
  begin
    FToggle.Caption := 'Anzeigen';
    FToggle.Hint := 'Unterschiede anzeigen';
    if FShowMarks then
    begin
      FToggle.Caption := 'Ausblenden';
      FToggle.Hint := 'Unterschiede ausblenden';
    end;
  end;
  // Die Umschaltung der Markierungen darf die Geometrie der
  // beiden PDF-Anzeigen nicht veraendern. Ein Layout-Neuaufbau
  // kann sonst das linke Anzeigefenster ueberdecken.
  FPreviousDifference.Enabled := Length(FRegions) > 0;
  FNextDifference.Enabled := Length(FRegions) > 0;
  Pages := Max(FLeftCore.PageCount, FRightCore.PageCount);
  if FEnglish then
    FInfo.Caption := Format('Page %d / %d – %d difference regions',
      [FPage + 1, Pages, Length(FRegions)])
  else
    FInfo.Caption := Format('Seite %d / %d – %d Unterschiedsbereiche',
      [FPage + 1, Pages, Length(FRegions)]);
  if (FSelectedRegion >= 0) and (Length(FRegions) > 0) then
    FInfo.Caption := FInfo.Caption + Format(' (%d/%d)',
      [FSelectedRegion + 1, Length(FRegions)]);
end;

procedure TCompareForm.ShowProgress(AValue: Integer);
begin
  FProgress.Position := AValue;
  if FEnglish then
    FInfo.Caption := Format('Comparing page %d ... %d%%', [FPage + 1, AValue])
  else
    FInfo.Caption := Format('Vergleiche Seite %d ... %d%%', [FPage + 1, AValue]);
end;

procedure TCompareForm.CancelCompare(Sender: TObject);
begin
  if FWorker <> nil then
  begin
    FWorker.Terminate;
    FCancelButton.Enabled := False;
    if FEnglish then FInfo.Caption := 'Cancelling comparison ...'
    else FInfo.Caption := 'Vergleich wird abgebrochen ...';
  end;
end;

procedure TCompareForm.CompareCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if not CanClose then
  begin
    FClosingAfterCancel := True;
    CancelCompare(nil);
  end;
end;

procedure TCompareForm.ApplyCachedPage;
var
  CacheIndex: Integer;
begin
  for CacheIndex := 0 to 2 do
    if FCachePages[CacheIndex] = FPage then
    begin
      FBaseLeft.Assign(FCacheLeft[CacheIndex]);
      FBaseRight.Assign(FCacheRight[CacheIndex]);
      FRegions := Copy(FCacheRegions[CacheIndex], 0, Length(FCacheRegions[CacheIndex]));
      Inc(FStamp);
      FCacheStamp[CacheIndex] := FStamp;
      FSelectedRegion := -1;
      if Length(FRegions) > 0 then FSelectedRegion := 0;
      PaintMarks;
      Exit;
    end;
end;

procedure TCompareForm.StartComparison;
begin
  FProgress.Position := 0;
  FProgress.Visible := True;
  FCancelButton.Enabled := True;
  FPrev.Enabled := False;
  FNext.Enabled := False;
  FPreviousDifference.Enabled := False;
  FNextDifference.Enabled := False;
  FToggle.Enabled := False;
  FWorker := TCompareWorker.Create(Self, FLeftFile, FRightFile, FPage);
  FWorker.OnTerminate := WorkerFinished;
  FWorker.Start;
end;

procedure TCompareForm.Render;
var
  Pages, CacheIndex: Integer;
begin
  if FWorker <> nil then Exit;
  Pages := Max(FLeftCore.PageCount, FRightCore.PageCount);
  if Pages = 0 then Exit;
  FPage := EnsureRange(FPage, 0, Pages - 1);
  FPrev.Enabled := FPage > 0;
  FNext.Enabled := FPage < Pages - 1;
  for CacheIndex := 0 to 2 do
    if FCachePages[CacheIndex] = FPage then
    begin
      ApplyCachedPage;
      Exit;
    end;
  StartComparison;
end;

procedure TCompareForm.WorkerFinished(Sender: TObject);
var
  Worker: TCompareWorker;
  Oldest, CacheIndex: Integer;
  WasCancelled: Boolean;
  ErrorText: string;
begin
  Worker := TCompareWorker(Sender);
  WasCancelled := Worker.Terminated;
  ErrorText := Worker.FError;
  FWorker := nil;
  FProgress.Visible := False;
  FCancelButton.Enabled := False;
  FToggle.Enabled := True;
  FPrev.Enabled := FPage > 0;
  FNext.Enabled := FPage < Max(FLeftCore.PageCount, FRightCore.PageCount) - 1;
  if FClosingAfterCancel then
  begin
    Close;
    Exit;
  end;
  if ErrorText <> '' then
  begin
    MessageDlg(ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  if WasCancelled then
  begin
    if FEnglish then FInfo.Caption := 'Comparison cancelled.'
    else FInfo.Caption := 'Vergleich abgebrochen.';
    Exit;
  end;
  FBaseLeft.Assign(Worker.FLeft);
  FBaseRight.Assign(Worker.FRight);
  FRegions := Copy(Worker.FRegions, 0, Length(Worker.FRegions));
  Oldest := 0;
  for CacheIndex := 0 to 2 do
    if (FCachePages[CacheIndex] < 0) or
       (FCacheStamp[CacheIndex] < FCacheStamp[Oldest]) then
      Oldest := CacheIndex;
  FCachePages[Oldest] := FPage;
  FCacheLeft[Oldest].Assign(FBaseLeft);
  FCacheRight[Oldest].Assign(FBaseRight);
  FCacheRegions[Oldest] := Copy(FRegions, 0, Length(FRegions));
  Inc(FStamp);
  FCacheStamp[Oldest] := FStamp;
  FSelectedRegion := -1;
  if Length(FRegions) > 0 then FSelectedRegion := 0;
  PaintMarks;
end;

procedure TCompareWorker.Execute;
const
  W = 900;
  H = 1200;
  CellSize = 10;
  GridW = (W + CellSize - 1) div CellSize;
  GridH = (H + CellSize - 1) div CellSize;
  // Require multiple meaningful pixels in a cell, not a single noisy pixel.
  MinCellPixels = 3;
var
  X, Y, I, D, Pages, CX, CY, NX, NY, Head, Tail, N, Count: Integer;
  L, R, LPrev, RPrev, LNext, RNext: PByteArray;
  EdgeL, EdgeR, EdgeBestL, EdgeBestR, J, Offset: Integer;
  Active, Seen: array of Boolean;
  Hits: array of Word;
  Queue: array of Integer;
  MinX, MinY, MaxX, MaxY, Cell, NextCell: Integer;
  Box: TRect;
  LW, LH, RW, RH: Single;
  LeftAspect, RightAspect: Double;
  DifferentSize: Boolean;
  LeftCore, RightCore: TFreePDF64PDFiumCore;

  procedure AddNeighbour(AX, AY: Integer);
  begin
    if (AX < 0) or (AY < 0) or (AX >= GridW) or (AY >= GridH) then Exit;
    NextCell := AY * GridW + AX;
    if Active[NextCell] and not Seen[NextCell] then
    begin
      Seen[NextCell] := True;
      Queue[Tail] := NextCell;
      Inc(Tail);
    end;
  end;

  procedure PreparePage(ACore: TFreePDF64PDFiumCore; ABitmap: TBitmap);
  begin
    ABitmap.PixelFormat := pf32bit;
    ABitmap.SetSize(W, H);
    ABitmap.Canvas.Brush.Color := clWhite;
    ABitmap.Canvas.FillRect(Rect(0, 0, W, H));
    if FPage < ACore.PageCount then
      ACore.RenderPage(FPage, ABitmap, W, H);
  end;
begin
  LeftCore := nil;
  RightCore := nil;
  try
   try
    LeftCore := TFreePDF64PDFiumCore.Create;
    RightCore := TFreePDF64PDFiumCore.Create;
    LeftCore.OpenFile(FLeftFile);
    if Terminated then Exit;
    ReportProgress(5);
    RightCore.OpenFile(FRightFile);
    if Terminated then Exit;
    ReportProgress(10);
    Pages := Max(LeftCore.PageCount, RightCore.PageCount);
    if (Pages = 0) or (FPage >= Pages) then Exit;
  PreparePage(LeftCore, FLeft);
  if Terminated then Exit;
  ReportProgress(25);
  PreparePage(RightCore, FRight);
  ReportProgress(45);
  if Terminated then Exit;
  SetLength(Hits, GridW * GridH);
  SetLength(Active, GridW * GridH);
  SetLength(Seen, GridW * GridH);
  SetLength(Queue, GridW * GridH);

  // Detect page aspect-ratio differences as well as image-pixel differences.
  // Missing pages are already compared against the white background.
  DifferentSize := False;
  if (FPage < LeftCore.PageCount) and (FPage < RightCore.PageCount) and
     LeftCore.PageSize(FPage, LW, LH) and
     RightCore.PageSize(FPage, RW, RH) and
     (LH > 0) and (RH > 0) then
  begin
    LeftAspect := LW / LH;
    RightAspect := RW / RH;
    DifferentSize := Abs(LeftAspect - RightAspect) > 0.003;
  end;

  for Y := 1 to H - 2 do
  begin
    if Terminated then Exit;
    if (Y mod 100) = 0 then ReportProgress(45 + (Y * 35 div H));
    L := FLeft.ScanLine[Y];
    R := FRight.ScanLine[Y];
    LPrev := FLeft.ScanLine[Y - 1];
    RPrev := FRight.ScanLine[Y - 1];
    LNext := FLeft.ScanLine[Y + 1];
    RNext := FRight.ScanLine[Y + 1];
    for X := 1 to W - 2 do
    begin
      I := X * 4;
      D := Abs(Integer(L[I]) - Integer(R[I])) +
           Abs(Integer(L[I + 1]) - Integer(R[I + 1])) +
           Abs(Integer(L[I + 2]) - Integer(R[I + 2]));
      // Preserve small, real colour/text edits while ignoring near-identical
      // pixels produced by different PDF rasterisation and antialiasing.
      if D <= 52 then Continue;

      // A one-pixel displacement of an antialiased edge can cause a large
      // direct difference. Only for moderate differences, check whether
      // BOTH pixels match a neighbouring pixel in the opposite image.
      // Strong differences are kept, so inserted/removed strokes survive.
      if D < 145 then
      begin
        EdgeBestL := D;
        EdgeBestR := D;
        for Offset := -1 to 1 do
        begin
          if Offset <> 0 then
          begin
            J := I + Offset * 4;
            EdgeL := Abs(Integer(L[I]) - Integer(R[J])) +
                     Abs(Integer(L[I + 1]) - Integer(R[J + 1])) +
                     Abs(Integer(L[I + 2]) - Integer(R[J + 2]));
            EdgeR := Abs(Integer(R[I]) - Integer(L[J])) +
                     Abs(Integer(R[I + 1]) - Integer(L[J + 1])) +
                     Abs(Integer(R[I + 2]) - Integer(L[J + 2]));
            EdgeBestL := Min(EdgeBestL, EdgeL);
            EdgeBestR := Min(EdgeBestR, EdgeR);
          end;
        end;
        EdgeL := Abs(Integer(L[I]) - Integer(RPrev[I])) +
                 Abs(Integer(L[I + 1]) - Integer(RPrev[I + 1])) +
                 Abs(Integer(L[I + 2]) - Integer(RPrev[I + 2]));
        EdgeR := Abs(Integer(R[I]) - Integer(LPrev[I])) +
                 Abs(Integer(R[I + 1]) - Integer(LPrev[I + 1])) +
                 Abs(Integer(R[I + 2]) - Integer(LPrev[I + 2]));
        EdgeBestL := Min(EdgeBestL, EdgeL);
        EdgeBestR := Min(EdgeBestR, EdgeR);
        EdgeL := Abs(Integer(L[I]) - Integer(RNext[I])) +
                 Abs(Integer(L[I + 1]) - Integer(RNext[I + 1])) +
                 Abs(Integer(L[I + 2]) - Integer(RNext[I + 2]));
        EdgeR := Abs(Integer(R[I]) - Integer(LNext[I])) +
                 Abs(Integer(R[I + 1]) - Integer(LNext[I + 1])) +
                 Abs(Integer(R[I + 2]) - Integer(LNext[I + 2]));
        EdgeBestL := Min(EdgeBestL, EdgeL);
        EdgeBestR := Min(EdgeBestR, EdgeR);
        if (EdgeBestL <= 28) and (EdgeBestR <= 28) then Continue;
      end;
      Cell := (Y div CellSize) * GridW + X div CellSize;
      if Hits[Cell] < High(Word) then Inc(Hits[Cell]);
    end;
  end;
  for I := 0 to High(Active) do
    Active[I] := Hits[I] >= MinCellPixels;

  SetLength(FRegions, 0);
  for CY := 0 to GridH - 1 do
  begin
    if Terminated then Exit;
    if (CY mod 20) = 0 then ReportProgress(80 + CY * 18 div GridH);
    for CX := 0 to GridW - 1 do
    begin
      Cell := CY * GridW + CX;
      if not Active[Cell] or Seen[Cell] then Continue;
      Head := 0;
      Tail := 1;
      Queue[0] := Cell;
      Seen[Cell] := True;
      MinX := CX;
      MaxX := CX;
      MinY := CY;
      MaxY := CY;
      Count := 0;
      while Head < Tail do
      begin
        if Terminated then Exit;
        N := Queue[Head];
        Inc(Head);
        Inc(Count);
        NX := N mod GridW;
        NY := N div GridW;
        MinX := Min(MinX, NX);
        MaxX := Max(MaxX, NX);
        MinY := Min(MinY, NY);
        MaxY := Max(MaxY, NY);
        AddNeighbour(NX - 1, NY);
        AddNeighbour(NX + 1, NY);
        AddNeighbour(NX, NY - 1);
        AddNeighbour(NX, NY + 1);
      end;
      // A single cell is accepted only if it contains substantial changes.
      if (Count = 1) and (Hits[Cell] < 9) then Continue;
      Box := Rect(Max(0, MinX * CellSize - 2),
        Max(0, MinY * CellSize - 2),
        Min(W - 1, (MaxX + 1) * CellSize + 2),
        Min(H - 1, (MaxY + 1) * CellSize + 2));
      SetLength(FRegions, Length(FRegions) + 1);
      FRegions[High(FRegions)] := Box;
    end;

  end;

  if DifferentSize then
  begin
    // The differing page proportions are a structural change even if
    // both pages happen to contain only white background.
    SetLength(FRegions, Length(FRegions) + 1);
    FRegions[High(FRegions)] := Rect(1, 1, W - 2, H - 2);
  end;

  ReportProgress(100);
  except
    on E: Exception do FError := E.Message;
   end;
  finally
    LeftCore.Free;
    RightCore.Free;
  end;
end;

procedure ShowPDFVisualComparison(AOwner: TComponent;
  const ALeftFile, ARightFile: string; AEnglish: Boolean);
var
  Dialog: TCompareForm;
begin
  Dialog := TCompareForm.CreateCompare(AOwner, ALeftFile, ARightFile, AEnglish);
  try
    Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

end.

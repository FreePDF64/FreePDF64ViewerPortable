unit uPDFSignatureLibrary;

interface

uses
  Winapi.Windows, Winapi.CommCtrl, System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ImgList,
  Vcl.Graphics, Vcl.Dialogs, Vcl.Imaging.pngimage, Vcl.ExtCtrls;

function SelectStoredPDFSignature(AOwner: TComponent; const Folder,
  CaptionText, UseText, RenameText, DeleteText, CancelText,
  NameText, ConfirmDeleteText: string; out SelectedFile: string;
  ADesign: Integer): Boolean;

function ConfirmStoreSignature(AOwner: TComponent; ADesign: Integer;
  const ACaption, AQuestion, ANote, AYes, ANo: string): Boolean;

function InputSignatureName(AOwner: TComponent; ADesign: Integer;
  const ACaption, ALabel, AOK, ACancel: string; var AName: string): Boolean;

function ChooseSignatureWidth(AOwner: TComponent; ADesign: Integer;
  const ACaption, ALabel, ACancel, AError: string;
  out AWidth: Double): Boolean;

implementation

type
  TSignatureLibraryForm = class(TForm)
  private
    FFolder, FNameText, FConfirmDeleteText: string;
    FList: TListView;
    FImages: TImageList;
    FUse, FRename, FDelete, FCancel: TPanel;
    FDesign: Integer;
    procedure ResizeButtons(Sender: TObject);
    procedure ArrangeSignatureIcons;
    procedure UseClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure LibraryKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ApplyLibraryDesign;
    procedure ItemDoubleClick(Sender: TObject);
    procedure RefreshItems;
    procedure RenameClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; Item: TListItem; Change: TItemChange);
    function CurrentPath: string;
  public
    constructor CreateLibrary(AOwner: TComponent; const Folder,
      CaptionText, UseText, RenameText, DeleteText, CancelText,
      NameText, ConfirmDeleteText: string; ADesign: Integer);
  end;

function SafeName(const Value: string): Boolean;
var I: Integer;
begin
  Result := (Trim(Value) <> '') and (Value <> '.') and (Value <> '..');
  for I := 1 to Length(Value) do
    if CharInSet(Value[I], ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
      Exit(False);
end;

constructor TSignatureLibraryForm.CreateLibrary(AOwner: TComponent;
  const Folder, CaptionText, UseText, RenameText, DeleteText, CancelText,
  NameText, ConfirmDeleteText: string; ADesign: Integer);
begin
  inherited CreateNew(AOwner);
  FDesign := ADesign;
  FFolder := Folder;
  FNameText := NameText;
  FConfirmDeleteText := ConfirmDeleteText;
  Caption := CaptionText;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  Scaled := False;
  Constraints.MinWidth := MulDiv(540, Screen.PixelsPerInch, 96);
  Constraints.MinHeight := MulDiv(360, Screen.PixelsPerInch, 96);
  ClientWidth := MulDiv(720, Screen.PixelsPerInch, 96);
  ClientHeight := MulDiv(470, Screen.PixelsPerInch, 96);
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  FImages := TImageList.Create(Self);
  FImages.Width := MulDiv(150, Screen.PixelsPerInch, 96);
  FImages.Height := MulDiv(90, Screen.PixelsPerInch, 96);
  FImages.ColorDepth := cd32Bit;
  FList := TListView.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.ViewStyle := vsIcon;
  FList.IconOptions.AutoArrange := True;
  FList.ReadOnly := True;
  FList.MultiSelect := False;
  FList.HideSelection := False;
  FList.LargeImages := FImages;
  FList.OnChange := SelectionChanged;
  FList.OnDblClick := ItemDoubleClick;
  FUse := TPanel.Create(Self);
  FUse.Parent := Self;
  FUse.Caption := UseText;
  FUse.OnClick := UseClick;
  FRename := TPanel.Create(Self);
  FRename.Parent := Self;
  FRename.Caption := RenameText;
  FRename.OnClick := RenameClick;
  FDelete := TPanel.Create(Self);
  FDelete.Parent := Self;
  FDelete.Caption := DeleteText;
  FDelete.OnClick := DeleteClick;
  FCancel := TPanel.Create(Self);
  FCancel.Parent := Self;
  FCancel.Caption := CancelText;
  FCancel.OnClick := CancelClick;
  // Unten bleibt eine feste Aktionsleiste frei.
  FList.AlignWithMargins := True;
  FList.Margins.Left := 10;
  FList.Margins.Top := 10;
  FList.Margins.Right := 10;
  FList.Margins.Bottom := MulDiv(68, Screen.PixelsPerInch, 96);
  FUse.Anchors := [akRight, akBottom];
  FRename.Anchors := [akRight, akBottom];
  FDelete.Anchors := [akRight, akBottom];
  FCancel.Anchors := [akRight, akBottom];
  OnResize := ResizeButtons;
  ResizeButtons(Self);
  KeyPreview := True;
  OnKeyDown := LibraryKeyDown;
  ApplyLibraryDesign;
  RefreshItems;
  ArrangeSignatureIcons;
end;

procedure TSignatureLibraryForm.UseClick(Sender: TObject);
begin
  if FList.Selected <> nil then ModalResult := mrOk;
end;

procedure TSignatureLibraryForm.CancelClick(Sender: TObject);
begin ModalResult := mrCancel; end;

procedure TSignatureLibraryForm.LibraryKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then ModalResult := mrCancel
  else if (Key = VK_RETURN) and (FList.Selected <> nil) then ModalResult := mrOk;
end;

procedure TSignatureLibraryForm.ApplyLibraryDesign;
var
  BackColor, ForeColor, ButtonColor: TColor;
  Buttons: array[0..3] of TPanel;
  I: Integer;
begin
  case FDesign of
    1: begin BackColor := RGB(248,250,253); ForeColor := RGB(35,48,65);
      ButtonColor := RGB(225,232,241); end;
    2,4: begin BackColor := RGB(55,59,66); ForeColor := clWhite;
      ButtonColor := RGB(65,70,79); end;
    3: begin BackColor := clBtnFace; ForeColor := clWindowText;
      ButtonColor := RGB(205,205,205); end;
    5: begin BackColor := RGB(232,242,253); ForeColor := RGB(24,55,88);
      ButtonColor := RGB(190,214,237); end;
  else begin BackColor := clBtnFace; ForeColor := clWindowText;
    ButtonColor := clBtnFace; end;
  end;
  Color := BackColor;
  Font.Color := ForeColor;
  FList.Color := BackColor;
  FList.Font.Color := ForeColor;
  Buttons[0] := FUse; Buttons[1] := FRename;
  Buttons[2] := FDelete; Buttons[3] := FCancel;
  for I := 0 to 3 do
  begin
    Buttons[I].ParentBackground := False;
    Buttons[I].ParentColor := False;
    Buttons[I].Color := ButtonColor;
    Buttons[I].Font.Name := Font.Name;
    Buttons[I].Font.Size := Font.Size;
    Buttons[I].Font.Color := ForeColor;
    if FDesign = 0 then Buttons[I].Font.Style := []
    else Buttons[I].Font.Style := [fsBold];
    Buttons[I].BevelOuter := bvRaised;
    Buttons[I].Cursor := crHandPoint;
  end;
end;

procedure TSignatureLibraryForm.ItemDoubleClick(Sender: TObject);
begin
  if FList.Selected <> nil then ModalResult := mrOk;
end;

function TSignatureLibraryForm.CurrentPath: string;
begin
  Result := '';
  if FList.Selected <> nil then
    Result := IncludeTrailingPathDelimiter(FFolder) + FList.Selected.Caption + '.png';
end;

procedure TSignatureLibraryForm.SelectionChanged(Sender: TObject;
  Item: TListItem; Change: TItemChange);
begin
  FUse.Enabled := FList.Selected <> nil;
  FRename.Enabled := FUse.Enabled;
  FDelete.Enabled := FUse.Enabled;
end;

procedure TSignatureLibraryForm.RefreshItems;
var
  SR: TSearchRec;
  Item: TListItem;
  PNG: TPngImage;
  Bmp: TBitmap;
  Target: TRect;
  W,H: Integer;
begin
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    FImages.Clear;
    if FindFirst(IncludeTrailingPathDelimiter(FFolder)+'*.png', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Attr and faDirectory) <> 0 then Continue;
        PNG := TPngImage.Create;
        Bmp := TBitmap.Create;
        try
          try
            PNG.LoadFromFile(IncludeTrailingPathDelimiter(FFolder)+SR.Name);
            Bmp.SetSize(FImages.Width,FImages.Height);
            Bmp.PixelFormat := pf32bit;
            Bmp.Canvas.Brush.Color := clWhite;
            Bmp.Canvas.FillRect(Rect(0,0,Bmp.Width,Bmp.Height));
            if (PNG.Width > 0) and (PNG.Height > 0) then
            begin
              // DPI-gerechter Innenabstand: keine abgeschnittenen Striche
              // am linken/rechten Rand der Miniatur.
              W := FImages.Width - 2 * MulDiv(14, Screen.PixelsPerInch, 96);
              H := MulDiv(PNG.Height,W,PNG.Width);
              if H > FImages.Height - 2 * MulDiv(10, Screen.PixelsPerInch, 96) then
              begin
                H := FImages.Height - 2 * MulDiv(10, Screen.PixelsPerInch, 96);
                W := MulDiv(PNG.Width,H,PNG.Height);
              end;
              Target := Rect((FImages.Width-W) div 2,(FImages.Height-H) div 2,
                (FImages.Width+W) div 2,(FImages.Height+H) div 2);
              Bmp.Canvas.StretchDraw(Target,PNG);
            end;
            Item := FList.Items.Add;
            Item.Caption := ChangeFileExt(SR.Name,'');
            Item.ImageIndex := FImages.Add(Bmp,nil);
          except
            // Defekte PNG-Dateien nicht in die Auswahl aufnehmen.
          end;
        finally
          Bmp.Free;
          PNG.Free;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  finally
    FList.Items.EndUpdate;
  end;
  SelectionChanged(nil,nil,ctState);
  ArrangeSignatureIcons;
end;


procedure TSignatureLibraryForm.ArrangeSignatureIcons;
var
  SpacingX, SpacingY: Integer;
begin
  if (FList = nil) or not FList.HandleAllocated then Exit;
  // Ein gleichmäßiges, DPI-skalierendes Raster. Die ListView bestimmt
  // anhand der verfügbaren Breite automatisch die Spaltenzahl.
  SpacingX := MulDiv(190, Screen.PixelsPerInch, 96);
  SpacingY := MulDiv(140, Screen.PixelsPerInch, 96);
  SendMessage(FList.Handle, LVM_SETICONSPACING, 0,
    LPARAM(MakeLParam(SpacingX, SpacingY)));
  SendMessage(FList.Handle, LVM_ARRANGE, LVA_DEFAULT, 0);
end;

procedure TSignatureLibraryForm.ResizeButtons(Sender: TObject);
var
  B: array[0..3] of TPanel;
  I, W, X, Gap, H: Integer;
begin
  B[0] := FUse; B[1] := FRename; B[2] := FDelete; B[3] := FCancel;
  Gap := MulDiv(10, Screen.PixelsPerInch, 96);
  H := MulDiv(39, Screen.PixelsPerInch, 96);
  W := MulDiv(112, Screen.PixelsPerInch, 96);
  for I := 0 to 3 do
    if B[I] <> nil then
      W := Max(W, MulDiv(Length(B[I].Caption) * 9 + 32,
        Screen.PixelsPerInch, 96));
  X := ClientWidth - Gap - 4*W - 3*Gap;
  for I := 0 to 3 do
    B[I].SetBounds(X + I*(W+Gap), ClientHeight-H-Gap, W, H);
  ArrangeSignatureIcons;
end;

function SignatureDialogDPI(AOwner: TComponent): Integer;
begin
  if AOwner is TControl then
    Result := TControl(AOwner).CurrentPPI
  else
    Result := Screen.PixelsPerInch;
  if Result < 96 then Result := 96;
end;

function SignatureIs4KDisplay: Boolean;
var
  Mode: TDevMode;
begin
  // Physische Bildschirmauflösung statt der DPI-virtualisierten VCL-Werte.
  ZeroMemory(@Mode, SizeOf(Mode));
  Mode.dmSize := SizeOf(Mode);
  Result := EnumDisplaySettings(nil, DWORD($FFFFFFFF), Mode) and
    (Mode.dmPelsWidth >= 3200) and (Mode.dmPelsHeight >= 1800);
end;

type
  TSignatureConfirmActions = class
    Form: TForm;
    procedure Click(Sender: TObject);
  end;

procedure TSignatureConfirmActions.Click(Sender: TObject);
begin
  Form.ModalResult := TControl(Sender).Tag;
end;

function ConfirmStoreSignature(AOwner: TComponent; ADesign: Integer;
  const ACaption, AQuestion, ANote, AYes, ANo: string): Boolean;
var
  D: TForm;
  L: TLabel;
  P: TPanel;
  Actions: TSignatureConfirmActions;
  BackColor, ForeColor, ButtonColor: TColor;
  DPI, ButtonHeight, ButtonWidth, TextHeight, Gap, Margin: Integer;
  function S(V: Integer): Integer;
  begin
    Result := MulDiv(V, DPI, 96);
  end;
  function AddAction(const AText: string; X, Modal: Integer): TPanel;
  begin
    Result := TPanel.Create(D);
    Result.Parent := D;
    Result.SetBounds(D.ClientWidth - Margin - (2-X) * (ButtonWidth+Gap) - ButtonWidth,
      D.ClientHeight - Margin - ButtonHeight, ButtonWidth, ButtonHeight);
    Result.Anchors := [akRight, akBottom];
    Result.Caption := AText;
    Result.BevelOuter := bvRaised;
    Result.Color := ButtonColor;
    Result.Font.Color := ForeColor;
    Result.Alignment := taCenter;
    Result.VerticalAlignment := taVerticalCenter;
    if ADesign = 0 then
      Result.Font.Style := []
    else
      Result.Font.Style := [fsBold];
    Result.Cursor := crHandPoint;
    Result.Tag := Modal;
    Result.OnClick := Actions.Click;
  end;
begin
  D := TForm.CreateNew(AOwner);
  D.Scaled := False;
  DPI := SignatureDialogDPI(AOwner);
  Actions := TSignatureConfirmActions.Create;
  try
    Actions.Form := D;
    D.Caption := ACaption;
    D.Position := poOwnerFormCenter;
    D.BorderStyle := bsDialog;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    // Die Maße werden nach der Schriftmetrik bestimmt, nicht nur nach DPI.
    D.ClientWidth := S(445);
    D.ClientHeight := S(150);
    case ADesign of
      1: begin BackColor := RGB(225,232,241); ForeColor := RGB(35,48,65);
        ButtonColor := RGB(245,247,250); end;
      2,4: begin BackColor := RGB(54,58,65); ForeColor := clWhite;
        ButtonColor := RGB(65,70,79); end;
      3: begin BackColor := RGB(192,192,192); ForeColor := clBlack;
        ButtonColor := RGB(220,220,220); end;
      5: begin BackColor := RGB(190,214,237); ForeColor := RGB(24,55,88);
        ButtonColor := RGB(205,225,245); end;
    else begin BackColor := clBtnFace; ForeColor := clWindowText;
      ButtonColor := clBtnFace; end;
    end;
    D.Color := BackColor;
    D.Font.Color := ForeColor;
    D.Canvas.Font.Assign(D.Font);
    Margin := Max(S(14), D.Canvas.TextHeight('Hg') div 2);
    Gap := Max(S(7), D.Canvas.TextWidth('  '));
    TextHeight := D.Canvas.TextHeight('Hg');
    D.Canvas.Font.Style := [fsBold];
    ButtonWidth := Max(S(96), Max(D.Canvas.TextWidth(AYes),
      D.Canvas.TextWidth(ANo)) + 2 * Margin);
    ButtonHeight := Max(S(32), TextHeight + 2 * Max(S(7), 5));
    D.ClientWidth := Max(S(445), 2 * ButtonWidth + Gap + 2 * Margin);
    // Zusätzliche Breite ausschließlich bei physischer 4K-Auflösung.
    if SignatureIs4KDisplay then
      D.ClientWidth := Max(D.ClientWidth, S(690));
    // Für die Frage einen eigenen Bereich vorsehen; kein Überlappen.
    D.ClientHeight := Margin + Max(TextHeight * 2, S(32));
    if Trim(ANote) <> '' then
      D.ClientHeight := D.ClientHeight + TextHeight * 3 + S(9);
    D.ClientHeight := D.ClientHeight + ButtonHeight + 2 * Margin;
    L := TLabel.Create(D);
    L.Parent := D;
    L.SetBounds(Margin, Margin, D.ClientWidth - 2*Margin,
      Max(TextHeight * 2, S(32)));
    L.AutoSize := False;
    L.WordWrap := True;
    L.Font.Style := [fsBold];
    L.Font.Color := ForeColor;
    L.Caption := AQuestion;
    if Trim(ANote) <> '' then
    begin
      L := TLabel.Create(D);
      L.Parent := D;
      L.SetBounds(Margin, Margin + Max(TextHeight*2, S(32)) + S(9),
        D.ClientWidth - 2*Margin, TextHeight*3);
      L.AutoSize := False;
      L.WordWrap := True;
      L.Font.Color := ForeColor;
      L.Caption := ANote;
    end;
    AddAction(AYes, 1, mrYes);
    AddAction(ANo, 2, mrNo);
    Result := D.ShowModal = mrYes;
  finally
    Actions.Free;
    D.Free;
  end;
end;

type
  TSignatureNameActions = class
    Form: TForm;
    Edit: TEdit;
    procedure Click(Sender: TObject);
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

procedure TSignatureNameActions.Click(Sender: TObject);
begin
  if (TControl(Sender).Tag = mrOk) and (Trim(Edit.Text) = '') then
  begin
    Edit.SetFocus;
    Exit;
  end;
  Form.ModalResult := TControl(Sender).Tag;
end;

procedure TSignatureNameActions.KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Form.ModalResult := mrCancel;
    Key := 0;
  end
  else if Key = VK_RETURN then
  begin
    if Trim(Edit.Text) <> '' then Form.ModalResult := mrOk;
    Key := 0;
  end;
end;

function InputSignatureName(AOwner: TComponent; ADesign: Integer;
  const ACaption, ALabel, AOK, ACancel: string; var AName: string): Boolean;
var
  D: TForm;
  L: TLabel;
  E: TEdit;
  B: TPanel;
  Actions: TSignatureNameActions;
  BackColor, ForeColor, ButtonColor: TColor;
  DPI, Margin, Gap, ButtonWidth, ButtonHeight, LineHeight, LabelWidth: Integer;
  function S(V: Integer): Integer;
  begin
    Result := MulDiv(V, DPI, 96);
  end;
  function AddButton(const AText: string; X, AResult: Integer): TPanel;
  begin
    Result := TPanel.Create(D);
    Result.Parent := D;
    Result.SetBounds(D.ClientWidth - Margin - (2-X) * (ButtonWidth+Gap) - ButtonWidth,
      D.ClientHeight - Margin - ButtonHeight, ButtonWidth, ButtonHeight);
    Result.Anchors := [akRight, akBottom];
    Result.Caption := AText;
    Result.BevelOuter := bvRaised;
    Result.Color := ButtonColor;
    Result.Font.Color := ForeColor;
    Result.Alignment := taCenter;
    Result.VerticalAlignment := taVerticalCenter;
    if ADesign = 0 then Result.Font.Style := []
    else Result.Font.Style := [fsBold];
    Result.Cursor := crHandPoint;
    Result.Tag := AResult;
    Result.OnClick := Actions.Click;
  end;
begin
  D := TForm.CreateNew(AOwner);
  D.Scaled := False;
  DPI := SignatureDialogDPI(AOwner);
  Actions := TSignatureNameActions.Create;
  try
    Actions.Form := D;
    D.Caption := ACaption;
    D.Position := poOwnerFormCenter;
    D.BorderStyle := bsDialog;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.ClientWidth := S(480);
    D.ClientHeight := S(112);
    case ADesign of
      1: begin BackColor := RGB(225,232,241); ForeColor := RGB(35,48,65);
        ButtonColor := RGB(245,247,250); end;
      2,4: begin BackColor := RGB(54,58,65); ForeColor := clWhite;
        ButtonColor := RGB(65,70,79); end;
      3: begin BackColor := RGB(192,192,192); ForeColor := clBlack;
        ButtonColor := RGB(220,220,220); end;
      5: begin BackColor := RGB(190,214,237); ForeColor := RGB(24,55,88);
        ButtonColor := RGB(205,225,245); end;
    else begin BackColor := clBtnFace; ForeColor := clWindowText;
      ButtonColor := clBtnFace; end;
    end;
    D.Color := BackColor;
    D.Font.Color := ForeColor;
    D.Canvas.Font.Assign(D.Font);
    Margin := Max(S(14), D.Canvas.TextHeight('Hg') div 2);
    Gap := Max(S(8), D.Canvas.TextWidth('  '));
    LineHeight := D.Canvas.TextHeight('Hg');
    D.Canvas.Font.Style := [fsBold];
    ButtonWidth := Max(S(114), Max(D.Canvas.TextWidth(AOK),
      D.Canvas.TextWidth(ACancel)) + 2*Margin);
    ButtonHeight := Max(S(34), LineHeight + 2*Max(S(7), 5));
    D.Canvas.Font.Style := [];
    LabelWidth := D.Canvas.TextWidth(ALabel) + S(8);
    // WQHD bleibt kompakt; die große Mindestbreite gilt nur für 4K.
    D.ClientWidth := Max(S(480), LabelWidth + S(260) + 3*Margin);
    if SignatureIs4KDisplay then
      D.ClientWidth := Max(D.ClientWidth, Max(S(760),
        LabelWidth + S(440) + 3*Margin));
    D.ClientWidth := Max(D.ClientWidth, 2*ButtonWidth + Gap + 2*Margin);
    D.ClientHeight := Margin*3 + Max(S(32), LineHeight + S(12)) + ButtonHeight;
    L := TLabel.Create(D);
    L.Parent := D;
    L.Caption := ALabel;
    L.SetBounds(Margin, Margin + S(5), LabelWidth, LineHeight + S(8));
    L.Font.Color := ForeColor;
    E := TEdit.Create(D);
    E.Parent := D;
    E.SetBounds(Margin + LabelWidth, Margin,
      D.ClientWidth - LabelWidth - 2*Margin, Max(S(32), LineHeight+S(12)));
    E.Text := AName;
    Actions.Edit := E;
    AddButton(AOK, 1, mrOk);
    AddButton(ACancel, 2, mrCancel);
    D.KeyPreview := True;
    D.OnKeyDown := Actions.KeyDown;
    D.ActiveControl := E;
    Result := D.ShowModal = mrOk;
    if Result then AName := E.Text;
  finally
    Actions.Free;
    D.Free;
  end;
end;

type
  TSignatureWidthForm = class(TForm)
  private
    FWidth: TTrackBar;
    FEdit: TEdit;
    FError: string;
    procedure TrackChanged(Sender: TObject);
    procedure EditChanged(Sender: TObject);
    procedure AcceptClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure WidthKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor CreateWidth(AOwner: TComponent; ADesign: Integer;
      const ACaption, ALabel, ACancel, AError: string);
    function WidthMM: Double;
  end;

constructor TSignatureWidthForm.CreateWidth(AOwner: TComponent; ADesign: Integer;
  const ACaption, ALabel, ACancel, AError: string);
var
  L: TLabel;
  B: TPanel;
  BackColor, ForeColor, ButtonColor: TColor;
  OKPanel, CancelPanel: TPanel;
  DPI: Integer;
  function S(V: Integer): Integer;
  begin
    Result := MulDiv(V, DPI, 96);
  end;
begin
  inherited CreateNew(AOwner);
  Scaled := False;
  KeyPreview := True;
  OnKeyDown := WidthKeyDown;
  DPI := SignatureDialogDPI(AOwner);
  Caption := ACaption;
  FError := AError;
  Position := poOwnerFormCenter;
  BorderStyle := bsDialog;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := S(390);
  ClientHeight := S(134);

  L := TLabel.Create(Self);
  L.Parent := Self;
  L.SetBounds(S(16), S(12), S(355), S(22));
  L.Caption := ALabel;
  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.SetBounds(S(16), S(40), S(76), S(27));
  FEdit.Text := '45';
  FWidth := TTrackBar.Create(Self);
  FWidth.Parent := Self;
  FWidth.SetBounds(S(102), S(37), S(272), S(42));
  FWidth.Min := 5;
  FWidth.Max := 200;
  FWidth.Frequency := 25;
  // Ein Klick in die Spur sowie die Pfeiltasten ändern die Breite um 1 mm.
  FWidth.PageSize := 10;
  FWidth.LineSize := 1;
  FWidth.Position := 45;
  FWidth.OnChange := TrackChanged;
  FEdit.OnChange := EditChanged;
  // Farbige Panels statt TButton: VCL-TButton.Color ist nicht frei setzbar.
  case ADesign of
    1: begin BackColor := RGB(248,250,253); ForeColor := RGB(35,48,65);
      ButtonColor := RGB(225,232,241); end;
    2,4: begin BackColor := RGB(55,59,66); ForeColor := clWhite;
      ButtonColor := RGB(65,70,79); end;
    3: begin BackColor := clBtnFace; ForeColor := clWindowText;
      ButtonColor := RGB(205,205,205); end;
    5: begin BackColor := RGB(232,242,253); ForeColor := RGB(24,55,88);
      ButtonColor := RGB(190,214,237); end;
  else begin BackColor := clBtnFace; ForeColor := clWindowText;
    ButtonColor := clBtnFace; end;
  end;
  Color := BackColor;
  Font.Color := ForeColor;
  L.Font.Color := ForeColor;
  FEdit.Color := clWindow;
  FEdit.Font.Color := clWindowText;
  OKPanel := TPanel.Create(Self);
  OKPanel.Parent := Self;
  OKPanel.Caption := 'OK';
  OKPanel.SetBounds(S(178), S(91), S(92), S(31));
  OKPanel.OnClick := AcceptClick;
  CancelPanel := TPanel.Create(Self);
  CancelPanel.Parent := Self;
  CancelPanel.Caption := ACancel;
  CancelPanel.SetBounds(S(280), S(91), S(94), S(31));
  CancelPanel.OnClick := CancelClick;
  for B in TArray<TPanel>.Create(OKPanel, CancelPanel) do
  begin
    B.ParentBackground := False;
    B.ParentColor := False;
    B.Color := ButtonColor;
    B.Font.Color := ForeColor;
    if ADesign = 0 then B.Font.Style := []
    else B.Font.Style := [fsBold];
    B.Alignment := taCenter;
    B.VerticalAlignment := taVerticalCenter;
    B.BevelOuter := bvRaised;
    B.Cursor := crHandPoint;
  end;
end;

procedure TSignatureWidthForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TSignatureWidthForm.WidthKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    ModalResult := mrCancel;
    Key := 0;
  end
  else if Key = VK_RETURN then
  begin
    AcceptClick(Self);
    Key := 0;
  end;
end;

procedure TSignatureWidthForm.TrackChanged(Sender: TObject);
begin
  FEdit.OnChange := nil;
  try FEdit.Text := IntToStr(FWidth.Position);
  finally FEdit.OnChange := EditChanged; end;
end;

procedure TSignatureWidthForm.EditChanged(Sender: TObject);
var N: Integer;
begin
  if TryStrToInt(Trim(FEdit.Text), N) and (N >= 5) and (N <= 200) then
  begin
    FWidth.OnChange := nil;
    try FWidth.Position := N;
    finally FWidth.OnChange := TrackChanged; end;
  end;
end;

procedure TSignatureWidthForm.AcceptClick(Sender: TObject);
var N: Double;
begin
  if not TryStrToFloat(Trim(FEdit.Text), N) or (N < 5) or (N > 200) then
  begin
    MessageDlg(FError, mtWarning, [mbOK], 0);
    FEdit.SetFocus;
    FEdit.SelectAll;
    Exit;
  end;
  ModalResult := mrOk;
end;

function TSignatureWidthForm.WidthMM: Double;
begin
  Result := StrToFloat(Trim(FEdit.Text));
end;

function ChooseSignatureWidth(AOwner: TComponent; ADesign: Integer;
  const ACaption, ALabel, ACancel, AError: string;
  out AWidth: Double): Boolean;
var D: TSignatureWidthForm;
begin
  D := TSignatureWidthForm.CreateWidth(AOwner, ADesign,
    ACaption, ALabel, ACancel, AError);
  try
    Result := D.ShowModal = mrOk;
    if Result then AWidth := D.WidthMM;
  finally D.Free; end;
end;

procedure TSignatureLibraryForm.RenameClick(Sender: TObject);
var OldPath, NewPath, NameValue: string;
begin
  OldPath := CurrentPath;
  if OldPath = '' then Exit;
  NameValue := FList.Selected.Caption;
  // Einheitlicher, DPI-skalierter Dialog in der aktuellen Designpalette.
  if Pos('delete', LowerCase(FConfirmDeleteText)) > 0 then
  begin
    if not InputSignatureName(Self, FDesign, Caption, FNameText,
      'OK', 'Cancel', NameValue) then Exit;
  end
  else if not InputSignatureName(Self, FDesign, Caption, FNameText,
    'OK', 'Abbrechen', NameValue) then Exit;
  NameValue := Trim(NameValue);
  if not SafeName(NameValue) then Exit;
  NewPath := IncludeTrailingPathDelimiter(FFolder)+NameValue+'.png';
  if SameText(OldPath,NewPath) then Exit;
  if FileExists(NewPath) then Exit;
  if RenameFile(OldPath,NewPath) then RefreshItems;
end;

procedure TSignatureLibraryForm.DeleteClick(Sender: TObject);
var Path: string;
begin
  Path := CurrentPath;
  if Path = '' then Exit;
  if Pos('delete', LowerCase(FConfirmDeleteText)) > 0 then
  begin
    if not ConfirmStoreSignature(Self, FDesign, 'Confirmation',
      FConfirmDeleteText, '', 'Yes', 'No') then Exit;
  end
  else if not ConfirmStoreSignature(Self, FDesign, 'Bestätigen',
    FConfirmDeleteText, '', 'Ja', 'Nein') then Exit;
  if System.SysUtils.DeleteFile(Path) then RefreshItems;
end;

function SelectStoredPDFSignature(AOwner: TComponent; const Folder,
  CaptionText, UseText, RenameText, DeleteText, CancelText,
  NameText, ConfirmDeleteText: string; out SelectedFile: string;
  ADesign: Integer): Boolean;
var Form: TSignatureLibraryForm;
begin
  SelectedFile := '';
  Form := TSignatureLibraryForm.CreateLibrary(AOwner,Folder,
    CaptionText,UseText,RenameText,DeleteText,CancelText,NameText,ConfirmDeleteText,ADesign);
  try
    Result := (Form.ShowModal = mrOk) and (Form.FList.Selected <> nil);
    if Result then
    begin
      SelectedFile := Form.CurrentPath;
      Result := FileExists(SelectedFile);
    end;
  finally
    Form.Free;
  end;
end;

end.

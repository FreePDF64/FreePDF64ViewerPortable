unit uPDFSignatureDialog;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Graphics,
  Vcl.Dialogs, Vcl.Imaging.pngimage;

type
  TPDFSignaturePad = class(TCustomControl)
  private
    FBitmap: TBitmap;
    FDrawing, FHasInk, FStrokeMoved: Boolean;
    FPrevious: TPoint;
    FPenWidth: Integer;
    procedure RepaintStroke(const A, B: TPoint);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    procedure ClearClick(Sender: TObject);
    property Bitmap: TBitmap read FBitmap;
    property HasInk: Boolean read FHasInk;
    property PenWidth: Integer read FPenWidth write FPenWidth;
  end;

function ChoosePDFSignatureSource(AOwner: TComponent; ADesign: Integer;
  const ATitle, ACreateText, AImportText, ACancelText: string): Integer;

function CreatePDFSignaturePNG(AOwner: TComponent; const ATitle,
  ADrawText, AClearText, AOKText, ACancelText: string;
  out AFileName: string; ADesign: Integer = 0): Boolean;

implementation

type
  TSignatureDialogActions = class
  private
    Pad: TPDFSignaturePad;
    ThinButton, MediumButton, ThickButton: TButton;
    Form: TForm;
    procedure ClearClick(Sender: TObject);
    procedure OKClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure DialogKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SetPen(AWidth: Integer);
  public
    procedure ThinClick(Sender: TObject);
    procedure MediumClick(Sender: TObject);
    procedure ThickClick(Sender: TObject);
  end;

type
  TSignatureSourceActions = class
    Form: TForm;
    procedure ButtonClick(Sender: TObject);
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

procedure TSignatureSourceActions.ButtonClick(Sender: TObject);
begin
  Form.ModalResult := TControl(Sender).Tag;
end;

procedure TSignatureSourceActions.KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then Form.ModalResult := mrCancel
  else if Key = VK_RETURN then Form.ModalResult := mrYes;
end;

procedure TSignatureDialogActions.ClearClick(Sender: TObject);
begin Pad.Clear; end;
procedure TSignatureDialogActions.OKClick(Sender: TObject);
begin Form.ModalResult := mrOk; end;
procedure TSignatureDialogActions.CancelClick(Sender: TObject);
begin Form.ModalResult := mrCancel; end;
procedure TSignatureDialogActions.DialogKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then Form.ModalResult := mrCancel
  else if Key = VK_RETURN then Form.ModalResult := mrOk;
end;

procedure TSignatureDialogActions.SetPen(AWidth: Integer);
begin
  Pad.PenWidth := AWidth;
  ThinButton.Font.Style := [];
  MediumButton.Font.Style := [];
  ThickButton.Font.Style := [];
  case AWidth of
    2: ThinButton.Font.Style := [fsBold];
    4: MediumButton.Font.Style := [fsBold];
    7: ThickButton.Font.Style := [fsBold];
  end;
end;

procedure TSignatureDialogActions.ThinClick(Sender: TObject);
begin SetPen(2); end;
procedure TSignatureDialogActions.MediumClick(Sender: TObject);
begin SetPen(4); end;
procedure TSignatureDialogActions.ThickClick(Sender: TObject);
begin SetPen(7); end;

constructor TPDFSignaturePad.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Width := 520;
  Height := 190;
  FPenWidth := 4;
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf24bit;
  FBitmap.SetSize(Width, Height);
  Clear;
end;

destructor TPDFSignaturePad.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

procedure TPDFSignaturePad.Clear;
begin
  FBitmap.Canvas.Brush.Color := clWhite;
  FBitmap.Canvas.FillRect(Rect(0, 0, FBitmap.Width, FBitmap.Height));
  FBitmap.Canvas.Pen.Color := clBlack;
  FBitmap.Canvas.Pen.Width := FPenWidth;
  FBitmap.Canvas.Pen.Style := psSolid;
  FHasInk := False;
  FStrokeMoved := False;
  Invalidate;
end;

procedure TPDFSignaturePad.ClearClick(Sender: TObject);
begin Clear; end;

procedure TPDFSignaturePad.Paint;
begin
  Canvas.Draw(0, 0, FBitmap);
end;

procedure TPDFSignaturePad.RepaintStroke(const A, B: TPoint);
var
  R: TRect;
  PadSize: Integer;
begin
  PadSize := FPenWidth + 4;
  R := Rect(Min(A.X, B.X) - PadSize, Min(A.Y, B.Y) - PadSize,
    Max(A.X, B.X) + PadSize + 1, Max(A.Y, B.Y) + PadSize + 1);
  InvalidateRect(Handle, @R, False);
end;

procedure TPDFSignaturePad.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then Exit;
  FDrawing := True;
  FStrokeMoved := False;
  FPrevious := Point(MulDiv(X, FBitmap.Width, Width),
    MulDiv(Y, FBitmap.Height, Height));
  // Noch keinen Kreis zeichnen: ein Anfangspunkt wuerde die erste Linie verdicken.
  // Ein einzelner Klick wird erst bei MouseUp als Punkt gezeichnet.
  MouseCapture := True;
end;

procedure TPDFSignaturePad.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P, OldP: TPoint;
begin
  inherited;
  if not FDrawing then Exit;
  P := Point(MulDiv(X, FBitmap.Width, Width), MulDiv(Y, FBitmap.Height, Height));
  if (P.X = FPrevious.X) and (P.Y = FPrevious.Y) then Exit;
  OldP := FPrevious;
  FBitmap.Canvas.Pen.Color := clBlack;
  FBitmap.Canvas.Pen.Width := FPenWidth;
  FBitmap.Canvas.Pen.Style := psSolid;
  FBitmap.Canvas.MoveTo(FPrevious.X, FPrevious.Y);
  FBitmap.Canvas.LineTo(P.X, P.Y);
  FPrevious := P;
  FStrokeMoved := True;
  FHasInk := True;
  RepaintStroke(OldP, P);
end;

procedure TPDFSignaturePad.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
begin
  inherited;
  if (Button <> mbLeft) or not FDrawing then Exit;
  if not FStrokeMoved then
  begin
    // Einzelklick: Punkt mit dem Durchmesser der gewaehlten Strichstaerke.
    R := FPenWidth div 2;
    FBitmap.Canvas.Pen.Style := psClear;
    FBitmap.Canvas.Brush.Color := clBlack;
    FBitmap.Canvas.Ellipse(FPrevious.X - R, FPrevious.Y - R,
      FPrevious.X - R + FPenWidth, FPrevious.Y - R + FPenWidth);
    FBitmap.Canvas.Pen.Style := psSolid;
    FHasInk := True;
    RepaintStroke(FPrevious, FPrevious);
  end;
  FDrawing := False;
  MouseCapture := False;
end;

function ChoosePDFSignatureSource(AOwner: TComponent; ADesign: Integer;
  const ATitle, ACreateText, AImportText, ACancelText: string): Integer;
var
  D: TForm;
  HeaderLabel, HelpLabel: TLabel;
  DrawButton, ImportButton, SavedButton, CancelButton: TPanel;
  Actions: TSignatureSourceActions;
  BackColor, ForeColor, ButtonColor: TColor;
  DPI: Integer;
  function S(V: Integer): Integer;
  begin Result := MulDiv(V, DPI, 96); end;
  function NewButton(const Caption: string; X, Y, W, H, Modal: Integer): TPanel;
  begin
    Result := TPanel.Create(D);
    Result.Parent := D;
    Result.ParentFont := False;
    Result.Font.Assign(D.Font);
    Result.Caption := Caption;
    Result.BevelOuter := bvRaised;
    Result.Alignment := taCenter;
    Result.VerticalAlignment := taVerticalCenter;
    Result.Cursor := crHandPoint;
    Result.Color := ButtonColor;
    Result.Font.Color := ForeColor;
    if ADesign = 0 then
      Result.Font.Style := []
    else
      Result.Font.Style := [fsBold];
    Result.Tag := Modal;
    Result.OnClick := Actions.ButtonClick;
    Result.SetBounds(S(X), S(Y), S(W), S(H));
  end;
begin
  Result := 0;
  D := TForm.CreateNew(AOwner);
  Actions := TSignatureSourceActions.Create;
  try
    Actions.Form := D;
    D.KeyPreview := True;
    D.OnKeyDown := Actions.KeyDown;
    // DPI vor dem Erstellen der Steuerelemente festlegen.
    // Keine zweite automatische VCL-Skalierung der bereits skalierten Bounds.
    D.Scaled := False;
    if AOwner is TControl then
      DPI := TControl(AOwner).CurrentPPI
    else
      DPI := Screen.PixelsPerInch;
    if DPI < 96 then DPI := 96;
    D.Caption := ATitle;
    D.Position := poScreenCenter;
    D.BorderStyle := bsDialog;
    D.ClientWidth := S(590);
    D.ClientHeight := S(300);
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    case ADesign of
      1: begin BackColor := RGB(225,232,241); ForeColor := RGB(35,48,65); ButtonColor := RGB(245,247,250); end;
      2: begin BackColor := RGB(54,58,65); ForeColor := clWhite; ButtonColor := RGB(65,70,79); end;
      3: begin BackColor := RGB(192,192,192); ForeColor := clBlack; ButtonColor := RGB(220,220,220); end;
      4: begin BackColor := RGB(34,36,40); ForeColor := clWhite; ButtonColor := RGB(45,48,54); end;
      5: begin BackColor := RGB(190,214,237); ForeColor := RGB(24,55,88); ButtonColor := RGB(205,225,245); end;
    else
      begin BackColor := clBtnFace; ForeColor := clWindowText; ButtonColor := clBtnFace; end;
    end;
    D.Color := BackColor;
    D.Font.Color := ForeColor;
    HeaderLabel := TLabel.Create(D);
    HeaderLabel.Parent := D;
    HeaderLabel.ParentFont := False;
    HeaderLabel.Font.Assign(D.Font);
    HeaderLabel.Font.Style := [fsBold];
    HeaderLabel.Font.Color := ForeColor;
    HeaderLabel.Caption := ATitle;
    HeaderLabel.SetBounds(S(20), S(20), S(550), S(30));
    HelpLabel := TLabel.Create(D);
    HelpLabel.Parent := D;
    HelpLabel.ParentFont := False;
    HelpLabel.Font.Assign(D.Font);
    HelpLabel.Font.Color := ForeColor;
    if Pos('Unterschrift', ATitle) > 0 then
      HelpLabel.Caption := 'Wählen Sie, wie Sie Ihre Unterschrift hinzufügen möchten.'
    else
      HelpLabel.Caption := 'Choose how to add your signature.';
    HelpLabel.SetBounds(S(20), S(60), S(550), S(30));
    DrawButton := NewButton(ACreateText, 20, 108, 267, 52, mrYes);
    ImportButton := NewButton(AImportText, 303, 108, 267, 52, mrNo);
    if Pos('Unterschrift', ATitle) > 0 then
      SavedButton := NewButton('Gespeicherte Unterschrift auswählen ...',
        20, 172, 550, 44, mrRetry)
    else
      SavedButton := NewButton('Select saved signature ...',
        20, 172, 550, 44, mrRetry);
    CancelButton := NewButton(ACancelText, 438, 241, 132, 36, mrCancel);
    Result := D.ShowModal;
  finally
    Actions.Free;
    D.Free;
  end;
end;

function CreatePDFSignaturePNG(AOwner: TComponent; const ATitle,
  ADrawText, AClearText, AOKText, ACancelText: string;
  out AFileName: string; ADesign: Integer): Boolean;
var
  D: TForm;
  Pad: TPDFSignaturePad;
  HintLabel, PenLabel: TLabel;
  ThinButton, MediumButton, ThickButton: TButton;
  ClearButton, OKButton, CancelButton: TPanel;
  Actions: TSignatureDialogActions;
  PNG: TPngImage;
  Tmp: string;
  DPI: Integer;
  BackColor, TextColor, ButtonColor, AccentColor: TColor;
  IsGerman: Boolean;
  function S(V: Integer): Integer;
  begin Result := MulDiv(V, DPI, 96); end;
  function AddAction(const Caption: string; X, Y, W, H: Integer;
    AClick: TNotifyEvent): TPanel;
  begin
    Result := TPanel.Create(D);
    Result.Parent := D;
    Result.ParentBackground := False;
    Result.ParentColor := False;
    Result.SetBounds(S(X), S(Y), S(W), S(H));
    Result.Caption := Caption;
    Result.Color := ButtonColor;
    Result.Font.Name := D.Font.Name;
    Result.Font.Size := D.Font.Size;
    Result.Font.Color := TextColor;
    if ADesign = 0 then Result.Font.Style := []
    else Result.Font.Style := [fsBold];
    Result.BevelOuter := bvRaised;
    Result.Cursor := crHandPoint;
    Result.OnClick := AClick;
  end;
  function AddButton(const Caption: string; X, Y, W, H: Integer): TButton;
  begin
    Result := TButton.Create(D);
    Result.Parent := D;
    Result.ParentFont := False;
    Result.Font.Assign(D.Font);
    Result.Caption := Caption;
    Result.SetBounds(S(X), S(Y), S(W), S(H));
  end;
begin
  Result := False;
  AFileName := '';
  D := TForm.CreateNew(AOwner);
  Actions := TSignatureDialogActions.Create;
  try
    // Die Panel-Buttons rufen Actions.CancelClick/OKClick auf.
    // Ohne diese Zuweisung ist Actions.Form = nil (AV bei ModalResult).
    Actions.Form := D;
    D.KeyPreview := True;
    D.OnKeyDown := Actions.DialogKeyDown;
    // DPI vor dem Erstellen der Steuerelemente festlegen.
    // Keine zweite automatische VCL-Skalierung der bereits skalierten Bounds.
    D.Scaled := False;
    if AOwner is TControl then
      DPI := TControl(AOwner).CurrentPPI
    else
      DPI := Screen.PixelsPerInch;
    if DPI < 96 then DPI := 96;
    D.Caption := ATitle;
    D.Position := poScreenCenter;
    D.BorderStyle := bsDialog;
    D.ClientWidth := S(620);
    D.ClientHeight := S(390);
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    IsGerman := Pos('Unterschrift', ATitle) > 0;
    case ADesign of
      1: begin BackColor := RGB(225,232,241); TextColor := RGB(35,48,65); ButtonColor := RGB(245,247,250); AccentColor := RGB(57,103,166); end;
      2: begin BackColor := RGB(54,58,65); TextColor := clWhite; ButtonColor := RGB(65,70,79); AccentColor := RGB(103,161,225); end;
      3: begin BackColor := RGB(192,192,192); TextColor := clBlack; ButtonColor := RGB(220,220,220); AccentColor := RGB(55,90,145); end;
      4: begin BackColor := RGB(34,36,40); TextColor := clWhite; ButtonColor := RGB(45,48,54); AccentColor := RGB(105,164,228); end;
      5: begin BackColor := RGB(190,214,237); TextColor := RGB(24,55,88); ButtonColor := RGB(205,225,245); AccentColor := RGB(30,91,157); end;
    else
      begin BackColor := clBtnFace; TextColor := clWindowText; ButtonColor := clBtnFace; AccentColor := clHighlight; end;
    end;
    D.Color := BackColor;
    D.Font.Color := TextColor;
    HintLabel := TLabel.Create(D);
    HintLabel.Parent := D;
    HintLabel.ParentFont := False;
    HintLabel.Font.Assign(D.Font);
    HintLabel.Font.Color := TextColor;
    HintLabel.Caption := ADrawText;
    HintLabel.SetBounds(S(20),S(13),S(580),S(24));
    Pad := TPDFSignaturePad.Create(D);
    Pad.Parent := D;
    Pad.SetBounds(S(20),S(43),S(580),S(220));
    Pad.Bitmap.SetSize(Pad.Width, Pad.Height);
    Pad.Clear;
    Actions.Pad := Pad;
    PenLabel := TLabel.Create(D);
    PenLabel.Parent := D;
    PenLabel.ParentFont := False;
    PenLabel.Font.Assign(D.Font);
    PenLabel.Font.Color := TextColor;
    if IsGerman then PenLabel.Caption := 'Stift:' else PenLabel.Caption := 'Pen:';
    PenLabel.SetBounds(S(20),S(282),S(43),S(25));
    if IsGerman then
    begin
      ThinButton := AddButton('Dünn', 65, 275, 76, 34);
      MediumButton := AddButton('Mittel', 149, 275, 76, 34);
      ThickButton := AddButton('Dick', 233, 275, 76, 34);
    end
    else
    begin
      ThinButton := AddButton('Thin', 65, 275, 76, 34);
      MediumButton := AddButton('Medium', 149, 275, 76, 34);
      ThickButton := AddButton('Thick', 233, 275, 76, 34);
    end;
    Actions.ThinButton := ThinButton;
    Actions.MediumButton := MediumButton;
    Actions.ThickButton := ThickButton;
    ThinButton.OnClick := Actions.ThinClick;
    MediumButton.OnClick := Actions.MediumClick;
    ThickButton.OnClick := Actions.ThickClick;
    Actions.SetPen(4);
    ClearButton := AddAction(AClearText, 20, 330, 108, 38, Actions.ClearClick);
    OKButton := AddAction(AOKText, 364, 330, 112, 38, Actions.OKClick);
    CancelButton := AddAction(ACancelText, 484, 330, 116, 38, Actions.CancelClick);
    // Native Schaltflaechen uebernehmen die System-/Designfarben ohne
    // OwnerDraw; das verhindert Flackern und erhaelt Tastaturbedienung.
    if (D.ShowModal <> mrOk) or not Pad.HasInk then Exit;
    Tmp := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
      'FreePDF64_signature_' + IntToHex(GetTickCount,8) + '.png';
    PNG := TPngImage.Create;
    try
      PNG.Assign(Pad.Bitmap);
      PNG.SaveToFile(Tmp);
    finally
      PNG.Free;
    end;
    AFileName := Tmp;
    Result := True;
  finally
    Actions.Free;
    D.Free;
  end;
end;

end.

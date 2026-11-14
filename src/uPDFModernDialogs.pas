unit uPDFModernDialogs;

interface

uses
  uPDFLanguage,
  System.SysUtils, System.Classes, System.Math, Winapi.Windows, Vcl.Forms, Vcl.Controls,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Dialogs;

function PDFModernMessageDlg(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint;
  EscapeClosesOK: Boolean = False): Integer;

implementation

type
  // ScrollBox, der Mausradbewegungen auch dann verarbeitet, wenn der Zeiger
  // über dem Nachrichtentext steht. Die Schrittweite wird DPI-skaliert.
  TPDFMessageScrollBox = class(TScrollBox)
  public
    function ScrollByWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean;
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  end;

  TPDFMessageBodyLabel = class(TLabel)
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  end;

function TPDFMessageScrollBox.ScrollByWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  OldPosition, Step: Integer;
begin
  OldPosition := VertScrollBar.Position;
  Step := MulDiv(48, CurrentPPI, 96);
  if Step < 1 then Step := 1;
  // Positiver WheelDelta bedeutet nach oben scrollen.
  VertScrollBar.Position := OldPosition - MulDiv(WheelDelta, Step, WHEEL_DELTA);
  Result := VertScrollBar.Position <> OldPosition;
  if not Result then
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

function TPDFMessageScrollBox.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := ScrollByWheel(Shift, WheelDelta, MousePos);
end;

function TPDFMessageBodyLabel.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  if (Parent is TPDFMessageScrollBox) then
    Result := TPDFMessageScrollBox(Parent).ScrollByWheel(Shift, WheelDelta, MousePos)
  else
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

function PDFModernMessageDlg(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint;
  EscapeClosesOK: Boolean): Integer;
const
  Ink = $00433425;
  Accent = $00C47A20;
  Pale = $00F8F1E8;
var
  D: TForm;
  TopBar, BottomBar: TPanel;
  BodyScroll: TPDFMessageScrollBox;
  Heading: TLabel;
  Body: TPDFMessageBodyLabel;
  B: TButton;
  Items: array[0..11] of TModalResult;
  Captions: array[0..11] of string;
  Count, I, Scale, Margin, Gap, BtnH, BtnW, X, DialogW: Integer;
  TitleText, DisplayMsg: string;
  MeasureRect: TRect;
  BodyTop, BodyHeight, BodyBottomGap: Integer;
  WorkArea: TRect;
  MaxDialogW, MaxDialogH, NaturalDialogH: Integer;

  function WrapLongTokens(const S: string; MaxChars: Integer): string;
  var
    P, StartPos, TokenLen, I: Integer;
    Token: string;
  begin
    Result := '';
    P := 1;
    while P <= Length(S) do
    begin
      if S[P] in [#9, #10, #13, ' '] then
      begin
        Result := Result + S[P];
        Inc(P);
        Continue;
      end;
      StartPos := P;
      while (P <= Length(S)) and not (S[P] in [#9, #10, #13, ' ']) do
        Inc(P);
      Token := Copy(S, StartPos, P - StartPos);
      TokenLen := Length(Token);
      I := 1;
      while I <= TokenLen do
      begin
        if I > 1 then Result := Result + sLineBreak;
        Result := Result + Copy(Token, I, MaxChars);
        Inc(I, MaxChars);
      end;
    end;
  end;

  procedure AddChoice(Kind: TMsgDlgBtn; Modal: TModalResult; const CaptionText: string);
  begin
    if Kind in Buttons then
    begin
      Items[Count] := Modal;
      Captions[Count] := CaptionText;
      Inc(Count);
    end;
  end;

begin
  D := TForm.CreateNew(Application.MainForm);
  try
    D.BorderStyle := bsDialog;
    // Alle Dialogkoordinaten werden unten explizit anhand der aktuellen
    // DPI skaliert. VCL-Autoskalierung deshalb deaktivieren, damit bei
    // 200/250 % keine doppelte Skalierung entsteht.
    D.Scaled := False;
    D.Position := poMainFormCenter;
    D.Font.Name := 'Segoe UI';
    D.Font.Size := 10;
    D.Color := clWhite;
    D.BorderIcons := [biSystemMenu];
    Scale := 96;
    if (Application.MainForm <> nil) and
       (Application.MainForm.CurrentPPI > 0) then
      Scale := Application.MainForm.CurrentPPI
    else if Screen.PixelsPerInch > 0 then
      Scale := Screen.PixelsPerInch;
    if Scale < 96 then Scale := 96;
    D.PixelsPerInch := Scale;
    Margin := MulDiv(24, Scale, 96);
    Gap := MulDiv(10, Scale, 96);
    BtnH := MulDiv(38, Scale, 96);
    BtnW := MulDiv(126, Scale, 96);
    Count := 0;
    if PDFLanguage = 'en' then
    begin
      AddChoice(mbYes, mrYes, 'Yes');
      AddChoice(mbNo, mrNo, 'No');
      AddChoice(mbOK, mrOk, 'OK');
      AddChoice(mbCancel, mrCancel, 'Cancel');
      AddChoice(mbAbort, mrAbort, 'Abort');
      AddChoice(mbRetry, mrRetry, 'Retry');
      AddChoice(mbIgnore, mrIgnore, 'Ignore');
      AddChoice(mbAll, mrAll, 'All');
      AddChoice(mbNoToAll, mrNoToAll, 'No to All');
      AddChoice(mbYesToAll, mrYesToAll, 'Yes to All');
      AddChoice(mbHelp, mrNone, 'Help');
      AddChoice(mbClose, mrClose, 'Close');
      case DlgType of
        mtWarning: TitleText := 'Notice';
        mtError: TitleText := 'Error';
        mtInformation: TitleText := 'Information';
        mtConfirmation: TitleText := 'Confirmation';
      else
        TitleText := 'FreePDF64-Viewer';
      end;
    end
    else
    begin
      AddChoice(mbYes, mrYes, 'Ja');
      AddChoice(mbNo, mrNo, 'Nein');
      AddChoice(mbOK, mrOk, 'OK');
      AddChoice(mbCancel, mrCancel, 'Abbrechen');
      AddChoice(mbAbort, mrAbort, 'Abbrechen');
      AddChoice(mbRetry, mrRetry, 'Wiederholen');
      AddChoice(mbIgnore, mrIgnore, 'Ignorieren');
      AddChoice(mbAll, mrAll, 'Alle');
      AddChoice(mbNoToAll, mrNoToAll, 'Nein für alle');
      AddChoice(mbYesToAll, mrYesToAll, 'Ja für alle');
      AddChoice(mbHelp, mrNone, 'Hilfe');
      AddChoice(mbClose, mrClose, 'Schließen');
      case DlgType of
        mtWarning: TitleText := 'Hinweis';
        mtError: TitleText := 'Fehler';
        mtInformation: TitleText := 'Information';
        mtConfirmation: TitleText := 'Bestätigung';
      else
        TitleText := 'FreePDF64-Viewer';
      end;
    end;
    D.Caption := TitleText + ' – FreePDF64-Viewer';

    // Sicherheitswarnung als eigenen Absatz darstellen, damit Frage und
    // Warnhinweis optisch klar voneinander getrennt sind.
    DisplayMsg := Trim(Msg);
    // Sicherheitswarnung unabhängig davon absetzen, ob der Aufrufer davor
    // ein Leerzeichen oder bereits einen Zeilenumbruch übergibt.
    DisplayMsg := StringReplace(DisplayMsg,
      sLineBreak + 'Öffnen Sie nur Anlagen', 'Öffnen Sie nur Anlagen',
      [rfReplaceAll, rfIgnoreCase]);
    DisplayMsg := StringReplace(DisplayMsg, 'Öffnen Sie nur Anlagen',
      sLineBreak + sLineBreak + 'Öffnen Sie nur Anlagen',
      [rfReplaceAll, rfIgnoreCase]);

    // Bei Anlagen-Informationsmeldungen die Anzahl/Überschrift optisch von
    // den Dateipfaden trennen. Die dynamische Texthöhe berücksichtigt den Abstand.
    if DlgType = mtInformation then
      DisplayMsg := StringReplace(DisplayMsg,
        'Anlage(n) wurden hinzugefügt:' + sLineBreak,
        'Anlage(n) wurden hinzugefügt:' + sLineBreak + sLineBreak,
        [rfReplaceAll, rfIgnoreCase]);

    // Formular-Kompatibilitaetswarnung: Nur diesen Hinweis optisch hervorheben.
    // Die eigentliche Nachricht bleibt unveraendert und scrollbar.
    if (Pos('WICHTIGER HINWEIS ZUR FORMULAR-KOMPATIBILITÄT', DisplayMsg) = 1) or
       (Pos('IMPORTANT FORM COMPATIBILITY NOTICE', DisplayMsg) = 1) then
    begin
      TitleText := Copy(DisplayMsg, 1, Pos(sLineBreak, DisplayMsg) - 1);
      Delete(DisplayMsg, 1, Length(TitleText));
      DisplayMsg := Trim(DisplayMsg);
    end;

    // Sehr lange Pfade oder Dateinamen enthalten oft keine Leerzeichen. Solche
    // Textteile werden für die Anzeige umgebrochen, damit nichts rechts abgeschnitten wird.
    DisplayMsg := WrapLongTokens(DisplayMsg, 58);

    // Etwas breiterer Dialog, damit die Nachricht den verfügbaren Platz besser nutzt.
    DialogW := MulDiv(620, Scale, 96);
    // Die verfügbare Fläche des Monitors verwenden, auf dem der Viewer liegt.
    // SPI_GETWORKAREA liefert sonst unter Umständen die Fläche des Primärmonitors.
    if (Application.MainForm <> nil) then
    begin
      WorkArea := Application.MainForm.Monitor.WorkareaRect;
    end
    else
      SystemParametersInfo(SPI_GETWORKAREA, 0, @WorkArea, 0);
    MaxDialogW := WorkArea.Right - WorkArea.Left - MulDiv(48, Scale, 96);
    if MaxDialogW > 0 then DialogW := Min(DialogW, MaxDialogW);
    if Count > 0 then
      DialogW := Max(DialogW, 2 * Margin + Count * BtnW + (Count - 1) * Gap);
    D.ClientWidth := DialogW;
    // Die tatsächliche Texthöhe statt einer pauschalen Zeichenlängen-Heuristik
    // verwenden. Das verhindert abgeschnittene mehrzeilige Hinweise bei DPI-Skalierung.
    D.Canvas.Font.Assign(D.Font);
    MeasureRect := Rect(0, 0, DialogW - 2 * Margin, 0);
    DrawText(D.Canvas.Handle, PChar(DisplayMsg), Length(DisplayMsg), MeasureRect,
      DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX or DT_EXPANDTABS);
    BodyHeight := Max(MeasureRect.Bottom - MeasureRect.Top,
      MulDiv(44, Scale, 96)) + MulDiv(12, Scale, 96);
    BodyTop := MulDiv(66, Scale, 96);
    BodyBottomGap := MulDiv(16, Scale, 96);
    NaturalDialogH := BodyTop + BodyHeight + BodyBottomGap + MulDiv(78, Scale, 96);
    MaxDialogH := WorkArea.Bottom - WorkArea.Top - MulDiv(48, Scale, 96);
    if MaxDialogH > 0 then
      D.ClientHeight := Min(NaturalDialogH, MaxDialogH)
    else
      D.ClientHeight := NaturalDialogH;

    TopBar := TPanel.Create(D);
    TopBar.Parent := D;
    TopBar.Align := alTop;
    TopBar.Height := MulDiv(66, Scale, 96);
    TopBar.BevelOuter := bvNone;
    TopBar.ParentBackground := False;
    TopBar.Color := Pale;

    Heading := TLabel.Create(D);
    Heading.Parent := TopBar;
    Heading.ParentFont := False;
    Heading.SetBounds(Margin, MulDiv(12, Scale, 96),
      DialogW - 2 * Margin, MulDiv(44, Scale, 96));
    Heading.Layout := tlCenter;
    Heading.AutoSize := False;
    Heading.Font.Name := 'Segoe UI';
    Heading.Font.Size := 13;
    Heading.Font.Style := [fsBold];
    Heading.Font.Color := Accent;
    if (Pos('WICHTIGER HINWEIS ZUR FORMULAR-KOMPATIBILITÄT', TitleText) = 1) or
       (Pos('IMPORTANT FORM COMPATIBILITY NOTICE', TitleText) = 1) then
    begin
      Heading.Font.Color := $002020A0; // Dunkelrot (VCL BGR)
      Heading.Font.Size := 11;
    end;
    Heading.Caption := TitleText;

    BottomBar := TPanel.Create(D);
    BottomBar.Parent := D;
    BottomBar.Align := alBottom;
    BottomBar.Height := MulDiv(78, Scale, 96);
    BottomBar.BevelOuter := bvNone;
    BottomBar.ParentBackground := False;
    BottomBar.Color := Pale;

    // Der Nachrichtenbereich darf bei sehr langen Meldungen nicht außerhalb
    // des Bildschirms liegen. In diesem Fall bleibt der vollständige Text scrollbar.
    BodyScroll := TPDFMessageScrollBox.Create(D);
    BodyScroll.Parent := D;
    BodyScroll.Align := alClient;
    BodyScroll.BorderStyle := bsNone;
    BodyScroll.HorzScrollBar.Visible := False;
    BodyScroll.VertScrollBar.Tracking := True;
    BodyScroll.AutoScroll := True;
    BodyScroll.Color := clWhite;
    BodyScroll.ParentBackground := False;

    Body := TPDFMessageBodyLabel.Create(D);
    Body.Parent := BodyScroll;
    Body.AutoSize := False;
    Body.WordWrap := True;
    Body.Font.Color := Ink;
    Body.SetBounds(Margin, Margin, Max(1, BodyScroll.ClientWidth - 2 * Margin),
      BodyHeight);
    Body.Anchors := [akLeft, akTop, akRight];
    Body.Caption := DisplayMsg;
    BodyScroll.VertScrollBar.Range := BodyHeight + 2 * Margin;
    X := DialogW - Margin - Count * BtnW - (Count - 1) * Gap;
    for I := 0 to Count - 1 do
    begin
      B := TButton.Create(D);
      B.Parent := BottomBar;
      B.ParentFont := False;
      B.Font.Assign(D.Font);
      B.Caption := Captions[I];
      B.ModalResult := Items[I];
      B.SetBounds(X, (BottomBar.Height - BtnH) div 2, BtnW, BtnH);
      B.Anchors := [akBottom];
      if (Items[I] = mrOK) or (Items[I] = mrYes) then
      begin
        B.Default := True;
        D.ActiveControl := B;
      end;
      if (Items[I] = mrCancel) or (Items[I] = mrNo) or
         (EscapeClosesOK and (Count = 1) and (Items[I] = mrOK)) then
        B.Cancel := True;
      Inc(X, BtnW + Gap);
    end;
    Result := D.ShowModal;
  finally
    D.Free;
  end;
end;

end.

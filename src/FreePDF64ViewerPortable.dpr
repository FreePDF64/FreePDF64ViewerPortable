//
// FreePDF64ViewerPortable
// =======================
// PROJEKT UND KONTAKT
// -------------------
// Projektseite: https://github.com/FreePDF64
// E-Mail:       FreePDF64@outlook.com
// Copyright © 2026 FreePDF64
//
program FreePDF64ViewerPortable;

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  uFreePDF64PDFiumCore in 'uFreePDF64PDFiumCore.pas',
  uFreePDF64PDFiumView in 'uFreePDF64PDFiumView.pas',
  uPDFAttachmentTemp in 'uPDFAttachmentTemp.pas',
  uPDFBrowserForm in 'uPDFBrowserForm.pas' {PDFBrowserForm},
  uPDFTabsForm in 'uPDFTabsForm.pas',
  uPDFPortableAttachments in 'uPDFPortableAttachments.pas',
  uPDFErrorLogger in 'uPDFErrorLogger.pas';

{$R *.res}

var
  ErrorLogger: TPDFErrorLogger;
  Viewer: TPDFTabsForm;
  Browser: TPDFBrowserForm;
  PDFFile: string;
  I: Integer;
  PDFArgs: TStringList;
  AllForwarded: Boolean;
  Attempt: Integer;
  SingleInstanceMutex: THandle;
  AlreadyRunning: Boolean;
  RestartLaunch: Boolean;
  WaitResult: DWORD;
begin
  ErrorLogger := nil;
  // Prozessübergreifende Sperre: auch parallele Explorer-Aufrufe
  // dürfen niemals ein zweites Viewer-Fenster erzeugen.
  SingleInstanceMutex := CreateMutex(nil, True,
    'Local\FreePDF64ViewerPortable.SingleInstance.v1');
  if SingleInstanceMutex = 0 then
    RaiseLastOSError;
  AlreadyRunning := GetLastError = ERROR_ALREADY_EXISTS;
  RestartLaunch := (ParamCount > 0) and SameText(ParamStr(1), '--restart');
  if RestartLaunch and AlreadyRunning then
  begin
    // Der bisherige Viewer beendet sich erst nach dem Speichern/Schliessen.
    WaitResult := WaitForSingleObject(SingleInstanceMutex, 30000);
    if (WaitResult <> WAIT_OBJECT_0) and (WaitResult <> WAIT_ABANDONED) then
      Exit;
    AlreadyRunning := False; // Mutex gehoert jetzt diesem Prozess.
  end;
  // Bei normalem Zweitstart wurde der Mutex nicht erworben.
  // Ein ReleaseMutex waere hier unzulaessig.

  try
    try
  // Der Explorer startet für jede ausgewählte PDF einen eigenen Prozess.
  // Bereits vor CreateForm an den laufenden Viewer weiterleiten.
  PDFArgs := TStringList.Create;
  try
    for I := 1 to ParamCount do
      if SameText(ExtractFileExt(ParamStr(I)), '.pdf') and
         FileExists(ExpandFileName(ParamStr(I))) then
        PDFArgs.Add(ExpandFileName(ParamStr(I)));

    // Nur eine bereits laufende Instanz braucht den Weiterleitungsversuch.
    // Beim Erststart entfallen sonst bis zu 1,5 Sekunden Wartezeit.
    if (PDFArgs.Count > 0) and AlreadyRunning then
    begin
      AllForwarded := False;
      // Kurze Wartezeit, falls die erste Instanz gerade erst startet.
      for Attempt := 1 to 15 do
      begin
        if SendPDFToExistingTabs(PDFArgs[0]) then
        begin
          AllForwarded := True;
          for I := 1 to PDFArgs.Count - 1 do
            if not SendPDFToExistingTabs(PDFArgs[I]) then
              AllForwarded := False;
          Break;
        end;
        if Attempt < 15 then Sleep(100);
      end;
      if AllForwarded then Exit;
    end;
    // Ohne PDF-Parameter ebenfalls nur das vorhandene Fenster aktivieren.
    // Bei gleichzeitigem Start auf die Initialisierung der ersten Instanz warten.
    if AlreadyRunning then
    begin
      for Attempt := 1 to 50 do
      begin
        if uPDFTabsForm.ActivateExistingPortableViewer then Break;
        Sleep(100);
      end;
      Exit;
    end;
  finally
    PDFArgs.Free;
  end;
  Application.Initialize;
  // Zentrale Fehlerbehandlung fuer unbehandelte VCL-Exceptions.
  // Die Log-Datei wird neben der EXE im Programmverzeichnis angelegt.
  ErrorLogger := TPDFErrorLogger.Create;
  Application.OnException := ErrorLogger.HandleException;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'FreePDF64-Viewer Portable';
  // Eigenstaendige Viewer-Instanz ohne FreePDF64-Hauptfenster.
  PDFTabsExplorerOnlyProcess := False;
  // Anlagen nicht mehr beim Oeffnen jeder PDF untersuchen.
  // Der Bueroklammer-Button erstellt die Anlagenliste bei Bedarf.
  PDFTabAttachmentsInitializer := nil;
  Application.CreateForm(TPDFTabsForm, PDFTabsWindow);
  Viewer := PDFTabsWindow;
  // Hauptfensterhandle wird mit WS_MINIMIZE erzeugt, falls gewuenscht.
  Viewer.HandleNeeded;
  for I := 1 to ParamCount do
  begin
    PDFFile := ExpandFileName(ParamStr(I));
    if FileExists(PDFFile) and SameText(ExtractFileExt(PDFFile), '.pdf') then
    begin
      if Viewer.ActivateExistingPDF(PDFFile) then Continue;
      Browser := TPDFBrowserForm.Create(nil);
      try
        Browser.PDFFileName := PDFFile;
        Browser.StandalonePDFMode := False;
        Viewer.AddPDF(Browser);
      except
        Browser.Free;
        raise;
      end;
    end;
  end;
  // VCL muss das Hauptfenster selbst im minimierten Zustand anzeigen.
  // ShowMainForm=False plus nachtraegliches ShowWindow verursachte ein
  // grosses weisses Fenster und inkonsistente Taskleisten-Zustaende.
  // WindowState wird bereits im Form-Konstruktor aus der INI gesetzt.
  // VCL zeigt die Hauptform zuerst korrekt an; die optionale
  // Minimierung erfolgt erst nach OnShow (WM_APP + 198).
  Application.ShowMainForm := True;
  Application.Run;
  except
    on E: Exception do
    begin
      // Auch Fehler waehrend des Programmstarts oder beim Erzeugen
      // von Formularen protokollieren, nicht nur VCL-Ereignisfehler.
      if ErrorLogger <> nil then
      begin
        ErrorLogger.LogException('Programmstart / Hauptprogramm', E);
        try
          Application.ShowException(E);
        except
          // Fehler beim Anzeigen der Meldung nicht weiter eskalieren.
        end;
      end
      else
        raise;
    end;
  end;
  finally
    Application.OnException := nil;
    FreeAndNil(ErrorLogger);
    if not AlreadyRunning then ReleaseMutex(SingleInstanceMutex);
    CloseHandle(SingleInstanceMutex);
  end;
end.

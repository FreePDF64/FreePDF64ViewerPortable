unit uPDFMetadataEditor;

interface

uses System.SysUtils, System.Classes, Vcl.Forms;

type
  TPDFMetadataValues = array[0..4] of string;

function EditPDFMetadata(AOwner: TComponent; const SourceFile: string;
  const Initial: TPDFMetadataValues; const English: Boolean; const DesignIndex: Integer): Boolean;

implementation

uses System.IOUtils, System.RegularExpressions, Vcl.StdCtrls, Vcl.Controls,
  Vcl.Dialogs, Vcl.Graphics, Winapi.Windows, Math, System.ZLib;

// PDFium is already bundled with the Viewer; no additional binaries are required.
function MetaFPDF_LoadDocument(FileName, Password: PAnsiChar): Pointer; stdcall;
  external 'pdfium.dll' name 'FPDF_LoadDocument';
procedure MetaFPDF_CloseDocument(Doc: Pointer); stdcall;
  external 'pdfium.dll' name 'FPDF_CloseDocument';
function MetaFPDF_GetPageCount(Doc: Pointer): Integer; stdcall;
  external 'pdfium.dll' name 'FPDF_GetPageCount';
function MetaFPDF_GetMetaText(Doc: Pointer; Tag: PAnsiChar; Buffer: Pointer;
  BufLen: Cardinal): Cardinal; stdcall;
  external 'pdfium.dll' name 'FPDF_GetMetaText';

function ReadPDFiumMeta(Doc: Pointer; const Key: AnsiString): string;
var
  N: Cardinal;
  Buffer: TArray<WideChar>;
begin
  Result := '';
  N := MetaFPDF_GetMetaText(Doc, PAnsiChar(Key), nil, 0);
  if N = 0 then Exit;
  if (N < 2) or (N > 1024*1024) or (N mod 2 <> 0) then
    raise Exception.Create('Invalid PDFium metadata length.');
  SetLength(Buffer, (N div 2) + 1);
  FillChar(Buffer[0], Length(Buffer)*SizeOf(WideChar), 0);
  if MetaFPDF_GetMetaText(Doc, PAnsiChar(Key), @Buffer[0], N) <> N then
    raise Exception.Create('PDFium metadata read failed.');
  Result := string(PWideChar(@Buffer[0]));
end;

procedure VerifyMetadataWithPDFium(const OriginalFile, TempFile: string;
  const Expected: TPDFMetadataValues);
const
  Keys: array[0..4] of AnsiString = ('Title','Author','Subject','Keywords','Creator');
var
  OriginalDoc, NewDoc: Pointer;
  OriginalName, TempName: UTF8String;
  I: Integer;
begin
  OriginalName := UTF8String(OriginalFile);
  TempName := UTF8String(TempFile);
  OriginalDoc := MetaFPDF_LoadDocument(PAnsiChar(OriginalName), nil);
  if OriginalDoc = nil then
    raise Exception.Create('PDFium cannot reopen the original PDF.');
  try
    NewDoc := MetaFPDF_LoadDocument(PAnsiChar(TempName), nil);
    if NewDoc = nil then
      raise Exception.Create('PDFium cannot open the newly written PDF.');
    try
      if MetaFPDF_GetPageCount(OriginalDoc) <> MetaFPDF_GetPageCount(NewDoc) then
        raise Exception.Create('PDFium page count differs after metadata update.');
      for I := 0 to 4 do
        if ReadPDFiumMeta(NewDoc, Keys[I]) <> Expected[I] then
          raise Exception.Create('PDFium metadata verification failed: ' + string(Keys[I]));
    finally
      MetaFPDF_CloseDocument(NewDoc);
    end;
  finally
    MetaFPDF_CloseDocument(OriginalDoc);
  end;
end;

function Enc(const S: string): string;
var I: Integer;
begin
  // PDF Unicode text string, UTF-16BE with BOM, encoded as hexadecimal.
  Result := '<FEFF';
  for I := 1 to Length(S) do
    Result := Result + IntToHex(Ord(S[I]), 4);
  Result := Result + '>';
end;

function MatchValue(const S, Pattern: string): string;
var M: TMatch;
begin
  M := TRegEx.Match(S, Pattern, [roSingleLine]);
  if not M.Success then raise Exception.Create('Unsupported PDF structure: ' + Pattern);
  Result := M.Groups[1].Value;
end;

procedure AppendMetadata(const SourceFile, DestFile: string; const Values: TPDFMetadataValues);
const Keys: array[0..4] of string = ('Title','Author','Subject','Keywords','Creator');
var Src, Dst: TFileStream; Tail: TBytes; S, Trailer, Root, IDPart: string;
    Prev, Size, NewObj, PosObj, PosXref: Int64; I, ReadSize, Got: Integer;
    Scan: TBytes; ChunkText, Carry: string;
    TempFile, XRefHeader: string;
    IsXRefStream: Boolean;
    MetaObj, MetaPos, XmpLength: Int64; XmpSource, XmpUpdated: string;
    XmpBytes: TBytes; M: TMatch; ObjHead, XmpText: string;
    EncodedXmp: TBytes; DecodedXmp: TMemoryStream;
    ZStream: TDecompressionStream; EncodedStream: TBytesStream;
    IsFlate: Boolean;
  function EscapeXML(const Value: string): string;
  begin
    Result := StringReplace(Value, '&', '&amp;', [rfReplaceAll]);
    Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
    Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
    Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
    Result := StringReplace(Result, #39, '&apos;', [rfReplaceAll]);
  end;
  function ReplaceElement(const XML, Tag, Value: string): string;
  var Pattern, Replacement: string; Match: TMatch;
  begin
    Pattern := '(<' + Tag + '(?:\s+[^>]*)?>)(.*?)(</' + Tag + '\s*>)';
    Match := TRegEx.Match(XML, Pattern, [roSingleLine]);
    if not Match.Success then
      raise Exception.Create('XMP field not supported: ' + Tag);
    Replacement := Match.Groups[1].Value + EscapeXML(Value) + Match.Groups[3].Value;
    Result := Copy(XML, 1, Match.Index-1) + Replacement +
      Copy(XML, Match.Index+Match.Length, MaxInt);
  end;
  function ReplaceListValue(const XML, Tag, Value: string): string;
  var Pattern, Replacement: string; Match: TMatch;
  begin
    Pattern := '(<' + Tag + '(?:\s+[^>]*)?>\s*<rdf:(?:Alt|Seq)>\s*<rdf:li(?:\s+[^>]*)?>)(.*?)(</rdf:li>)';
    Match := TRegEx.Match(XML, Pattern, [roSingleLine]);
    if not Match.Success then
      raise Exception.Create('XMP list field not supported: ' + Tag);
    Replacement := Match.Groups[1].Value + EscapeXML(Value) + Match.Groups[3].Value;
    Result := Copy(XML, 1, Match.Index-1) + Replacement +
      Copy(XML, Match.Index+Match.Length, MaxInt);
  end;
  procedure WriteUTF8(const Text: string);
  var B: TBytes;
  begin
    B := TEncoding.UTF8.GetBytes(Text);
    if Length(B)>0 then Dst.WriteBuffer(B[0], Length(B));
  end;
  procedure WriteASCII(const Text: string);
  var B: TBytes;
  begin
    B := TEncoding.ASCII.GetBytes(Text);
    if Length(B)>0 then Dst.WriteBuffer(B[0], Length(B));
  end;
begin
  if SameText(ExpandFileName(SourceFile), ExpandFileName(DestFile)) then
    raise Exception.Create('Choose a different destination file.');
  Src := TFileStream.Create(SourceFile, fmOpenRead or fmShareDenyWrite);
  try
    if Src.Size < 30 then
      raise Exception.Create('Invalid PDF file.');
    ReadSize := Integer(Min(Src.Size, Int64(2*1024*1024)));
    SetLength(Tail, ReadSize);
    Src.Position := Src.Size - ReadSize;
    Src.ReadBuffer(Tail[0], ReadSize);
    S := TEncoding.GetEncoding(28591).GetString(Tail);
    if not TRegEx.IsMatch(S, 'startxref\s+\d+\s+%%EOF\s*$', [roSingleLine]) then
      raise Exception.Create('Unsupported PDF ending.');
    Prev := StrToInt64(MatchValue(S, 'startxref\s+(\d+)\s+%%EOF\s*$'));
    if (Prev < 0) or (Prev >= Src.Size) then
      raise Exception.Create('Invalid PDF cross-reference offset.');
    // An incremental classic xref section may follow an existing xref stream.
    // The /Prev pointer retains the complete preceding cross-reference chain.
    Src.Position := Prev;
    SetLength(Tail, Integer(Min(Src.Size-Prev, Int64(16))));
    Src.ReadBuffer(Tail[0], Length(Tail));
    IsXRefStream := Copy(TrimLeft(TEncoding.ASCII.GetString(Tail)), 1, 4) <> 'xref';
    if IsXRefStream then
    begin
      // Read the object header and its dictionary, not the compressed stream.
      Src.Position := Prev;
      ReadSize := Integer(Min(Src.Size - Prev, Int64(65536)));
      SetLength(Tail, ReadSize);
      Src.ReadBuffer(Tail[0], ReadSize);
      XRefHeader := TEncoding.GetEncoding(28591).GetString(Tail);
      I := Pos('stream', XRefHeader);
      if I = 0 then
        raise Exception.Create('Invalid cross-reference stream.');
      XRefHeader := Copy(XRefHeader, 1, I-1);
      if not TRegEx.IsMatch(XRefHeader, '^\s*\d+\s+\d+\s+obj\s*<<', [roSingleLine]) or
         not TRegEx.IsMatch(XRefHeader, '/Type\s*/XRef\b') then
        raise Exception.Create('Unsupported cross-reference structure.');
      Trailer := XRefHeader;
    end
    else
    begin
      // Classic xref: the trailer preceding the final startxref.
      I := S.LastIndexOf('trailer');
      if I < 0 then raise Exception.Create('PDF trailer not found.');
      Trailer := Copy(S, I+8, MaxInt);
      I := Pos('startxref', Trailer);
      if I <= 0 then raise Exception.Create('PDF trailer is incomplete.');
      Trailer := Copy(Trailer, 1, I-1);
    end;
    Root := MatchValue(Trailer, '/Root\s+(\d+\s+\d+\s+R)');
    Size := StrToInt64(MatchValue(Trailer, '/Size\s+(\d+)'));
    if (Size < 1) or (Size > 99999999) then raise Exception.Create('Invalid PDF object count.');
    if TRegEx.IsMatch(Trailer, '/Encrypt\b') then
      raise Exception.Create('Encrypted PDFs are not supported.');
    // Hybrid-reference PDFs retain their previous xref table and /XRefStm.
    // An appended classic xref update can point to the prior revision via /Prev.
    // Do not carry /XRefStm into the newly generated trailer.
    // Read-only, bounded-memory scan; also works for large PDFs.
    // Overlap catches markers crossing a chunk boundary.
    Src.Position := 0;
    SetLength(Scan, 1024*1024);
    Carry := '';
    repeat
      Got := Src.Read(Scan[0], Length(Scan));
      if Got <= 0 then Break;
      ChunkText := Carry + TEncoding.GetEncoding(28591).GetString(Scan, 0, Got);
      if TRegEx.IsMatch(ChunkText, '/ByteRange\s*\[|/Type\s*/Sig\b|/FT\s*/Sig\b') then
        raise Exception.Create('Digitally signed PDFs are not supported.');
      if Length(ChunkText) > 256 then
        Carry := Copy(ChunkText, Length(ChunkText)-255, 256)
      else
        Carry := ChunkText;
    until False;
    // Locate an uncompressed XMP metadata stream. Complex XMP layouts are rejected,
    // rather than silently producing conflicting Info and XMP values.
    MetaObj := -1; XmpSource := '';
    Src.Position := 0;
    SetLength(Scan, 1024*1024);
    Carry := '';
    repeat
      Got := Src.Read(Scan[0], Length(Scan));
      if Got <= 0 then Break;
      ChunkText := Carry + TEncoding.GetEncoding(28591).GetString(Scan, 0, Got);
      for M in TRegEx.Matches(ChunkText, '/Metadata\s+(\d+)\s+0\s+R') do
        MetaObj := StrToInt64(M.Groups[1].Value);
      if Length(ChunkText)>255 then Carry := Copy(ChunkText, Length(ChunkText)-254, 255)
      else Carry := ChunkText;
    until False;
    if MetaObj >= 0 then
    begin
      // This branch supports ordinary, uncompressed XML XMP packets (including
      // the Ghostscript-produced PDF64-HowTo.pdf test document).
      Src.Position := 0;
      Carry := '';
      MetaPos := -1;
      repeat
        Got := Src.Read(Scan[0], Length(Scan));
        if Got <= 0 then Break;
        ChunkText := Carry + TEncoding.GetEncoding(28591).GetString(Scan, 0, Got);
        M := TRegEx.Match(ChunkText, '(?<!\d)' + IntToStr(MetaObj) + '\s+0\s+obj\s*<<(?:(?!endobj).)*?/Type\s*/Metadata\b', [roSingleLine]);
        if M.Success then
        begin
          MetaPos := Src.Position-Got-Length(Carry)+M.Index-1;
          Break;
        end;
        if Length(ChunkText)>8191 then Carry := Copy(ChunkText, Length(ChunkText)-8190, 8191)
        else Carry := ChunkText;
      until False;
      if MetaPos < 0 then raise Exception.Create('Compressed or unsupported XMP metadata object.');
      Src.Position := MetaPos;
      SetLength(Tail, Integer(Min(Src.Size-MetaPos, Int64(4*1024*1024))));
      if Length(Tail)=0 then raise Exception.Create('Empty XMP metadata object.');
      Src.ReadBuffer(Tail[0], Length(Tail));
      ObjHead := TEncoding.GetEncoding(28591).GetString(Tail);
      M := TRegEx.Match(ObjHead, '^\d+\s+0\s+obj\s*<<(.*?)>>\s*stream\r?\n', [roSingleLine]);
      if not M.Success then raise Exception.Create('Unsupported XMP stream dictionary.');
      XmpLength := StrToInt64(MatchValue(M.Groups[1].Value, '/Length\s+(\d+)'));
      if (XmpLength < 0) or (XmpLength > 3*1024*1024) or
         (M.Length + XmpLength > Length(Tail)) then
        raise Exception.Create('Oversized or invalid XMP packet.');
      IsFlate := TRegEx.IsMatch(M.Groups[1].Value,
        '/Filter\s*(?:/FlateDecode\b|\[\s*/FlateDecode\s*\])');
      if TRegEx.IsMatch(M.Groups[1].Value, '/Filter\b') and not IsFlate then
        raise Exception.Create('Unsupported XMP compression filter.');
      if IsFlate and TRegEx.IsMatch(M.Groups[1].Value, '/DecodeParms\b') then
        raise Exception.Create('XMP with DecodeParms requires separate handling.');
      if IsFlate then
      begin
        SetLength(EncodedXmp, Integer(XmpLength));
        if XmpLength > 0 then Move(Tail[M.Length], EncodedXmp[0], Integer(XmpLength));
        EncodedStream := TBytesStream.Create(EncodedXmp);
        try
          ZStream := TDecompressionStream.Create(EncodedStream);
          try
            DecodedXmp := TMemoryStream.Create;
            try
              // Bounded decompression to avoid decompression bombs.
              repeat
                SetLength(EncodedXmp, 16384);
                Got := ZStream.Read(EncodedXmp[0], Length(EncodedXmp));
                if Got <= 0 then Break;
                if DecodedXmp.Size + Got > 8*1024*1024 then
                  raise Exception.Create('Decompressed XMP exceeds safety limit.');
                DecodedXmp.WriteBuffer(EncodedXmp[0], Got);
              until False;
              SetLength(EncodedXmp, Integer(DecodedXmp.Size));
              DecodedXmp.Position := 0;
              if Length(EncodedXmp)>0 then DecodedXmp.ReadBuffer(EncodedXmp[0], Length(EncodedXmp));
              XmpSource := TEncoding.UTF8.GetString(EncodedXmp);
            finally DecodedXmp.Free; end;
          finally ZStream.Free; end;
        finally EncodedStream.Free; end;
      end
      else
        XmpSource := TEncoding.UTF8.GetString(Tail, M.Length, Integer(XmpLength));
      if not TRegEx.IsMatch(XmpSource, '<rdf:RDF\b') then
        raise Exception.Create('XMP is not a supported RDF/XML packet.');
      XmpUpdated := ReplaceListValue(XmpSource, 'dc:title', Values[0]);
      XmpUpdated := ReplaceListValue(XmpUpdated, 'dc:creator', Values[1]);
      XmpUpdated := ReplaceListValue(XmpUpdated, 'dc:description', Values[2]);
      XmpUpdated := ReplaceElement(XmpUpdated, 'pdf:Keywords', Values[3]);
      XmpUpdated := ReplaceElement(XmpUpdated, 'xmp:CreatorTool', Values[4]);
      XmpBytes := TEncoding.UTF8.GetBytes(XmpUpdated);
    end;
    IDPart := '';
    if TRegEx.IsMatch(Trailer, '/ID\s*\[\s*<[^>]+>\s*<[^>]+>\s*\]') then
      IDPart := TRegEx.Match(Trailer, '/ID\s*\[\s*<[^>]+>\s*<[^>]+>\s*\]').Value;
    NewObj := Size;
    // Always create an exclusive temporary file in the destination directory.
    // Never open the user's destination with fmCreate.
    TempFile := TPath.Combine(ExtractFilePath(DestFile),
      '.' + ExtractFileName(DestFile) + '.' + TGUID.NewGuid.ToString + '.tmp');
    try
      Dst := TFileStream.Create(TempFile, fmCreate);
      try
        // Stream the original PDF without loading it into memory.
        Src.Position := 0;
        Dst.CopyFrom(Src, Src.Size);
      // A replacement of the existing XMP object is appended as an incremental
      // revision, keeping the catalog and all page objects untouched.
      if MetaObj >= 0 then
      begin
        MetaPos := Dst.Position;
        WriteASCII(#10 + IntToStr(MetaObj) + ' 0 obj' + #10 +
          '<< /Type /Metadata /Subtype /XML /Length ' + IntToStr(Length(XmpBytes)) +
          ' >>' + #10 + 'stream' + #10);
        if Length(XmpBytes)>0 then Dst.WriteBuffer(XmpBytes[0], Length(XmpBytes));
        WriteASCII(#10 + 'endstream' + #10 + 'endobj' + #10);
      end;
      PosObj := Dst.Position;
      WriteASCII(#10 + IntToStr(NewObj) + ' 0 obj' + #10 + '<<' + #10);
      for I := 0 to 4 do WriteASCII('/' + Keys[I] + ' ' + Enc(Values[I]) + #10);
      WriteASCII('>>' + #10 + 'endobj' + #10);
      PosXref := Dst.Position;
      WriteASCII('xref' + #10);
      if MetaObj >= 0 then
        WriteASCII(IntToStr(MetaObj) + ' 1' + #10 +
          Format('%.10d 00000 n ', [MetaPos]) + #10);
      WriteASCII(IntToStr(NewObj) + ' 1' + #10 +
        Format('%.10d 00000 n ', [PosObj]) + #10);
      WriteASCII('trailer' + #10 + '<< /Size ' + IntToStr(NewObj+1) +
        ' /Root ' + Root + ' /Info ' + IntToStr(NewObj) + ' 0 R' +
        ' /Prev ' + IntToStr(Prev) + ' ' + IDPart + ' >>' + #10 +
        'startxref' + #10 + IntToStr(PosXref) + #10 + '%%EOF' + #10);
      finally Dst.Free; end;
    except
      System.SysUtils.DeleteFile(TempFile);
      raise;
    end;
    // Validate the appended tail before publishing the output.
    try
      Dst := TFileStream.Create(TempFile, fmOpenRead or fmShareDenyNone);
      try
      if Dst.Size <= Src.Size then
        raise Exception.Create('The generated PDF is incomplete.');
      Dst.Position := PosXref;
      SetLength(Tail, 4);
      Dst.ReadBuffer(Tail[0], 4);
      if TEncoding.ASCII.GetString(Tail) <> 'xref' then
        raise Exception.Create('Generated PDF cross-reference validation failed.');
      finally
        Dst.Free;
      end;
    except
      System.SysUtils.DeleteFile(TempFile);
      raise;
    end;
    // Verify the full PDF and all five metadata fields with the existing
    // PDFium engine before making the output visible to the user.
    try
      VerifyMetadataWithPDFium(SourceFile, TempFile, Values);
    except
      System.SysUtils.DeleteFile(TempFile);
      raise;
    end;
    // Publish only after PDFium validation. ReplaceFile preserves the old
    // destination if replacement cannot be completed (e.g. locked file).
    if FileExists(DestFile) then
    begin
      if not Winapi.Windows.ReplaceFile(PChar(DestFile), PChar(TempFile),
        nil, 0, nil, nil) then
      begin
        System.SysUtils.DeleteFile(TempFile);
        raise Exception.Create('Cannot replace the existing PDF. Close it in other applications and try again.');
      end;
    end
    else if not Winapi.Windows.MoveFile(PChar(TempFile), PChar(DestFile)) then
    begin
      System.SysUtils.DeleteFile(TempFile);
      raise Exception.Create('Cannot create the destination PDF.');
    end;
  finally Src.Free; end;
end;

// Map internal writer diagnostics to complete, user-readable DE/EN messages.
// The underlying exception text is deliberately not appended to German UI.
function MetadataErrorText(const Detail: string; English: Boolean): string;
var D: string;
begin
  D := LowerCase(Detail);
  if Pos('cannot replace the existing pdf', D) > 0 then
  begin
    if English then Result := 'The existing PDF could not be replaced. Close it in other applications and try again.'
    else Result := 'Die vorhandene PDF-Datei konnte nicht ersetzt werden. Schließen Sie die Datei in anderen Anwendungen und versuchen Sie es erneut.';
  end
  else if (Pos('cannot create the destination pdf', D) > 0) or
          (Pos('access is denied', D) > 0) or (Pos('zugriff verweigert', D) > 0) then
  begin
    if English then Result := 'The destination PDF could not be created. Check folder permissions and whether the file is in use.'
    else Result := 'Die Ziel-PDF konnte nicht erstellt werden. Prüfen Sie die Ordnerberechtigungen und ob die Datei verwendet wird.';
  end
  else if Pos('digitally signed', D) > 0 then
  begin
    if English then Result := 'This PDF contains a digital signature. Editing its metadata is blocked to protect the signature.'
    else Result := 'Diese PDF enthält eine digitale Signatur. Die Metadatenbearbeitung wurde zum Schutz der Signatur verhindert.';
  end
  else if Pos('encrypted pdf', D) > 0 then
  begin
    if English then Result := 'Encrypted PDF files cannot currently be edited.'
    else Result := 'Verschlüsselte PDF-Dateien können derzeit nicht bearbeitet werden.';
  end
  else if (Pos('xmp', D) > 0) or (Pos('rdf/xml', D) > 0) then
  begin
    if English then Result := 'The XMP metadata structure in this PDF is not supported.'
    else Result := 'Die XMP-Metadatenstruktur dieser PDF wird noch nicht unterstützt.';
  end
  else if (Pos('pdfium', D) > 0) or (Pos('verification', D) > 0) or
          (Pos('page count differs', D) > 0) then
  begin
    if English then Result := 'The generated PDF failed validation. The destination file was not changed.'
    else Result := 'Die erzeugte PDF hat die Prüfung nicht bestanden. Die Zieldatei wurde nicht verändert.';
  end
  else if (Pos('unsupported', D) > 0) or (Pos('invalid', D) > 0) or
          (Pos('incomplete', D) > 0) then
  begin
    if English then Result := 'The PDF structure is invalid or not yet supported.'
    else Result := 'Die PDF-Struktur ist ungültig oder wird noch nicht unterstützt.';
  end
  else
  begin
    if English then Result := 'The PDF metadata could not be saved. Check the file and access permissions.'
    else Result := 'Die PDF-Metadaten konnten nicht gespeichert werden. Prüfen Sie die Datei und die Zugriffsberechtigungen.';
  end;
end;

function EditPDFMetadata(AOwner: TComponent; const SourceFile: string;
  const Initial: TPDFMetadataValues; const English: Boolean; const DesignIndex: Integer): Boolean;
const DE: array[0..4] of string = ('Titel','Autor','Betreff','Schlüsselwörter','Ersteller');
      EN: array[0..4] of string = ('Title','Author','Subject','Keywords','Creator');
var F: TForm; Ed: array[0..4] of TEdit; L: TLabel; B: TButton;
    D: TSaveDialog; V: TPDFMetadataValues; I, PPI: Integer;
    function Px(N: Integer): Integer;
    begin Result := Round(Int64(N) * PPI / 96); end;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  try
    if English then F.Caption := 'Edit PDF metadata' else F.Caption := 'PDF-Metadaten bearbeiten';
    F.Scaled := False;
    F.Font.Name := 'Segoe UI'; F.Font.Size := 9;
    case DesignIndex of
      1: begin F.Color := RGB(249,251,254); F.Font.Color := RGB(35,48,65); end;
      3: begin F.Color := RGB(232,232,232); F.Font.Color := clBlack; end;
      5: begin F.Color := RGB(220,233,247); F.Font.Color := RGB(24,55,88); end;
      6: begin F.Color := RGB(231,234,237); F.Font.Color := RGB(49,57,65); end;
    else begin F.Color := clBtnFace; F.Font.Color := clWindowText; end;
    end;
    PPI := 96;
    if AOwner is TControl then
      if GetParentForm(TControl(AOwner)) <> nil then
        PPI := GetParentForm(TControl(AOwner)).CurrentPPI;
    if PPI < 96 then PPI := 96;
    F.BorderStyle := bsDialog; F.Position := poDesigned;
    F.ClientWidth := Px(480); F.ClientHeight := Px(250);
    // Dialog am Viewer-Hauptfenster statt am gesamten Bildschirm ausrichten.
    // AOwner ist die PDF-Ansicht; ihr ParentForm ist das Viewer-Fenster.
    if (AOwner is TControl) and (GetParentForm(TControl(AOwner)) <> nil) then
    begin
      F.PopupMode := pmExplicit;
      F.PopupParent := GetParentForm(TControl(AOwner));
      F.Left := F.PopupParent.Left + (F.PopupParent.Width - F.Width) div 2;
      F.Top := F.PopupParent.Top + (F.PopupParent.Height - F.Height) div 2;
    end
    else
      F.Position := poScreenCenter;
    for I := 0 to 4 do
    begin
      L := TLabel.Create(F); L.Parent := F;
      if English then L.Caption := EN[I] else L.Caption := DE[I];
      L.SetBounds(Px(14), Px(17+I*35), Px(125), Px(24));
      Ed[I] := TEdit.Create(F); Ed[I].Parent := F;
      Ed[I].Text := Initial[I]; Ed[I].SetBounds(Px(145), Px(13+I*35), Px(320), Px(27));
      Ed[I].Color := clWindow; Ed[I].Font.Color := clWindowText;
    end;
    B := TButton.Create(F); B.Parent := F; B.ModalResult := mrOk;
    if English then B.Caption := 'Save as...' else B.Caption := 'Speichern unter ...';
    B.SetBounds(Px(230), Px(202), Px(130), Px(32)); B.Default := True;
    B := TButton.Create(F); B.Parent := F; B.ModalResult := mrCancel;
    if English then B.Caption := 'Cancel' else B.Caption := 'Abbrechen';
    B.SetBounds(Px(370), Px(202), Px(95), Px(32)); B.Cancel := True;
    // Keep the metadata editor alive if the user cancels the file picker,
    // selects the source itself, or a write fails. All edits remain in Ed[].
    while F.ShowModal = mrOk do
    begin
      for I := 0 to 4 do V[I] := Ed[I].Text;
      D := TSaveDialog.Create(F);
      try
        D.Filter := 'PDF (*.pdf)|*.pdf'; D.DefaultExt := 'pdf';
        D.Options := [ofOverwritePrompt, ofPathMustExist];
        D.FileName := ChangeFileExt(SourceFile, '') + '_metadata.pdf';
        if not D.Execute then Continue;
        if SameText(ExpandFileName(SourceFile), ExpandFileName(D.FileName)) then
        begin
          if English then
            MessageDlg('The PDF currently open in the Viewer cannot be overwritten directly. Choose a different file or close the PDF first.', mtWarning, [mbOK], 0)
          else
            MessageDlg('Die aktuell im Viewer geöffnete PDF kann nicht direkt überschrieben werden. Bitte wählen Sie eine andere Datei oder schließen Sie die PDF zuerst.', mtWarning, [mbOK], 0);
          Continue;
        end;
        try
          AppendMetadata(SourceFile, D.FileName, V);
          Result := True;
          if English then ShowMessage('Metadata saved to: ' + D.FileName)
          else ShowMessage('Metadaten gespeichert: ' + D.FileName);
          Break;
        except
          on E: Exception do
          begin
            MessageDlg(MetadataErrorText(E.Message, English), mtError, [mbOK], 0);
          end;
        end;
      finally D.Free; end;
    end;
  finally F.Free; end;
end;

end.

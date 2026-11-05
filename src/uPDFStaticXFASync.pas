unit uPDFStaticXFASync;

// Patch 25: conservative synchronization for classic, unencrypted PDFs with
// an /XFA array and one FlateDecode or uncompressed datasets stream.
// Unsupported structures are rejected rather than silently corrupted.
interface
uses System.SysUtils, System.Classes, System.Generics.Collections;
procedure SynchronizeStaticXFA(const FileName: string;
  Values: TDictionary<string,string>);
implementation
uses Winapi.Windows, System.RegularExpressions, System.ZLib, System.StrUtils,
     Xml.XMLDoc, Xml.XMLIntf;

function Match1(const S, Pattern: string): string;
var M: TMatch;
begin
  M := TRegEx.Match(S, Pattern, [roSingleLine, roIgnoreCase]);
  if not M.Success then Result := '' else Result := M.Groups[1].Value;
end;

function BytesToLatin(const B: TBytes): string;
var I: Integer;
begin
  SetLength(Result, Length(B));
  for I := 0 to High(B) do Result[I+1] := Char(B[I]);
end;

function UTF8Bytes(const S: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(S);
end;

function StreamInflate(const Data: TBytes): TBytes;
var Input, Output: TMemoryStream; D: TDecompressionStream; CountRead: Integer; Chunk: array[0..8191] of Byte;
begin
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;
  try
    if Length(Data)>0 then Input.WriteBuffer(Data[0], Length(Data));
    Input.Position := 0;
    D := TDecompressionStream.Create(Input);
    try
      while True do
      begin
        CountRead := D.Read(Chunk, SizeOf(Chunk));
        if CountRead=0 then Break;
        if Output.Size+CountRead>32*1024*1024 then
          raise Exception.Create('XFA-Datasets zu gross.');
        Output.WriteBuffer(Chunk,CountRead);
      end;
    finally D.Free; end;
    if Output.Size > 32*1024*1024 then
      raise Exception.Create('XFA-Datasets zu gross.');
    SetLength(Result, Output.Size);
    Output.Position := 0;
    if Length(Result)>0 then Output.ReadBuffer(Result[0],Length(Result));
  finally Input.Free; Output.Free; end;
end;

function StreamDeflate(const Data: TBytes): TBytes;
var Output: TMemoryStream; Z: TCompressionStream;
begin
  Output := TMemoryStream.Create;
  try
    Z := TCompressionStream.Create(clDefault, Output);
    try if Length(Data)>0 then Z.WriteBuffer(Data[0], Length(Data));
    finally Z.Free; end;
    SetLength(Result, Output.Size);
    Output.Position := 0;
    if Length(Result)>0 then Output.ReadBuffer(Result[0],Length(Result));
  finally Output.Free; end;
end;

// Find the last *complete* indirect object of a given number.  PDFium can
// write a newer generation/revision, so an early match is not authoritative.
function LatestIndirectObject(const PDF: string; Number: Integer;
  Generation: Integer = -1): string;
var
  Pattern: string;
  M: TMatch;
  Matches: TMatchCollection;
  K: Integer;
begin
  Result := '';
  if Generation >= 0 then
    Pattern := Format('(?:^|[\r\n])\s*%d\s+%d\s+obj\b(.*?)endobj',
      [Number, Generation])
  else
    Pattern := Format('(?:^|[\r\n])\s*%d\s+\d+\s+obj\b(.*?)endobj',
      [Number]);
  Matches := TRegEx.Matches(PDF, Pattern, [roSingleLine]);
  for K := Matches.Count - 1 downto 0 do
  begin
    M := Matches.Item[K];
    if M.Success then
    begin
      Result := M.Groups[1].Value;
      Exit;
    end;
  end;
end;

function ApplyStaticXFA(const FileName: string;
  Values: TDictionary<string,string>): Boolean;
var
  FS: TFileStream;
  All, Obj, Acro, XFAArray, Trailer, XRefText, XMLText, NewXML: string;
  Buf, Data, NewData, ObjBytes, Suffix: TBytes;
  AcroNo, DatasetNo, DatasetGen, RootNo, RootGen, SizeVal: Integer;
  ObjMatch, M: TMatch;
  HeaderMatches: TMatchCollection;
  HeaderPattern: string;
  HeaderPos, HeaderEnd, EndObjPos: Integer;
  ObjStart, StreamStart, StreamEnd, PrevXRef, NewXRef: Int64;
  N, I, Updated: Integer;
  Doc: IXMLDocument;
  Node, DataNode: IXMLNode;
  Used: TDictionary<string,Boolean>;
  Name, Value: string;
  IsFlate: Boolean;
  ChildIndex: Integer;
  function FindNode(const Parent: IXMLNode; const Key: string): IXMLNode;
  var C: IXMLNode; J: Integer;
  begin
    Result := nil;
    if Parent = nil then Exit;
    for J := 0 to Parent.ChildNodes.Count-1 do
    begin
      C := Parent.ChildNodes[J];
      if SameText(C.LocalName, Key) or SameText(C.NodeName,Key) then
      begin Result := C; Exit; end;
      Result := FindNode(C,Key);
      if Result<>nil then Exit;
    end;
  end;
  function LocatePath(const Parent: IXMLNode; const Path: string): IXMLNode;
  var Parts: TArray<string>; J: Integer; P: IXMLNode;
  begin
    Result := nil;
    Parts := Path.Split(['.']);
    P := Parent;
    for J := 0 to High(Parts) do
    begin
      P := FindNode(P, Parts[J]);
      if P=nil then Exit;
    end;
    Result := P;
  end;
  procedure WriteBytes(const B: TBytes);
  begin if Length(B)>0 then FS.WriteBuffer(B[0],Length(B)); end;
begin
  Result := False;
  if (Values=nil) or (Values.Count=0) then Exit;
  FS := TFileStream.Create(FileName, fmOpenReadWrite or fmShareExclusive);
  try
    if FS.Size > 128*1024*1024 then
      raise Exception.Create('XFA-Synchronisation: PDF ueber 128 MB wird aus Sicherheitsgruenden nicht direkt geaendert.');
    SetLength(Buf, FS.Size);
    if Length(Buf)>0 then FS.ReadBuffer(Buf[0],Length(Buf));
    All := BytesToLatin(Buf);
    if Pos('/Encrypt', All)>0 then
      raise Exception.Create('XFA-Synchronisation: verschluesselte PDFs nicht unterstuetzt.');
    // Read the last classic trailer and its preceding xref position.
    I := LastDelimiter(#10, All); // no semantic reliance; below uses regex
    M := TRegEx.Match(All, 'startxref\s*(\d+)\s*%%EOF\s*$', [roSingleLine]);
    if not M.Success then raise Exception.Create('XFA: startxref fehlt.');
    PrevXRef := StrToInt64(M.Groups[1].Value);
    if (PrevXRef<0) or (PrevXRef>=Length(All)) or
      (Copy(All,PrevXRef+1,4)<>'xref') then
      raise Exception.Create('XFA: nur klassische PDF-Querverweistabellen unterstuetzt.');
    Trailer := Copy(All,PrevXRef+1,Length(All)-PrevXRef);
    if Pos('/XRefStm',Trailer)>0 then
      raise Exception.Create('XFA: hybride Querverweistabellen nicht unterstuetzt.');
    RootNo := StrToIntDef(Match1(Trailer,'/Root\s+(\d+)\s+\d+\s+R'),0);
    RootGen := StrToIntDef(Match1(Trailer,'/Root\s+\d+\s+(\d+)\s+R'),0);
    SizeVal := StrToIntDef(Match1(Trailer,'/Size\s+(\d+)'),0);
    if (RootNo=0) or (SizeVal=0) then raise Exception.Create('XFA: PDF-Trailer unvollstaendig.');
    // PDFium can rewrite the catalog with a different generation than an
    // older incremental revision. Locate the latest matching object number.
    Obj := LatestIndirectObject(All, RootNo, RootGen);
    if Obj = '' then Obj := LatestIndirectObject(All, RootNo);
    if Obj = '' then raise Exception.Create('XFA: Katalog nicht lesbar (Objekt '+IntToStr(RootNo)+').');
    AcroNo := StrToIntDef(Match1(Obj,'/AcroForm\s+(\d+)\s+\d+\s+R'),0);
    if AcroNo=0 then Exit;
    Acro := LatestIndirectObject(All, AcroNo);
    if Acro = '' then raise Exception.Create('XFA: AcroForm nicht lesbar.');
    XFAArray := Match1(Acro,'/XFA\s*(\[.*?\])');
    if XFAArray='' then Exit; // no XFA: normal AcroForm unchanged
    DatasetNo := StrToIntDef(Match1(XFAArray,'\(datasets\)\s+(\d+)\s+\d+\s+R'),0);
    DatasetGen := StrToIntDef(Match1(XFAArray,'\(datasets\)\s+\d+\s+(\d+)\s+R'),0);
    if DatasetNo=0 then raise Exception.Create('XFA: datasets-Paket nicht gefunden.');
    Obj := LatestIndirectObject(All, DatasetNo, DatasetGen);
    if Obj = '' then raise Exception.Create('XFA: datasets-Objekt nicht lesbar.');
    if Pos('/Filter',Obj)>0 then
    begin
      if (Pos('/FlateDecode',Obj)=0) or
        TRegEx.IsMatch(Obj,'/Filter\s*\[', [roSingleLine]) then
        raise Exception.Create('XFA: unbekannter Kompressionsfilter.');
      IsFlate := True;
    end else IsFlate := False;
    N := StrToIntDef(Match1(Obj,'/Length\s+(\d+)'),-1);
    if (N<0) or (N>32*1024*1024) then
      raise Exception.Create('XFA: ungueltige datasets-Streamlaenge.');
    // Locate the exact stream marker in the original byte-preserving
    // Latin-1 representation. PosEx returns a ONE-based position.
    // The previous regex-offset calculation could select the wrong byte.
    HeaderPattern := Format('(?:^|[\r\n])\s*%d\s+%d\s+obj\b',
      [DatasetNo, DatasetGen]);
    HeaderMatches := TRegEx.Matches(All, HeaderPattern, [roSingleLine]);
    if HeaderMatches.Count = 0 then
      raise Exception.Create('XFA: datasets-Objektkopf nicht gefunden.');
    ObjMatch := HeaderMatches.Item[HeaderMatches.Count - 1];
    HeaderPos := ObjMatch.Index + ObjMatch.Length; // zero based
    EndObjPos := PosEx('endobj', All, HeaderPos + 1); // one based
    if EndObjPos = 0 then
      raise Exception.Create('XFA: datasets-Objektende nicht gefunden.');
    I := PosEx('stream'#13#10, All, HeaderPos + 1);
    if (I > 0) and (I < EndObjPos) then
      StreamStart := I - 1 + Length('stream'#13#10)
    else
    begin
      I := PosEx('stream'#10, All, HeaderPos + 1);
      if (I = 0) or (I >= EndObjPos) then
        raise Exception.Create('XFA: datasets-Stream fehlt.');
      StreamStart := I - 1 + Length('stream'#10);
    end;
    if (StreamStart < 0) or (StreamStart + N > Length(Buf)) or
       (StreamStart + N > EndObjPos - 1) then
      raise Exception.Create('XFA: datasets-Stream abgeschnitten.');
    SetLength(Data, N);
    if N > 0 then
      Move(Buf[Integer(StreamStart)], Data[0], N);
    if IsFlate then
    begin
      // Validate the RFC1950 zlib header before invoking Delphi's inflater.
      // This makes malformed extraction distinguishable from an inflate error.
      if (Length(Data) < 6) or
         ((Integer(Data[0]) * 256 + Integer(Data[1])) mod 31 <> 0) or
         ((Data[0] and $0F) <> 8) then
        raise Exception.CreateFmt(
          'XFA: FlateDecode-Header ungueltig (Objekt %d, Laenge %d, Offset %d).',
          [DatasetNo, Length(Data), StreamStart]);
      try
        Data := StreamInflate(Data);
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'XFA: FlateDecode fehlgeschlagen (Objekt %d, %d Bytes): %s',
            [DatasetNo, N, E.Message]);
      end;
    end;
    XMLText := TEncoding.UTF8.GetString(Data);
    Doc := TXMLDocument.Create(nil);
    Doc.Options := [doNodeAutoIndent];
    Doc.LoadFromXML(XMLText);
    Doc.Active := True;
    DataNode := FindNode(Doc.DocumentElement,'data');
    if DataNode=nil then raise Exception.Create('XFA: xfa:data fehlt.');
    Used := TDictionary<string,Boolean>.Create;
    try
      Updated := 0;
      for Name in Values.Keys do
      begin
        Value := Values[Name];
        Node := LocatePath(DataNode,Name);
        if Node=nil then Node := FindNode(DataNode,Name);
        if Node=nil then
          raise Exception.Create('XFA: keine eindeutige XML-Zuordnung fuer Feld '+Name);
        // Text nodes are normal children of simple XML elements. Reject
        // nested elements only, not the existing text value.
        for ChildIndex := 0 to Node.ChildNodes.Count - 1 do
          if Node.ChildNodes[ChildIndex].NodeType = ntElement then
            raise Exception.Create('XFA: Feld enthaelt Unterelemente: '+Name);
        Node.Text := Value;
        Inc(Updated);
      end;
    finally Used.Free; end;
    if Updated=0 then Exit;
    NewXML := Doc.XML.Text;
    NewData := UTF8Bytes(NewXML);
    if IsFlate then NewData := StreamDeflate(NewData);
    // Incremental update of the same datasets object; all previous PDF
    // bytes remain untouched. A fresh classic xref points to the new revision.
    FS.Position := FS.Size;
    ObjStart := FS.Position;
    XRefText := Format(#13#10'%d %d obj'#13#10'<< /Length %d',[DatasetNo,DatasetGen,Length(NewData)]);
    if IsFlate then XRefText := XRefText+' /Filter /FlateDecode';
    if Pos('/Type /EmbeddedFile',Obj)>0 then
      XRefText := XRefText+' /Type /EmbeddedFile';
    XRefText := XRefText+' >>'#13#10'stream'#13#10;
    WriteBytes(TEncoding.ASCII.GetBytes(XRefText));
    WriteBytes(NewData);
    WriteBytes(TEncoding.ASCII.GetBytes(#13#10'endstream'#13#10'endobj'#13#10));
    NewXRef := FS.Position;
    XRefText := Format('xref'#13#10'%d 1'#13#10'%.10d %.5d n '#13#10,
      [DatasetNo,ObjStart,DatasetGen]);
    // Preserve the original trailer dictionary to keep /ID, /Info and
    // other optional entries, but replace /Prev and /Size explicitly.
    M := TRegEx.Match(Trailer,'trailer\s*(<<.*?>>)\s*startxref',[roSingleLine]);
    if not M.Success then raise Exception.Create('XFA: Trailer-Dictionary nicht lesbar.');
    Acro := M.Groups[1].Value;
    Acro := TRegEx.Replace(Acro,'/Prev\s+\d+','');
    Acro := TRegEx.Replace(Acro,'/Size\s+\d+','');
    Acro := Copy(Acro,1,Length(Acro)-2)+Format(' /Size %d /Prev %d >>',[SizeVal,PrevXRef]);
    XRefText := XRefText+'trailer'#13#10+Acro+#13#10+
      'startxref'#13#10+IntToStr(NewXRef)+#13#10'%%EOF'#13#10;
    WriteBytes(TEncoding.ASCII.GetBytes(XRefText));
    Result := True;
  finally FS.Free; end;
end;

function FPDF_LoadDocument(Path: PAnsiChar; Password: PAnsiChar): Pointer;
  stdcall; external 'pdfium.dll';
procedure FPDF_CloseDocument(Doc: Pointer);
  stdcall; external 'pdfium.dll';

procedure SynchronizeStaticXFA(const FileName: string;
  Values: TDictionary<string,string>);
var Temp: string; D: Pointer; UTF8Name: UTF8String; Changed: Boolean;
begin
  if (Values=nil) or (Values.Count=0) then Exit;
  Temp := FileName+'.xfa25.'+IntToStr(GetCurrentProcessId)+'.tmp';
  if not CopyFile(PChar(FileName),PChar(Temp),False) then
    RaiseLastOSError;
  try
    Changed := ApplyStaticXFA(Temp,Values);
    if not Changed then Exit;
    // Avoid a second PDFium document load inside an active form save.
    // The caller performs its own saved-document validation.
    if not MoveFileEx(PChar(Temp),PChar(FileName),
       MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
  finally
    if FileExists(Temp) then
      System.SysUtils.DeleteFile(Temp);
  end;
end;
end.

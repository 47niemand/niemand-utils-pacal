(*****************************************
 * (c) 2010-2015 Dmitry Muza
 *
 * @author Dmitry Muza,
 * @email  dmitry.muza@gmail.com
 *
 ******************************************)

unit newwebcamstream;

interface

uses
{$IFDEF LINUX}
  Linux,
{$ELSE}
  Windows,
{$ENDIF}
  DateUtils,
  Classes,
  SyncObjs,
  webcamstreamtypes,
  Sysutils;

{$J+}
const
  ws_streamsignature: AnsiString = '--WINBONDBOUDARY'#13#10'Content-Type: image/jpeg'#13#10#13#10;
  ws_jpegsignature: AnsiString = #$FF#$D8#$FF; //#$E0;
{$J-}

type
  TPtrRange = record
    Start, Finish: Pointer;
  end;

  CPtrUtils = class
  public
    class function PosBuf(SubStr: String; Data: Pointer; Len: Integer; var Offset: Integer): Boolean;
    class function PtrEQ(A, B: Pointer): boolean;
    class function PtrGE(A, B: Pointer): boolean;
    class function PtrLT(A, B: Pointer): boolean;
    class function InRange(P, Start, Finish: Pointer): Boolean;
    class function IsIntersect(A, B: TPtrRange): Boolean;
    class function IsInclude(A, B: TPtrRange): Boolean;
    class function PtrDiff(BeforePtr, AfterPtr: Pointer): Integer;
    class function IncPointer(P: Pointer; D: Integer): Pointer;
    class function RangeIsSerial(A, B: TPtrRange): boolean;
  end;

  TBuffer = class
  private
    FBufPtr: Pointer;
    FBufSize: Integer;
    FOwnData: Boolean;
    function GetBufPtr: Pointer;
    function GetBufSize: Integer;
  protected
    procedure debug(const action: string);
  public
    function GetAsString: AnsiString;
    function GetPtrRange: TPtrRange;
    property OwnData: Boolean read FOwnData;
    property BufPtr: Pointer read GetBufPtr;
    property BufSize: Integer read GetBufSize;
    procedure CropHead(Count: Integer);
    procedure CropTail(Count: Integer);
    constructor CreateCopy(var Buf; Len: Integer);
    constructor Create(ABufPtr: Pointer; Len: Integer);
    constructor CreateOwn(ABufPtr: Pointer; Len: Integer);
    destructor Destroy; override;
  end;

  TBufferSearchResult = record
    FindBufferIndex: Integer;
    FindBufferOffset: Integer;
    FindBufferMathLine: Integer;
    GlobalOffset: Integer;
  end;

  TBufferList = class
  private
    FList: TList;
    function GetItems(Index: Integer): TBuffer;
    function GetCount: Integer;
    function PosBufEx(const SubStr: AnsiString; P: Pointer; Len: integer; out ResPtr: Pointer;
      var X: Integer): Boolean;
    function GetAsDebug: String;
  protected
    FResultsStreamSearchRange: Integer;
    function Last: TBuffer;
    function First: TBuffer;
    procedure debug(const action: string);
    function CrateResultsStream(S, F: Pointer; const ADataSignature: AnsiString = ''): TMemoryStream;
    function LastPtr(offset: Integer = 0): Pointer;
    function BuffGlobalOffset(Index: Integer): Integer;
  public
    procedure Clear;
    function SearchEx(SubStr: AnsiString; Offset: Integer; out SearchResult: TBufferSearchResult;
      const MaxLen: Integer = 0): Boolean;
    function FindBufferEx(P: Pointer; StartIndex: Integer; out BufferOffset: Integer): Integer;
    function FindBufferInRange(R: TPtrRange; StartIndex: Integer): Integer;
    procedure Add(ABuf: TBuffer);
    function Extract(index: Integer): TBuffer;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TBuffer read GetItems;
    function GetAsString: AnsiString;
    constructor Create;
    destructor Destroy; override;
  end;

  TWebCamStream = class (TStream)
  private
    CS: TCriticalSection;
    FBufList: TBufferList;
    FBufPtr: Pointer;
    FSaveCounter: Integer;
    FWriteCounter: Integer;
    FTail: Integer;
    FMarker: Integer;
    FBuffSize: Integer;
    FFoundSignatures: TList;
    FWebImageReciveEvent: TStreamImageReciveEvent;
    FStreamSignature: AnsiString;
    FDataSignature: AnsiString;
    FLocalTime: Boolean;
    FFixedCamId: Integer;
    procedure SetWebImageReciveEvent(const Value: TStreamImageReciveEvent);
    procedure SetDataSignature(const Value: AnsiString);
    procedure SetStreamSignature(const Value: AnsiString);
    procedure Purge(RangeStart, RangeFinish: Pointer);
    procedure TrySaveResults;
    procedure SetFixedCamId(const Value: Integer);
    procedure SetLocalTime(const Value: Boolean);
    procedure SetSignature(const Value: AnsiString);
    function GetSignature: AnsiString;
  protected
    procedure debug(const action: string); virtual;
  public
    procedure Clear;
    property Capacity: Integer read FBuffSize;
    property FixedCamId: Integer read FFixedCamId write SetFixedCamId;
    property LocalTime: Boolean read FLocalTime write SetLocalTime;
    constructor Create(ABufSize: Integer);
    function GetBufferAsString: AnsiString;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Write(const Buffer; Count: Integer): Integer; override;
    property OnWebImageReciveEvent: TStreamImageReciveEvent read FWebImageReciveEvent write SetWebImageReciveEvent;
    property DataSignature: AnsiString read FDataSignature write SetDataSignature;
    property StreamSignature: AnsiString read FStreamSignature write SetStreamSignature;
    property Signature: AnsiString read GetSignature write SetSignature;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
      override;
    destructor Destroy; override;
  end;


implementation

uses
  StrUtils, Math;

const
  AllowConcat = True;

type
  TByteArray = array[0..maxint div 2] of byte;
  PByteArray = ^TByteArray;

function PtrRange(AStart, AFinish: Pointer): TPtrRange;
begin
  if CPtrUtils.PtrGE(AStart, AFinish) then
  begin
    result.Start := AFinish;
    result.Finish := AStart;
  end
  else
  begin
    result.Start := AStart;
    result.Finish := AFinish;
  end;
end;

{ TWebCamStream }

constructor TWebCamStream.Create(ABufSize: Integer);
begin
  inherited Create;
  FFixedCamId := -1;
  FFoundSignatures := TList.Create;
  FBuffSize := ABufSize;
  GetMem(FBufPtr, ABufSize);
  FillChar(FBufPtr^, ABufSize, 0);
  FBufList := TBufferList.Create;
  CS := TCriticalSection.Create;
  FTail := 0;
  FDataSignature := ws_jpegsignature;
  FStreamSignature := ws_streamsignature;
end;

function TWebCamStream.Read(var Buffer; Count: Integer): Integer;
begin
  raise EStreamError.Create('Read not supproted');
end;

function TWebCamStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  result := 0;
end;

procedure TWebCamStream.SetWebImageReciveEvent(const Value: TStreamImageReciveEvent);
begin
  FWebImageReciveEvent := Value;
end;


procedure TWebCamStream.Purge(RangeStart, RangeFinish: Pointer);

  procedure PurgeSignature(S, F: Pointer);
  var
    i: Integer;
  begin
    i := 0;
    while i < FFoundSignatures.Count do
      if CPtrUtils.InRange(FFoundSignatures.Items[i], S, F) then
      begin
        debug(format('delete signature ptr %p', [FFoundSignatures.Items[i]]));
        FFoundSignatures.Delete(i);
      end
      else
        inc(i);
  end;

var
  i, j: Integer;
  A: TPtrRange;
  L: tList;
begin
  Assert(CPtrUtils.PtrLT(RangeStart, RangeFinish) or CPtrUtils.PtrEQ(RangeStart, RangeFinish));

  A := PtrRange(RangeStart, RangeFinish);

  L := nil;
  j := 0;
  j := FBufList.FindBufferInRange(A, j);

  while j >= 0 do
  begin
    if not Assigned(L) then
      L := TList.Create;
    L.Add(FBufList.Items[j]);

    debug(format('found intersect %d [%p,%p]', [j, FBufList.Items[j].BufPtr, FBufList.Items[j].GetPtrRange.Finish]));
    inc(j);
    j := FBufList.FindBufferInRange(A, j);
  end;

  if Assigned(L) then
  begin
    debug(format('try purge [%p,%p] of %d fragments', [RangeStart, RangeFinish, L.Count]));

    while L.Count > 0 do
    begin
      if CPtrUtils.IsInclude(TBuffer(L.First).GetPtrRange, A) then
      begin
        i := FBufList.FList.IndexOf(L.First);
        Assert(I >= 0);
        PurgeSignature(FBufList.Items[i].BufPtr, FBufList.Items[i].GetPtrRange.Finish);
        FBufList.Extract(i).Free;
      end
      else
      if CPtrUtils.RangeIsSerial(A, TBuffer(L.First).GetPtrRange) then
      begin
        TBuffer(L.First).CropHead(CPtrUtils.PtrDiff(TBuffer(L.First).GetBufPtr, A.Finish));
        PurgeSignature(TBuffer(L.First).GetBufPtr, A.Finish);
      end
      else
      begin
        TBuffer(L.First).CropTail(CPtrUtils.PtrDiff(A.Start, TBuffer(L.First).GetPtrRange.Finish));
        PurgeSignature(A.Start, TBuffer(L.First).GetPtrRange.Finish);
      end;
      l.Delete(0);
    end;
  end;
end;

procedure TWebCamStream.TrySaveResults;

  function Qq(i: cardinal): Cardinal; register;
  asm
    XCHG AL,AH
    ROL  EAX,16
    XCHG AL,AH
  end;
var
  S, F: Pointer;
  Q: TMemoryStream;
  A: Integer;
  Qa: Cardinal;
  QT: TDateTime;
  R: Boolean;
begin
  while FFoundSignatures.Count > 1 do
  begin
    S := FFoundSignatures.Items[0];
    F := FFoundSignatures.Items[1];
    debug(format('TrySaveResults.[%p,%p]', [S, F]));
    if Assigned(FWebImageReciveEvent) then
    begin
      if FDataSignature <> FStreamSignature then
        Q := FBufList.CrateResultsStream(S, F, DataSignature)
      else
        Q := FBufList.CrateResultsStream(S, F);
      if Assigned(Q) then
      begin
        debug(format('TrySaveResults.CreatedStream(%p) %d bytes', [Pointer(Q), Q.Size]));

        if LocalTime or (q.Size < $10) then
          qt := now()
        else
        begin
          Move(CPtrUtils.IncPointer(q.memory, $0A - $04)^, Qa, sizeof(Qa));
          Qa := qq(Qa);
          try
            qt := UnixToDateTime(Qa);
          except
            qt := now();
          end;
        end;

        if (FFixedCamId >= 0) or (q.Size < $10) then
          a := FFixedCamId
        else
          a := Byte(CPtrUtils.IncPointer(q.memory, $0e)^);

        R := True;
        try
          debug(format('TrySaveResults.WebImageReciveEvent(%p)', [Pointer(Q)]));
          Inc(FSaveCounter);
          Q.Seek(0,soBeginning);
          FWebImageReciveEvent(Self, Q, a, qt, R);
        finally
          if R then
            Q.Free;
        end;
      end
      else
        debug('TrySaveResults.EmptyResult');

    end;
    FFoundSignatures.Delete(0);
  end;
end;


function TWebCamStream.Write(const Buffer; Count: Integer): Integer;
var
  P, FoundPtr: Pointer;
  FStartPtr: Pointer;
  C, FNewTail: Integer;
  i, j: Integer;
  X: TBufferSearchResult;
  B: Boolean;
  T: String;
begin
  inc(FWriteCounter);
  if Count > FBuffSize then
    EStreamError.Create('not enouth space in buffer');

  if Count <= 0 then
    exit;


  FNewTail := FTail + Count;
  if FNewTail > FBuffSize then
  begin
    C := FBuffSize - FTail;
    if c > 0 then
    begin
      P := CPtrUtils.IncPointer(FBufPtr, FTail);
      Move(Buffer, P^, C);
      Purge(P, CPtrUtils.IncPointer(P, C));
      FBufList.Add(TBuffer.Create(P, C));
    end;

    C := Count - C;
    P := FBufPtr;
    Move(TByteArray(Buffer)[Count - C], P^, C);
    Purge(P, CPtrUtils.IncPointer(P, C));
    FBufList.Add(TBuffer.Create(P, C));
    FNewTail := C;
  end
  else
  begin
    FNewTail := FTail + Count;
    P := CPtrUtils.IncPointer(FBufPtr, FTail);

    Move(Buffer, P^, Count);
    Purge(P, CPtrUtils.IncPointer(P, Count));
    FBufList.Add(TBuffer.Create(P, Count));
  end;


  j := 0;
  i := FBufList.FindBufferEx(FBufList.LastPtr(Count + FMarker), 0, j);
  if i >= 0 then
    j := j + FBufList.BuffGlobalOffset(i)
  else
    j := 0;

  X.GlobalOffset := 0;
  b := FBufList.SearchEx(StreamSignature, j, X);
  while B do
  begin
    P := CPtrUtils.IncPointer(FBufList.Items[x.FindBufferIndex].BufPtr, x.FindBufferOffset);
    debug(format('{%d/%d} found %d at block [%d] at %d, Global = %0.8x (%p)',
      [FSaveCounter, FWriteCounter, FFoundSignatures.count + 1, X.FindBufferIndex,
      X.FindBufferOffset, X.GlobalOffset, P]));
    FFoundSignatures.Add(P);
    b := FBufList.SearchEx(StreamSignature, X.GlobalOffset + length(StreamSignature), X);
  end;

  FMarker := X.FindBufferMathLine;
  FTail := FNewTail;
  Result := Count;

  {try save search results}
  TrySaveResults;
end;

procedure TWebCamStream.SetDataSignature(const Value: AnsiString);
begin
  FDataSignature := Value;
end;

procedure TWebCamStream.SetStreamSignature(const Value: AnsiString);
begin
  FStreamSignature := Value;
  FDataSignature := '';
  FBufList.FResultsStreamSearchRange := 2 * Length(Value);
end;


function TWebCamStream.GetBufferAsString: AnsiString;
begin
  result := FBufList.GetAsString;
end;

procedure TWebCamStream.debug(const action: string);
begin
{$IFDEF DEBUG}
  writeln(action);
{$ENDIF}
end;

procedure TWebCamStream.SetFixedCamId(const Value: Integer);
begin
  FFixedCamId := Value;
end;

procedure TWebCamStream.SetLocalTime(const Value: Boolean);
begin
  FLocalTime := Value;
end;

procedure TWebCamStream.SetSignature(const Value: AnsiString);
begin
  StreamSignature := Value;
  DataSignature := ws_jpegsignature;
end;

function TWebCamStream.GetSignature: AnsiString;
begin
  result := FStreamSignature;
end;

destructor TWebCamStream.Destroy;
begin
  FBufList.Free;
  FFoundSignatures.Free;
  FreeMem(FBufPtr);
  inherited;
end;

procedure TWebCamStream.Clear;
begin
  FBufList.Clear;
  FFoundSignatures.Clear;
  FTail := 0;
  FMarker := 0;
end;

{ TBuffer }

constructor TBuffer.Create(ABufPtr: Pointer; Len: Integer);
begin
  FOwnData := False;
  FBufPtr  := ABufPtr;
  FBufSize := Len;
end;

constructor TBuffer.CreateCopy(var Buf; Len: Integer);
begin
  GetMem(FBufPtr, Len);
  FBufSize := Len;
  Move(Buf, FBufPtr^, Len);
  FOwnData := True;
end;

constructor TBuffer.CreateOwn(ABufPtr: Pointer; Len: Integer);
begin
  FOwnData := True;
  FBufPtr  := ABufPtr;
  FBufSize := Len;
end;

procedure TBuffer.CropHead(Count: Integer);
var
  T: Pointer;
begin
  if FOwnData then
    raise Exception.Create('not supprted on owned data');
  if Count >= FBufSize then
    raise Exception.Create('crop to large');

  FBufSize := FBufSize - Count;
  T := FBufPtr;
  FBufPtr := CPtrUtils.IncPointer(FBufPtr, Count);
  debug(format('CropHead(%d) (size %d->%d) (shift %p->%p)', [Count, FBufSize + Count, FBufSize, T, FBufPtr]));
end;

procedure TBuffer.CropTail(Count: Integer);
begin
  if FOwnData then
    raise Exception.Create('not supprted on owned data');
  if Count >= FBufSize then
    raise Exception.Create('crop to large');
  FBufSize := FBufSize - Count;
  debug(format('CropTail(%d) (size %d->%d)', [Count, FBufSize + Count, FBufSize]));
end;

procedure TBuffer.debug(const action: string);
begin
{$IFDEF DEBUG}
  Writeln('TBuffer.', action);
{$ENDIF}
end;

destructor TBuffer.Destroy;
begin
  if FOwnData then
    FreeMem(FBufPtr);
  inherited;
end;

function TBuffer.GetAsString: AnsiString;
begin
  setlength(Result, BufSize);
  move(FBufPtr^, Result[1], BufSize);
end;

function TBuffer.GetBufPtr: Pointer;
begin
  result := FBufPtr;
end;

function TBuffer.GetBufSize: Integer;
begin
  Result := FBufSize;
end;

function TBuffer.GetPtrRange: TPtrRange;
begin
  result := PtrRange(BufPtr, CPtrUtils.IncPointer(BufPtr, BufSize));
end;


{ TBufferList }

procedure TBufferList.Add(ABuf: TBuffer);
var
  i: Integer;
begin
  if AllowConcat and (Count > 0) and (not Last.OwnData) and (not ABuf.OwnData) and
    CPtrUtils.PtrEQ(CPtrUtils.IncPointer(Last.BufPtr, Last.BufSize), ABuf.BufPtr) then
  begin
    Inc(Last.FBufSize, ABuf.BufSize);
    debug(format('add via concat(%d) %p(%d->%d)', [FList.Count - 1, Last.BufPtr, Last.BufSize -
      ABuf.BufSize, Last.BufSize]));
  end
  else
  begin
    i := FList.Add(ABuf);
    debug(format('add new(%d) [%p,%p] (%d)', [i, ABuf.BufPtr, ABuf.GetPtrRange.Finish, ABuf.BufSize]));
  end;
end;

function TBufferList.BuffGlobalOffset(Index: Integer): Integer;
var
  c, i: Integer;
begin
  if Index >= Count then
    raise Exception.Create('out of bounds');
  result := 0;
  for i := 1 to Index do
    result := result + Items[i - 1].BufSize;
end;

procedure TBufferList.Clear;
begin
  while FList.Count > 0 do
  begin
    TObject(FList.Items[FList.Count - 1]).Free;
    FList.Delete(FList.Count - 1);
  end;
end;

function TBufferList.CrateResultsStream(S, F: Pointer; const ADataSignature: String): TMemoryStream;
var
  k, i, j, l, n: Integer;
  q: TBufferSearchResult;
begin
  Result := nil;
  i := FindBufferEx(S, 0, j);
  if i >= 0 then
  begin
    if (FResultsStreamSearchRange > 0) and (length(ADataSignature) > 0) then
      if SearchEx(ADataSignature, i, q, FResultsStreamSearchRange) then
      begin
        S := CPtrUtils.IncPointer(Items[q.FindBufferIndex].BufPtr, q.FindBufferOffset);
        i := q.FindBufferIndex;
      end;
    k := FindBufferEx(F, i, l);
    if k >= i then
    begin
      Result := TMemoryStream.Create;
      for n := i to k do
        if (n = i) and (n = k) then
          Result.Write(CPtrUtils.IncPointer(Items[n].BufPtr, j)^, l - j)
        else
        if (n = i) then
          Result.Write(CPtrUtils.IncPointer(Items[n].BufPtr, j)^, Items[n].GetBufSize - j)
        else
        if (n = k) then
          Result.Write(Items[n].BufPtr^, l)
        else
          Result.Write(Items[n].BufPtr^, Items[n].BufSize);
    end;
  end;
end;

constructor TBufferList.Create;
begin
  FResultsStreamSearchRange := 256;
  FList := TList.Create;
end;


procedure TBufferList.debug(const action: string);
begin
{$IFDEF DEBUG}
  writeln('TBufferList.', action);
{$ENDIF}
end;

destructor TBufferList.Destroy;
begin
  Clear;
  FList.Free;
  inherited;
end;

function TBufferList.Extract(index: Integer): TBuffer;
begin
  Result := FList.Items[index];
  FList.Delete(index);
  debug(format('extract[%d] %p(%d)', [index, Result.BufPtr, result.BufSize]));
end;

function TBufferList.FindBufferEx(P: Pointer; StartIndex: Integer; out BufferOffset: Integer): Integer;
var
  i: Integer;
begin
  i := StartIndex;
  Result := -1;
  while i < Count do
  begin
    with CPtrUtils do
      if InRange(P, Items[i].BufPtr, IncPointer(Items[i].BufPtr, Items[i].BufSize)) then
      begin
        BufferOffset := CPtrUtils.PtrDiff(Items[i].BufPtr, P);
        Result := i;
        break;
      end;
    inc(i);
  end;
end;

function TBufferList.FindBufferInRange(R: TPtrRange; StartIndex: Integer): Integer;
var
  i: Integer;
begin
  i := StartIndex;
  Result := -1;
  while i < Count do
  begin
    with CPtrUtils do
      if IsIntersect(R, PtrRange(Items[i].BufPtr, IncPointer(Items[i].BufPtr, Items[i].BufSize))) then
      begin
        Result := i;
        break;
      end;
    inc(i);
  end;
end;


function TBufferList.First: TBuffer;
begin
  if FList.Count > 0 then
    result := FList.First
  else
    result := Nil;
end;

function TBufferList.GetAsDebug: String;
var
  I: Integer;
  F: TStrings;
begin
  F := TStringList.Create;
  for i := 0 to GetCount - 1 do
    F.Add(format('[%p,%p](%d){data}', [Items[i].BufPtr, Items[i].GetPtrRange.Finish, Items[i].BufSize]));
  result := f.Text;
  f.Free;
end;

function TBufferList.GetAsString: AnsiString;
var
  c, i, d: Integer;
begin
  c := 0;
  for i := 0 to GetCount - 1 do
    c := c + Items[i].BufSize;
  SetLength(Result, c);
  c := 1;
  for i := 0 to GetCount - 1 do
  begin
    d := Items[i].BufSize;
    Move(Items[i].BufPtr^, result[c], d);
    c := c + d;
  end;
end;

function TBufferList.GetCount: Integer;
begin
  result := FList.Count;
end;

function TBufferList.GetItems(Index: Integer): TBuffer;
begin
  Result := TBuffer(FList.Items[index]);
end;


function TBufferList.Last: TBuffer;
begin
  if FList.Count > 0 then
    result := FList.Last
  Else
    Result := Nil;
end;

function TBufferList.LastPtr(offset: Integer): Pointer;
var
  i: Integer;
begin
  result := nil;
  if count <= 0 then
    exit;

  for i := Count - 1 downto 0 do
  begin
    if (Items[i].BufSize > 0) and (Items[i].BufSize >= offset) then
    begin
      result := CPtrUtils.IncPointer(Items[i].BufPtr, Items[i].BufSize - offset);
      break;
    end;
    offset := offset - Items[i].BufSize;
    if offset < 0 then
      break;
  end;
end;

function TBufferList.PosBufEx(const SubStr: String; P: Pointer; Len: integer; out ResPtr: Pointer;
  var X: Integer): Boolean;
var
  I: integer;
  LenSubStr: integer;
  S: PChar;
begin
  S := P;
  LenSubStr := Length(SubStr);
  I := 0;
  Assert(X < LenSubStr);
  Result := False;
  if X = 0 then
    ResPtr := nil;

  while I < Len do
  begin
    if S[I] = SubStr[X + 1] then
    begin
      if X = 0 then
        ResPtr := @S[I];
      Inc(X);
      Inc(I);

      while (I < Len) and (X < LenSubStr) and (S[I] = SubStr[X + 1]) do
      begin
        Inc(X);
        Inc(I);
      end;
      if (X = LenSubStr) then
      begin
        Result := True;
        exit;
      end
      else
      if I = len then
        exit
      else
        X := 0;
    end
    else
    if X > 0 then
      x := 0;
    Inc(I);
  end;
end;


function TBufferList.SearchEx(SubStr: AnsiString; Offset: Integer; out SearchResult: TBufferSearchResult;
  const MaxLen: Integer = 0): Boolean;
var
  I: Integer;
  ResPtr: Pointer;
  X: Integer;
  S, B: Boolean;
  K, C: Integer;
begin
  ResPtr := nil;
  Result := False;
  SearchResult.FindBufferMathLine := 0;

  X := 0;
  C := 0;
  I := 0;
  K := 0;

  while (i < Count) and (Offset > 0) do
    if Offset >= Items[i].BufSize then
    begin
      Offset := Offset - Items[i].BufSize;
      C := C + Items[i].BufSize;
      inc(i);
    end
    else
      break;

  while i < Count do
  begin
    B := PosBufEx(SubStr, CPtrUtils.IncPointer(Items[i].BufPtr, Offset), Items[i].BufSize - Offset, ResPtr, X);
    Offset := 0;
    K := 1;
    while (not B) and (X > 0) and ((i + k) < Count) do
    begin
      B := PosBufEx(SubStr, Items[I + K].BufPtr, Items[I + K].BufSize, ResPtr, X);
      if B then
        break;
      Inc(K);
    end;

    if B then
    begin
      SearchResult.FindBufferIndex := i;
      SearchResult.FindBufferOffset := CPtrUtils.PtrDiff(Items[i].BufPtr, ResPtr);
      SearchResult.GlobalOffset := C + SearchResult.FindBufferOffset;
      SearchResult.FindBufferMathLine := X;
      Result := True;
      exit;
    end;
    C := C + Items[i].BufSize;
    Inc(I);
    if MaxLen > 0 then
      if C >= MaxLen then
        break;
  end;
  SearchResult.FindBufferIndex := i - 1;
  SearchResult.GlobalOffset := C;
  SearchResult.FindBufferMathLine := X;
end;



{ CPtrUtils }

class function CPtrUtils.PtrEQ(A, B: Pointer): boolean;
begin
  result := Cardinal(A) = Cardinal(B);
end;

class function CPtrUtils.PtrGE(A, B: Pointer): boolean;
begin
  result := Cardinal(A) > Cardinal(B);
end;

class function CPtrUtils.PtrLT(A, B: Pointer): boolean;
begin
  result := Cardinal(A) < Cardinal(B);
end;

class function CPtrUtils.PtrDiff(BeforePtr, AfterPtr: Pointer): Integer;
begin
  if Cardinal(AfterPtr) >= Cardinal(BeforePtr) then
    result := Cardinal(AfterPtr) - Cardinal(BeforePtr)
  else
    raise Exception.Create('after smaller than before');
end;

class function CPtrUtils.IncPointer(P: Pointer; D: Integer): Pointer;
begin
  if D >= 0 then
    result := @PByteArray(P)^[D]
  else
    result := Pointer(Cardinal(P) - Cardinal(Abs(D)));
end;

class function CPtrUtils.InRange(P, Start, Finish: Pointer): Boolean;
begin
  result := PtrEQ(P, Start) or (PtrGE(P, Start) and PtrLT(P, Finish));
end;

class function CPtrUtils.IsIntersect(A, B: TPtrRange): Boolean;
begin
{
  A   ---
  B ------

  A  ----
  B  ----

  A  ----
  B ---
}
  result := InRange(A.Start, B.Start, B.Finish);
  if result then
    exit;
{
  A  ----
  B     ---

  A  ----
  B   --

}
  result := InRange(B.Start, A.Start, A.Finish);
  if result then
    exit;
end;

class function CPtrUtils.IsInclude(A, B: TPtrRange): Boolean;
begin
{
  A  ----
  B -------

  A  ----
  B  ----

}
  result := (PtrEQ(A.Start, B.Start) or PtrGE(A.Start, B.Start)) and (PtrEQ(A.Finish, B.Finish) or
    PtrLT(A.Finish, B.Finish));
end;

class function CPtrUtils.RangeIsSerial(A, B: TPtrRange): boolean;
begin
{
  A  ----
  B   ->

  A  ----
  B  ->

  A.Start>=B.Start
}
  result := PtrEQ(A.Start, B.Start) or PtrGE(B.Start, A.Start);
end;

class function CPtrUtils.PosBuf(SubStr: String; Data: Pointer; Len: Integer; var Offset: Integer): Boolean;
var
  I, X: integer;
  LenSubStr: integer;
  S: PChar;
begin
  S := Data;
  LenSubStr := Length(SubStr);
  I := 0;
  while I < Len do
  begin
    if S[I] = SubStr[1] then
    begin
      X := 1;
      while (X < LenSubStr) and (S[I + X] = SubStr[X + 1]) do
        Inc(X);
      if (X = LenSubStr) then
      begin
        Result := True;
        Offset := i;
        exit;
      end;
    end;
    Inc(I);
  end;
  Offset := i;
  Result := False;
end;

end.


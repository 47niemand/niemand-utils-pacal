unit uBlockList;

interface

uses Classes, SysUtils, uBlock;

type
  TBufferSearchResult = record
    BlockIndex:   integer;
    BlockOffset:  integer;
    BlockOverlap: integer;
    GlobalOffset: integer;
  end;

  TBlockList = class
  private
    FList: TList;
    FOwnBuffers: boolean;
    FAllowConcat: boolean;
    function GetItems(Index: integer): TBlock;
    function GetCount: integer;
    class function PosBufEx(const SubStr: AnsiString; APtr: Pointer;
      Len: integer; out ResPtr: Pointer; var XOverlap: integer): boolean;
    function GetAsDebug: string;
    procedure SetAllowConcat(const Value: boolean);
  protected
    FResultsStreamSearchRange: integer;
    function Last: TBlock;
    function First: TBlock;
    function LastPtr(offset: integer = 0): Pointer;
    function BlockGlobalOffset(Index: integer): integer;
    function GetAsString: AnsiString;
  public
    function CrateResultsStream(AStart, AFinish: Pointer;
      const ADataSignature: string): TMemoryStream;
    property AllowConcat: boolean Read FAllowConcat Write SetAllowConcat;
    property OwnBlocks: boolean Read FOwnBuffers;
    property AsString: AnsiString Read GetAsString;
    procedure Clear;
    function SearchEx(const SubStr: AnsiString; Offset: integer;
      out SearchResult: TBufferSearchResult; const MaxLen: integer = 0): boolean;
    function FindBlockEx(const APtr: Pointer; const StartIndex: integer;
      out BufferOffset: integer): integer;
    function FindBlockInRange(const ARange: TPtrRange;
      const StartIndex: integer): integer;
    procedure Add(ABuf: TBlock);
    function Extract(const index: integer): TBlock;
    property Count: integer Read GetCount;
    property Items[Index: integer]: TBlock Read GetItems;
    constructor Create;
    destructor Destroy; override;
  end;


implementation


const
  cnt_default_stream_search_range = 256;

type
  TByteArray = array[0..maxint div 2] of byte;
  PByteArray = ^TByteArray;

{ TBlockList }

procedure TBlockList.Add(ABuf: TBlock);
begin
  if AllowConcat and FOwnBuffers and (Count > 0) and (not Last.OwnData) and
    (not ABuf.OwnData) and (CPtrUtils.RangeIsSerial(Last.PtrRange, ABuf.PtrRange)) then
  begin
    Last.Realloc(ABuf.DataSize + Last.DataSize);
    ABuf.Free;
  end
  else
  begin
    Assert(FindBlockInRange(ABuf.PtrRange, 0) < 0);
    FList.Add(ABuf);
  end;
end;

function TBlockList.BlockGlobalOffset(Index: integer): integer;
var
  I: integer;
begin
  if Index >= Count then
    raise Exception.Create('out of bounds');
  Result := 0;
  for I := 1 to Index do
    Result := Result + Items[I - 1].DataSize;
end;

procedure TBlockList.Clear;
begin
  while FList.Count > 0 do
  begin
    TObject(FList.Items[FList.Count - 1]).Free;
    FList.Delete(FList.Count - 1);
  end;
end;

function TBlockList.CrateResultsStream(AStart, AFinish: Pointer;
  const ADataSignature: string): TMemoryStream;
var
  finalBlockIndex, startBlockIndex, outBlockOffset, outFinalBlockOffset, N: integer;
  q: TBufferSearchResult;
begin
  Result := nil;
  startBlockIndex := FindBlockEx(AStart, 0, outBlockOffset);
  if startBlockIndex >= 0 then
  begin
    if (FResultsStreamSearchRange > 0) and (length(ADataSignature) > 0) then
      {try allign AStart position to ADataSignature}
      if SearchEx(ADataSignature, startBlockIndex, q, FResultsStreamSearchRange) then
      begin
        AStart := CPtrUtils.IncPointer(Items[q.BlockIndex].HeadPtr, q.BlockOffset);
        startBlockIndex := q.BlockIndex;
        outBlockOffset := q.BlockOffset;
      end;
    finalBlockIndex := FindBlockEx(AFinish, startBlockIndex, outFinalBlockOffset);
    if finalBlockIndex >= startBlockIndex then
    begin
      Result := TMemoryStream.Create;
      for N := startBlockIndex to finalBlockIndex do
        if (N = startBlockIndex) and (N = finalBlockIndex) then
        begin
          Assert(outFinalBlockOffset >= outBlockOffset);
          Result.Write(CPtrUtils.IncPointer(Items[N].HeadPtr, outBlockOffset)^,
            outFinalBlockOffset - outBlockOffset);
        end
        else
        if (N = startBlockIndex) then
          Result.Write(CPtrUtils.IncPointer(Items[N].HeadPtr, outBlockOffset)^,
            Items[N].DataSize - outBlockOffset)
        else
        if (N = finalBlockIndex) then
          Result.Write(Items[N].HeadPtr^, outFinalBlockOffset)
        else
          Result.Write(Items[N].HeadPtr^, Items[N].DataSize);
    end;
  end;
end;

constructor TBlockList.Create;
begin
  FResultsStreamSearchRange := cnt_default_stream_search_range;
  FList := TList.Create;
  FOwnBuffers := True;
  FAllowConcat := True;
end;


destructor TBlockList.Destroy;
begin
  Clear;
  FList.Free;
  inherited;
end;

function TBlockList.Extract(const index: integer): TBlock;
begin
  Result := FList.Items[index];
  FList.Delete(index);
end;

function TBlockList.FindBlockEx(const APtr: Pointer; const StartIndex: integer;
  out BufferOffset: integer): integer;
var
  I: integer;
begin
  I      := StartIndex;
  Result := -1;
  while I < Count do
  begin
    with CPtrUtils do
      if InRange(APtr, Items[I].HeadPtr, IncPointer(Items[I].HeadPtr,
        Items[I].DataSize)) then
      begin
        BufferOffset := CPtrUtils.PtrDiff(Items[I].HeadPtr, APtr);
        Result := I;
        break;
      end;
    Inc(I);
  end;
end;

function TBlockList.FindBlockInRange(const ARange: TPtrRange;
  const StartIndex: integer): integer;
var
  I: integer;
begin
  I      := StartIndex;
  Result := -1;
  while I < Count do
  begin
    with CPtrUtils do
      if IsIntersect(ARange, PtrRange(Items[I].HeadPtr,
        IncPointer(Items[I].HeadPtr, Items[I].DataSize))) then
      begin
        Result := I;
        break;
      end;
    Inc(I);
  end;
end;


function TBlockList.First: TBlock;
begin
  if FList.Count > 0 then
    Result := FList.First
  else
    Result := nil;
end;

function TBlockList.GetAsDebug: string;
var
  I: integer;
  F: TStrings;
begin
  F := TStringList.Create;
  try
    for I := 0 to GetCount - 1 do
      F.Add(format('[%p,%p](%d){data}', [Items[I].HeadPtr,
        Items[I].PtrRange.Finish, Items[I].DataSize]));
    Result := f.Text;
  finally
    f.Free;
  end;
end;

function TBlockList.GetAsString: AnsiString;
var
  c, I, d: integer;
begin
  c := 0;
  for I := 0 to GetCount - 1 do
    c := c + Items[I].DataSize;
  SetLength(Result, c);
  c := 1;
  for I := 0 to GetCount - 1 do
  begin
    d := Items[I].DataSize;
    Move(Items[I].HeadPtr^, Result[c], d);
    c := c + d;
  end;
end;

function TBlockList.GetCount: integer;
begin
  Result := FList.Count;
end;

function TBlockList.GetItems(Index: integer): TBlock;
begin
  Result := TBlock(FList.Items[index]);
end;

function TBlockList.Last: TBlock;
begin
  if FList.Count > 0 then
    Result := FList.Last
  else
    Result := nil;
end;

function TBlockList.LastPtr(offset: integer): Pointer;
var
  I: integer;
begin
  Result := nil;
  if Count <= 0 then
    exit;

  for I := Count - 1 downto 0 do
  begin
    if (Items[I].DataSize > 0) and (Items[I].DataSize >= offset) then
    begin
      Result := CPtrUtils.IncPointer(Items[I].HeadPtr, Items[I].DataSize - offset);
      break;
    end;
    offset := offset - Items[I].DataSize;
    if offset < 0 then
      break;
  end;
end;

class function TBlockList.PosBufEx(const SubStr: string; APtr: Pointer;
  Len: integer; out ResPtr: Pointer; var XOverlap: integer): boolean;
var
  I: integer;
  LenSubStr: integer;
  S: PChar;
begin
  S := APtr;
  LenSubStr := Length(SubStr);
  I := 0;
  Assert(XOverlap < LenSubStr);
  Result := False;
  if XOverlap = 0 then
    ResPtr := nil;

  while I < Len do
  begin
    if S[I] = SubStr[XOverlap + 1] then
    begin
      if XOverlap = 0 then
        ResPtr := @S[I];
      Inc(XOverlap);
      Inc(I);

      while (I < Len) and (XOverlap < LenSubStr) and (S[I] = SubStr[XOverlap + 1]) do
      begin
        Inc(XOverlap);
        Inc(I);
      end;
      if (XOverlap = LenSubStr) then
      begin
        Result := True;
        exit;
      end
      else
      if I = len then
        exit
      else
        XOverlap := 0;
    end
    else
    if XOverlap > 0 then
      XOverlap := 0;
    Inc(I);
  end;
end;

function TBlockList.SearchEx(const SubStr: AnsiString; Offset: integer;
  out SearchResult: TBufferSearchResult; const MaxLen: integer = 0): boolean;
var
  I:      integer;
  ResPtr: Pointer;
  Overlap: integer;
  B:      boolean;
  K, GlobalOffset: integer;
begin
  ResPtr := nil;
  Result := False;
  SearchResult.BlockOverlap := 0;

  Overlap := 0;
  GlobalOffset := 0;
  I := 0;

  while (I < Count) and (Offset > 0) do
    if Offset >= Items[I].DataSize then
    begin
      Offset := Offset - Items[I].DataSize;
      GlobalOffset := GlobalOffset + Items[I].DataSize;
      Inc(I);
    end
    else
      break;

  while I < Count do
  begin
    B      := PosBufEx(SubStr, CPtrUtils.IncPointer(Items[I].HeadPtr, Offset),
      Items[I].DataSize - Offset, ResPtr, Overlap);
    Offset := 0;
    K      := 1;
    while (not B) and (Overlap > 0) and ((I + K) < Count) do
    begin
      B := PosBufEx(SubStr, Items[I + K].HeadPtr, Items[I + K].DataSize,
        ResPtr, Overlap);
      if B then
        break;
      Inc(K);
    end;

    if B then
    begin
      SearchResult.BlockIndex := I;
      SearchResult.BlockOffset := CPtrUtils.PtrDiff(Items[I].HeadPtr, ResPtr);
      SearchResult.GlobalOffset := GlobalOffset + SearchResult.BlockOffset;
      SearchResult.BlockOverlap := Overlap;
      Result := True;
      exit;
    end;
    GlobalOffset := GlobalOffset + Items[I].DataSize;
    Inc(I);
    if MaxLen > 0 then
      if GlobalOffset >= MaxLen then
        break;
  end;
  SearchResult.BlockIndex   := I - 1;
  SearchResult.GlobalOffset := GlobalOffset;
  SearchResult.BlockOverlap := Overlap;
end;

procedure TBlockList.SetAllowConcat(const Value: boolean);
begin
  FAllowConcat := Value;
end;

end.


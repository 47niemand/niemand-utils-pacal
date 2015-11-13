unit uBlock;

interface

uses SysUtils, Classes;

type
  TPtrRange = record
    Start, Finish: Pointer;
  end;

  CPtrUtils = class
  public
    class function PtrRange(const AStart, AFinish: Pointer): TPtrRange;
    class function PosBuf(const SubStr: string; const Data: Pointer;
      const Len: integer; out Offset: integer): boolean;
    class function PtrEQ(const A, B: Pointer): boolean;
    class function PtrGE(const A, B: Pointer): boolean;
    class function PtrLT(const A, B: Pointer): boolean;
    class function InRange(const P, Start, Finish: Pointer): boolean;
    class function IsIntersect(const A, B: TPtrRange): boolean;
    class function IsInclude(const A, B: TPtrRange): boolean;
    class function PtrDiff(const BeforePtr, AfterPtr: Pointer): integer;
    class function IncPointer(const P: Pointer; const D: integer): Pointer;
    class function RangeIsSerial(const A, B: TPtrRange): boolean;
  end;

  TBlock = class
  private
    FOwnedBuff: Pointer;
    FBufPtr:    Pointer;
    FDataSize:  integer;
    function GetOwnData: boolean;
  protected
    function GetHeadPtr: Pointer;
    function GetDataSize: integer;
    function GetAsString: AnsiString;
    function GetPtrRange: TPtrRange;
  public
    procedure Realloc(const NewSize: integer);
    property OwnData: boolean Read GetOwnData;
    property HeadPtr: Pointer Read GetHeadPtr;
    property DataSize: integer Read GetDataSize;
    property AsString: AnsiString Read GetAsString;
    property PtrRange: TPtrRange Read GetPtrRange;
    procedure CropHead(const Count: integer);
    procedure CropTail(const Count: integer);
    constructor CreateCopy(var Buf; const Len: integer);
    constructor Create(const ABufPtr: Pointer; const Len: integer;
      ATakeOwn: boolean = False);
    destructor Destroy; override;
    class procedure Test;
  end;


implementation

{ TBlock }

constructor TBlock.Create(const ABufPtr: Pointer; const Len: integer;
  ATakeOwn: boolean = False);
begin
  if ATakeOwn then
    FOwnedBuff := ABufPtr;
  FBufPtr := ABufPtr;
  FDataSize := Len;
end;

constructor TBlock.CreateCopy(var Buf; const Len: integer);
begin
  GetMem(FOwnedBuff, Len);
  FBufPtr   := FOwnedBuff;
  FDataSize := Len;
  Move(Buf, FBufPtr^, Len);
end;


procedure TBlock.CropHead(const Count: integer);
begin
  if Count >= FDataSize then
    raise Exception.Create('Allocated buffer smaller than crop count');

  FDataSize := FDataSize - Count;
  FBufPtr   := CPtrUtils.IncPointer(FBufPtr, Count);
end;

procedure TBlock.CropTail(const Count: integer);
begin
  if Count >= FDataSize then
    raise Exception.Create('Allocated buffer smaller than crop count');

  FDataSize := FDataSize - Count;
end;

destructor TBlock.Destroy;
begin
  if Assigned(FOwnedBuff) then
    FreeMem(FOwnedBuff);
  inherited;
end;

function TBlock.GetAsString: AnsiString;
begin
  setlength(Result, DataSize);
  move(GetHeadPtr^, Result[1], GetDataSize);
end;

function TBlock.GetHeadPtr: Pointer;
begin
  Result := FBufPtr;
end;

function TBlock.GetOwnData: boolean;
begin
  Result := Assigned(FOwnedBuff);
end;

function TBlock.GetDataSize: integer;
begin
  Result := FDataSize;
end;

function TBlock.GetPtrRange: TPtrRange;
begin
  with CPtrUtils do
    Result := PtrRange(GetHeadPtr, IncPointer(GetHeadPtr, GetDataSize));
end;

procedure TBlock.Realloc(const NewSize: integer);
begin
  if GetOwnData then
    raise Exception.Create('can`t reallocate owned block')
  else
    FDataSize := NewSize;
end;

class procedure TBlock.Test;
begin
  //TODO
end;

{ CPtrUtils }

class function CPtrUtils.PtrEQ(const A, B: Pointer): boolean;
begin
  Result := cardinal(A) = cardinal(B);
end;

class function CPtrUtils.PtrGE(const A, B: Pointer): boolean;
begin
  Result := cardinal(A) > cardinal(B);
end;

class function CPtrUtils.PtrLT(const A, B: Pointer): boolean;
begin
  Result := cardinal(A) < cardinal(B);
end;

class function CPtrUtils.PtrDiff(const BeforePtr, AfterPtr: Pointer): integer;
begin
  if cardinal(AfterPtr) >= cardinal(BeforePtr) then
    Result := cardinal(AfterPtr) - cardinal(BeforePtr)
  else
    raise Exception.Create('after smaller than before');
end;

class function CPtrUtils.IncPointer(const P: Pointer; const D: integer): Pointer;
begin
  if D >= 0 then
    Result := @PByteArray(P)^[D]
  else
    Result := Pointer(cardinal(P) - cardinal(Abs(D)));
end;

class function CPtrUtils.InRange(const P, Start, Finish: Pointer): boolean;
begin
  Result := PtrEQ(P, Start) or (PtrGE(P, Start) and PtrLT(P, Finish));
end;

class function CPtrUtils.IsIntersect(const A, B: TPtrRange): boolean;
begin
{
  A   ---
  B ------

  A  ----
  B  ----

  A  ----
  B ---
}
  Result := InRange(A.Start, B.Start, B.Finish);
  if Result then
    exit;
{
  A  ----
  B     ---

  A  ----
  B   --

}
  Result := InRange(B.Start, A.Start, A.Finish);
  if Result then
    exit;
end;

class function CPtrUtils.IsInclude(const A, B: TPtrRange): boolean;
begin
{
  A  ----
  B -------

  A  ----
  B  ----

}
  Result := (PtrEQ(A.Start, B.Start) or PtrGE(A.Start, B.Start)) and
    (PtrEQ(A.Finish, B.Finish) or PtrLT(A.Finish, B.Finish));
end;

class function CPtrUtils.RangeIsSerial(const A, B: TPtrRange): boolean;
begin
{
  A  ----
  B   ->

  A  ----
  B  ->

  A.Start>=B.Start
}
  Result := PtrEQ(A.Start, B.Start) or PtrGE(B.Start, A.Start);
end;

class function CPtrUtils.PosBuf(const SubStr: string; const Data: Pointer;
  const Len: integer; out Offset: integer): boolean;
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
        Offset := I;
        exit;
      end;
    end;
    Inc(I);
  end;
  Offset := I;
  Result := False;
end;

class function CPtrUtils.PtrRange(const AStart, AFinish: Pointer): TPtrRange;
begin
  if CPtrUtils.PtrGE(AStart, AFinish) then
  begin
    Result.Start  := AFinish;
    Result.Finish := AStart;
  end
  else
  begin
    Result.Start  := AStart;
    Result.Finish := AFinish;
  end;
end;

end.


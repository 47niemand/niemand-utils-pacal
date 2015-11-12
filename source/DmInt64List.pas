unit DmInt64List;

{.$DEFINE WITHTEST}

{$IFNDEF WITHTEST}
 {$C-}
{$ENDIF}

{$IFDEF WITHTEST}
 {$O-}
 {$C+}
 {$R+}
{$ENDIF}


interface

uses
  classes;

type
  VarArrayOfInt64 = array of Int64;


type
  TDmInt64List = class
  private
    FList: VarArrayOfInt64;
    FSorted: Boolean;
    FCapacity: Integer;
    FHolesCount: Integer;
    FLastActualIdx: Integer;
    FLastHoleIdx: Integer;
    FCount: Integer;
    FDuplicates: TDuplicates;
    function NearesteIdx(idx: Integer): Integer;
    function GetDuplicates: TDuplicates;
    function GetItems(idx: integer): int64;
    function GetLast(var idx: Integer): int64;
    function GetFirst(var idx: Integer): int64;
    procedure SetDuplicates(const Value: TDuplicates);
    procedure SetSorted(const Value: boolean);
    function GetCount: integer;
    procedure Grow;
    procedure Pack;
    function _NextSpace(idx: Integer): Integer;
    function _GetItemsInternal(idx: integer): int64;
    function _XValue(avalue: int64): int64;
    function _YValue(avalue: int64): int64;
{$IFDEF WITHTEST}
    procedure IntCheck;
{$ENDIF}
    procedure _Insert(pos: Integer; avalue: Int64);
    function GetCapacity: integer;
    procedure _append(avalue: Int64);
  public
    property Capacity: integer read GetCapacity;
    procedure Add(avalue: Int64); overload;
    procedure Add(list: TDmInt64List); overload;
    procedure Remove(avalue: int64);
    property Duplicates: TDuplicates read GetDuplicates write SetDuplicates;
    property Items[idx: integer]: Int64 read GetItems; default;
    property Sorted: boolean read FSorted write SetSorted;
    procedure Sort;
    procedure Toss;
    property Count: integer read GetCount;
    function Find(avalue: Int64; var idx: integer): boolean;
    function Exists(avalue: Int64): Boolean;
    procedure Delete(idx: integer);
    function CopyArray: VarArrayOfInt64;
    function Text: string;
    procedure Clear;
    constructor Create;
    destructor Destroy; override;
  end;


implementation

uses
  SysUtils, Math, StdConvs;


{ TDmInt64List }

const
  NULL_VALUE = 0;

function Integer64Compare(avalue1, avalue2: int64): integer;
begin
  if avalue1 < avalue2 then
    Result := -1
  else
  if avalue1 > avalue2 then
    Result := 1
  else
    Result := 0;
end; { Integer64Compare }


function TDmInt64List._NextSpace(idx: Integer): Integer;
begin
  if idx >= 0 then
    result := idx
  else
    result := 0;

  if (FHolesCount > 0) and (FLastHoleIdx >= idx) then
  begin
    while result < FCapacity do
    begin
      if FList[result] = NULL_VALUE then
        break;
      inc(result);
    end;
  end
  else
    result := FLastActualIdx + 1;
end;

function TDmInt64List._XValue(avalue: int64): int64;
begin
  if avalue >= NULL_VALUE then
    result := avalue + 1
  else
    result := avalue - 1;
end;

function TDmInt64List._YValue(avalue: int64): int64;
begin
  Assert(avalue <> NULL_VALUE, 'NULL_VALUE error');
  if avalue > NULL_VALUE then
    result := avalue - 1
  else
    result := avalue + 1;
end;

procedure TDmInt64List._Insert(pos: Integer; avalue: Int64);
var
  k: Integer;
begin
  if (FCount = FCapacity) then
    Grow
  else

  if pos >= FCapacity then
  begin
    Pos := FCapacity;
    Grow;
  end;

  Assert(Pos < FCapacity, 'out of range');

  if pos < 0 then
    pos := 0;

  if FList[pos] = NULL_VALUE then
  begin
    FList[pos] := _XValue(avalue);
    inc(FCount);
    if pos > FLastActualIdx then
      FLastActualIdx := pos
    else
    begin
      dec(FHolesCount);
      if FLastHoleIdx = pos then
        FLastHoleIdx := -1;
    end;

  end
  else
  if (pos > 0) and (FList[pos - 1] = NULL_VALUE) then
  begin
    FList[pos - 1] := _XValue(avalue);
    inc(FCount);
    if pos > FLastActualIdx then
      FLastActualIdx := pos
    else
    begin
      dec(FHolesCount);
      if FLastHoleIdx = (pos - 1) then
        FLastHoleIdx := -1;
    end;
  end
  else
  begin
    k := _NextSpace(pos);

    Assert((k >= 0) and (k <= FCapacity));

    if k = FCapacity then
    begin
      Grow;
      Assert(FLastActualIdx < k);
      FLastActualIdx := k;
    end
    else
    if k > FLastActualIdx then
      FLastActualIdx := k
    else
    begin
      FLastHoleIdx := -1;
      if k = FLastHoleIdx then
        FLastHoleIdx := -1;
      dec(FHolesCount);
    end;

    if k > pos then
      System.Move(FList[pos], FList[pos + 1], sizeof(Integer) * (k - pos));

    FList[pos] := _XValue(avalue);
    inc(FCount);
  end;
end;

procedure TDmInt64List._append(avalue: int64);
begin
  if FSorted then
    _Insert(FCapacity, avalue)
  else
  if FCount = 0 then
  begin
    Assert(FCapacity > 0);
    FList[0] := _XValue(avalue);
    FLastActualIdx := 0;
    inc(FCount);
  end
  else
  begin
    Assert(length(FList) = FCapacity);
    Assert(FCapacity > FLastActualIdx);
    Assert(FLastActualIdx < FCapacity);
    if (FLastActualIdx + 1) = FCapacity then
      Grow;
    FList[FLastActualIdx + 1] := _XValue(avalue);
    inc(FLastActualIdx);
    inc(FCount);
  end;
end;

procedure TDmInt64List.Add(avalue: Int64);
var
  i: Integer;
begin

  if FCapacity = FCount then
    Grow;

  if FHolesCount > FCount then
    Pack;

  if not FSorted then
  begin
    if FDuplicates in [dupIgnore, dupError] then
    begin
      if Find(avalue, i) then
      begin
        if FDuplicates = dupError then
          raise Exception.Create('duplicate error');
      end
      else
      begin
        _append(avalue);
      end;
    end
    else
    begin
      _append(avalue);
    end;

  end
  else
  if Find(avalue, i) then
  begin
    if FDuplicates = dupAccept then
      _Insert(i, avalue)
    else
    if FDuplicates = dupError then
      raise Exception.Create('duplicate error');
  end
  else
    _Insert(i, avalue);
  {$IFDEF WITHTEST}
  IntCheck;
  {$ENDIF}
end;

procedure TDmInt64List.Delete(idx: integer);
var
  j, i: Integer;
begin
  if FCount = 0 then
    raise Exception.Create('out of range');

  i := NearesteIdx(idx);

  if i < 0 then
    raise Exception.Create('out of range');

  if FList[i] = NULL_VALUE then
    raise Exception.Create('index allredy deleted');

  FList[i] := NULL_VALUE;

  dec(FCount);

  Assert(i <= FLastActualIdx);

  if FCount = 0 then
  begin
    FLastActualIdx := -1;
    FHolesCount := 0;
    FLastHoleIdx := -1;
  end
  else
  if i < FLastActualIdx then
  begin
    if i > FLastHoleIdx then
      FLastHoleIdx := i;
    inc(FHolesCount);
  end
  else
  begin
    FLastActualIdx := NearesteIdx(i);
    j := i - FLastActualIdx - 1;
    if j > 0 then
    begin
      FHolesCount := FHolesCount - j;
      FLastHoleIdx := -1;
    end;
  end;

  {$IFDEF WITHTEST}
  IntCheck;
  {$ENDIF}

  if FHolesCount > FCount then
    Pack;
end;

function TDmInt64List.Find(avalue: Int64; var idx: integer): boolean;
var
  i, c, mid, first, last: Integer;
begin
  avalue := _XValue(avalue);

  if not FSorted then
  begin
    for i := FCapacity - 1 downto 0 do
      if (FList[i] <> NULL_VALUE) and (FList[i] = avalue) then
      begin
        idx := i;
        result := True;
        exit;
      end;
    result := False;
    idx := -1;
    exit;
  end
  else
  if FCount = 0 then
  begin
    idx := 0;
    result := False;
  end
  else
  if Integer64Compare(avalue, GetLast(last)) >= 0 then
  begin
    idx := last;
    result := avalue = FList[idx];
    if not Result then
      inc(idx);
  end
  else
  if Integer64Compare(avalue, GetFirst(first)) <= 0 then
  begin
    idx := first;
    result := avalue = FList[idx];
    if not Result then
      dec(idx);
  end
  else
  begin
    while first < last do
    begin
      mid := first + (last - first) div 2;
      c := Integer64Compare(avalue, _GetItemsInternal(mid));
      if c <= 0 then
      begin
        if c = 0 then
        begin
          last := mid;
          break;
        end;
        last := mid;
      end
      else
        first := mid + 1;
    end;
    idx := last;
    result := c = 0;
  end;
end;

function TDmInt64List.GetCapacity: integer;
begin
  result := FCapacity;
end;

function TDmInt64List.GetCount: integer;
begin
  result := fcount;
end;

function TDmInt64List.GetDuplicates: TDuplicates;
begin
  result := FDuplicates;
end;

function TDmInt64List.GetItems(idx: integer): int64;
var
  i: Integer;
begin
  i := NearesteIdx(idx);
  if i < 0 then
    raise Exception.Create('out of range');

  result := _YValue(Flist[i]);
end;

procedure TDmInt64List.Grow;
begin
  if FCapacity < 64 then
    FCapacity := FCapacity + 4
  else
    FCapacity := FCapacity + 64;
  Assert(NULL_VALUE = 0);
  SetLength(FList, FCapacity);
end;

function TDmInt64List.CopyArray: VarArrayOfInt64;
var
  j, i: Integer;
begin
  setlength(Result, FCount);
  j := 0;
  for i := 0 to FCapacity - 1 do
    if not (FList[i] = NULL_VALUE) then
    begin
      Result[j] := _YValue(FList[i]);
      inc(j);
      if J = FCount then
        break;
    end;
end;

procedure TDmInt64List.Pack;
var
  j, i: Integer;
begin
{$IFNDEF WITHTEST}
  if FCapacity = FCount then
    exit;
{$ENDIF}
  j := 0;
  for i := 0 to FCapacity - 1 do
    if not (FList[i] = NULL_VALUE) then
    begin
      if i <> j then
        FList[j] := FList[i];
      inc(j);
      if j = FCount then
        Break;
    end;

  SetLength(FList, j);
  FCapacity := j;
  FLastActualIdx := FCapacity - 1;
  FHolesCount := 0;
  FLastHoleIdx := -1;

  {$IFDEF WITHTEST}
  IntCheck;
  {$ENDIF}

end;

procedure TDmInt64List.Remove(avalue: int64);
var
  i: Integer;
begin
  while (FCount > 0) and Find(avalue, i) do
    Delete(i);
end;

procedure TDmInt64List.SetDuplicates(const Value: TDuplicates);
begin
  if Value <> FDuplicates then
  begin
    if (Value = dupError) and (FCount > 1) then
      raise Exception.Create('list not empty');
    FDuplicates := Value;
  end;
end;


procedure TDmInt64List.SetSorted(const Value: boolean);
begin
  if Value and (not FSorted) then
  begin
    Sort;
    FSorted := True;
  end
  else
    FSorted := False;
end;

procedure TDmInt64List.Sort;

  procedure Swap(var X, Y: Int64);
  var
    Temp: Int64;
  begin
    Temp := X;
    X := Y;
    Y := Temp;
  end;

  procedure Partition(var A: VarArrayOfInt64; First, Last: integer);
  var
    Right, Left: integer;
    V: integer;
  begin
    V := A[(First + Last) div 2];
    Right := First;
    Left := Last;
    repeat
      while (A[Right] < V) do
        Right := Right + 1;
      while (A[Left] > V) do
        Left := Left - 1;
      if (Right <= Left) then
      begin
        Swap(A[Right], A[Left]);
        Right := Right + 1;
        Left  := Left - 1;
      end;
    until Right > Left;
    if (First < Left) then
      Partition(A, First, Left);
    if (Right < Last) then
      Partition(A, Right, Last);
  end;

  procedure QuickSort(var List: VarArrayOfInt64);
  var
    First, Last: integer;
  begin
    First := 0;
    Last  := Length(List) - 1;
    if (First < Last) then
      Partition(List, First, Last);
  end;

begin
  Pack;
  QuickSort(FList);
end;

constructor TDmInt64List.Create;
begin
  Clear;
  FDuplicates := dupAccept;
end;

destructor TDmInt64List.Destroy;
begin
  Clear;
  inherited;
end;

procedure TDmInt64List.Clear;
begin
  FCapacity := 0;
  FCount := 0;
  FLastActualIdx := -1;
  FLastHoleIdx := -1;
  FHolesCount := 0;
  SetLength(FList, 0);
end;

function TDmInt64List.NearesteIdx(idx: Integer): Integer;
var
  i, x: Integer;
begin
  Assert(FCount > 0, 'array is empty');
  Assert(FLastActualIdx >= 0, 'array is empty');

  if (idx >= FLastActualIdx) and (FList[FLastActualIdx] <> NULL_VALUE) then
    result := FLastActualIdx
  else
  if (idx >= FLastActualIdx) and (FList[FLastActualIdx] = NULL_VALUE) then
  begin
    i := FLastActualIdx;
    while (i >= 0) and (FList[i] = NULL_VALUE) do
      dec(i);
    Result := i;
    Assert(i >= 0);
  end
  else
  begin
    i := idx;
    while (i < FLastActualIdx) and (FList[i] = NULL_VALUE) do
      inc(i);
    Result := i;
  end;
end;

function TDmInt64List.GetFirst(var idx: Integer): int64;
begin
  if FCount > 0 then
  begin
    idx := NearesteIdx(0);
    result := Flist[idx];
  end
  else
  begin
    result := NULL_VALUE;
    idx := -1;
  end;
end;

function TDmInt64List.GetLast(var idx: Integer): int64;
begin
  if FCount > 0 then
  begin
    idx := NearesteIdx(FCapacity - 1);
    result := Flist[idx];
  end
  else
  begin
    result := NULL_VALUE;
    idx := -1;
  end;
end;

function TDmInt64List._GetItemsInternal(idx: integer): int64;
begin
  if FCount = 0 then
    result := NULL_VALUE
  else
    result := Flist[NearesteIdx(idx)];
end;

{$IFDEF WITHTEST}
procedure TDmInt64List.IntCheck;
var
  i, last, holes, lastindex: Integer;
begin
  if FLastHoleIdx >= 0 then
    Assert(FList[FLastHoleIdx] = NULL_VALUE);

  if Sorted and (FCount > 0) then
  begin
   //sort order check
    last := NULL_VALUE;
    for i := 0 to FCapacity - 1 do
      if (last <> NULL_VALUE) and (FList[i] <> NULL_VALUE) then
      begin
        Assert(FList[i] >= last);
        last := FList[i];
      end;

    lastindex := -1;
    for i := FCapacity - 1 downto 0 do
      if FList[i] <> NULL_VALUE then
      begin
        lastindex := i;
        break;
      end;
    assert(lastindex >= 0);

    holes := 0;
    for i := 0 to lastindex do
      if FList[i] = NULL_VALUE then
        inc(holes);

    assert(FHolesCount = holes);
    assert(lastindex = FLastActualIdx);
  end;
end;

{$ENDIF}

function TDmInt64List.Exists(avalue: Int64): Boolean;
var
  i: Integer;
begin
  result := Find(avalue, i);
end;

procedure TDmInt64List.Add(list: TDmInt64List);
var
  i: Integer;
  a: VarArrayOfInt64;
begin
  a := list.CopyArray;
  for i := 0 to length(a) - 1 do
    self.Add(a[i]);
  SetLength(a, 0);
end;

function TDmInt64List.Text: string;
var
  j, i: Integer;
{$IFDEF WITHTEST}
  k: Integer;
{$ENDIF}
  t: TStrings;
begin
  result := '';
  t := TStringList.Create;
  try
    j := 0;
    for i := 0 to FCapacity - 1 do
      if not (FList[i] = NULL_VALUE) then
      begin
        t.Add(IntToStr(_YValue(FList[i])));
        inc(j);
        if J = FCount then
        begin
{$IFDEF WITHTEST}
          k := i;
{$ENDIF}
          break;
        end;
      end;
{$IFDEF WITHTEST}
    for i := k + 1 to FCapacity - 1 do
      Assert(FList[i] = NULL_VALUE);
{$ENDIF}
    result := t.Text;
  finally
    t.Free;
  end;
end;

procedure TDmInt64List.Toss;
var
  i, j: Integer;
  t: Int64;
begin
  Sorted := False;
  Pack;
  Assert(Fcount = FCapacity);
{
для тасования массива a из n элементов (индексы 0..n-1):
  для всех i от n - 1 до 1 выполнить
       j ? случайное число 0 <= j <= i
       обменять местами a[j] и a[i]
}
  for i := FCount - 1 downto 1 do
  begin
    j := random(i + 1);
    t := FList[i];
    FList[i] := FList[j];
    FList[j] := t;
  end;
end;

end.


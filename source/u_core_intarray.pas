(*****************************************
 * (c) 2010-2015 Dmitry Muza
 * 
 * @author Dmitry Muza, 
 * @email  dmitry.muza@gmail.com
 * 
 ******************************************)

unit u_core_intarray;

{$ifdef FPC}
 {$mode delphi}
{$endif}

interface

uses sysutils, classes;

type

  TIntegerVarArray = array of Integer;

  TIntegerArray = Class(TObject)
  private
    FCount: Integer;
    FCapacity: Integer;
    FStore: array of Integer;
    FDuplicates: TDuplicates;
    FMin, FMax: Integer;
    function GetItem(index: Integer): Integer;
    function _SetItem(index: Integer; const Value: Integer): Boolean;
    procedure SetItem(index: Integer; const Value: Integer);
    procedure SetDuplicates(const Value: TDuplicates);
  public
    procedure Add(i: Integer);
    function GetMax: Integer;
    function GetMin: Integer;
    constructor Create(Capacity: Integer);
    function FindFirstValue(value: Integer): Integer;
    property Count: Integer read FCount;
    property Item[index: Integer]: Integer read GetItem write SetItem;
    property Duplicates: TDuplicates read FDuplicates write SetDuplicates;
    function AsArray: TIntegerVarArray;
  end;


implementation



{ TIntegerArray }

procedure TIntegerArray.Add(i: Integer);
begin
  if FCount >= FCapacity then
    raise Exception.Create('no free space');
  if _SetItem(FCount, i) then
    inc(FCount);
end;

function TIntegerArray.AsArray: TIntegerVarArray;
var
  i: Integer;
begin
  SetLength(result, FCount);
  for i := 0 to FCount - 1 do
    Result[i] := FStore[i];
end;

constructor TIntegerArray.Create(Capacity: Integer);
begin
  FCapacity := Capacity;
  FDuplicates := dupIgnore;
  SetLength(FStore, Capacity);
  FMin := -maxint;
  FMax := MaxInt;
end;

function TIntegerArray.FindFirstValue(value: Integer): Integer;
var
  i: Integer;
begin
  result := -1;
  for i := 0 to FCount - 1 do
    if FStore[i] = value then
    begin
      result := i;
      break;
    end;
end;

function TIntegerArray.GetItem(index: Integer): Integer;
begin
  Assert((index >= 0) and (index < FCapacity));
  Result := FStore[index];
end;

function TIntegerArray.GetMax: Integer;
begin
  if FCount <= 0 then
    raise Exception.Create('empty array')
  else
    Result := FMax;
end;

function TIntegerArray.GetMin: Integer;
begin
  if FCount <= 0 then
    raise Exception.Create('empty array')
  else
    result := FMin;
end;

procedure TIntegerArray.SetDuplicates(const Value: TDuplicates);
begin
  FDuplicates := Value;
end;

procedure TIntegerArray.SetItem(index: Integer; const Value: Integer);
begin
  Assert((index >= 0) and (index < FCount));
  _SetItem(index, value);
end;

function TIntegerArray._SetItem(index: Integer; const Value: Integer): Boolean;
begin
  if FDuplicates = dupIgnore then
  begin
    if FCount = 0 then
    begin
      FMin := Value;
      FMax := Value;
    end
    else
    if Value < FMin then
      FMin := Value
    else
    if Value > FMax then
      FMax := Value;
    FStore[index] := Value;
    Result := True;
  end
  else
  if FindFirstValue(value) >= 0 then
  begin
    if FDuplicates = dupAccept then
      result := False
    else
    if FDuplicates = dupError then
    begin
      result := False;
      Raise Exception.Create('not allow duplicates');
    end;
  end
  else
  begin
    if FCount = 0 then
    begin
      FMin := Value;
      FMax := Value;
    end
    else
    if Value < FMin then
      FMin := Value
    else
    if Value > FMax then
      FMax := Value;
    FStore[index] := Value;
    Result := True;
  end;
end;


end.

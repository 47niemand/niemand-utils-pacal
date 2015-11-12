
(*****************************************
 * (c) 2010-2015 Dmitry Muza
 * 
 * @author Dmitry Muza, 
 * @email  dmitry.muza@gmail.com
 * 
 ******************************************)

unit u_intervals;

interface

uses
  Math, Types, Classes, Contnrs;

type
  TIIType = Integer;

const
  TIITypeMin = Low(TIIType);
  TIITypeMax = High(TIIType);

type
  TIntervalItem = record
    A, B: TIIType;
  end;

  TIntervalItemClass = class
  public
    item: TIntervalItem;
    class function ToString(V: TIIType): String;
    constructor Create(A, B: TIIType); overload;
    constructor Create(I: TIntervalItem); overload;
  end;

  TInterval = class ;

  TInterval = class (TObject)
  private
    AItems: TObjectList;
    FSorted: Boolean;
    procedure Sort;
    function GetItems(Index: Integer): TIntervalItem;
    procedure SetItems(Index: Integer; const Value: TIntervalItem);
    function Optimize: Integer; // return count of changes
    procedure OptimizeAll;
    procedure Append(I: TInterval); overload; //Dobavlyaet novyy nabor v sushchestvuyushchiy
    procedure Append(I: TIntervalItem); overload; //Dobavlyaet novyy element v sushchestvuyushchiy
  public
    function Count: Integer;
    constructor Create; virtual;
    destructor Destroy; override;

    //Proveryaet, soderzhitsya li polnostyu interval value v tekushchem intervale.
    function Include(I: TInterval): Boolean; overload;
    function Include(I: TIIType): Boolean; overload;
    function Include(I: TIntervalItem): Boolean; overload;


    procedure Combine(I: TInterval); overload;
    procedure Combine(I: TIntervalItem); overload;

    procedure Exclude(I: TInterval); overload;
    procedure Exclude(I: TIntervalItem); overload;

    function Crop(I: TIntervalItem): Boolean;

    function Sum: TIIType;
    function Empty: Boolean;
    function List: TStrings;

    procedure CopyTo(I: TInterval);
    procedure Clear;
    property Items[Index: Integer]: TIntervalItem read GetItems write SetItems;
    function Print: String;
  end;


function AInterval(A, B: TIIType): TIntervalItem;


implementation

uses
  SysUtils;

function AInterval(A, B: TIIType): TIntervalItem;
begin
  Result.A := A;
  Result.B := B;
end;

const
  NullItem: TIntervalItem = (A: 0; B: 0);

function IsNullInterval(I: TIntervalItem): boolean;
begin
  Result := (I.A = 0) and (I.B = 0);
end;

function IsNullLengthInterval(I: TIntervalItem): boolean;
begin
  Result := abs(I.B - I.A) = 0;
end;


function SignOfInterval(I: TIntervalItem): Integer;
begin
  if I.B > I.A then
    result := 1
  else
  if I.B = I.A then
    result := 0
  else
    {I.A>I.B} result := -1;
end;


procedure IntervalNorm(var I: TIntervalItem);
var
  C: TIntervalItem;
begin
  if I.A > I.B then
  begin
    C.A := I.A;
    I.A := I.B;
    I.B := C.A;
  end;
end;

{ TInterval }


procedure TInterval.Append(I: TInterval);
var
  j: Integer;
begin
  for j := 0 to I.count - 1 do
    Self.Append(I.Items[j]);
end;


procedure TInterval.Append(I: TIntervalItem);
begin
  FSorted := False;
  AItems.Add(TIntervalItemClass.Create(I));
end;

procedure TInterval.Clear;
begin
  AItems.Clear;
end;


function CompareProcA(item1, item2: TIntervalItem): Integer;
begin
  if item1.A > item2.A then
    result := 1
  else
  if item1.A < item2.A then
    result := -1
  else
  if item1.B > item2.B then
    result := 1
  else
  if item1.B < item2.B then
    result := -1
  else
    result := 0;
end;

function CompareProcForIntervalItemObjcet(i1, i2: pointer): Integer;
var
  item1: TIntervalItemClass absolute i1;
  item2: TIntervalItemClass absolute i2;
begin
  result := CompareProcA(item1.item, item2.item);
  //CompareProc should compare the two items given as
  //parameters and return a value less than 0 if item1
  //comes before item2, return a value greater than 0
  //if item1 comes after item2, and return 0 if item1 is the same as item2.
end;


procedure TInterval.Sort;
begin
  AItems.Sort(CompareProcForIntervalItemObjcet);
  FSorted := true;
end;

procedure TInterval.Combine(I: TInterval);
begin
  Append(I);
  OptimizeAll;
end;

function TInterval.Include(I: TIntervalItem): Boolean;
var
  k: Integer;
begin
  result := False;
  for k := 0 to Count - 1 do
  begin
    result := result or (InRange(i.A, items[k].A, items[k].b) and InRange(i.B, items[k].A, items[k].b));
    if result then
      break;
  end;
end;


function TInterval.Include(I: TIIType): Boolean;
var
  k: Integer;
begin
  result := false;
  for k := 0 to Count - 1 do
  begin
    result := result or (InRange(I, items[k].A, items[k].b));
    if result then
      break;
  end;
end;

function TInterval.Include(I: TInterval): Boolean;
var
  k: Integer;
begin
  result := false;
  for k := 0 to i.Count - 1 do
  begin
    result := result or Include(I.Items[k]);
    if result then
      break;
  end;
end;


procedure TInterval.CopyTo(I: TInterval);
begin
  I.Clear;
  I.Append(Self);
end;

function TInterval.Empty: Boolean;
begin
  Result := AItems.Count = 0;
end;

function TInterval.Count: Integer;
begin
  Result := AItems.Count;
end;

constructor TInterval.Create;
begin
  AItems := TObjectList.Create(True);
  FSorted := False;
  Clear;
end;

destructor TInterval.Destroy;
begin
  AItems.Free;
  inherited;
end;

procedure TInterval.Exclude(I: TInterval);
var
  k: Integer;
begin
  for k := 0 to i.Count - 1 do
    Exclude(I.Items[k]);
end;

function TInterval.GetItems(Index: Integer): TIntervalItem;
begin
  Result := TIntervalItemClass(AItems.Items[index]).item;
end;

function _Q_iss(a, b: TIntervalItem): TIntervalItem;
  // a must be < b
  // a & b normalized
begin
  result.A := min(a.A, b.A);
  result.b := max(a.B, b.B);
end;

procedure TInterval.SetItems(Index: Integer; const Value: TIntervalItem);
begin
  TIntervalItemClass(AItems.Items[Index]).item := Value;
end;

function TInterval.Optimize: Integer;
var
  i: Integer;
  l: Integer;
begin
  if not FSorted then
    Sort;
  L := 0;
  if Count > 1 then
  begin
    i := 0;

   //Udalyaem dublikaty  i pustye intervaly
    while i < (Count - 1) do
      if CompareProcA(Items[i], Items[i + 1]) = 0 then
      begin
        AItems.Delete(I);
        inc(l);
      end
      else
      if IsNullInterval(Items[i]) then
      begin
        AItems.Delete(I);
        inc(l);
      end
      else
        Inc(i);

    //proveryaem posledniy interval esli on pustoy udalyaem
    if (Count > 0) and IsNullInterval(Items[count - 1]) then
    begin
      AItems.Delete(I);
      inc(l);
    end;

    //Vyranivaem peresechenie
    for i := 0 to Count - 2 do
      if Items[i].B >= Items[i + 1].A then
      begin
        Items[i] := _Q_iss(Items[i], Items[i + 1]);
        Items[i + 1] := Items[i];
        inc(l);
      end;

  end;
  result := l;
end;

procedure TInterval.OptimizeAll;
begin
  while Optimize > 0 do ;
end;

procedure TInterval.Combine(I: TIntervalItem);
begin
  Append(I);
  OptimizeAll;
end;

procedure TInterval.Exclude(I: TIntervalItem);
var
  k, c: Integer;
  p: Integer;
  f: TIIType;
begin
  if not FSorted then
    Sort;
  p := 0;

  c := count;
  for k := 0 to c - 1 do
    if (I.A > Items[k].A) and (I.B < Items[k].B) then
    begin //razryv intervalom
      f := Items[k].B;
      Items[k] := AInterval(Items[k].A, I.A); // zamenyaem tekushchiy
      Append(AInterval(I.B, f));
 // dobavlyaem razryv v konets spiska on budet sotrirovan pozzhe i ne budet obrabotn vy  etom tsikle
    end
    else
    if InRange(I.A, Items[k].A, Items[k].B) and (I.B >= Items[k].B) then
      Items[k] := AInterval(Items[k].A, I.A)// peresechenie sprava
    else
    if InRange(I.B, Items[k].A, Items[k].B) and (I.A <= Items[k].A) then
      Items[k] := AInterval(I.B, Items[k].B)// peresechenie sleva
    else
    if (I.A <= Items[k].A) and (I.B >= Items[k].B) then
      Items[k] := NullItem// polnoe isklyuchenie, budet udalen pri optimizatsii
  ;
  OptimizeAll;
end;

function TInterval.Print: String;
var
  S: TStrings;
  i: Integer;
begin
  S := List;
  try
    if S.Count = 0 then
      Result := '<empty>'
    else
      Result := '[' + S.CommaText + ']';
  finally
    S.Free;
  end;
end;

function TInterval.List: TStrings;
var
  S: TStringList;
  i: Integer;
begin
  Result := TStringList.Create;
  for i := 0 to Count - 1 do
    Result.Add(format('(%s ; %s)', [TIntervalItemClass.ToString(Items[i].A),
      TIntervalItemClass.ToString(Items[i].B)]));

end;


function TInterval.Crop(I: TIntervalItem): boolean;
begin
  if not FSorted then
    Sort;
  result := False;
  Exclude(AInterval(TIITypeMin, I.A));
  Exclude(AInterval(I.B, TIITypeMax));
  if Count > 0 then
    result := (i.A = Items[0].A) and (i.B = items[Count - 1].B);
end;

function TInterval.Sum: TIIType;
var
  k: Integer;
begin
  result := 0;
  for k := 0 to Count - 1 do
    result := result + (Items[k].B - Items[k].A);
end;


{ TIntervalItemClass }

constructor TIntervalItemClass.Create(A, B: TIIType);
begin
  Self.item.A := A;
  Self.item.B := B;
end;

constructor TIntervalItemClass.Create(I: TIntervalItem);
begin
  Self.item := I;
end;


class function TIntervalItemClass.ToString(V: TIIType): String;
begin
  result := IntToStr(V);
end;

end.

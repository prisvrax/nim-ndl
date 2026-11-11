import std/[sequtils, tables]

type
  NdlIntKind* = enum
    nikPos, nikNeg, nikRaw

  NdlInt* = object
    case kind*: NdlIntKind
    of NdlIntKind.nikPos:
      valPos*: uint64
    of NdlIntKind.nikNeg:
      valNeg*: int64
    of NdlIntKind.nikRaw:
      valRaw*: string

  NdlRealKind* = enum
    nrkF64, nrkRaw

  NdlReal* = object
    case kind*: NdlRealKind
    of NdlRealKind.nrkF64:
      valFloat*: float64
    of NdlRealKind.nrkRaw:
      valRaw*: string

  NdlValueKind* = enum
    nvNull, nvBool, nvInt, nvReal, nvString, nvArray, nvMap

  NdlValue* = object
    case kind*: NdlValueKind
    of NdlValueKind.nvNull:
      discard
    of NdlValueKind.nvBool:
      valBool*: bool
    of NdlValueKind.nvInt:
      valInt*: NdlInt
    of NdlValueKind.nvReal:
      valReal*: NdlReal
    of NdlValueKind.nvString:
      valStr*: string
    of NdlValueKind.nvArray:
      valArr*: seq[NdlValue]
    of NdlValueKind.nvMap:
      valMap*: OrderedTable[string, NdlValue]

func `$`*(ndlIntVal: NdlInt): string =
  case ndlIntVal.kind
  of NdlIntKind.nikPos:
    $ndlIntVal.valPos
  of NdlIntKind.nikNeg:
    $ndlIntVal.valNeg
  of NdlIntKind.nikRaw:
    ndlIntVal.valRaw

func `$`*(ndlRealVal: NdlReal): string =
  case ndlRealVal.kind
  of NdlRealKind.nrkF64:
    $ndlRealVal.valFloat
  of NdlRealKind.nrkRaw:
    ndlRealVal.valRaw

func `$`*(ndlVal: NdlValue): string =
  case ndlVal.kind
  of NdlValueKind.nvNull:
    return "null"
  of NdlValueKind.nvBool:
    return if ndlVal.valBool: "true" else: "false"
  of NdlValueKind.nvInt:
    return $ndlVal.valInt
  of NdlValueKind.nvReal:
    return $ndlVal.valReal
  of NdlValueKind.nvString:
    return "\"" & ndlVal.valStr & "\""
  of NdlValueKind.nvArray:
    var
      arr = "["
      first = true
    for ele in ndlVal.valArr:
      if not first:
        arr.add(" ")
      first = false
      arr.add(`$`(ele))
    arr.add("]")
    return arr
  of NdlValueKind.nvMap:
    var
      map = "{"
      first = true
    for mapK, mapV in ndlVal.valMap:
      if not first:
        map.add(" ")
      first = false
      map.add(mapK)
      map.add(" ")
      map.add(`$`(mapV))
    map.add("}")
    return map

proc `[]`*(val: NdlValue, mKey: string): NdlValue =
  doAssert val.kind == nvMap
  val.valMap[mKey]

proc `[]`*(val: NdlValue, aIdx: int): NdlValue =
  doAssert val.kind == nvArray
  val.valArr[aIdx]

proc `[]=`*(val: var NdlValue, mKey: string, mVal: NdlValue) =
  doAssert val.kind == nvMap
  val.valMap[mKey] = mVal

proc `[]=`*(val: var NdlValue, aIdx: int, aVal: NdlValue) =
  doAssert val.kind == nvArray
  val.valArr[aIdx] = aVal

proc initNdlNull*(): NdlValue =
  NdlValue(kind: NdlValueKind.nvNull)

proc initNdlBool*(val: bool): NdlValue =
  NdlValue(kind: NdlValueKind.nvBool, valBool: val)

proc initNdlInt*(val: int64): NdlValue =
  if val >= 0:
    NdlValue(kind: NdlValueKind.nvInt, valInt: NdlInt(kind: NdlIntKind.nikPos, valPos: uint64(val)))
  else:
    NdlValue(kind: NdlValueKind.nvInt, valInt: NdlInt(kind: NdlIntKind.nikNeg, valNeg: val))

proc initNdlInt*(val: uint64): NdlValue =
  NdlValue(kind: NdlValueKind.nvInt, valInt: NdlInt(kind: NdlIntKind.nikPos, valPos: val))

proc initNdlBigInt*(rawVal: string): NdlValue =
  NdlValue(kind: NdlValueKind.nvInt, valInt: NdlInt(kind: NdlIntKind.nikRaw, valRaw: rawVal))

proc initNdlReal*(val: float64): NdlValue =
  NdlValue(kind: NdlValueKind.nvReal, valReal: NdlReal(kind: NdlRealKind.nrkF64, valFloat: val))

proc initNdlBigReal*(rawVal: string): NdlValue =
  NdlValue(kind: NdlValueKind.nvReal, valReal: NdlReal(kind: NdlRealKind.nrkRaw, valRaw: rawVal))

proc initNdlString*(val: string): NdlValue =
  NdlValue(kind: NdlValueKind.nvString, valStr: val)

proc initNdlArray*(arr: openArray[NdlValue] = []): NdlValue =
  NdlValue(kind: NdlValueKind.nvArray, valArr: arr.toSeq())

proc initNdlMap*(orderTbl: OrderedTable[string, NdlValue]): NdlValue =
  NdlValue(kind: NdlValueKind.nvMap, valMap: orderTbl)

proc initNdlMap*(pairs: openArray[(string, NdlValue)] = []): NdlValue =
  var ndlMap = initOrderedTable[string, NdlValue]()
  for (pairK, pairV) in pairs:
    ndlMap[pairK] = pairV
  NdlValue(kind: NdlValueKind.nvMap, valMap: ndlMap)

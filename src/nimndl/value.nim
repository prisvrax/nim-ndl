import std/[sequtils, tables]

type
  NdlIntKind* = enum
    nikU64, nikI64, nikRaw

  NdlInt* = object
    case kind*: NdlIntKind
    of NdlIntKind.nikU64:
      valUint*: uint64
    of NdlIntKind.nikI64:
      valInt*: int64
    of NdlIntKind.nikRaw:
      valBig*: string

  NdlRealKind* = enum
    nrkF64, nrkRaw

  NdlReal* = object
    case kind*: NdlRealKind
    of NdlRealKind.nrkF64:
      valFloat*: float64
    of NdlRealKind.nrkRaw:
      valBig*: string

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
  NdlValue(kind: nvNull)

proc initNdlBool*(val: bool): NdlValue =
  NdlValue(kind: nvBool, valBool: val)

proc initNdlInt*(val: int64): NdlValue =
  if val >= 0:
    NdlValue(kind: nvInt, valInt: NdlInt(kind: nikU64, valUint: uint64(val)))
  else:
    NdlValue(kind: nvInt, valInt: NdlInt(kind: nikI64, valInt: val))

proc initNdlInt*(val: uint64): NdlValue =
  NdlValue(kind: nvInt, valInt: NdlInt(kind: nikU64, valUint: val))

proc initNdlBigInt*(rawVal: string): NdlValue =
  NdlValue(kind: nvInt, valInt: NdlInt(kind: nikRaw, valBig: rawVal))

proc initNdlReal*(val: float64): NdlValue =
  NdlValue(kind: nvReal, valReal: NdlReal(kind: nrkF64, valFloat: val))

proc initNdlBigReal*(rawVal: string): NdlValue =
  NdlValue(kind: nvReal, valReal: NdlReal(kind: nrkRaw, valBig: rawVal))

proc initNdlString*(val: string): NdlValue =
  NdlValue(kind: nvString, valStr: val)

proc initNdlArray*(arr: openArray[NdlValue] = []): NdlValue =
  NdlValue(kind: nvArray, valArr: arr.toSeq())

proc initNdlMap*(orderTbl: OrderedTable[string, NdlValue]): NdlValue =
  NdlValue(kind: nvMap, valMap: orderTbl)

proc initNdlMap*(pairs: openArray[(string, NdlValue)] = []): NdlValue =
  var ndlMap = initOrderedTable[string, NdlValue]()
  for (pairK, pairV) in pairs:
    ndlMap[pairK] = pairV
  NdlValue(kind: nvMap, valMap: ndlMap)

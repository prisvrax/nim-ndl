import std/[tables]

type
  NdlIntKind* = enum
    nikU64, nikI64, nikBig

  NdlInt* = object
    case kind*: NdlIntKind
    of NdlIntKind.nikU64:
      valUint*: uint64
    of NdlIntKind.nikI64:
      valInt*: int64
    of NdlIntKind.nikBig:
      valBig*: string

  NdlRealKind* = enum
    nrkF64, nrkRaw

  NdlReal* = object
    case kind*: NdlRealKind
    of NdlRealKind.nrkF64:
      valFloat*: float64
    of NdlRealKind.nrkRaw:
      valText*: string

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

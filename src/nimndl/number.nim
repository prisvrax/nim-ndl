import std/[math, parseutils, strutils]
import pkg/results
import ./[error, value]

template overflow(store: untyped, fresh: untyped, limit: untyped): bool =
  store >= limit div 10'u64 and (store > limit div 10'u64 or fresh > limit mod 10'u64)

proc parseNdlIntHex(negative: bool, nums: string, raw: string): Result[NdlInt, NdlError]
  {.inline, raises: [].} =
  type Rt = Result[NdlInt, NdlError]
  if nums.len() > 16:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))
  var numX: uint64
  if parseHex(nums, numX) != nums.len():
    return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
  if not negative:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikPos, valPos: numX))
  if numX <= uint64(high(int64)):
    return Rt.ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(numX)))
  return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))

proc parseNdlIntBin(negative: bool, nums: string, raw: string): Result[NdlInt, NdlError]
  {.inline, raises: [].} =
  type Rt = Result[NdlInt, NdlError]
  if nums.len() > 64:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))
  var numB: uint64
  if parseBin(nums, numB) != nums.len():
    return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
  if not negative:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikPos, valPos: numB))
  if numB <= uint64(high(int64)):
    return Rt.ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(numB)))
  return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))

proc parseNdlInt*(raw: string): Result[NdlInt, NdlError] {.raises: [].} =
  type Rt = Result[NdlInt, NdlError]
  let
    negative = raw.len() > 0 and raw[0] == '-'
    numBd = if negative: raw[1 .. ^1] else: raw

  # hex: 0x
  if numBd.len() >= 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'x':
    let nums = numBd[2 .. ^1].toLowerAscii()
    if nums.len() == 0:
      return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    return parseNdlIntHex(negative, nums, raw)
  
  # bin: 0b
  if numBd.len() >= 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'b':
    let nums = numBd[2 .. ^1]
    if nums.len() == 0:
      return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    return parseNdlIntBin(negative, nums, raw)

  # dec
  if numBd.len() > 20:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))
  var numD: uint64 = 0
  for numi in numBd:
    if numi notin {'0'..'9'}:
      return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    let numiCurr = uint64(ord(numi) - ord('0'))
    if overflow(numD, numiCurr, high(uint64)):
      return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))
    numD = numD * 10 + numiCurr

  if not negative:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikPos, valPos: numD))

  if numD <= uint64(high(int64)):
    return Rt.ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(numD)))
  elif numD == uint64(high(int64)) + 1:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: low(int64)))
  else:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))

proc parseNdlReal*(raw: string): Result[NdlReal, NdlError] {.raises: [].} =
  type Rt = Result[NdlReal, NdlError]
  case raw
  of "inf":
    return Rt.ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: Inf))
  of "-inf":
    return Rt.ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: -Inf))
  of "nan":
    return Rt.ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: NaN))
  else:
    discard

  var numF: float64
  if parseFloat(raw, numF) != raw.len():
    return Rt.err(NdlError(kind: NdlErrorKind.parseRealError, numRaw: raw))
  if numF.classify == fcInf or numF.classify == fcNegInf:
    return Rt.ok(NdlReal(kind: NdlRealKind.nrkRaw, valBig: raw))
  else:
    return Rt.ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: numF))

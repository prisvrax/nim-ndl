import std/[math, parseutils, strutils]
import pkg/results
import ./[error, value]

template overflow(store: untyped, fresh: untyped, limit: untyped): bool =
  store >= limit div 10'u64 and (store > limit div 10'u64 or fresh > limit mod 10'u64)

template finishParseInt(negative: bool, num: uint64, raw: string) =
  if not negative:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikPos, valPos: num))
  if num <= uint64(high(int64)):
    return Rt.ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(num)))
  elif num == uint64(high(int64)) + 1:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: low(int64)))
  return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))

proc parseNdlIntBin(negative: bool, nums: string, raw: string): Result[NdlInt, NdlError]
  {.inline, raises: [].} =
  type Rt = Result[NdlInt, NdlError]
  var start = 0
  while start < nums.len and nums[start] == '0':
    inc start
  if nums.len() - start > 64:
    return Rt.ok(NdlInt(kind: nikRaw, valBig: raw))
  var numB: uint64
  if parseBin(nums, numB, start) != nums.len() - start:
    return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
  finishParseInt(negative, numB, raw)

proc parseNdlIntHex(negative: bool, nums: string, raw: string): Result[NdlInt, NdlError]
  {.inline, raises: [].} =
  type Rt = Result[NdlInt, NdlError]
  var start = 0
  while start < nums.len and nums[start] == '0':
    inc start
  if nums.len() - start > 16:
    return Rt.ok(NdlInt(kind: NdlIntKind.nikRaw, valBig: raw))
  var numX: uint64
  if parseHex(nums, numX, start) != nums.len() - start:
    return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
  finishParseInt(negative, numX, raw)

proc parseNdlInt*(raw: string): Result[NdlInt, NdlError] {.raises: [].} =
  type Rt = Result[NdlInt, NdlError]

  let
    negative = raw.len() > 0 and raw[0] == '-'
    numBd = if negative: raw[1 .. ^1] else: raw
  if numBd.len() == 0:
    return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))

  # bin: 0b
  if numBd.len() >= 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'b':
    let nums = numBd[2 .. ^1]
    if nums.len() == 0:
      return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    return parseNdlIntBin(negative, nums, raw)

  # hex: 0x
  if numBd.len() >= 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'x':
    let nums = numBd[2 .. ^1].toLowerAscii()
    if nums.len() == 0:
      return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    return parseNdlIntHex(negative, nums, raw)

  # dec
  if numBd.len() > 1 and numBd[0] == '0':
    return Rt.err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
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

  finishParseInt(negative, numD, raw)

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

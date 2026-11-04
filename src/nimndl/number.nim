import std/[math, strutils]
import ./value

template overflow(store: untyped, fresh: untyped, limit: untyped): bool =
  store >= limit div 10'u64 and (store > limit div 10'u64 or fresh > limit mod 10'u64)

proc parseNdlIntHex(negative: bool, nums: string, raw: string): NdlInt {.inline, raises: [].} =
  if nums.len > 16:
    return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)
  var numX: uint64 = 0
  for numi in nums:
    let numiCurr = case numi
      of '0'..'9': uint64(ord(numi) - ord('0'))
      of 'a'..'f': uint64(ord(numi) - ord('a') + 10)
      else:
        return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)
    numX = (numX shl 4) or numiCurr
  if not negative:
    return NdlInt(kind: NdlIntKind.nikPos, valPos: numX)
  if numX <= uint64(high(int64)):
    return NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(numX))
  return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)

proc parseNdlIntBin(negative: bool, nums: string, raw: string): NdlInt {.inline, raises: [].} =
  if nums.len() > 64:
    return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)
  var numB: uint64 = 0
  for numi in nums:
    let numiCurr = case numi
      of '0': 0'u64
      of '1': 1'u64
      else:
        return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)
    numB = (numB shl 1) or numiCurr
  if not negative:
    return NdlInt(kind: NdlIntKind.nikPos, valPos: numB)
  if numB <= uint64(high(int64)):
    return NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(numB))
  return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)

proc parseNdlInt*(raw: string): NdlInt {.raises: [].} =
  let
    negative = raw.len() > 0 and raw[0] == '-'
    numBd = if negative: raw[1 .. ^1] else: raw

  # hex: 0x
  if numBd.len() > 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'x':
    let nums = numBd[2 .. ^1].toLowerAscii()
    return parseNdlIntHex(negative, nums, raw)

  # bin: 0b
  if numBd.len() > 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'b':
    let nums = numBd[2 .. ^1]
    return parseNdlIntBin(negative, nums, raw)

  # dec
  if numBd.len() > 20:
    return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)
  var numD: uint64 = 0
  for numi in numBd:
    let numiCurr = uint64(ord(numi) - ord('0'))
    if overflow(numD, numiCurr, high(uint64)):
      return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)
    numD = numD * 10 + numiCurr

  if not negative:
    return NdlInt(kind: NdlIntKind.nikPos, valPos: numD)

  if numD <= uint64(high(int64)):
    return NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(numD))
  elif numD == uint64(high(int64)) + 1:
    return NdlInt(kind: NdlIntKind.nikNeg, valNeg: low(int64))
  else:
    return NdlInt(kind: NdlIntKind.nikRaw, valBig: raw)

proc parseNdlReal*(raw: string): NdlReal {.raises: [ValueError].} =
  case raw
  of "inf":
    return NdlReal(kind: NdlRealKind.nrkF64, valFloat: Inf)
  of "-inf":
    return NdlReal(kind: NdlRealKind.nrkF64, valFloat: -Inf)
  of "nan":
    return NdlReal(kind: NdlRealKind.nrkF64, valFloat: NaN)
  else:
    discard

  let numF = parseFloat(raw)
  if numF.classify == fcInf or numF.classify == fcNegInf:
    return NdlReal(kind: NdlRealKind.nrkRaw, valBig: raw)
  else:
    return NdlReal(kind: NdlRealKind.nrkF64, valFloat: numF)

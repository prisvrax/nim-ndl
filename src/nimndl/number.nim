import std/[math, parseutils, strutils]
import pkg/results
import ./[error, value]

template overflow(store: untyped, fresh: untyped, limit: untyped): bool =
  store >= limit div 10'u64 and (store > limit div 10'u64 or fresh > limit mod 10'u64)

template finishParseInt(negative: bool, num: uint64, raw: string) =
  if not negative:
    return ok(NdlInt(kind: NdlIntKind.nikPos, valPos: num))
  if num <= uint64(high(int64)):
    return ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: -int64(num)))
  elif num == uint64(high(int64)) + 1:
    return ok(NdlInt(kind: NdlIntKind.nikNeg, valNeg: low(int64)))
  return ok(NdlInt(kind: NdlIntKind.nikRaw, valRaw: raw))

proc parseNdlIntBin(negative: bool, nums: string, start: int, raw: string): Result[NdlInt, NdlError]
  {.inline, raises: [].} =
  var start = start
  while start < nums.len() and nums[start] == '0':
    inc start
  if nums.len() - start > 64:
    return ok(NdlInt(kind: NdlIntKind.nikRaw, valRaw: raw))
  var numB: uint64
  if parseBin(nums, numB, start) != nums.len() - start:
    return err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
  finishParseInt(negative, numB, raw)

proc parseNdlIntHex(negative: bool, nums: string, start: int, raw: string): Result[NdlInt, NdlError]
  {.inline, raises: [].} =
  var start = start
  while start < nums.len() and nums[start] == '0':
    inc start
  if nums.len() - start > 16:
    return ok(NdlInt(kind: NdlIntKind.nikRaw, valRaw: raw))
  var numX: uint64
  if parseHex(nums, numX, start) != nums.len() - start:
    return err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
  finishParseInt(negative, numX, raw)

proc parseNdlInt*(raw: string): Result[NdlInt, NdlError] {.raises: [].} =
  let
    negative = raw.len() > 0 and raw[0] == '-'
    numBd = if negative: raw[1 .. ^1] else: raw
  if numBd.len() == 0:
    return err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))

  # bin: 0b
  if numBd.len() >= 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'b':
    if numBd.len() == 2:
      return err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    return parseNdlIntBin(negative, numBd, 2, raw)

  # hex: 0x
  if numBd.len() >= 2 and numBd[0] == '0' and numBd[1].toLowerAscii() == 'x':
    if numBd.len() == 2:
      return err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    return parseNdlIntHex(negative, numBd, 2, raw)

  # dec
  if numBd.len() > 1 and numBd[0] == '0':
    return err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
  if numBd.len() > 20:
    return ok(NdlInt(kind: NdlIntKind.nikRaw, valRaw: raw))
  var numD: uint64 = 0
  for numi in numBd:
    if numi notin {'0'..'9'}:
      return err(NdlError(kind: NdlErrorKind.parseIntError, numRaw: raw))
    let numiCurr = uint64(ord(numi) - ord('0'))
    if overflow(numD, numiCurr, high(uint64)):
      return ok(NdlInt(kind: NdlIntKind.nikRaw, valRaw: raw))
    numD = numD * 10 + numiCurr

  finishParseInt(negative, numD, raw)

proc parseNdlIntUnchecked*(raw: string): Result[NdlInt, NdlError] {.raises: [].} =
  let
    negative = raw.len() > 0 and raw[0] == '-'
    numBd = if negative: raw[1 .. ^1] else: raw

  # bin: 0b
  if numBd.len >= 2 and numBd[0] == '0':
    case numBd[1].toLowerAscii()
    of 'b':
      return parseNdlIntBin(negative, numBd, 2, raw)
    of 'x':
      return parseNdlIntHex(negative, numBd, 2, raw)
    else:
      discard

  # dec
  if numBd.len() > 20:
    return ok(NdlInt(kind: NdlIntKind.nikRaw, valRaw: raw))
  var numD: uint64 = 0
  for numi in numBd:
    let numiCurr = uint64(ord(numi) - ord('0'))
    if overflow(numD, numiCurr, high(uint64)):
      return ok(NdlInt(kind: NdlIntKind.nikRaw, valRaw: raw))
    numD = numD * 10 + numiCurr

  finishParseInt(negative, numD, raw)

proc mantissaIsZero(raw: string): bool =
  ## determining whether a floating-point zero is a mathematical zero
  var i = 0
  if i < raw.len() and raw[i] == '-':
    inc i
  while i < raw.len():
    case raw[i]
    of '1'..'9':
      return false
    of 'e', 'E':
      return true
    of '0', '.':
      discard
    else:
      return true
    inc i
  true

proc isValidNdlReal(raw: string): bool =
  if raw in ["inf", "-inf", "nan"]:
    return true

  let rawL = raw.len()
  var idx: int = 0

  if idx < rawL and raw[idx] == '-':
    inc idx
  if idx >= rawL:
    return false

  # integer part: 0 | [1-9][0-9]*
  if raw[idx] == '0':
    inc idx
  elif raw[idx] in {'1'..'9'}:
    inc idx
    while idx < rawL and raw[idx] in {'0'..'9'}:
      inc idx
  else:
    return false

  # fractional part: .[0-9]+
  var hasDot = false
  if idx < rawL and raw[idx] == '.':
    hasDot = true
    inc idx
    if idx >= rawL or raw[idx] notin {'0'..'9'}:
      return false
    while idx < rawL and raw[idx] in {'0'..'9'}:
      inc idx

  # exponent part: [eE]-?(0|[1-9][0-9]*)
  var hasExp = false
  if idx < rawL and raw[idx] in {'e', 'E'}:
    hasExp = true
    inc idx
    if idx < rawL and raw[idx] == '-':
      inc idx
    if idx >= rawL or raw[idx] notin {'0'..'9'}:
      return false
    if raw[idx] == '0':
      inc idx
      if idx < rawL and raw[idx] in {'0'..'9'}:
        return false
    else:
      while idx < rawL and raw[idx] in {'0'..'9'}:
        inc idx

  if not hasDot and not hasExp:
    return false

  return idx == rawL

proc parseNdlRealUnchecked*(raw: string): Result[NdlReal, NdlError] {.raises: [].} =
  case raw
  of "inf":
    return ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: Inf))
  of "-inf":
    return ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: -Inf))
  of "nan":
    return ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: NaN))
  else:
    discard

  var numF: float64
  if parseFloat(raw, numF) != raw.len():
    return err(NdlError(kind: NdlErrorKind.parseRealError, numRaw: raw))
  if numF.classify() in {FloatClass.fcInf, FloatClass.fcNegInf}:
    return ok(NdlReal(kind: NdlRealKind.nrkRaw, valRaw: raw))
  elif numF.classify() in {FloatClass.fcZero, FloatClass.fcNegZero} and not mantissaIsZero(raw):
    return ok(NdlReal(kind: NdlRealKind.nrkRaw, valRaw: raw))
  else:
    return ok(NdlReal(kind: NdlRealKind.nrkF64, valFloat: numF))

proc parseNdlReal*(raw: string): Result[NdlReal, NdlError] {.raises: [].} =
  if not isValidNdlReal(raw):
    return err(NdlError(kind: NdlErrorKind.parseRealError, numRaw: raw))
  return parseNdlRealUnchecked(raw)

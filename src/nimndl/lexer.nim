import std/[options, parseutils, unicode]
import pkg/[results]
import ./[token, error]

type NdlLexer* = object
  input*: string
  pos*: int
  line*: int
  col*: int
  peeked*: Option[NdlToken]

proc initNdlLexer*(input: string): NdlLexer =
  NdlLexer(input: input, pos: 0, line: 1, col: 1, peeked: none(NdlToken))

proc atEnd(lex: NdlLexer): bool {.inline.} =
  lex.pos >= lex.input.len

proc advance(lex: var NdlLexer) {.inline.} =
  if lex.pos < lex.input.len:
    if lex.input[lex.pos] == '\n':
      inc lex.line
      lex.col = 1
    else:
      inc lex.col
    inc lex.pos

proc skipWhitespace(lex: var NdlLexer): bool =
  var skip = false
  while not lex.atEnd() and lex.input[lex.pos] in {' ', '\t', '\r', '\n'}:
    skip = true
    lex.advance()
  return skip

template lexErrorAt(lex: NdlLexer, msg: string): NdlError =
  NdlError(kind: NdlErrorKind.lexError, lexMsg: msg, lexLine: lex.line, lexCol: lex.col)

proc scanIdent(lex: var NdlLexer, hadSpace: bool): NdlToken =
  let
    ctnStart = lex.pos
    lineStart = lex.line
    colStart = lex.col
  lex.advance()
  while not lex.atEnd() and lex.input[lex.pos] in {'a'..'z', 'A'..'Z', '0'..'9', '_', '-'}:
    lex.advance()
  let text = lex.input[ctnStart ..< lex.pos]
  return NdlToken(
    kind: NdlTokenKind.tkIdent, line: lineStart, col: colStart, text: text, leadingSpace: hadSpace)

proc scanQuoted(lex: var NdlLexer, terminator: char): Result[string, NdlError] {.inline.} =
  lex.advance()
  var decoded = ""
  while not lex.atEnd():
    let curr = lex.input[lex.pos]
    if curr == terminator:
      lex.advance()
      return ok(decoded)
    elif curr == '\\':
      lex.advance()
      if lex.atEnd():
        return err(lexErrorAt(lex, "unterminated escape"))
      let escChr = lex.input[lex.pos]
      case escChr
      of 'n':
        decoded.add('\n')
        lex.advance()
      of 't':
        decoded.add('\t')
        lex.advance()
      of '\\':
        decoded.add('\\')
        lex.advance()
      of '\'':
        decoded.add('\'')
        lex.advance()
      of '"':
        decoded.add('"')
        lex.advance()
      of 'u':
        lex.advance()
        if lex.atEnd() or lex.input[lex.pos] != '{':
          return err(lexErrorAt(lex, "expected '{' after \\u"))
        lex.advance()
        var hex = ""
        while not lex.atEnd() and lex.input[lex.pos] != '}':
          hex.add(lex.input[lex.pos])
          lex.advance()
        if lex.atEnd():
          return err(lexErrorAt(lex, "unterminated \\u{"))
        if hex.len() < 1 or hex.len() > 6:
          return err(lexErrorAt(lex, "\\u{...} needs 1-6 hex digits"))
        var unicp: int
        if parseHex(hex, unicp) != hex.len():
          return err(lexErrorAt(lex, "invalid hex in \\u{...}"))
        if unicp > 0x10FFFF or (unicp >= 0xD800 and unicp <= 0xDFFF):
          return err(lexErrorAt(lex, "invalid code point in \\u{...}"))
        decoded.add(Rune(unicp).toUTF8)
        lex.advance()
      else:
        return err(lexErrorAt(lex, "invalid escape: \\" & $escChr))
    else:
      decoded.add(curr)
      lex.advance()
  return err(lexErrorAt(lex, "unterminated string"))

proc scanRawString(lex: var NdlLexer, hadSpace: bool): Result[NdlToken, NdlError] =
  let
    lineStart = lex.line
    colStart = lex.col
  lex.advance()
  let ctnStart = lex.pos
  while not lex.atEnd() and lex.input[lex.pos] != '`':
    lex.advance()
  if lex.atEnd():
    return err(NdlError(
      kind: NdlErrorKind.lexError,
      lexMsg: "unterminated raw string",
      lexLine: lineStart, lexCol: colStart))
  let text = lex.input[ctnStart ..< lex.pos]
  lex.advance()
  ok(NdlToken(
    kind: NdlTokenKind.tkRawString,
    line: lineStart, col: colStart, leadingSpace: hadSpace, text: text))

proc scanString(lex: var NdlLexer, hadSpace: bool): Result[NdlToken, NdlError] =
  let
    lineStart = lex.line
    colStart = lex.col
  let token = lex.scanQuoted('"')
  if token.isErr():
    return err(token.error)
  ok(NdlToken(
    kind: NdlTokenKind.tkString,
    line: lineStart, col: colStart, leadingSpace: hadSpace, text: token.get))

proc scanQuotedKey(lex: var NdlLexer, hadSpace: bool): Result[NdlToken, NdlError] =
  let
    lineStart = lex.line
    colStart = lex.col
  let token = lex.scanQuoted('\'')
  if token.isErr():
    return err(token.error)
  ok(NdlToken(
    kind: NdlTokenKind.tkQuotedKey,
    line: lineStart, col: colStart, leadingSpace: hadSpace, text: token.get))

proc scanNumberBin(lex: var NdlLexer, hadSpace: bool, negative: bool): Result[NdlToken, NdlError] =
  let
    ctnStart = lex.pos
    lineStart = lex.line
    colStart = lex.col
  lex.advance()
  lex.advance()
  while not lex.atEnd() and lex.input[lex.pos] in {'0', '1'}:
    lex.advance()
  if lex.pos - ctnStart <= 2:
    return err(lexErrorAt(lex, "binary number needs at least 1 digits"))
  let raw = lex.input[(if negative: ctnStart - 1 else: ctnStart) ..< lex.pos]
  return ok(NdlToken(
    kind: NdlTokenKind.tkInt, line: lineStart, col: colStart, raw: raw, leadingSpace: hadSpace))

proc scanNumberHex(lex: var NdlLexer, hadSpace: bool, negative: bool): Result[NdlToken, NdlError] =
  let
    ctnStart = lex.pos
    lineStart = lex.line
    colStart = lex.col
  lex.advance()
  lex.advance()
  while not lex.atEnd() and lex.input[lex.pos] in {'0'..'9', 'a'..'f', 'A'..'F'}:
    lex.advance()
  if lex.pos - ctnStart <= 2:
    return err(lexErrorAt(lex, "hexdecimal number needs at least 1 digits"))
  let raw = lex.input[(if negative: ctnStart - 1 else: ctnStart) ..< lex.pos]
  return ok(NdlToken(
    kind: NdlTokenKind.tkInt, line: lineStart, col: colStart, raw: raw, leadingSpace: hadSpace))

proc scanNumber(lex: var NdlLexer, hadSpace: bool): Result[NdlToken, NdlError] =
  let
    ctnStart = lex.pos
    lineStart = lex.line
    colStart = lex.col
    negative = lex.input[lex.pos] == '-'

  if negative:
    lex.advance()
    if lex.atEnd():
      return err(lexErrorAt(lex, "'-' must be followed by a digit"))

  if lex.input[lex.pos] == '0' and lex.pos + 1 < lex.input.len():
    let nextChr = lex.input[lex.pos + 1]
    if nextChr in {'b', 'B'}:
      return lex.scanNumberBin(hadSpace, negative)
    elif nextChr in {'x', 'X'}:
      return lex.scanNumberHex(hadSpace, negative)

  if lex.input[lex.pos] == '0':
    lex.advance()
    if not lex.atEnd() and lex.input[lex.pos] in {'0'..'9'}:
      return err(lexErrorAt(lex, "leading zeros not allowed"))
  else:
    lex.advance()
    while not lex.atEnd() and lex.input[lex.pos] in {'0'..'9'}:
      lex.advance()

  var isReal = false
  if not lex.atEnd() and lex.input[lex.pos] == '.':
    isReal = true
    lex.advance()
    if lex.atEnd() or lex.input[lex.pos] notin {'0'..'9'}:
      return err(lexErrorAt(lex, "expected digit after '.'"))
    while not lex.atEnd() and lex.input[lex.pos] in {'0'..'9'}:
      lex.advance()

  if not lex.atEnd() and lex.input[lex.pos] in {'e', 'E'}:
    isReal = true
    lex.advance()
    if not lex.atEnd() and lex.input[lex.pos] == '-':
      lex.advance()
    if lex.atEnd() or lex.input[lex.pos] notin {'0'..'9'}:
      return err(lexErrorAt(lex, "expected digit in exponent"))
    if lex.input[lex.pos] == '0':
      lex.advance()
      if not lex.atEnd() and lex.input[lex.pos] in {'0'..'9'}:
        return err(lexErrorAt(lex, "leading zeros in exponent not allowed"))
    else:
      while not lex.atEnd() and lex.input[lex.pos] in {'0'..'9'}:
        lex.advance()

  let raw = lex.input[ctnStart ..< lex.pos]
  if isReal:
    return ok(NdlToken(
      kind: NdlTokenKind.tkReal,
      line: lineStart, col: colStart, raw: raw, leadingSpace: hadSpace))
  return ok(NdlToken(
    kind: NdlTokenKind.tkInt,
    line: lineStart, col: colStart, raw: raw, leadingSpace: hadSpace))

proc scanNdlToken(lex: var NdlLexer): Result[NdlToken, NdlError] =
  let hadSpace = lex.skipWhitespace()
  if lex.atEnd():
    return ok(NdlToken(
      kind: NdlTokenKind.tkEof, line: lex.line, col: lex.col, leadingSpace: hadSpace))

  let
    startLine = lex.line
    startCol = lex.col
    curr = lex.input[lex.pos]

  return case curr
  of '{':
    lex.advance()
    ok(NdlToken(
      kind: NdlTokenKind.tkLBrace, line: startLine, col: startCol, leadingSpace: hadSpace))
  of '}':
    lex.advance()
    ok(NdlToken(
      kind: NdlTokenKind.tkRBrace, line: startLine, col: startCol, leadingSpace: hadSpace))
  of '[':
    lex.advance()
    ok(NdlToken(
      kind: NdlTokenKind.tkLBracket, line: startLine, col: startCol, leadingSpace: hadSpace))
  of ']':
    lex.advance()
    ok(NdlToken(
      kind: NdlTokenKind.tkRBracket, line: startLine, col: startCol, leadingSpace: hadSpace))
  of '.':
    lex.advance()
    ok(NdlToken(
      kind: NdlTokenKind.tkDot, line: startLine, col: startCol, leadingSpace: hadSpace))
  of 'a'..'z', 'A'..'Z', '_':
    ok(lex.scanIdent(hadSpace))
  of '`':
    lex.scanRawString(hadSpace)
  of '\"':
    lex.scanString(hadSpace)
  of '\'':
    lex.scanQuotedKey(hadSpace)
  of '0'..'9':
    lex.scanNumber(hadSpace)
  of '-':
    if lex.pos + 1 < lex.input.len() and lex.input[lex.pos + 1] in {'0'..'9'}:
      lex.scanNumber(hadSpace)
    elif lex.pos + 3 < lex.input.len() and
      lex.input[lex.pos + 1 ..< lex.pos + 4] in ["inf", "INF"]:
      lex.advance()
      lex.advance()
      lex.advance()
      lex.advance()
      ok(NdlToken(
        kind: NdlTokenKind.tkIdent,
        line: startLine, col: startCol, leadingSpace: hadSpace, text: "-inf"))
    else:
      err(lexErrorAt(lex, "'-' must be followed by digit or 'inf'"))
  else:
    err(NdlError(
      kind: NdlErrorKind.lexError,
      lexMsg: "unexpected character: " & $curr,
      lexLine: startLine, lexCol: startCol))

proc peek*(lex: var NdlLexer): Result[NdlToken, NdlError] =
  if lex.peeked.isSome():
    return ok(lex.peeked.get)
  let token = lex.scanNdlToken()
  if token.isOk():
    lex.peeked = some(token.get())
  return token

proc next*(lex: var NdlLexer): Result[NdlToken, NdlError] =
  if lex.peeked.isSome():
    let token = ok(lex.peeked.get())
    lex.peeked = none(NdlToken)
    return token
  return lex.scanNdlToken()

proc lexAll*(input: string): Result[seq[NdlToken], NdlError] =
  var
    lex = initNdlLexer(input)
    tokens: seq[NdlToken] = newSeq[NdlToken]()
  while true:
    let nxtToken = ?lex.next()
    tokens.add(nxtToken)
    if nxtToken.kind == NdlTokenKind.tkEof:
      break
  ok(tokens)

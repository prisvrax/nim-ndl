import std/[strutils, options]
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
  while not lex.atEnd and lex.input[lex.pos] in {' ', '\t', '\r', '\n'}:
    skip = true
    lex.advance()
  return skip

proc scanIdent(lex: var NdlLexer, hadSpace: bool): NdlToken =
  let
    start = lex.pos
    startLine = lex.line
    startCol = lex.col
  lex.advance()
  while not lex.atEnd and lex.input[lex.pos] in {'a'..'z', 'A'..'Z', '0'..'9', '_', '-'}:
    lex.advance()
  let text = lex.input[start ..< lex.pos]
  return NdlToken(kind: tkIdent, line: startLine, col: startCol, text: text, leadingSpace: hadSpace)

proc scanNdlToken(lex: var NdlLexer): Result[NdlToken, NdlError] =
  let hadSpace = lex.skipWhitespace()
  if lex.atEnd:
    return ok(
      NdlToken(kind: NdlTokenKind.tkEof, line: lex.line, col: lex.col, leadingSpace: hadSpace))

  let
    startLine = lex.line
    startCol = lex.col
    curr = lex.input[lex.pos]

  case curr
  of '{':
    lex.advance()
    ok(NdlToken(kind: tkLBrace, line: startLine, col: startCol, leadingSpace: hadSpace))
  of '}':
    lex.advance()
    ok(NdlToken(kind: tkRBrace, line: startLine, col: startCol, leadingSpace: hadSpace))
  of '[':
    lex.advance()
    ok(NdlToken(kind: tkLBracket, line: startLine, col: startCol, leadingSpace: hadSpace))
  of ']':
    lex.advance()
    ok(NdlToken(kind: tkRBracket, line: startLine, col: startCol, leadingSpace: hadSpace))
  of '.':
    lex.advance()
    ok(NdlToken(kind: tkDot, line: startLine, col: startCol, leadingSpace: hadSpace))
  of 'a'..'z', 'A'..'Z', '_':
    ok(lex.scanIdent(hadSpace))
  else:
    err(NdlError(
      kind: lexError, lexMsg: "unexpected character: " & $curr,
      lexLine: startLine, lexCol: startCol))

proc peek*(lex: var NdlLexer): Result[NdlToken, NdlError] =
  if lex.peeked.isSome:
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
    if nxtToken.kind == tkEof:
      break
  ok(tokens)

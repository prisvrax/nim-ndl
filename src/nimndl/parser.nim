import std/[options, strutils, tables, unicode]
import pkg/[results]
import ./[token, value, error, lexer, number]

const ReservedKeywords* = ["null", "true", "false", "inf", "nan"]

type NdlParser* = object
  lexer: NdlLexer
  current: NdlToken

proc advance*(prs: var NdlParser): Result[void, NdlError] =
  prs.current = ?prs.lexer.next()
  ok()

proc peekNext*(prs: NdlParser): Result[NdlToken, NdlError] =
  var lex = prs.lexer
  lex.next()

proc initParser*(input: string): Result[NdlParser, NdlError] =
  var lex = initNdlLexer(input)
  let ndlToken = lex.next()
  ok(NdlParser(lexer: lex, current: ?ndlToken))

proc parseErrorAt(prs: NdlParser, msg: string): NdlError =
  NdlError(
    kind: parseError, parseMsg: msg, parseLine: prs.current.line, parseCol: prs.current.col)

proc parseValue(prs: var NdlParser): Result[NdlValue, NdlError]
proc parsePrimitive(prs: var NdlParser): Result[NdlValue, NdlError]
proc parseArray(prs: var NdlParser): Result[NdlValue, NdlError]
proc parseMap(prs: var NdlParser): Result[NdlValue, NdlError]

proc parseValue(prs: var NdlParser): Result[NdlValue, NdlError] =
  case prs.current.kind
  of NdlTokenKind.tkLBracket:
    parseArray(prs)
  of NdlTokenKind.tkLBrace:
    parseMap(prs)
  of NdlTokenKind.tkString, NdlTokenKind.tkRawString,
     NdlTokenKind.tkInt, NdlTokenKind.tkReal,
     NdlTokenKind.tkIdent:
    parsePrimitive(prs)
  of NdlTokenKind.tkQuotedKey:
    err(parseErrorAt(prs, "single-quoted key cannot be a value"))
  of NdlTokenKind.tkRBracket, NdlTokenKind.tkRBrace:
    err(parseErrorAt(prs, "unexpected closing bracket"))
  else:
    err(parseErrorAt(prs, "expected a value"))

proc parsePrimitive(prs: var NdlParser): Result[NdlValue, NdlError] =
  let currTok = prs.current
  case currTok.kind
  of NdlTokenKind.tkString, NdlTokenKind.tkRawString:
    ?prs.advance()
    ok(initNdlString(currTok.text))
  of NdlTokenKind.tkInt:
    let rawToken = parseNdlInt(currTok.raw)
    ?prs.advance()
    ok(NdlValue(kind: NdlValueKind.nvInt, valInt: ?rawToken))
  of NdlTokenKind.tkReal:
    let rawToken = parseNdlReal(currTok.raw)
    ?prs.advance()
    ok(NdlValue(kind: NdlValueKind.nvReal, valReal: ?rawToken))
  of NdlTokenKind.tkIdent:
    case currTok.text
    of "true":
      ?prs.advance()
      ok(initNdlBool(true))
    of "false":
      ?prs.advance()
      ok(initNdlBool(false))
    of "null":
      ?prs.advance()
      ok(initNdlNull())
    of "inf":
      ?prs.advance()
      ok(initNdlReal(Inf))
    of "nan":
      ?prs.advance()
      ok(initNdlReal(NaN))
    else:
      err(parseErrorAt(prs, "unexpected ident: " & currTok.text))
  of NdlTokenKind.tkQuotedKey:
    err(parseErrorAt(prs, "single-quoted key cannot be a value"))
  else:
    err(parseErrorAt(prs, "expected a value"))

proc parseArray(prs: var NdlParser): Result[NdlValue, NdlError] =
  ?prs.advance()

  var valArrs: seq[NdlValue] = newSeq[NdlValue]()
  if prs.current.kind == NdlTokenKind.tkRBracket:
    ?prs.advance()
    return ok(initNdlArray(valArrs))
  valArrs.add(?prs.parseValue())

  while prs.current.kind != NdlTokenKind.tkRBracket:
    if prs.current.kind == NdlTokenKind.tkEof:
      return err(parseErrorAt(prs, "unterminated array"))
    if not prs.current.leadingSpace:
      return err(parseErrorAt(prs, "expected separator between array elements"))
    valArrs.add(?prs.parseValue())
  ?prs.advance()
  ok(initNdlArray(valArrs))

proc parseMap(prs: var NdlParser): Result[NdlValue, NdlError] =
  err(parseErrorAt(prs, "map not implemented yet"))

proc parseDocument*(input: string): Result[NdlValue, NdlError] =
  var psr = ?initParser(input)
  if psr.current.kind == NdlTokenKind.tkEof:
    return ok(initNdlMap())
  case psr.current.kind
  of NdlTokenKind.tkLBracket:
    let val = ?parseArray(psr)
    if psr.current.kind != NdlTokenKind.tkEof:
      return err(parseErrorAt(psr, "unexpected token after document"))
    return ok(val)
  of NdlTokenKind.tkLBrace:
    return err(parseErrorAt(psr, "root map must omit '{}' braces"))
  of NdlTokenKind.tkString, NdlTokenKind.tkRawString, NdlTokenKind.tkInt, NdlTokenKind.tkReal:
    return parsePrimitive(psr)
  of NdlTokenKind.tkIdent:
    if psr.current.text in ReservedKeywords:
      return parsePrimitive(psr)
    else:
      discard
  of NdlTokenKind.tkQuotedKey:
    discard
  else:
    return err(parseErrorAt(psr, "unexpected token at document root"))

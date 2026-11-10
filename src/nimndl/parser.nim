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

proc parsePrimitive(prs: var NdlParser): Result[NdlValue, NdlError] =
  let currTok = prs.current
  case currTok.kind
  of NdlTokenKind.tkString, NdlTokenKind.tkRawString:
    discard prs.advance()
    ok(initNdlString(currTok.text))
  of NdlTokenKind.tkInt:
    let rawToken = parseNdlInt(currTok.raw)
    discard prs.advance()
    ok(NdlValue(kind: NdlValueKind.nvInt, valInt: ?rawToken))
  of NdlTokenKind.tkReal:
    let rawToken = parseNdlReal(currTok.raw)
    discard prs.advance()
    ok(NdlValue(kind: NdlValueKind.nvReal, valReal: ?rawToken))
  of NdlTokenKind.tkIdent:
    case currTok.text
    of "true":
      discard prs.advance()
      ok(initNdlBool(true))
    of "false":
      discard prs.advance()
      ok(initNdlBool(false))
    of "null":
      discard prs.advance()
      ok(initNdlNull())
    of "inf":
      discard prs.advance()
      ok(initNdlReal(Inf))
    of "nan":
      discard prs.advance()
      ok(initNdlReal(NaN))
    else:
      err(parseErrorAt(prs, "unexpected ident: " & currTok.text))
  of NdlTokenKind.tkQuotedKey:
    err(parseErrorAt(prs, "single-quoted key cannot be a value"))
  else:
    err(parseErrorAt(prs, "expected a value"))

proc parseDocument*(input: string): Result[NdlValue, NdlError] =
  var psr = ?initParser(input)
  if psr.current.kind == NdlTokenKind.tkEof:
    return ok(initNdlMap())
  case psr.current.kind
  of NdlTokenKind.tkLBracket:
    discard
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

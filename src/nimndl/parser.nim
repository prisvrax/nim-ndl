import std/[options, strutils, tables, unicode]
import pkg/[results]
import ./[token, value, error, lexer, number]

const reservedKeywords* = ["null", "true", "false", "inf", "nan"]

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

proc parseKey(prs: var NdlParser): Result[string, NdlError] =
  case prs.current.kind
  of NdlTokenKind.tkIdent:
    if prs.current.text in reservedKeywords:
      return err(parseErrorAt(prs, "reserved keyword cannot be unquoted key: " & prs.current.text))
    let curr = prs.current.text
    ?prs.advance()
    ok(curr)
  of NdlTokenKind.tkQuotedKey:
    let curr = prs.current.text
    ?prs.advance()
    ok(curr)
  else:
    err(parseErrorAt(prs, "expected key"))

proc parseKeyPath(prs: var NdlParser): Result[seq[string], NdlError] =
  var mapKs: seq[string] = newSeq[string]()
  mapKs.add(?prs.parseKey())
  while prs.current.kind == NdlTokenKind.tkDot:
    if prs.current.leadingSpace:
      return err(parseErrorAt(prs, "whitespace before '.'"))
    ?prs.advance()
    if prs.current.leadingSpace:
      return err(parseErrorAt(prs, "whitespace after '.'"))
    mapKs.add(?prs.parseKey())
  ok(mapKs)

proc parsePair(prs: var NdlParser): Result[NdlValue, NdlError] =
  let mapKs = ?prs.parseKeyPath()
  if prs.current.kind in {NdlTokenKind.tkEof, NdlTokenKind.tkRBrace, NdlTokenKind.tkRBracket}:
    return err(parseErrorAt(prs, "expected value after key"))
  if not prs.current.leadingSpace:
    return err(parseErrorAt(prs, "expected separator between key and value"))

  # a.b.c d  ->  {a: {b: {c: d}}}
  var mapVs = ?prs.parseValue()
  for i in countdown(mapKs.len() - 1, 0):
    var currMap = initOrderedTable[string, NdlValue]()
    currMap[mapKs[i]] = mapVs
    mapVs = NdlValue(kind: NdlValueKind.nvMap, valMap: currMap)
  ok(mapVs)

proc mergeMaps(dst: var NdlValue, src: NdlValue): Result[void, NdlError] =
  if dst.kind != NdlValueKind.nvMap or src.kind != NdlValueKind.nvMap:
    return err(NdlError(
      kind: NdlErrorKind.parseError,
      parseMsg: "expected map",
      parseLine: 0, parseCol: 0))
  for srcK, srcV in src.valMap:
    if srcK notin dst.valMap:
      dst.valMap[srcK] = srcV
    elif dst.valMap[srcK].kind == NdlValueKind.nvMap and srcV.kind == NdlValueKind.nvMap:
      ?mergeMaps(dst.valMap[srcK], srcV)
    else:
      return err(NdlError(
        kind: NdlErrorKind.parseError,
        parseMsg: "conflicting values for key '" & srcK & "'",
        parseLine: 0, parseCol: 0))
  return ok()

proc parseMap(prs: var NdlParser): Result[NdlValue, NdlError] =
  # '{'
  ?prs.advance()
  var map = initNdlMap()
  if prs.current.kind == NdlTokenKind.tkRBrace:
    ?prs.advance()
    return ok(map)

  ?mergeMaps(map, ?prs.parsePair())

  while prs.current.kind != NdlTokenKind.tkRBrace:
    if prs.current.kind == NdlTokenKind.tkEof:
      return err(parseErrorAt(prs, "unterminated map"))
    if not prs.current.leadingSpace:
      return err(parseErrorAt(prs, "expected separator between pairs"))
    ?mergeMaps(map, ?prs.parsePair())

  # '}'
  ?prs.advance()
  return ok(map)

proc parseRootPairs(prs: var NdlParser): Result[NdlValue, NdlError] =
  var m = initNdlMap()
  ?mergeMaps(m, ?prs.parsePair())
  while prs.current.kind != NdlTokenKind.tkEof:
    if not prs.current.leadingSpace:
      return err(parseErrorAt(prs, "expected separator between pairs"))
    ?mergeMaps(m, ?prs.parsePair())
  return ok(m)

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
    let val = ?parsePrimitive(psr)
    if psr.current.kind != NdlTokenKind.tkEof:
      return err(parseErrorAt(psr, "unexpected token after document"))
    return ok(val)
  of NdlTokenKind.tkIdent:
    if psr.current.text in reservedKeywords:
      let val = ?parsePrimitive(psr)
      if psr.current.kind != NdlTokenKind.tkEof:
        return err(parseErrorAt(psr, "unexpected token after document"))
      return ok(val)
    else:
      return parseRootPairs(psr)
  of NdlTokenKind.tkQuotedKey:
    return parseRootPairs(psr)
  else:
    return err(parseErrorAt(psr, "unexpected token at document root"))

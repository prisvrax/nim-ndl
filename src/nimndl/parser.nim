import std/[tables]
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
proc parseMap(prs: var NdlParser, dst: var NdlValue): Result[void, NdlError]

proc parseValue(prs: var NdlParser): Result[NdlValue, NdlError] =
  case prs.current.kind
  of NdlTokenKind.tkLBracket:
    parseArray(prs)
  of NdlTokenKind.tkLBrace:
    var ndlMap = initNdlMap()
    ?prs.parseMap(ndlMap)
    ok(ndlMap)
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

proc insertKey(
  dst: var NdlValue, mapK: string, mapV: NdlValue,
  lineAt: int, colAt: int): Result[void, NdlError] =
  if mapK notin dst.valMap:
    dst.valMap[mapK] = mapV
  elif dst.valMap[mapK].kind == NdlValueKind.nvMap and mapV.kind == NdlValueKind.nvMap:
    for srcK, srcV in mapV.valMap:
      ?insertKey(dst.valMap[mapK], srcK, srcV, lineAt, colAt)
  else:
    return err(NdlError(
      kind: NdlErrorKind.parseError,
      parseMsg: "conflicting values for key '" & mapK & "'",
      parseLine: lineAt, parseCol: colAt))
  ok()

proc insertPath(
  dst: var NdlValue, mapKs: seq[string], mapV: NdlValue, idx: int,
  lineAt: int, colAt: int): Result[void, NdlError] =
  if idx == mapKs.len() - 1:
    return insertKey(dst, mapKs[idx], mapV, lineAt, colAt)
  let currK = mapKs[idx]
  if currK notin dst.valMap:
    dst.valMap[currK] = initNdlMap()
  elif dst.valMap[currK].kind != NdlValueKind.nvMap:
    return err(NdlError(
      kind: NdlErrorKind.parseError,
      parseMsg: "conflicting values for key '" & currK & "'",
      parseLine: lineAt, parseCol: colAt))
  insertPath(dst.valMap[currK], mapKs, mapV, idx + 1, lineAt, colAt)

proc insertPair(dst: var NdlValue, prs: var NdlParser): Result[void, NdlError] =
  let
    lineAt = prs.current.line
    colAt = prs.current.col
    currMapKs = ?prs.parseKeyPath()
  if prs.current.kind in {NdlTokenKind.tkEof, NdlTokenKind.tkRBrace, NdlTokenKind.tkRBracket}:
    return err(parseErrorAt(prs, "expected value after key"))
  if not prs.current.leadingSpace:
    return err(parseErrorAt(prs, "expected separator between key and value"))
  insertPath(dst, currMapKs, ?prs.parseValue(), 0, lineAt, colAt)

proc parseMap(prs: var NdlParser, dst: var NdlValue): Result[void, NdlError] =
  # '{'
  ?prs.advance()
  if prs.current.kind == NdlTokenKind.tkRBrace:
    ?prs.advance()
    return ok()
  ?insertPair(dst, prs)
  while prs.current.kind != NdlTokenKind.tkRBrace:
    if prs.current.kind == NdlTokenKind.tkEof:
      return err(parseErrorAt(prs, "unterminated map"))
    if not prs.current.leadingSpace:
      return err(parseErrorAt(prs, "expected separator between pairs"))
    ?insertPair(dst, prs)
  # '}'
  ?prs.advance()
  ok()

proc parseObject(prs: var NdlParser, dst: var NdlValue): Result[void, NdlError] =
  ?insertPair(dst, prs)
  while prs.current.kind != NdlTokenKind.tkEof:
    if not prs.current.leadingSpace:
      return err(parseErrorAt(prs, "expected separator between pairs"))
    ?insertPair(dst, prs)
  ok()

proc parseDocument*(input: string): Result[NdlValue, NdlError] =
  var psr = ?initParser(input)
  if psr.current.kind == NdlTokenKind.tkEof:
    return ok(initNdlMap())
  case psr.current.kind
  of NdlTokenKind.tkLBracket:
    let val = ?psr.parseArray()
    if psr.current.kind != NdlTokenKind.tkEof:
      return err(psr.parseErrorAt("unexpected token after document"))
    return ok(val)
  of NdlTokenKind.tkLBrace:
    return err(psr.parseErrorAt("root map must omit '{}' braces"))
  of NdlTokenKind.tkString, NdlTokenKind.tkRawString, NdlTokenKind.tkInt, NdlTokenKind.tkReal:
    let val = ?psr.parsePrimitive()
    if psr.current.kind != NdlTokenKind.tkEof:
      return err(psr.parseErrorAt("unexpected token after document"))
    return ok(val)
  of NdlTokenKind.tkIdent:
    if psr.current.text in reservedKeywords:
      let val = ?psr.parsePrimitive()
      if psr.current.kind != NdlTokenKind.tkEof:
        return err(psr.parseErrorAt("unexpected token after document"))
      return ok(val)
    else:
      var rootObj = initNdlMap()
      ?psr.parseObject(rootObj)
      return ok(rootObj)
  of NdlTokenKind.tkQuotedKey:
    var rootObj = initNdlMap()
    ?psr.parseObject(rootObj)
    return ok(rootObj)
  else:
    return err(psr.parseErrorAt("unexpected token at document root"))

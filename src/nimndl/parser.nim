import std/[options, strutils, tables, unicode]
import pkg/[results]
import ./[token, value, error, lexer, number]

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

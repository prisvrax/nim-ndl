type NdlTokenKind* = enum
  tkEof,
  tkLBrace, tkRBrace,
  tkLBracket, tkRBracket,
  tkDot,
  tkString,
  tkRawString,
  tkQuotedKey,
  tkIdent,
  tkInt, tkReal

type NdlToken* = object
  line*: int
  col*: int
  leadingSpace*: bool
  case kind*: NdlTokenKind
  of tkString, tkRawString, tkQuotedKey, tkIdent:
    text*: string
  of tkInt, tkReal:
    raw*: string
  of tkEof, tkLBrace, tkRBrace, tkLBracket, tkRBracket, tkDot:
    discard

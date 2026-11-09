type NdlErrorKind* = enum
  parseIntError,
  parseRealError,
  lexError,
  parseError

type NdlError* = object
  case kind*: NdlErrorKind
  of NdlErrorKind.parseIntError, NdlErrorKind.parseRealError:
    numRaw*: string
  of NdlErrorKind.lexError:
    lexMsg*: string
    lexLine*: int
    lexCol*: int
  of NdlErrorKind.parseError:
    parseMsg*: string
    parseLine*: int
    parseCol*: int

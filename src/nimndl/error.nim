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

func `$`*(e: NdlError): string =
  case e.kind
  of NdlErrorKind.parseIntError:
    "parseIntError: " & e.numRaw
  of NdlErrorKind.parseRealError:
    "parseRealError: " & e.numRaw
  of NdlErrorKind.lexError:
    "lexError at " & $e.lexLine & ":" & $e.lexCol & ": " & e.lexMsg
  of NdlErrorKind.parseError:
    "parseError at " & $e.parseLine & ":" & $e.parseCol & ": " & e.parseMsg

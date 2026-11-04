type NdlErrorKind* = enum
  parseIntError,
  parseRealError,

type NdlError* = object
  case kind*: NdlErrorKind
  of NdlErrorKind.parseIntError, NdlErrorKind.parseRealError:
    numRaw*: string

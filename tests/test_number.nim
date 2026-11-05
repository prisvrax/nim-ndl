import std/[math, strutils, unittest]
import pkg/[results]
import nimndl
import nimndl/[number]

suite "NdlInt parse":
  test "binary positive":
    check parseNdlInt("0b0").value().valPos == 0'u64
    check parseNdlInt("0b1").value().valPos == 1'u64
    check parseNdlInt("0b10110").value().valPos == 22'u64
    check parseNdlInt("0b" & "1".repeat(64)).value().valPos == high(uint64)
    check parseNdlInt("0b1" & "0".repeat(64)).value().kind == NdlIntKind.nikRaw
    check parseNdlInt("0b1" & "0".repeat(63) & "1").value().kind == NdlIntKind.nikRaw

  test "binary negative":
    check parseNdlInt("-0b0").value().kind == NdlIntKind.nikNeg
    check parseNdlInt("-0b0").value().valNeg == 0'i64
    check parseNdlInt("-0b1").value().valNeg == -1'i64
    check parseNdlInt("-0b10110").value().valNeg == -22'i64
    check parseNdlInt("-0b" & "1".repeat(63)).value().valNeg == low(int64) + 1
    check parseNdlInt("-0b1" & "0".repeat(63)).value().valNeg == low(int64)
    check parseNdlInt("-0b" & "1".repeat(64)).value().kind == NdlIntKind.nikRaw
    check parseNdlInt("-0b1" & "0".repeat(64)).value().kind == NdlIntKind.nikRaw

  test "binary leading-zeros":
    check parseNdlInt("0b00000000").value().valPos == 0'u64
    check parseNdlInt("-0b00000000").value().valNeg == 0'i64
    check parseNdlInt("0b00000001").value().valPos == 1'u64
    check parseNdlInt("-0b00000001").value().valNeg == -1'i64
    check parseNdlInt("0b" & "0".repeat(64)).value().valPos == 0'u64
    check parseNdlInt("-0b" & "0".repeat(64)).value().valNeg == 0'i64
    check parseNdlInt("0b" & "0".repeat(64) & "1".repeat(64)).value().valPos == high(uint64)
    check parseNdlInt("-0b" & "0".repeat(64) & "1" & "0".repeat(63)).value().valNeg == low(int64)
    check parseNdlInt("0b" & "0".repeat(65)).value().valPos == 0'u64

  test "binary invalid":
    check parseNdlInt("0b").isErr()
    check parseNdlInt("-0b").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("0b123").isErr()
    check parseNdlInt("0b123").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("0b00123").error().kind == NdlErrorKind.parseIntError

  test "hexadecimal positive":
    check parseNdlInt("0x0").value().valPos == 0'u64
    check parseNdlInt("0x1").value().valPos == 1'u64
    check parseNdlInt("0x16").value().valPos == 22'u64
    check parseNdlInt("0xff").value().valPos == 255'u64
    check parseNdlInt("0x" & "f".repeat(16)).value().valPos == high(uint64)
    check parseNdlInt("0x1" & "0".repeat(16)).value().kind == NdlIntKind.nikRaw
    check parseNdlInt("0x1" & "0".repeat(15) & "1").value().kind == NdlIntKind.nikRaw

  test "hexadecimal negative":
    check parseNdlInt("-0x0").value().kind == NdlIntKind.nikNeg
    check parseNdlInt("-0x0").value().valNeg == 0'i64
    check parseNdlInt("-0x1").value().valNeg == -1'i64
    check parseNdlInt("-0x16").value().valNeg == -22'i64
    check parseNdlInt("-0x7" & "f".repeat(15)).value().valNeg == low(int64) + 1
    check parseNdlInt("-0x8" & "0".repeat(15)).value().valNeg == low(int64)
    check parseNdlInt("-0x8" & "0".repeat(15) & "1").value().kind == NdlIntKind.nikRaw
    check parseNdlInt("-0x" & "f".repeat(16)).value().kind == NdlIntKind.nikRaw
    check parseNdlInt("-0x1" & "0".repeat(16)).value().kind == NdlIntKind.nikRaw

  test "hexadecimal leading-zeros":
    check parseNdlInt("0x00000000").value().valPos == 0'u64
    check parseNdlInt("-0x00000000").value().valNeg == 0'i64
    check parseNdlInt("0x00000001").value().valPos == 1'u64
    check parseNdlInt("-0x00000001").value().valNeg == -1'i64
    check parseNdlInt("0x" & "0".repeat(16)).value().valPos == 0'u64
    check parseNdlInt("-0x" & "0".repeat(16)).value().valNeg == 0'i64
    check parseNdlInt("0x" & "0".repeat(20)).value().valPos == 0'u64
    check parseNdlInt("0x" & "0".repeat(16) & "F".repeat(16)).value().valPos == high(uint64)
    check parseNdlInt("-0x" & "0".repeat(16) & "8" & "0".repeat(15)).value().valNeg == low(int64)

  test "hexadecimal invalid":
    check parseNdlInt("0x").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("-0x").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("0xgg").isErr()
    check parseNdlInt("0xgg").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("0x123g").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("0x00123g").error().kind == NdlErrorKind.parseIntError

  test "decimal positive":
    check parseNdlInt("0").value().kind == NdlIntKind.nikPos
    check parseNdlInt("0").value().valPos == 0'u64
    check parseNdlInt("1").value().valPos == 1'u64
    check parseNdlInt("22").value().valPos == 22'u64
    check parseNdlInt("9223372036854775807").value().valPos == uint64(high(int64))
    check parseNdlInt("18446744073709551614").value().valPos == high(uint64) - 1
    check parseNdlInt("18446744073709551615").value().valPos == high(uint64)
    check parseNdlInt("18446744073709551616").value().kind == NdlIntKind.nikRaw

  test "decimal negative":
    check parseNdlInt("-0").value().kind == NdlIntKind.nikNeg
    check parseNdlInt("-0").value().valNeg == 0'i64
    check parseNdlInt("-1").value().valNeg == -1'i64
    check parseNdlInt("-22").value().valNeg == -22'i64
    check parseNdlInt("-9223372036854775807").value().valNeg == low(int64) + 1
    check parseNdlInt("-9223372036854775808").value().valNeg == low(int64)
    check parseNdlInt("-9223372036854775809").value().kind == NdlIntKind.nikRaw
    check parseNdlInt("-18446744073709551615").value().kind == NdlIntKind.nikRaw
    check parseNdlInt("-18446744073709551616").value().kind == NdlIntKind.nikRaw

  test "decimal leading-zeros":
    check parseNdlInt("0").value().valPos == 0'u64
    check parseNdlInt("-0").value().valNeg == 0'i64
    check parseNdlInt("00").isErr()
    check parseNdlInt("01").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("007").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("-00").isErr()
    check parseNdlInt("-01").error().kind == NdlErrorKind.parseIntError
    check parseNdlInt("-007").isErr()

  test "decimal invalid":
    check parseNdlInt("").isErr()
    check parseNdlInt("-").isErr()
    check parseNdlInt("abc").isErr()
    check parseNdlInt("1a").isErr()
    check parseNdlInt("12a3").isErr()
    check parseNdlInt("-1a").isErr()

suite "NdlReal parse":
  test "real f64":
    check parseNdlReal("0").isErr()
    check parseNdlReal("0.0").value().kind == NdlRealKind.nrkF64
    check parseNdlReal("0e999").value().kind == NdlRealKind.nrkF64
    check parseNdlReal("0.0e-999").value().kind == NdlRealKind.nrkF64
    check parseNdlReal("-0.0").value().kind == NdlRealKind.nrkF64
    check parseNdlReal("-0.0").value().valFloat == 0.0
    check parseNdlReal("-0.0").value().valFloat.classify() == FloatClass.fcNegZero

  test "real underflow":
    check parseNdlReal("1e-999").value().kind == nrkRaw
    check parseNdlReal("1e-999").value().valRaw == "1e-999"
    check parseNdlReal("-1e-999").value().kind == nrkRaw
    check parseNdlReal("0.1e-400").value().kind == nrkRaw

  test "real overflow":
    check parseNdlReal("1e999").value().kind == nrkRaw
    check parseNdlReal("-1e999").value().kind == nrkRaw

  test "real subnormal":
    check parseNdlReal("4.9e-324").value().kind == nrkF64
    check parseNdlReal("4.9e-324").value().valFloat > 0.0
    check parseNdlReal("4.9e-324").value().valFloat.classify() == FloatClass.fcSubnormal
  
  test "real invalid":
    check parseNdlReal(".").isErr()
    check parseNdlReal(".0").isErr()
    check parseNdlReal("1.").isErr()
    check parseNdlReal("10.").isErr()
    check parseNdlReal("10.1a").isErr()
    check parseNdlReal("12a.3").isErr()
    check parseNdlReal("-1.a").isErr()

  test "real leading-zeros":
    check parseNdlReal("0.00").value().valFloat == 0.0'f64
    check parseNdlReal("00.1").isErr()
    check parseNdlReal("001.2").isErr()
    check parseNdlReal("-0.00").value().valFloat == -0.0'f64
    check parseNdlReal("-00.1").isErr()
    check parseNdlReal("-001.2").isErr()
    check parseNdlReal("1.2e0").value().valFloat == 1.2'f64
    check parseNdlReal("1.2e-0").value().valFloat == 1.2'f64
    check parseNdlReal("1.2e-01").isErr()

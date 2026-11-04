import std/[tables, unittest]
import nimndl

suite "NdlValue construction":
  test "null":
    check initNdlNull().kind == NdlValueKind.nvNull

  test "bool":
    check initNdlBool(true).valBool == true
    check initNdlBool(false).valBool == false

  test "int via i64 to u64":
    let val = initNdlInt(42'i64)
    check val.kind == NdlValueKind.nvInt
    check val.valInt.kind == NdlIntKind.nikPos
    check val.valInt.valPos == 42'u64

  test "int via i64 to i64":
    let val = initNdlInt(-42'i64)
    check val.valInt.kind == NdlIntKind.nikNeg
    check val.valInt.valNeg == -42'i64

  test "int via u64":
    let val = initNdlInt(high(uint64))
    check val.valInt.kind == NdlIntKind.nikPos
    check val.valInt.valPos == high(uint64)

  test "int raw":
    let val = initNdlBigInt("123456789012345678901234567890")
    check val.valInt.kind == NdlIntKind.nikRaw
    check val.valInt.valRaw == "123456789012345678901234567890"

  test "real f64":
    let val = initNdlReal(3.14)
    check val.valReal.kind == NdlRealKind.nrkF64
    check val.valReal.valFloat == 3.14

  test "real raw":
    let val = initNdlBigReal("1e9")
    check val.valReal.kind == NdlRealKind.nrkRaw
    check val.valReal.valRaw == "1e9"

  test "string":
    check initNdlString("hello").valStr == "hello"

suite "NdlValue container access":
  test "empty map":
    let tbl = initNdlMap()
    check tbl.kind == NdlValueKind.nvMap
    check tbl.valMap.len == 0

  test "map literal":
    let tbl = initNdlMap([("a", initNdlInt(1'i64)), ("b", initNdlInt(2'i64))])
    check tbl["a"].valInt.valPos == 1'u64
    check tbl["b"].valInt.valPos == 2'u64


  test "map order":
    var tbl = initNdlMap()
    tbl["z"] = initNdlInt(1'i64)
    tbl["a"] = initNdlInt(2'i64)
    tbl["m"] = initNdlInt(3'i64)
    var tblKeys: seq[string]
    for mapK in tbl.valMap.keys():
      tblKeys.add(mapK)
    check tblKeys == @["z", "a", "m"]

  test "array":
    let arr = initNdlArray([initNdlInt(1'i64), initNdlInt(2'i64), initNdlInt(3'i64)])
    check arr.valArr.len == 3
    check arr[0].valInt.valPos == 1'u64
    check arr[2].valInt.valPos == 3'u64

  test "nested":
    let tbl = initNdlMap([
      ("scene", initNdlMap([
        ("size", initNdlMap([("x", initNdlInt(1920'i64)), ("y", initNdlInt(1080'i64))])),
      ])),
    ])
    check tbl["scene"]["size"]["x"].valInt.valPos == 1920'u64
    check tbl["scene"]["size"]["y"].valInt.valPos == 1080'u64

import std/[math, strutils, tables, unittest]
import results
import nimndl

suite "document parser":
  test "empty document":
    let emptyDoc = parseDocument("")
    check emptyDoc.isOk()
    check emptyDoc.value().kind == NdlValueKind.nvMap
    check emptyDoc.value().valMap.len() == 0

  test "whitespace":
    check parseDocument("   \n\t  ").value().kind == NdlValueKind.nvMap

  test "root curly brackets":
    check parseDocument("{}").isErr()
    check parseDocument("{a 1}").isErr()
    check parseDocument("{}").tryError().parseMsg.contains("omit")

  test "root primitive":
    check parseDocument("42").value().valInt.valPos == 42'u64
    check parseDocument("-42").value().valInt.valNeg == -42'i64
    check parseDocument("3.14").value().valReal.valFloat == 3.14
    check parseDocument("\"hello\"").value().valStr == "hello"
    check parseDocument("`raw`").value().valStr == "raw"
    check parseDocument("true").value().valBool == true
    check parseDocument("false").value().valBool == false
    check parseDocument("null").value().kind == NdlValueKind.nvNull
    check parseDocument("inf").value().valReal.valFloat == Inf
    check parseDocument("nan").value().valReal.valFloat.classify() == FloatClass.fcNan

suite "array parser":
  test "empty array":
    let emptyArr = parseDocument("[]").value()
    check emptyArr.kind == nvArray
    check emptyArr.valArr.len() == 0

  test "single element":
    let singleElemArr = parseDocument("[1]").value()
    check singleElemArr.kind == nvArray
    check singleElemArr.valArr.len() == 1
    check singleElemArr.valArr[0].valInt.valPos == 1'u64

  test "multiple elements":
    let multiElemArr = parseDocument("[1 2 3]").value()
    check multiElemArr.kind == nvArray
    check multiElemArr.valArr.len() == 3
    check multiElemArr.valArr[0].valInt.valPos == 1'u64
    check multiElemArr.valArr[1].valInt.valPos == 2'u64
    check multiElemArr.valArr[2].valInt.valPos == 3'u64

  test "mixed types":
    let mixedTypesArr = parseDocument("[1 \"two\" true null]").value()
    check mixedTypesArr.kind == nvArray
    check mixedTypesArr.valArr.len() == 4
    check mixedTypesArr.valArr[0].kind == nvInt
    check mixedTypesArr.valArr[1].kind == nvString
    check mixedTypesArr.valArr[2].kind == nvBool
    check mixedTypesArr.valArr[3].kind == nvNull

  test "nested array":
    let nestedArrArr = parseDocument("[[1 2] [3 4]]").value()
    check nestedArrArr.kind == nvArray
    check nestedArrArr.valArr.len() == 2
    check nestedArrArr.valArr[0].valArr.len() == 2
    check nestedArrArr.valArr[1].valArr[1].valInt.valPos == 4'u64

  test "missing separator":
    check parseDocument("[1 2]").isOk()
    check parseDocument("[1/*c*/2]").isOk()
    check parseDocument("[1 2a3]").isErr()

  test "unclosed bracket error":
    check parseDocument("[").isErr()
    check parseDocument("[1").isErr()
    check parseDocument("[1 2").isErr()

  test "array trailing token":
    check parseDocument("[1] 2").isErr()
    check parseDocument("[] []").isErr()

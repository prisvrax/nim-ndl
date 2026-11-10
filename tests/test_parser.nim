import std/[math, strutils, tables, unittest]
import results
import nimndl

suite "parseDocument skeleton":
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

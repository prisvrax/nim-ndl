import std/[math, unittest]
import pkg/[results]
import nimndl

suite "ident":
  test "基本":
    let ts = lexAll("a").get
    check ts.len == 2
    check ts[0].kind == tkIdent
    check ts[0].text == "a"
    check ts[1].kind == tkEof

  test "含连字符和数字":
    check lexAll("foo-bar").get[0].text == "foo-bar"
    check lexAll("_x").get[0].text == "_x"
    check lexAll("a1-b2").get[0].text == "a1-b2"

  test "保留字不在 lexer 区分":
    for s in ["true", "false", "null", "inf", "nan"]:
      let t = lexAll(s).get[0]
      check t.kind == tkIdent
      check t.text == s

  test "leadingSpace":
    let ts = lexAll("a b").get
    check ts[0].leadingSpace == false
    check ts[1].leadingSpace == true
    check ts[1].text == "b"

  test "ident 和括号相邻":
    let ts = lexAll("a{}").get
    check ts[0].kind == tkIdent
    check ts[1].kind == tkLBrace
    check ts[1].leadingSpace == false

  test "非法首字符仍报错":
    check lexAll("$").isErr
    check lexAll("@a").error.kind == lexError

suite "quoted":
  test "raw string":
    check lexAll("`hello`").get[0].text == "hello"
    check lexAll("`a\nb`").get[0].text == "a\nb"
    check lexAll("`it's \"fine\"`").get[0].text == "it's \"fine\""
    check lexAll("``").get[0].text == ""
    check lexAll("`unterminated").isErr
  
  test "string":
    check lexAll("\"hello\"").get[0].text == "hello"
    check lexAll("\"line\\nbreak\"").get[0].text == "line\nbreak"
    check lexAll("\"it's\"").get[0].text == "it's"
    check lexAll("\"say \\\"hi\\\"\"").get[0].text == "say \"hi\""
    check lexAll("\"\\u{4F60}\\u{597D}\"").get[0].text == "你好"
    check lexAll("\"\"").get[0].text == ""
    check lexAll("\"unterminated").isErr()
    check lexAll("\"bad \\x\"").isErr()
    check lexAll("\"\\u{110000}\"").isErr()
    check lexAll("\"\\u{D800}\"").isErr()
    check lexAll("\"\\u{}\"").isErr()
    check lexAll("\"\\u{1234567}\"").isErr()

  test "quoted key":
    check lexAll("'weird key'").get[0].text == "weird key"
    check lexAll("'it\\'s'").get[0].text == "it's"
    check lexAll("'k.1'").get[0].text == "k.1"
    check lexAll("'can\\\"quote'").get[0].text == "can\"quote"

suite "number":
  test "int":
    let
      num1 = lexAll("123").value()[0]
      num2 = lexAll("-123").value()[0]
      num3 = lexAll("0").value()[0]
      num4 = lexAll("-0").value()[0]
      num5 = lexAll("inf").value()[0]
      num6 = lexAll("-inf").value()[0]
    check num1.kind == NdlTokenKind.tkInt
    check num1.raw == "123"
    check num2.kind == NdlTokenKind.tkInt
    check num2.raw == "-123"
    check num3.kind == NdlTokenKind.tkInt
    check num3.raw == "0"
    check num4.kind == NdlTokenKind.tkInt
    check num4.raw == "-0"
    check lexAll("000").isErr()
    check lexAll("001").isErr()
    check lexAll("-000").isErr()
    check lexAll("-001").isErr()
    check num5.kind == NdlTokenKind.tkIdent
    check num5.text == "inf"
    check num6.kind == NdlTokenKind.tkIdent
    check num6.text == "-inf"

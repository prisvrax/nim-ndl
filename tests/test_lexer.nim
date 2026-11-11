import std/[math, strutils, unittest]
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
    check lexAll("@a").error().kind == lexError

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

  test "real":
    let
      num1 = lexAll("123.456").value()[0]
      num2 = lexAll("-123.456").value()[0]
      num3 = lexAll("0.0").value()[0]
      num4 = lexAll("-0.0").value()[0]
    check num1.kind == NdlTokenKind.tkReal
    check num1.raw == "123.456"
    check num2.kind == NdlTokenKind.tkReal
    check num2.raw == "-123.456"
    check num3.kind == NdlTokenKind.tkReal
    check num3.raw == "0.0"
    check num4.kind == NdlTokenKind.tkReal
    check num4.raw == "-0.0"
    check lexAll("00.0").isErr()
    check lexAll("00.1").isErr()
    check lexAll("-00.0").isErr()
    check lexAll("-00.1").isErr()
    check lexAll("0.").isErr()
    check lexAll("-0.").isErr()
    check lexAll("-.1").isErr()
    let numDot1 = lexAll(".1").value()
    check numDot1.len() == 3
    check numDot1[0].kind == NdlTokenKind.tkDot
    check numDot1[1].kind == NdlTokenKind.tkInt
    check numDot1[1].raw == "1"

    let
      num5 = lexAll("0e123").value()[0]
      num6 = lexAll("-0e123").value()[0]
      num7 = lexAll("12.3e456").value()[0]
      num8 = lexAll("-123e456").value()[0]
      num9 = lexAll("0e0").value()[0]
      num10 = lexAll("-0e0").value()[0]
      num11 = lexAll("-11e-0").value()[0]

    check num5.kind == NdlTokenKind.tkReal
    check num5.raw == "0e123"
    check num6.kind == NdlTokenKind.tkReal
    check num6.raw == "-0e123"
    check num7.kind == NdlTokenKind.tkReal
    check num7.raw == "12.3e456"
    check num8.kind == NdlTokenKind.tkReal
    check num8.raw == "-123e456"
    check lexAll("0123e-456").isErr()
    check lexAll("-00e-456").isErr()
    check num9.kind == NdlTokenKind.tkReal
    check num9.raw == "0e0"
    check num10.kind == NdlTokenKind.tkReal
    check num10.raw == "-0e0"
    check num11.kind == NdlTokenKind.tkReal
    check num11.raw == "-11e-0"
    check lexAll("13e+1").isErr()
    check lexAll("15e").isErr()
    check lexAll("-e16").isErr()

    let
      numDot2 = lexAll("17e1.7").value()
      numDot3 = lexAll("-1.8e1.8").value()
    check numDot2.len() == 4
    check numDot2[0].kind == NdlTokenKind.tkReal
    check numDot2[0].raw == "17e1"
    check numDot2[1].kind == NdlTokenKind.tkDot
    check numDot3.len() == 4
    check numDot3[0].raw == "-1.8e1"
    check numDot3[2].kind == NdlTokenKind.tkInt

suite "comment":
  test "line comment":
    check lexAll("/").isErr()
    let tArrs = lexAll("a // comment\nb").value()
    check tArrs[0].text == "a"
    check tArrs[1].text == "b"
    check tArrs[1].leadingSpace == true
    check tArrs[1].line == 2

  test "line comment EOF":
    check lexAll("a // comment").value[1].kind == NdlTokenKind.tkEof

  test "block comment":
    let tArrs = lexAll("a /* c */ b").value()
    check tArrs[0].text == "a"
    check tArrs[1].text == "b"
    check tArrs[1].leadingSpace == true

  test "nested block comment":
    let tArrs = lexAll("a /* x /* y */ z */ b").value()
    check tArrs[0].text == "a"
    check tArrs[1].text == "b"

  test "comment separator":
    check lexAll("a/*c*/b").value()[1].leadingSpace == true
    check lexAll("[1/*c*/2]").value()[2].leadingSpace == true

  test "unterminated block comment":
    let errCom = lexAll("/* unterminated")
    check errCom.isErr()
    check errCom.tryError().lexMsg.contains("unterminated")

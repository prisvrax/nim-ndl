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
    check lexAll("@a").error.kind == lexError

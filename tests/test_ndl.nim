import std/[math, strutils, tables, unittest]
import results
import nimndl

suite "ndl":
  test "ndl test 1":
    let ndlSrc = """scene {
  size { x 1920 y 1080 }
  camera.type "orthographic"
  layers [ {
    name "background"
    textures [ `background.png` `mask.png` ]
    scale { x 1.2 y 1.0 }
  } {
    name "foreground"
    enabled false
  } ]
}"""
    let ndlVal = parseDocument(ndlSrc).value()
    check ndlVal["scene"]["size"]["x"].valInt.valPos == 1920'u64
    check ndlVal["scene"]["size"]["y"].valInt.valPos == 1080'u64
    check ndlVal["scene"]["camera"]["type"].valStr == "orthographic"
    check ndlVal["scene"]["layers"].valArr.len() == 2
    check ndlVal["scene"]["layers"].valArr[0]["name"].valStr == "background"
    check ndlVal["scene"]["layers"].valArr[0]["textures"].valArr[0].valStr == "background.png"
    check ndlVal["scene"]["layers"].valArr[0]["scale"]["x"].valReal.valFloat == 1.2
    check ndlVal["scene"]["layers"].valArr[1]["enabled"].valBool == false

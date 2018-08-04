
import unittest
import readMetadata
import metadata
import json
import strutils
import readable

const keyName = keyNameImp

suite "Test readMetadata.nim":

  # proc keyName*(readerName: string, section: string, key: string): string =
  test "keyName invalid name":
    check(keyName("missing", "xmp", "key") == "")

  test "keyName invalid section":
    check(keyName("jpeg", "missing", "key") == "")
    check(keyName("dng", "missing", "key") == "")
    check(keyName("tiff", "missing", "key") == "")

  test "keyName invalid key":
    check(keyName("jpeg", "xmp", "missing") == "")
    check(keyName("dng", "xmp", "missing") == "")
    check(keyName("tiff", "xmp", "missing") == "")

  test "keyName xmp":
    check(keyName("jpeg", "xmp", "crs:Temperature") == "")

  test "keyName tiff 258":
    check(keyName("tiff", "ifd1", "258") == "BitsPerSample(258)")

  test "keyName jpeg":
    check(keyName("jpeg", "exif", "258") == "BitsPerSample(258)")

  test "test getMetaInfo":
    var problems = newSeq[tuple[reader: string, message: string]]()
    let info = getMetaInfo("filename", "readerName", 12345, problems)
    let str = $info
    # echo str
    # {"filename":"filename","reader":"readerName","size":12345,"version":"0.0.2","nimVersion":"0.17.2","os":"macosx","cpu":"amd64","problems":[],"readers":["jpeg","dng","tiff"]}
    check(str.contains(""""filename":"filename",""") == true)
    check(str.contains(""""reader":"readerName",""") == true)
    check(str.contains(""""size":12345,""") == true)
    check(str.contains(""""version":"""") == true)
    check(str.contains(""""problems":[],""") == true)
    check(str.contains(""""nimVersion":"""") == true)
    check(str.contains(""""os":"""") == true)
    check(str.contains(""""cpu":"""") == true)
    check(str.contains(""""readers":["""") == true)

  test "test getMetaInfo problems":
    var problems = newSeq[tuple[reader: string, message: string]]()
    problems.add(("jpeg", "problem message here"))
    problems.add(("dng", "message 2"))
    let info = getMetaInfo("filename", "readerName", 12345, problems)
    # echo pretty(info)
    let str = $info
    # echo str
# {"filename":"filename","reader":"readerName","size":12345,"version":"0.0.2","nimVersion":"0.17.2","os":"macosx","cpu":"amd64","problems":[["jpeg","problem message here"],["dng","message 2"]],"readers":["jpeg","dng","tiff"]}
    check(str.contains(""""filename":"filename",""") == true)
    check(str.contains(""""reader":"readerName",""") == true)
    check(str.contains(""""size":12345,""") == true)
    check(str.contains(""""version":"""") == true)
    check(str.contains(""""problems":[["jpeg","problem message here"],["dng","message 2"]],""") == true)
    check(str.contains(""""nimVersion":"""") == true)
    check(str.contains(""""os":"""") == true)
    check(str.contains(""""cpu":"""") == true)
    check(str.contains(""""readers":["""") == true)


  test "test getMetadata nil":
    var gotException = false
    try:
      discard getMetadata("filename")
    except UnknownFormatError:
      gotException = true
    check(gotException == true)

  test "test getMetadata":
    let filename = "testfiles/image.jpg"
    let str = getMetadata(filename).readable("jpeg")
    let expected = """
========== APP0 ==========
id = "JFIF"
major = 1
minor = 1
units = 1
x = 96
y = 96
width = 0
height = 0
"""
    check(str[0..expected.len-1] == expected)

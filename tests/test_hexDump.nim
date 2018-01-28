import unittest
import hexDump

const bytes = [0xff'u8, 0xe1, 0x0, 0x5, (uint8)'e', (uint8)'x',
        (uint8)'i', (uint8)'f', 0x0, 0x31, 1, 2, 3, 4, 5, 6, 7, 8, 9]

suite "Test hexDump.nim":

  test "test hexDump":
    var hex = hexDump(@bytes)
    # echo hex
    let expected = """
0000  FF E1 00 05 65 78 69 66 00 31 01 02 03 04 05 06  ....exif.1......
0010  07 08 09                                         ...
"""
    check(hex == expected)

  test "test hexDump 17":
    var hex = hexDump(@bytes[0..<17], 2)
    # echo hex
    let expected = """
0002  FF E1 00 05 65 78 69 66 00 31 01 02 03 04 05 06  ....exif.1......
0012  07                                               .
"""
    check(hex == expected)

  test "test hexDump 16":
    var hex = hexDump(@bytes[0..<16], 0x1234)
    # echo hex
    let expected = """
1234  FF E1 00 05 65 78 69 66 00 31 01 02 03 04 05 06  ....exif.1......
"""
    check(hex == expected)

  test "test hexDump 15":
    var hex = hexDump(@bytes[0..<15], 0x1234)
    # echo hex
    let expected = """
1234  FF E1 00 05 65 78 69 66 00 31 01 02 03 04 05     ....exif.1.....
"""
    check(hex == expected)
    
  test "test hexDump 1":
    var hex = hexDump(@bytes[0..<1], 0x1234)
    # echo hex
    let expected = """
1234  FF                                               .
"""
    check(hex == expected)
    # echo hexDump(@bytes[0..<1])

  test "test toHex00":
    check(toHex0(0) == "0")
    check(toHex0(0x10'u8) == "10")
    check(toHex0(0x12'u8) == "12")
    check(toHex0(0x1'u8) == "1")
    check(toHex0(0x1234'u16) == "1234")
    check(toHex0(0x0004'u16) == "4")
    check(toHex0(0x0104'u16) == "104")
    check(toHex0(0x12345678'u32) == "12345678")
    check(toHex0(0x00000008'u32) == "8")

  test "test hexDumpSource":
    var hex = hexDumpSource(@bytes)
    let expected = """
var buffer = [
  0xFF'u8, 0xE1, 0x00, 0x05, 0x65, 0x78, 0x69, 0x66,
  0x00, 0x31, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
  0x07, 0x08, 0x09,
]"""
    check(hex == expected)

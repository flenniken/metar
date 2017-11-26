import unittest
import hexDump

var bytes = [0xff'u8, 0xe1, 0x0, 0x5, (uint8)'e', (uint8)'x',
        (uint8)'i', (uint8)'f', 0x0, 0x31, 1, 2, 3, 4, 5, 6, 7, 8, 9]

suite "Test hexDump.nim":

  test "hex dump 1":
    var hex = hexDump(@bytes)
    echo hex
    echo hexDump(@bytes[0..<17], 2)
    echo hexDump(@bytes[0..<16], 0x1234)
    echo hexDump(@bytes[0..<15])
    echo hexDump(@bytes[0..<1])


# See: bytesToString.nim(0):

import strutils
import unittest
import metadata
import bytesToString

suite "Test bytesToString.nim":

    test "test bytesToString good":
      var buffer = [(uint8)'s', (uint8)'t', (uint8)'a', (uint8)'r',
        (uint8)'E', (uint8)'x', (uint8)'i', (uint8)'f', (uint8)'f',
        (uint8)'t', (uint8)'e', (uint8)'s', (uint8)'t']
      check(bytesToString(buffer, 0, buffer.len) == "starExifftest")
      check(bytesToString(buffer, 9, 0) == "")
      check(bytesToString(buffer, 9, 1) == "t")
      check(bytesToString(buffer, 9, 4) == "test")
      check(bytesToString(buffer, 4, 4) == "Exif")

    test "test bytesToString empty":
      var buffer = newSeq[uint8]()
      check(bytesToString(buffer, 0, 0) == "")
      check(bytesToString(buffer) == "")

    test "test bytesToString error length":
      # invalid start index
      var buffer = [0x1u8, 0x02, 0x03, 0x04]
      try:
        discard bytesToString(buffer, 0, buffer.len+1)
        fail()
      except:
        # echo repr(getCurrentException())
        # echo getCurrentException().name
        # echo getCurrentExceptionMsg()
        discard

    test "test bytesToString error index":
      # invalid start index
      var buffer = [0x1u8, 0x02, 0x03, 0x04]
      try:
        discard bytesToString(buffer, 4, 1)
        fail()
      except:
        # echo repr(getCurrentException())
        # echo getCurrentException().name
        # echo getCurrentExceptionMsg()
        discard

    test "test bytesToString error index length":
      # invalid start index
      var buffer = [0x1u8, 0x02, 0x03, 0x04]
      try:
        discard bytesToString(buffer, 3, 2)
        fail()
      except:
        # echo getCurrentExceptionMsg()
        discard

    test "test bytesToString invalid utf8":
      # invalid start index
      var buffer = [0x1u8, 0xe2, 0x03, 0x04]
      try:
        discard bytesToString(buffer, 0, 4)
        fail()
      except:
        # echo getCurrentExceptionMsg()
        discard

    test "test bytesToString embedded 0":
      # invalid start index
      var buffer = [0x1u8, 0x0, 0x03, 0x04]
      try:
        discard bytesToString(buffer, 0, 4)
        fail()
      except:
        # echo getCurrentExceptionMsg()
        discard


import std/nre
import unittest
import version

suite "Test version.nim":

    test "test version string":
      if match(metarVersion, re"^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$").isSome():
        discard
      else:
        echo "Invalid version number: " & metarVersion
        fail

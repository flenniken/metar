import unittest
import strutils
import version

proc isValidVersion(version: string): bool =
  ## Validates version string format: X.Y.Z where X, Y, Z are 1-3
  ## digit numbers.
  let parts = version.split('.')
  if parts.len != 3:
    return false
  for part in parts:
    if part.len == 0 or part.len > 3:
      return false
    for ch in part:
      if ch notin '0'..'9':
        return false
  return true

suite "Test version.nim":

    test "test version string":
      if not isValidVersion(metarVersion):
        echo "Invalid version number: " & metarVersion
        fail

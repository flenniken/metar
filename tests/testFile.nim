## Procedures to work with test files.

import os


proc createTestFile*(bytes: openArray[uint8]):
  tuple[file:File, filename:string] =
  ## Create a test file with the given bytes. Return the file and
  ## filename. Current file position is at 0. Raise an exception when
  ## the file cannot be created.

  let filename = joinPath(getTempDir(), "testfile.bin")
  var file = open(filename, fmReadWrite)
  if file.writeBytes(bytes, 0, bytes.len) != bytes.len:
    raise newException(IOError, "Unable to write all the bytes.")
  file.setFilePos(0)
  result = (file, filename)


proc createTestFile*(str: string):  tuple[file:File, filename:string] =
  ## Create a test file with the string. Return the file and
  ## filename. Current file position is at 0. Raise an exception when
  ## the file cannot be created.

  let filename = joinPath(getTempDir(), "testfile.bin")
  var file = open(filename, fmReadWrite)
  if file.writeChars(str, 0, str.len) != str.len:
    raise newException(IOError, "Unable to write the string.")
  file.setFilePos(0)
  result = (file, filename)


proc openTestFile*(filename: string): File =
  ## Open the given test file for reading and return the file object.

  if not open(result, filename, fmRead):
    assert(false, "test file missing: " & filename)


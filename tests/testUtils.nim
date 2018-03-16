
proc createTestFile*(bytes: openArray[uint8]):
  tuple[file:File, filename:string] =
  ## Create a test file with the given bytes.

  var filename = "testfile.bin"
  var file: File
  if open(file, filename, fmReadWrite):
    if file.writeBytes(bytes, 0, bytes.len) != bytes.len:
      raise newException(IOError, "Unable to write all the bytes.")
  result = (file, filename)

proc openTestFile*(filename: string): File =
  ## Open the given test file and return the file object.
  if not open(result, filename, fmRead):
    assert(false, "test file missing: " & filename)


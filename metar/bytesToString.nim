
## You use bytesToString module to create a string from an array of bytes.

import tpub
import unicode

proc stripInvalidUtf8(str: string): string {.tpub.} =
  ## Strip out invalid utf characters and return a new string.

  result = newStringOfCap(str.len)

  var start = 0
  while true:
    var pos = validateUtf8(str[start..<str.len])
    if pos == -1:
      pos = str.len

    for ix in start..<pos:
      result.add(str[ix])

    start = pos + 1
    if start > str.len:
      break


proc bytesToString*(buffer: openArray[uint8|char], index: Natural=0,
                   length: Natural=0): string {.tpub.} =
  ## Create a string from bytes in a buffer starting at the given
  ## index and using length bytes. It strips out invalid utf8 bytes
  ## and removes 0s.

  if length == 0:
    return ""

  result = newStringOfCap(length)
  for ix in index..index+length-1:
    result.add((char)buffer[ix])

  # Strip invalid unicode characters.
  result = stripInvalidUtf8(result)

  # Remove 0 bytes.
  result = result.replace("\0")

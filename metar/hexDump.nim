import strutils
import tpub

## You can display a sequence of bytes as a hex string and ascii.

iterator iteratorCount(bytes: openArray[uint8], count: Natural): seq[uint8] {.tpub.} =
  ## Iterate through the given bytes returning 'count' bytes at a time.
  ## If there are not enough bytes, return the remaining.
  ##
  ## For example, to return 16 bytes at a time:
  ##
  ## ::
  ##
  ## for row in iteratorCount(bytes, 16):
  ##   ...

  var xstart = 0
  var xend = count
  while xstart < bytes.len:
    if xend > bytes.len:
      xend = bytes.len
    yield bytes[xstart..<xend]
    xstart = xend
    xend = xstart + count


proc hexDump*(bytes: openArray[uint8|char], offset: uint16=0): string =
  ## Return a hex string of the given bytes. The offset parameter is
  ## the starting offset shown on the left.
  ##
  ## For example:
  ##
  ## ::
  ##
  ## 0000  FF E1 1D 78 68 74 74 70 3A 2F 2F 6E 73 2E 61 64  ...xhttp://ns.ad
  ## 0010  6F 62 65 2E 63 6F 6D 2F 78 61 70 2F 31 2E 30 2F  obe.com/xap/1.0/

  result = ""
  var start = offset

  for row in iteratorCount(bytes, 16):
    result.add(toHex(start))
    result.add("  ")

    for item in row:
      result.add("$1 " % [toHex(item)])

    for ix in 0..<16 - row.len:
      result.add("   ")

    result.add(" ")

    for ascii in row:
      if ascii >= 0x20'u8 and ascii <= 0x7f'u8:
        result.add($char(ascii))
      else:
        result.add(".")

    start += 16
    result.add("\n")


proc hexDump*(str: string, offset: uint16=0): string =
  ## Return a hex string of the given string. The offset parameter is
  ## the starting offset shown on the left.
  ##
  ## For example:
  ##
  ## ::
  ## echo hexDump("this is a test where we show a string as hex", 0x536'u16)
  ##
  ## 0536  74 68 69 73 20 69 73 20 61 20 74 65 73 74 20 77  this is a test w
  ## 0546  68 65 72 65 20 77 65 20 73 68 6F 77 20 61 20 73  here we show a s
  ## 0556  74 72 69 6E 67 20 61 73 20 68 65 78              tring as hex

  var buffer = newSeq[uint8](str.len)
  for ix, ch in str:
    buffer[ix] = (uint8)ch
  result = hexDump(buffer, offset)


proc toHex0*[T](number: T): string =
  ## Return the number as a hex string. It is like toHex but with the
  ## leading 0's removed.
  ##
  ## .. code-block:: nim
  ##   check(toHex(0x4'u16) == "0004")
  ##   check(toHex0(0x4'u16) == "4")

  let str = toHex(number)

  # Count the leading zeros.
  var count = 0
  for char in str:
    if char == '0':
      count += 1
    else:
      break;

  # Remove the leading zeros.
  result = str[count..str.len-1]

  if result == "":
     return "0"

when defined(test):
  proc hexDumpSource(bytes: openArray[uint8|char], columns: int=8): string {.tpub.} =
    ## Dump the buffer as an array of bytes in nim source code.
    ## This procedure is only defined in test mode.

    var lines = newSeq[string]()
    lines.add("var buffer = [")
    var first = true
    for row in iteratorCount(bytes, columns):
      var line = newSeq[string]()
      for item in row:
        if first:
          line.add("0x$1'u8" % [toHex(item)])
        else:
          line.add("0x$1" % [toHex(item)])
        first = false
      lines.add("  " & line.join(", ") & ",")
    lines.add("]")
    result = lines.join("\n")


proc hexDumpFileRange*(file: File, start: int64, finish: int64): string =
  ## Read a section of the given file (up to 16K) and return it as a
  ## hex string.  If there is an error, the IOError exception is raised.

  let length = finish - start
  if length < 0:
     raise newException(IOError, "Invalid range")
  elif length == 0:
    return ""
  elif length > 16 * 1024:
    raise newException(IOError, "Not implemented support for that big a range.")

  var buffer = newSeq[uint8](length)
  file.setFilePos(start)
  if file.readBytes(buffer, 0, length) != length:
    raise newException(IOError, "Unable to read the file.")
  result = hexDump(buffer, (uint16)start)

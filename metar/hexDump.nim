import strutils
import tpub

iterator iterator16(bytes: seq[uint8]): seq[uint8] {.tpub.} =
  ## Return 16 bytes of a sequence at a time.
  var xstart = 0
  var xend = 16
  while xstart < bytes.len:
    if xend > bytes.len:
      xend = bytes.len
    yield bytes[xstart..<xend]
    xstart = xend
    xend = xstart + 16

proc hexDump*(bytes: seq[uint8|char], offset: uint16=0): string =
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

  for row in iterator16(bytes):
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

proc toHex0*[T](number: T): string =
  ## Remove the leading 0's from toHex output.

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

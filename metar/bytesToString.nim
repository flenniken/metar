# See: test_bytesToString.nim(0):

## Create a string from an array of bytes.

import unicode
# import hexdump
# import metadata


# proc validateUtf8*(s: string, start: Natural = 0): int =
#   ## Returns the position of the invalid byte in ``s`` if the string ``s`` does
#   ## not hold valid UTF-8 data. Otherwise ``-1`` is returned.
#   var i = start
#   let L = s.len
#   while i < L:
#     if ord(s[i]) <=% 127:
#       inc(i)
#     elif ord(s[i]) shr 5 == 0b110:
#       if ord(s[i]) < 0xc2: return i # Catch overlong ascii representations.
#       if i+1 < L and ord(s[i+1]) shr 6 == 0b10: inc(i, 2)
#       else: return i
#     elif ord(s[i]) shr 4 == 0b1110:
#       if i+2 < L and ord(s[i+1]) shr 6 == 0b10 and ord(s[i+2]) shr 6 == 0b10:
#         inc i, 3
#       else: return i
#     elif ord(s[i]) shr 3 == 0b11110:
#       if i+3 < L and ord(s[i+1]) shr 6 == 0b10 and
#                      ord(s[i+2]) shr 6 == 0b10 and
#                      ord(s[i+3]) shr 6 == 0b10:
#         inc i, 4
#       else: return i
#     else:
#       return i
#   return -1


# proc stripInvalidUtf8(str: string): (string, seq[int]) {.tpub.} =
#   ## Strip out invalid utf characters and return a new string.

#   var stripped = newSeq[int]()
#   var newStr = newStringOfCap(str.len)
#   var start = 0
#   while true:
#     var pos = validateUtf8(str, start)
#     if pos == -1:
#       pos = str.len
#     else:
#       stripped.add(pos)

#     for ix in start..<pos:
#       newStr.add(str[ix])

#     assert(start <= pos)

#     start = pos + 1

#     if start > str.len:
#       break

#   result = (newStr, stripped)


proc bytesToString*(buffer: openArray[uint8|char], index: Natural=0,
                   length: Natural=0): string =
  ## Create a string from bytes in a buffer starting at the given
  ## index and using length bytes. Raise a NotSupportedError when the
  ## bytes are not valid utf8 characters or when there are embedded
  ## zeros.

  if length == 0:
    return ""

  result = newStringOfCap(length)
  for ix in index..<index+length:
    result.add((char)buffer[ix])

  let pos = validateUtf8(result)
  if pos != -1:
    # echo hexDump(result)
    let str = result[pos..pos]
    raise newException(NotSupportedError, "Invalid utf8 string, found " & toHex(str) & ".")
    
  let zero = result.find((char)0'u8)
  if zero != -1:
    # echo hexDump(result)
    raise newException(NotSupportedError, "Embedded zero in string.")

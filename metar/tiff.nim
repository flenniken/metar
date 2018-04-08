
import tables
import readNumber
import endians
import metadata
import tiffTags
import strutils
import tpub
import macros

#[
https://www.loc.gov/preservation/digital/formats/fdd/fdd000022.shtml

https://web.archive.org/web/20150503034412/http://partners.adobe.com/public/developer/en/tiff/TIFF6.pdf



This is the layout of a Tiff file:

header -> IFD
IFD starts with a count, then that many IFD entries (IDFEntry),
  then an offset to the next IFD or 0.
IFD.next -> IFD or 0
IFD.SubIFDs = [->IFD, ->IFD,...]
IFD.Exif_IFD -> IFD
Each IFD entry contains a tag and a list of values.

If the Value is shorter than 4 bytes, it is left-justified within the
4-byte Value Offset, i.e., stored in the lower numbered bytes.

]#

type
  Kind* {.size: 2, pure.} = enum
    dummy
    bytes
    strings
    shorts
    longs
    rationals
    sbytes
    blob
    sshorts
    slongs
    srationals
    floats
    doubles ##[ \
IFDEntry types.

Skip over fields containing an unexpected field type.

0, dummy, This is here because enums used as discriminates must start at 0.
1, bytes, uint8
2, strings, One or more ASCII strings each ending with 0. Count includes the 0s.
3, shorts, uint16
4, longs, uint32
5, rationals, Two uint32, numerator then denominator.
6, sbytes, s stands for signed.
7, blob, list of bytes.
8, sshorts
9, slongs
10, srationals
11, floats, float32
12, doubles, float64
]##

  IFDEntry* = object
    tag: uint16
    kind: Kind
    count: uint32
    packed: array[4, uint8] ## 12 byte IFD entry.

#[ To save time and space the Value Offset (packed) contains the Value
instead of pointing to the Value if and only if the Value fits into 4
bytes. If the Value is shorter than 4 bytes, it is left-justified
within the 4-byte Value Offset, i.e., stored in the lower-numbered
bytes. Whether the Value fits within 4 bytes is determined by the Type
(kind) and Count of the field.  ]#

  # todo: use numerator and denominator as two uint32 values for rationals.
  ValueList* = ref object
    case kind: Kind
    of Kind.dummy: discard
    of Kind.bytes: bytesList*: seq[uint8]
    of Kind.strings: stringsList*: seq[uint8]
    of Kind.shorts: shortsList*: seq[uint16]
    of Kind.longs: longsList*: seq[uint32]
    of Kind.rationals: rationalsList*: seq[uint64]
    of Kind.sbytes: sbytesList*: seq[int8]
    of Kind.blob: blobList*: seq[uint8]
    of Kind.sshorts: sshortsList*: seq[int16]
    of Kind.slongs: slongsList*: seq[int32]
    of Kind.srationals: srationalsList*: seq[int64]
    of Kind.floats: floatsList*: seq[float32]
    of Kind.doubles: doublesList*: seq[float64] ##\
    ## A sequence of kind elements.


proc tagName*(tag: uint16): string =
  ## Return the name of the given tag or "" when not known.

  result = tagToString.getOrDefault(tag)
  if result == nil:
    result = ""


proc `$`*(entry: IFDEntry): string =
  # Return a string representation of the IFDEntry.
  "$1($2, $3h), $4 $5, packed: $6 $7 $8 $9"  %
    [tagName(entry.tag), $entry.tag, toHex(entry.tag),
    $entry.count, $entry.kind,
    toHex(entry.packed[0]), toHex(entry.packed[1]),
    toHex(entry.packed[2]), toHex(entry.packed[3])]


proc len*(v: ValueList): int =
  case v.kind:
    of dummy: result = 0
    of bytes: result = v.bytesList.len()
    of strings: result = v.stringsList.len()
    of shorts: result = v.shortsList.len()
    of longs: result = v.longsList.len()
    of rationals: result = v.rationalsList.len()
    of sbytes: result = v.sbytesList.len()
    of blob: result = v.blobList.len()
    of sshorts: result = v.sshortsList.len()
    of slongs: result = v.slongsList.len()
    of srationals: result = v.srationalsList.len()
    of floats: result = v.floatsList.len()
    of doubles: result = v.doublesList.len()


proc kindSize*(kind: Kind): Natural {.tpub.} =
  case kind:
    of dummy: result = 0
    of bytes: result = 1
    of strings: result = 1
    of shorts: result = 2
    of longs: result = 4
    of rationals: result = 8
    of sbytes: result = 1
    of blob: result = 1
    of sshorts: result = 2
    of slongs: result = 4
    of srationals: result = 8
    of floats: result = 4
    of doubles: result = 8


proc `$`*(v: ValueList): string =
  ## Return a string representation of the ValueList.
  case v.kind:
    of bytes: result = $v.bytesList
    of strings: result = $v.stringsList
    of shorts: result = $v.shortsList
    of longs: result = $v.longsList
    of rationals: result = $v.rationalsList
    of sbytes: result = $v.sbytesList
    of blob: result = $v.blobList
    of sshorts: result = $v.sshortsList
    of slongs: result = $v.slongsList
    of srationals: result = $v.srationalsList
    of floats: result = $v.floatsList
    of doubles: result = $v.doublesList
    else:
      result = "Unknown type of Valuelist."


proc readHeader*(file: File, headerOffset: int64):
    tuple[ifdOffset: int64, endian: Endianness] =
  ## Read the tiff header at the given header offset and return the
  ## offset of the first image file directory (IFD), and the endianness of
  ## the file.  Raise UnknownFormatError when the file format is
  ## unknown.

  # A header is made up of a three elements, order, magic and offset:
  # 2 bytes: byte order, 0x4949 or 0x4d4d
  # 2 bytes: magic number, 0x2a (42)
  # 4 bytes: offset

  try:
    file.setFilePos(headerOffset)

    # Determine the endian of the file by reading the byte order marker.
    var endian: Endianness
    var order = readNumber[uint16](file, system.cpuEndian)
    if order == 0x4d4d:
      endian = bigEndian
    elif order == 0x4949:
      endian = littleEndian
    else:
      raise newException(UnknownFormatError, "Tiff: invalid byte order marker.")

    # Check for the magic 42.
    var magic = readNumber[uint16](file, endian)
    if magic != 0x2a: # 42
      raise newException(UnknownFormatError, "Tiff: wrong magic number.")

    # Read the offset of the first image file directory (IFD).
    var ifdOffset = readNumber[uint32](file, endian)
    result = ((int64)ifdOffset, endian)
  except UnknownFormatError:
    raise
  except:
    raise newException(UnknownFormatError, "Tiff: not a tiff file.")


proc getIFDEntry*(buffer: var openArray[uint8], endian: Endianness,
                  index: Natural = 0): IFDEntry =
  ## Given a buffer of IFDEntry bytes starting at the given index,
  ## return an IFDEntry object.
  if buffer.len()-index < 12:
    raise newException(NotSupportedError, "Tiff: not enough bytes for IFD entry.")

  # 2 tag bytes, 2 kind bytes, 4 count bytes, 4 packed bytes
  result.tag = length[uint16](buffer, index+0, endian)
  let kind = length[uint16](buffer, index+2, endian)
  try:
    result.kind = Kind(kind)
    if result.kind == Kind.dummy:
      raise newException(RangeError, "")
  except RangeError:
    raise newException(NotSupportedError,
      "Tiff: IFD entry kind is not known: " & $kind)
  result.count = length[uint32](buffer, index+4, endian)
  result.packed[0] = buffer[index+8]
  result.packed[1] = buffer[index+9]
  result.packed[2] = buffer[index+10]
  result.packed[3] = buffer[index+11]


# macro setAttr(object: untyped, attr: static[string], value: untyped): typed =
#   ## At compile time generate code like: object.attr = value

#   let source = object & "." & attr & " = " & value
#   result = parseStmt(source)


# proc newValueList(kindType: typedesc, attr: string, entry: IFDEntry,
#                   buffer: seq[uint8], endian: Endianness): ValueList =
#   # Create a new value list for the given item.

#   var list = newSeq[kindType]((int)entry.count)
#   for ix in 0..<(int)entry.count:
#     list[ix] = length[kindType](buffer, ix * sizeof(kindType), endian)
#   new(result)
#   result.kind = entry.kind
#   setAttr(result, attr, list)


# macro newValueList(theType: static[string], attribute: static[string]): typed =
#   ## Create a new ValueList object for the given Kind.
#   let source = """
# var list = newSeq[$1]((int)entry.count)
# for ix in 0..<(int)entry.count:
#   list[ix] = length[$1](buffer, ix * sizeof($1), endian)
# new(result)
# result.kind = entry.kind
# result.$2 = list
# """ % [theType, attribute]
#   result = parseStmt(source)


proc readValueList*(file: File, entry: IFDEntry, endian: Endianness,
               headerOffset: int64 = 0): ValueList =
  ## Read the list of values of the IFD entry from the file and return the
  ## data as a ValueList object.

  # Determine where the values start and how many bytes long, read
  # them into a buffer then put them into a list.

  let bufferSize: int = kindSize(entry.kind) * (int)entry.count

  # Read the bytes into a buffer.
  var buffer = newSeq[uint8](bufferSize)
  if bufferSize <= 4:
    # The values fit in packed.
    # Move packed to buffer.
    for ix in 0..<bufferSize:
      buffer[ix] = entry.packed[ix]
  else:
    # The values are in the file at the offset specified by packed.
    let startOffset = length[uint32](entry.packed, 0, endian)
    file.setFilePos((int64)startOffset)
    if file.readBytes(buffer, 0, bufferSize) != bufferSize:
      raise newException(UnknownFormatError, "Tiff: Unable to read all the IFD entry values.")


  case entry.kind:
    of Kind.dummy:
      raise newException(UnknownFormatError, "Kind of 0 is not valid.")

    of Kind.bytes:
      var list = newSeq[uint8]((int)entry.count)
      for ix in 0..<(int)entry.count:
        list[ix] = length[uint8](buffer, ix * sizeof(uint8), endian)
      new(result)
      result.kind = Kind.bytes
      result.bytesList = list

    of Kind.shorts:
      var list = newSeq[uint16]((int)entry.count)
      for ix in 0..<(int)entry.count:
        list[ix] = length[uint16](buffer, ix * sizeof(uint16), endian)
      new(result)
      result.kind = Kind.shorts
      result.shortsList = list

    of Kind.longs:
      var list = newSeq[uint32]((int)entry.count)
      for ix in 0..<(int)entry.count:
        list[ix] = length[uint32](buffer, ix * sizeof(uint32), endian)
      new(result)
      result.kind = Kind.longs
      result.longsList = list


    else:
      echo result.kind
      raise newException(UnknownFormatError, "not implemented yet")

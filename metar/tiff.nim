# See: test_tiff.nim(0):

import tables
import readNumber
import endians
import metadata
import tiffTags
import strutils
import tpub
import macros
import json

#[
The following links are good references for the Tiff format.

* https://www.loc.gov/preservation/digital/formats/fdd/fdd000022.shtml
* https://web.archive.org/web/20150503034412/http://partners.adobe.com/public/developer/en/tiff/TIFF6.pdf

This is the layout of a Tiff file:

* header -> IFD
* IFD starts with a count, then that many IFD entries (IDFEntry),
  then an offset to the next IFD or 0.
* IFD.next -> IFD or 0
* IFD.SubIFDs = [->IFD, ->IFD,...]
* IFD.Exif_IFD -> IFD

]#

type
  Kind* {.size: 2, pure.} = enum
    bytes = 1
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

  IFDInfo* = object
    nodeList*: seq[tuple[name: string, node: JsonNode]]
    nextList*: seq[uint32] ## Node list contains the ifd section and
    ## any other optional nodes. The next list contains ifd offsets
    ## found.

#[
To save time and space the Value Offset (packed) contains the Value
instead of pointing to the Value if and only if the Value fits into 4
bytes. If the Value is shorter than 4 bytes, it is left-justified
within the 4-byte Value Offset, i.e., stored in the lower-numbered
bytes. Whether the Value fits within 4 bytes is determined by the Type
(kind) and Count of the field.
]#


proc tagName*(tag: uint16): string =
  ## Return the name of the given tag or "" when not known.

  result = tagToString.getOrDefault(tag)
  if result == nil:
    result = ""


proc `$`*(entry: IFDEntry): string =
  ## Return a string representation of the IFDEntry.

  "$1($2, $3h), $4 $5, packed: $6 $7 $8 $9"  %
    [tagName(entry.tag), $entry.tag, toHex(entry.tag),
    $entry.count, $entry.kind,
    toHex(entry.packed[0]), toHex(entry.packed[1]),
    toHex(entry.packed[2]), toHex(entry.packed[3])]


proc kindSize*(kind: Kind): Natural {.tpub.} =
  ## Return the number of bytes the given kind uses.

  case kind:
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


proc readHeader*(file: File, headerOffset: int64):
    tuple[ifdOffset: int64, endian: Endianness] =
  ## Read the tiff header at the given header offset and return the
  ## offset of the first image file directory (IFD), and the endianness of
  ## the file.  Raise UnknownFormatError when the file format is
  ## unknown.

  # A header is made up of a three elements, order, magic and offset:
  # 2 bytes: byte order, 0x4949 or 0x4d4d
  # 2 bytes: magic number, 0x2a (42)
  # 4 bytes: IFD offset

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

  # 2 tag bytes, 2 kind bytes, 4 count bytes, 4 packed bytes
  if buffer.len()-index < 12:
    raise newException(NotSupportedError, "Tiff: not enough bytes for IFD entry.")

  let tag = length[uint16](buffer, index+0, endian)
  let kind_ord = (int)length[uint16](buffer, index+2, endian)
  if kind_ord < ord(low(Kind)) or kind_ord > ord(high(Kind)):
    # todo: show the kind in the range error field.
    raise newException(NotSupportedError,
                       "Tiff: IFD entry kind is not known: " & $kind_ord)
  let kind = Kind(kind_ord)
  let count = length[uint32](buffer, index+4, endian)
  var packed: array[4, uint8]
  packed[0] = buffer[index+8]
  packed[1] = buffer[index+9]
  packed[2] = buffer[index+10]
  packed[3] = buffer[index+11]
  result = IFDEntry(tag: tag, kind: kind, count: count, packed: packed)


iterator items*[T](a: openArray[T], start: Natural = 0): T {.inline.} =
  ## Iterate over each item of the array starting at the given index.

  var i = start
  while i < len(a):
    yield a[i]
    inc(i)


proc find*[T, S](a: T, item: S, start: Natural = 0): int {.inline.} =
  ## Find the item in an array and return its index or -1. Start
  ## searching at the given start index.

  result = start
  for i in items(a, start):
    if i == item:
      return
    inc(result)
  result = -1


proc parseStrings(buffer: openArray[uint8]): JsonNode {.tpub.} =
  ## Parse the buffer and return the strings in a JSON array.

  # Each string ends with 0 in the buffer.
  result = newJArray()
  if buffer.len == 0:
    return
  var start = 0
  var finish = 0
  while true:
    finish = buffer.find(0'u8, start)
    # The last string doesn't need to end with a 0.
    if finish == -1:
      finish = buffer.len
    var str = newStringOfCap(finish-start)
    for b in buffer[start..<finish]:
      str.add((char)b)
    result.add(newJString(str))
    start = finish + 1
    if start >= buffer.len:
      break

proc readLongs*(file: File, entry: IFDEntry, endian: Endianness,
               headerOffset: int64 = 0): seq[uint32] =
  ## Read and return the entry's value list as a list of uint32s. The
  ## item kind must be longs.

  assert(file != nil)
  assert(entry.kind == Kind.longs)

  let count = (int)entry.count
  result = newSeq[uint32](count)
  let start = length[uint32](entry.packed, 0, endian)
  case count:
    of 0:
      discard
    of 1:
      result[0] = start
    else:
      file.setFilePos(((int64)start) + headerOffset)
      for ix in 0..<count:
        result[ix] = readNumber[uint32](file, endian)
    

proc readValueList*(file: File, entry: IFDEntry, endian: Endianness,
               headerOffset: int64 = 0): JsonNode =
  ## Read the list of values of the IFD entry from the file and return the
  ## data as a JSON array.

  # Determine where the values start and how many bytes long, read
  # them into a buffer then put them into a list.

  # Read the bytes of the value list into a buffer.
  let bufferSize: int = kindSize(entry.kind) * (int)entry.count
  var buffer = newSeq[uint8](bufferSize)
  if bufferSize <= 4:
    # The values fit in packed.  Move packed to the buffer.
    for ix in 0..<bufferSize:
      buffer[ix] = entry.packed[ix]
  else:
    assert(file != nil)
    # The values are in the file at the offset specified by packed.
    let startOffset = length[uint32](entry.packed, 0, endian)
    file.setFilePos(((int64)startOffset) + headerOffset)
    if file.readBytes(buffer, 0, bufferSize) != bufferSize:
      raise newException(UnknownFormatError, "Tiff: Unable to read all the IFD entry values.")

  result = newJArray()

  case entry.kind:

    of Kind.bytes, Kind.blob:
      for ix in 0..<(int)entry.count:
        let number = length[uint8](buffer, ix * sizeof(uint8), endian)
        result.add(newJInt((BiggestInt)number))

    of Kind.sbytes:
      for ix in 0..<(int)entry.count:
        let number = length[int8](buffer, ix * sizeof(int8), endian)
        result.add(newJInt((BiggestInt)number))

    of Kind.strings:
      result = parseStrings(buffer)

    of Kind.shorts:
      for ix in 0..<(int)entry.count:
        let number = length[uint16](buffer, ix * sizeof(uint16), endian)
        result.add(newJInt((BiggestInt)number))

    of Kind.sshorts:
      for ix in 0..<(int)entry.count:
        let number = length[int16](buffer, ix * sizeof(int16), endian)
        result.add(newJInt((BiggestInt)number))

    of Kind.longs:
      for ix in 0..<(int)entry.count:
        let number = length[uint32](buffer, ix * sizeof(uint32), endian)
        result.add(newJInt((BiggestInt)number))

    of Kind.slongs:
      for ix in 0..<(int)entry.count:
        let number = length[int32](buffer, ix * sizeof(int32), endian)
        result.add(newJInt((BiggestInt)number))

    of Kind.rationals:
      for ix in countup(0, (int)entry.count*8-1, 8):
        let numerator = length[uint32](buffer, ix, endian)
        let denominator = length[uint32](buffer, ix+4, endian)
        var rational = newJArray()
        rational.add(newJInt((BiggestInt)numerator))
        rational.add(newJInt((BiggestInt)denominator))
        result.add(rational)

    of Kind.srationals:
      for ix in countup(0, (int)entry.count*8-1, 8):
        let numerator = length[int32](buffer, ix, endian)
        let denominator = length[int32](buffer, ix+4, endian)
        var rational = newJArray()
        rational.add(newJInt((BiggestInt)numerator))
        rational.add(newJInt((BiggestInt)denominator))
        result.add(rational)

    of Kind.floats:
      for ix in 0..<(int)entry.count:
        let number = length[float32](buffer, ix * sizeof(float32), endian)
        result.add(newJFloat(number))

    of Kind.doubles:
      for ix in 0..<(int)entry.count:
        let number = length[float64](buffer, ix * sizeof(float64), endian)
        result.add(newJFloat(number))



  ## list of json dictionaries. The first dictionary is the ifd and
  ## the optional other dictionaries are for special items found in
  ## the idf, like xmp, exif, etc. The "next" return value is the
  ## offset to the next ifd. The ifd dictionary key is the entry tag,
  ## and the value is a list of the entry's values. The key for xmp is
  ## 700 and its value is "xmp".


proc readValueListMax(file: File, entry: IFDEntry, endian: Endianness,
    maximumCount:Natural=20, maximumSize:Natural=1000): JsonNode =
  # Read the entry's value list. For big lists, return a short string
  # instead.

  let bufferSize: Natural = kindSize(entry.kind) * (Natural)entry.count
  if ((Natural)entry.count) <= maximumCount and bufferSize <= maximumSize:
    let jArray = readValueList(file, entry, endian)
    result = jArray
  else:
    # example string: 135 longs starting at 23456.
    let start = length[uint32](entry.packed, 0, endian)
    let str = "$1 $2 starting at $3" % [$entry.count, $entry.kind, $start]
    result = newJString(str)


proc getImage(imageData: Table[string, seq[uint32]], headerOffset: int64): JsonNode =
  ## Return an image node from the imageData.

  var width, height, starts, counts, offset: seq[uint32]
  try:
    width = imageData["width"]
    height = imageData["height"]
    starts = imageData["starts"]
    counts = imageData["counts"]
    offset = imageData["ifd_offset"]
  except:
    raise newException(NotSupportedError, "Tiff: IFD without all image parameters.")

  if width.len != 1 or height.len != 1 or
     starts.len < 1 or counts.len < 1 or starts.len != counts.len:
    raise newException(NotSupportedError, "Tiff: IFD invalid image parameters.")
    
  result = newJObject()
  result["ifd_offset"] = newJInt((BiggestInt)offset[0])
  result["width"] = newJInt((BiggestInt)width[0])
  result["height"] = newJInt((BiggestInt)height[0])

  # Create a pixels array of start end offsets: [(start, end), (start, end),...]
  var pixels = newJArray()
  for ix, start in starts:
    let begin = ((int64)start)+headerOffset
    let finish = begin+(int64)counts[ix]
    var part = newJArray()
    part.add(newJInt(begin))
    part.add(newJInt(finish))
    pixels.add(part)

  result["pixels"] = pixels



#   # Read the Strip or Tile offsets and make an sequence of start offsets.
#   # Read the byte counts and make a sequence of end offsets.

# proc addPixelRanges(file: File, entry: IFDEntry, endian: Endianness, headerOffset: uint16) =
#   ## Add strip or tile ranges to the given ifd.

#   start = header_offset + offset
#   end = start + byte_counts[ix]

#   # (StripOffsets, StripByteCounts), (TileOffsets, TileByteCounts)
#   tups = [('strip', 273, 279), ('tile', 324, 325)]

#   for name, tag_offset, tag_byte_counts in tups:
#     offsets = ifd.get(tag_offset)
#     byte_counts = ifd.get(tag_byte_counts)
#     if offsets and byte_counts:
#       if len(offsets) != len(byte_counts):
#         raise NotSupported("The number of offsets is not the same as the number of byte counts.")
#       for ix, offset in enumerate(offsets):
#         value_range_name = "range_{}{}".format(name, ix)
#         start = header_offset + offset
#         end = start + byte_counts[ix]
#         ifd[value_range_name] = (start, end)


proc getOneInteger(file: File, entry: IFDEntry, endian: Endianness, minimum:int=1): JsonNode =
  ## Get one integer from the entry. Return a Json array with one JInt.

  if entry.count != 1:
    raise newException(NotSupportedError, "Tiff: IFD expected one value.")

  case entry.kind:
    of Kind.bytes, Kind.shorts, Kind.longs, Kind.sbytes, Kind.sshorts, Kind.slongs:
      discard
    else:
      raise newException(NotSupportedError, "Tiff: IFD entry is not an integer.")

  result = readValueList(file, entry, endian)
  let jNumber = result[0]
  if jNumber.getInt() < minimum:
    raise newException(NotSupportedError, "Tiff: IFD invalid image dimension.")


proc readIFD*(file: File, headerOffset: int64, ifdOffset: int64,
    endian: Endianness): IFDInfo =
  ## Read the Image File Directory at the given offset and return the
  ## IFD metadata information which contains a list of named
  ## nodes. The list contains at least an IFD node.  It may contain
  ## other nodes as well. The IFDInfo also contains a list of offsets
  ## to other IFDs found in the entries.

  assert(sizeOf(IFDEntry) == 12)

  # Create a list of offsets to IFDs found. The first item in the list
  # is the offset to the next IFD (which may be 0), following that are
  # subifds if there are any.
  var nextList = newSeq[uint32]()

  # The imageData table contains information collected across multiple
  # sections used to build the images metadata section. It gets filled
  # in with the image width, height, pixel starts and pixel counts.
  var imageData = initTable[string, seq[uint32]]()
  # todo: down casting int64 to uint32
  imageData["ifd_offset"] = @[(uint32)ifdOffset]

  # Read all the IFD bytes into a memory buffer.
  let start = headerOffset + ifdOffset
  file.setFilePos(start)
  var numberEntries = (int)readNumber[uint16](file, endian)
  let bufferSize = 12 * numberEntries
  var buffer = newSeq[uint8](bufferSize)
  if file.readBytes(buffer, 0, bufferSize) != bufferSize:
    raise newException(IOError, "Unable to read the file.")

  # Create a list to hold the ifd's list of nodes.
  var nodeList = newSeq[tuple[name: string, node: JsonNode]]()

  # Create an ifd node and add it to the list of nodes.
  var ifd = newJObject()
  nodeList.add(("ifd-" & $ifdOffset, ifd))

  # Add start and next offset into the ifd node dictionary.
  let next = readNumber[uint32](file, endian)
  ifd["offset"] = newJInt((BiggestInt)start)
  ifd["next"] = newJInt((BiggestInt)next)
  if next != 0'u32:
    nextList.add(next)

  # Loop through the IFD entries and process each one.
  if numberEntries > 0:
    for ix in 0..<numberEntries:
      let entry = getIFDEntry(buffer, endian, ix*12)

      case entry.tag:
      of 256'u16, 257'u16: # ImageWidth, ImageLength
        ifd[$entry.tag] = readValueListMax(file, entry, endian, 10)
        let name = if entry.tag == 256'u16: "width" else: "height"
        imageData[name] = readLongs(file, entry, endian)

      of 700'u16:
        # The name xmp, exif, iptc are common between image formats.  The user can
        # find them by name.

        # Create an xmp node and add it to the node list.
        let name = "xmp"
        ifd[$entry.tag] = newJString(name)
        var xmp = newJObject()
        xmp["test"] = newJString("testing")
        nodeList.add((name, xmp))

      of 34665'u16: # exif
        # Create an xmp node and add it to the node list.
        let name = "exif"
        ifd[$entry.tag] = newJString(name)
        var exif = newJObject()
        exif["testexit"] = newJString("exiftttt")
        nodeList.add((name, exif))

      of 273'u16, 324'u16: # StripOffsets, TileOffsets
        ifd[$entry.tag] = readValueListMax(file, entry, endian, 1000)
        imageData["starts"] = readLongs(file, entry, endian)

      of 279'u16, 325'u16: # StripByteCounts, TileByteCounts
        ifd[$entry.tag] = readValueListMax(file, entry, endian, 1000)
        imageData["counts"] = readLongs(file, entry, endian)

      of 330'u16: # SubIFDs
        # SubIFDs is a list of offsets to low res ifds. Add them to
        # the next list.
        let jArray = readValueList(file, entry, endian)
        ifd[$entry.tag] = jArray
        for jInt in jArray.items():
          let ifdOffset = (uint32)jInt.getInt()
          nextList.add(ifdOffset)

      else:
        ifd[$entry.tag] = readValueListMax(file, entry, endian, 1000)

  # Add the image node to the list of nodes.
  let image = getImage(imageData, headerOffset)
  nodeList.add(("image", image))

  result = IFDInfo(nodeList: nodeList, nextList: nextList)

# todo: use an array for the ifd items instead of appending a number to them.

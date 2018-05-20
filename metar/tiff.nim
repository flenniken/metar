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
import readerJpeg # remove this
import xmpparser
import algorithm


#[
The following links are good references for the Tiff format.

* https://www.fileformat.info/format/tiff/egff.htm
* https://www.loc.gov/preservation/digital/formats/fdd/fdd000022.shtml
* https://web.archive.org/web/20150503034412/http://partners.adobe.com/public/developer/en/tiff/TIFF6.pdf

This is the layout of a Tiff file:

* header -> IFD
* IFD starts with a count, then that many IFD entries (IDFEntry),
  then an offset to the next IFD or 0.
* IFD.next -> IFD or 0
* IFD.SubIFDs = [->IFD, ->IFD,...]
* IFD.Exif_IFD -> IFD

Tags are always found in contiguous groups within each IFD.
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
    packed: array[4, uint8]
    endian: Endianness
    headerOffset: uint32


  IFDInfo* = object
    nodeList*: seq[tuple[name: string, node: JsonNode]]
    nextList*: seq[tuple[name: string, offset: uint32]] ## \\ Node
    ## list contains the ifd section and any other optional nodes. The
    ## next list contains ifd offsets found and their associated name.
    ## The first item is the offset to the next IFD (which may be 0),
    ## following that are subifds or exif if there are any. The
    ## nextList name overrides the nodeList name if it is not "".


  Range* = object
    start*: uint32
    finish*: uint32
    name*: string
    message*: string
    known*: bool  ## \\
    ## A range describes a section of the file.  The start is the
    ## offset of the beginning of the section and finish is one past
    ## the end. The known field is true when the section format is
    ## known and handled by the current code, false when the format of
    ## the section is unknown.

  OffsetList = seq[tuple[start: uint32, finish: uint32]]


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


proc readHeader*(file: File, headerOffset: uint32):
    tuple[ifdOffset: uint32, endian: Endianness] =
  ## Read the tiff header at the given header offset and return the
  ## offset of the first image file directory (IFD), and the endianness of
  ## the file.  Raise UnknownFormatError when the file format is
  ## unknown.

  # A header is made up of a three elements, order, magic and offset:
  # 2 bytes: byte order, 0x4949 or 0x4d4d
  # 2 bytes: magic number, 0x2a (42)
  # 4 bytes: IFD offset

  try:
    file.setFilePos((int64)headerOffset)

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
    result = (ifdOffset, endian)
  except UnknownFormatError:
    raise
  except:
    raise newException(UnknownFormatError, "Tiff: not a tiff file.")


proc getIFDEntry*(buffer: var openArray[uint8], endian: Endianness,
                  headerOffset: uint32, index: Natural = 0): IFDEntry =
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
  result = IFDEntry(tag: tag, kind: kind, count: count, packed: packed,
                    endian: endian, headerOffset: headerOffset)


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


proc readBlob*(file: File, entry: IFDEntry): seq[uint8] =
  ## Read and return the entry's value list as a list of uint8s. The
  ## item kind must be bytes or blob.

  assert(file != nil)
  assert(entry.kind == Kind.bytes or entry.kind == Kind.blob)

  let count = (int)entry.count
  result = newSeq[uint8](count)
  if file.readBytes(result, 0, count) != count:
    raise newException(UnknownFormatError, "Tiff: Unable to read all the bytes.")


proc readLongs*(file: File, entry: IFDEntry, maximum: Natural): seq[uint32] =
  ## Read and return the entry's value list as a list of uint32s. The
  ## item kind must be longs. The maximum parameter limits the number
  ## of items to read. An error is raised when it exceeds the maximum.

  assert(file != nil)
  assert(entry.kind == Kind.longs)

  let count = (int)entry.count
  if count > maximum:
    let message = "Tiff: too many longs, got: $1 max: $2." % [$count, $maximum]
    raise newException(NotSupportedError, message)

  result = newSeq[uint32](count)
  let start = length[uint32](entry.packed, 0, entry.endian)
  case count:
    of 0:
      discard
    of 1:
      result[0] = start
    else:
      file.setFilePos(((int64)start) + (int64)entry.headerOffset)
      for ix in 0..<count:
        result[ix] = readNumber[uint32](file, entry.endian)


proc readValueList*(file: File, entry: IFDEntry): JsonNode =
  ## Read the list of values of the IFD entry from the file and return the
  ## data as a JSON array.

  let endian = entry.endian

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
    file.setFilePos(((int64)startOffset) + (int64)entry.headerOffset)
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


proc readValueListMax(file: File, entry: IFDEntry, maximumCount:Natural=20,
                      maximumSize:Natural=1000): JsonNode =
  # Read the entry's value list. For big lists, return a short string
  # instead.

  let bufferSize: Natural = kindSize(entry.kind) * (Natural)entry.count
  if ((Natural)entry.count) <= maximumCount and bufferSize <= maximumSize:
    let jArray = readValueList(file, entry)
    result = jArray
  else:
    # example string: 135 longs starting at 23456.
    let start = length[uint32](entry.packed, 0, entry.endian)
    let str = "$1 $2 starting at $3" % [$entry.count, $entry.kind, $start]
    result = newJString(str)


proc getRangeNode*(name: string, start: uint32, finish: uint32,
              known: bool, error: string): JsonNode =
  ## Add a range to the ranges list.

  result = newJArray()
  result.add(newJString(name))
  result.add(newJInt((BiggestInt)start))
  result.add(newJInt((BiggestInt)finish))
  result.add(newJBool(known))
  result.add(newJString(error))


proc mergeOffsets*(ranges: OffsetList, checkPadding: bool = false):
    tuple[minList: OffsetList, gapList: OffsetList] =
  ## Given a list of ranges, merge them into the smallest set of
  ## contiguous ranges. Return the new list of ranges. Also return a
  ## list of ranges that cover the gaps.  You can add the ranges (0,0)
  ## or (totalSize, totalSize) to the range list to cover the
  ## beginning and end of the file. The maxPadding number is the
  ## maxium number of bytes of padding at the end of a range.

  var minList = newSeq[tuple[start: uint32, finish: uint32]]()
  var gapList = newSeq[tuple[start: uint32, finish: uint32]]()

  if ranges.len == 0:
    result = (minList, gapList)
    return

  # Sort the pixels by the start offset.
  let sortedRanges = ranges.sortedByIt(it.start)

  var start = ranges[0].start
  var finish = ranges[0].finish

  for ix in 1..sortedRanges.len-1:
    let (r_start, r_finish) = sortedRanges[ix]

    var boundry: uint32
    if checkPadding:
      const paddingShift = 1
      boundry = ((finish shr paddingShift) + 1) shl paddingShift

    if finish >= r_start or (checkPadding and boundry == r_start):
      # Contiguous, ovelapping range or padding, merge.
      if r_finish > finish:
        finish = r_finish
    else:
      # Found a gap
      if start < finish:
        minList.add((start, finish))
      gapList.add((finish, r_start))
      start = r_start
      finish = r_finish

  if start < finish:
    minList.add((start, finish))
  result = (minList, gapList)


proc getImage(name: string, imageData: Table[string, seq[uint32]], headerOffset: uint32):
    tuple[image: bool, node: JsonNode, ranges: seq[Range]] =
  ## Return image node and associated ranges from the imageData or nil when no image.

  var width, height, starts, counts: seq[uint32]
  try:
    width = imageData["width"]
    height = imageData["height"]
    starts = imageData["starts"]
    counts = imageData["counts"]
  except:
    # exif ifd doesn't have an image.
    result = (false, nil, nil)
    return

  if width.len != 1 or height.len != 1 or
     starts.len < 1 or counts.len < 1 or starts.len != counts.len:
    raise newException(NotSupportedError, "Tiff: IFD invalid image parameters.")

  var imageNode = newJObject()
  imageNode["name"] = newJString(name)
  imageNode["width"] = newJInt((BiggestInt)width[0])
  imageNode["height"] = newJInt((BiggestInt)height[0])

  var offsets = newSeq[tuple[start: uint32, finish: uint32]](starts.len)
  for ix in 0..<starts.len:
    offsets[ix] = (starts[ix], starts[ix] + counts[ix])

  let (sections, _) = mergeOffsets(offsets, checkPadding=true)

  # Create a pixels array of start end offsets: [(start, end), (start, end),...]
  var pixels = newJArray()
  for section in sections:
    var part = newJArray()
    part.add(newJInt((BiggestInt)section.start))
    part.add(newJInt((BiggestInt)section.finish))
    pixels.add(part)
  imageNode["pixels"] = pixels

  var ranges = newSeq[Range](sections.len)
  for ix, item in sections:
    let (imageStart, imageFinish) = item
    ranges[ix] = Range(name: "image", start: imageStart, finish: imageFinish,
                       known: true, message: "")

  result = (true, imageNode, ranges)


proc getEntryStart(entry: IFDEntry): int64 =
  # Get the start offset of the entry, if the entry is outside
  # itself. If inside, return -1.

  let bufferSize: int = kindSize(entry.kind) * (int)entry.count
  if bufferSize <= 4:
    return 0'i64
  result = (int64)length[uint32](entry.packed, 0, entry.endian)


proc getEntryFinish(entry: IFDEntry): int64 =
  # Get the start offset of the entry, if the entry is outside
  # itself. If inside, return -1.

  let bufferSize: int = kindSize(entry.kind) * (int)entry.count
  if bufferSize <= 4:
    return 0'i64

  let start = (int64)length[uint32](entry.packed, 0, entry.endian)
  return start + (int64)bufferSize


proc readIFD*(file: File, headerOffset: uint32, ifdOffset: uint32,
              endian: Endianness, nodeName: string,
              ranges: var seq[Range]): IFDInfo =
  ## Read the Image File Directory at the given offset and return the
  ## IFD metadata information which contains a list of named
  ## nodes. The list contains at least an IFD node and it may contain
  ## other nodes as well. The IFDInfo also contains a list of offsets
  ## to other IFDs found in the entries. The rangeList is filled in
  ## with the ranges found in the IFD.

  # Create a list of IFD offsets found. The first item in the list is
  # the offset to the next IFD (which may be 0), following that are
  # subifds or exif if there are any.
  var nextList = newSeq[tuple[name: string, offset: uint32]]()

  # The imageData table contains information collected across multiple
  # sections used to build the images metadata section. It gets filled
  # in with the image width, height, pixel starts and pixel counts.
  var imageData = initTable[string, seq[uint32]]()

  # Read all the IFD bytes into a memory buffer.
  let start: uint32 = headerOffset + ifdOffset
  file.setFilePos((int64)start)
  var numberEntries = (int)readNumber[uint16](file, endian)
  let bufferSize = 12 * numberEntries
  let finish:uint32 = start + (uint32)bufferSize

  var buffer = newSeq[uint8](bufferSize)
  if file.readBytes(buffer, 0, bufferSize) != bufferSize:
    raise newException(IOError, "Unable to read the file.")
  ranges.add(Range(name: nodeName, start: start, finish: finish, known: true, message: ""))

  # todo: change finish to include the outside items.
  # todo: sort the ranges.
  # todo: format the ranges with the ranges first.

  # Create a list to hold the ifd's list of nodes.
  var nodeList = newSeq[tuple[name: string, node: JsonNode]]()

  # Create an ifd node and add it to the list of nodes.
  var ifd = newJObject()
  nodeList.add((nodeName, ifd))

  # Add start and next offset into the ifd node dictionary.
  let next = readNumber[uint32](file, endian)
  ifd["offset"] = newJInt((BiggestInt)start)
  ifd["next"] = newJInt((BiggestInt)next)
  if next != 0'u32:
    nextList.add( ("ifd", next))

  var entryStart: int64
  var entryFinish: int64

  # Loop through the IFD entries and process each one.
  if numberEntries > 0:
    for ix in 0..<numberEntries:
      let entry = getIFDEntry(buffer, endian, headerOffset, ix*12)
      if entryStart == 0:
        entryStart = getEntryStart(entry)
      let temp = getEntryFinish(entry)
      if temp != 0:
        entryFinish = temp

      case entry.tag:
      of 256'u16, 257'u16: # ImageWidth, ImageLength
        ifd[$entry.tag] = readValueListMax(file, entry, 10)
        let widthHeight = if entry.tag == 256'u16: "width" else: "height"
        imageData[widthHeight] = readLongs(file, entry, 1)

      of 700'u16:
        # The name xmp, exif, iptc are common between image formats.  The user can
        # find them by name.

        let name = "xmp"
        ifd[$entry.tag] = newJString(name)

        let start = (uint32)file.getFilePos()
        let blob = readBlob(file, entry)
        let xml = bytesToString(blob, 0, blob.len-1)
        let xmp = xmpParser(xml)
        nodeList.add((name, xmp))
        ranges.add(Range(name: "xmp", start: start, finish: start+(uint32)blob.len,
                         known: true, message: ""))

      of 34665'u16: # exif
        ifd[$entry.tag] = newJString("exif")

        let tempList = readLongs(file, entry, 1)
        if tempList.len != 1:
          raise newException(NotSupportedError, "Tiff: more than one exif.")
        nextList.add( ("exif", tempList[0]))

      of 273'u16, 324'u16: # StripOffsets, TileOffsets
        ifd[$entry.tag] = readValueListMax(file, entry, 100)
        imageData["starts"] = readLongs(file, entry, 10000)

      of 279'u16, 325'u16: # StripByteCounts, TileByteCounts
        ifd[$entry.tag] = readValueListMax(file, entry, 100)
        imageData["counts"] = readLongs(file, entry, 10000)

      of 330'u16: # SubIFDs
        # SubIFDs is a list of offsets to low res ifds. Add them to
        # the next list.
        let jArray = readValueList(file, entry)
        ifd[$entry.tag] = jArray
        for jInt in jArray.items():
          let ifdOffset = (uint32)jInt.getInt()
          nextList.add( ("ifd", ifdOffset))

      else:
        ifd[$entry.tag] = readValueListMax(file, entry, 1000)

  # If the image exists, Add its node and ranges.
  let (image, imageNode, imageRanges) = getImage($ifdOffset, imageData, headerOffset)
  if image:
    nodeList.add(("image", imageNode))
    for item in imageRanges:
      ranges.add(item)

  result = IFDInfo(nodeList: nodeList, nextList: nextList)

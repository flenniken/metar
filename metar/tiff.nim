# See: test_tiff.nim(0):

## You use the tiff module to read and parse tiff files.

import tables
import options
import readNumber
import endians
import metadata
import tiffTags
import strutils
import tpub
import json
import xmpparser
import algorithm
import bytesToString
import ranges
import imageData

#[
The following links are good references for the Tiff format.

* https://www.fileformat.info/format/tiff/egff.htm
* https://www.loc.gov/preservation/digital/formats/fdd/fdd000022.shtml
* https://web.archive.org/web/20150503034412/http://partners.adobe.com/public/developer/en/tiff/TIFF6.pdf
* https://www.sno.phy.queensu.ca/~phil/exiftool/TagNames/EXIF.html
* http://www.cipa.jp/std/documents/e/DC-008-Translation-2016-E.pdf

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
    ## IFDEntry types.
    ## 1. bytes, uint8
    ## 2. strings, one or more ASCII strings each ending with 0. Count includes the 0s.
    ## 3. shorts, uint16
    ## 4. longs, uint32
    ## 5. rationals, two uint32, numerator then denominator.
    ## 6. sbytes, s stands for signed.
    ## 7. blob, list of bytes.
    ## 8. sshorts
    ## 9. slongs
    ## 10. srationals
    ## 11. floats, float32
    ## 12. doubles, float64
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
    doubles


  IFDEntry* = object
    ## Image File Directory (IFD) Entry information. The tag, kind,
    ## count and packed fields correspond to the 12 byte entries in
    ## the tiff file.
    tag*: uint16
    kind*: Kind
    count*: uint32
    packed*: array[4, uint8]
    endian*: Endianness
    headerOffset*: uint32


  IFDInfo* = object
    ## Image File Directory (IFD) information.  The node list contains
    ## the IFD section node (name and metadata). In addition it may
    ## contain other types of nodes, i.e, xmp, iptc, etc.  The next
    ## list contains the pointers to additional IFDs found in the
    ## current IFD. The first item is the offset to the next IFD
    ## (which may be 0), followed by subifds or exif, if there are
    ## any.
    nodeList*: seq[tuple[name: string, node: JsonNode]]
    nextList*: seq[tuple[name: string, offset: uint32]]


  TiffImageData* = object
    ## Image metadata for an image. The width and height of the image
    ## and to file offsets of the image pixel data.
    width*: int32
    height*: int32
    starts*: seq[uint32]
    counts*: seq[uint32]


# proc `$`(entry: IFDEntry): string =
#   ## Return a string representation of the IFDEntry.

#   "$1, $2 $3, packed: $4 $5 $6 $7"  %
#     [tagName(entry.tag),
#     $entry.count, $entry.kind,
#     toHex(entry.packed[0]), toHex(entry.packed[1]),
#     toHex(entry.packed[2]), toHex(entry.packed[3])]


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
  ## Read the tiff header at the given offset and return the offset of
  ## the first image file directory (IFD) and the endianness of the
  ## file.  Raise UnknownFormatError when the file is not a tiff file.

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


iterator items[T](a: openArray[T], start: Natural = 0): T {.inline.} =
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

  if entry.kind != Kind.bytes and entry.kind != Kind.blob:
    let message = "Tiff: Unexpected kind for bytes. got: $1." % [$entry.kind]
    raise newException(NotSupportedError, message)

  let count = (int)entry.count
  result = newSeq[uint8](count)

  if count <= 4:
    # The values fit in packed.  Move packed values to the list.
    for ix in 0..<count:
      result[ix] = entry.packed[ix]
  else:
    let start = length[uint32](entry.packed, 0, entry.endian)
    file.setFilePos(((int64)start) + (int64)entry.headerOffset)
    if file.readBytes(result, 0, count) != count:
      raise newException(NotSupportedError, "Tiff: Unable to read all the bytes.")


proc readOneNumber*(file: File, entry: IFDEntry): int32 =
  ## Read one entry number and return it as an int32.  It can be a long,
  ## slong, short, sshort, bytes or sbytes. If the number is an
  ## uint32, it must be less than the maximum int32. An error is
  ## raised if there is more than one number or if the entry kind is
  ## not a number.

  assert(file != nil)

  let count = (int)entry.count
  if count != 1:
    let message = "Tiff: expected one number, got: $1." % [$count]
    raise newException(NotSupportedError, message)

  case entry.kind:
    of Kind.longs:
      let number = length[uint32](entry.packed, 0, entry.endian)
      if number > (uint32)high(int32):
        let message = "Tiff: unsigned number too big, got: $1." % [$number]
        raise newException(NotSupportedError, message)
      result = (int32)number
    of Kind.slongs:
      result = length[int32](entry.packed, 0, entry.endian)
    of Kind.shorts:
      result = (int32)length[uint16](entry.packed, 0, entry.endian)
    of Kind.sshorts:
      result = (int32)length[int16](entry.packed, 0, entry.endian)
    of Kind.bytes:
      result = (int32)length[uint8](entry.packed, 0, entry.endian)
    of Kind.sbytes:
      result = (int32)length[int8](entry.packed, 0, entry.endian)
    else:
      let message = "Tiff: unexpected number type, got: $1." % [$entry.kind]
      raise newException(NotSupportedError, message)


proc readLongs*(file: File, entry: IFDEntry, maximum: Natural): seq[uint32] =
  ## Read and return the entry's value list as a list of uint32s. The
  ## item kind must be longs. The maximum parameter limits the number
  ## of items to read. An error is raised when the number of items in
  ## the file exceeds the maximum.

  assert(file != nil)
  if entry.kind != Kind.longs:
    let message = "Tiff: expected longs, got: $1." % [$entry.kind]
    raise newException(NotSupportedError, message)
  # assert(entry.kind == Kind.longs)

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
                      maximumSize:Natural=1000): JsonNode {.tpub.} =
  ## Read the entry's value list. For lists that exceed the maximum,
  ## return a short string instead.

  let bufferSize: Natural = kindSize(entry.kind) * (Natural)entry.count
  if ((Natural)entry.count) <= maximumCount and bufferSize <= maximumSize:
    let jArray = readValueList(file, entry)
    result = jArray
  else:
    # example string: 135 longs starting at 23456.
    let start = length[uint32](entry.packed, 0, entry.endian)
    var str: string
    if entry.kind == Kind.blob:
      str = "$1 byte blob starting at $2" % [$entry.count, $start]
    else:
      str = "$1 $2 starting at $3" % [$entry.count, $entry.kind, $start]
    result = newJString(str)


proc getImage(ifdOffset: uint32, id: string, tiffImageData: TiffImageData, headerOffset: uint32):
    Option[tuple[image: bool, node: JsonNode, ranges: seq[Range]]] =
  ## Return image node and associated ranges from the imageData or none when no image.

  let im = tiffImageData
  var option = newImageData(im.width, im.height, im.starts, im.counts)
  if option.isNone:
    return
  let imageData = option.get()

  let imageNode = createImageNode(imageData).get()
  assert(imageNode != nil)

  var ranges = newSeq[Range](imageData.pixelOffsets.len)
  var ix = 0
  for start, finish in imageData.pixelOffsets.items():
    ranges[ix] = newRange(start, finish, name = "image")
    ix += 1

  result = some((true, imageNode, ranges))


proc handleEntry(file: File,
    entry: IfdEntry,
    endian: Endianness,
    ifd: var JsonNode,
    nodeList: var seq[tuple[name: string, node: JsonNode]],
    nextList: var seq[tuple[name: string, offset: uint32]],
    tiffImageData: var TiffImageData,
    ranges: var seq[Range]) =

  ## Handle the given IFD entry and add to the provided lists.

  case entry.tag:

  of 256'u16: # ImageWidth
    ifd[$entry.tag] = readValueListMax(file, entry, 10)
    tiffImageData.width = readOneNumber(file, entry)

  of 257'u16: # ImageHeight
    ifd[$entry.tag] = readValueListMax(file, entry, 10)
    tiffImageData.height = readOneNumber(file, entry)

  of 700'u16:
    # Note: The name xmp, exif, iptc are common between image
    # formats. Use the same name so the user can find.

    let name = "xmp"
    ifd[$entry.tag] = newJString(name)
    let blob = readBlob(file, entry)
    let xml = bytesToString(blob, 0, blob.len-1)
    let xmp = xmpParser(xml)
    nodeList.add((name, xmp))

  of 34665'u16: # exif
    ifd[$entry.tag] = newJString("exif")
    let tempList = readLongs(file, entry, 1)
    if tempList.len != 1:
      raise newException(NotSupportedError, "Tiff: more than one exif.")
    nextList.add( ("exif", tempList[0]))

  of 273'u16, 324'u16: # StripOffsets, TileOffsets
    ifd[$entry.tag] = readValueListMax(file, entry, 100)
    tiffImageData.starts = readLongs(file, entry, 10000)

  of 279'u16, 325'u16: # StripByteCounts, TileByteCounts
    ifd[$entry.tag] = readValueListMax(file, entry, 100)
    tiffImageData.counts = readLongs(file, entry, 10000)

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


proc readIFD*(file: File, id: int, headerOffset: uint32, ifdOffset: uint32,
              endian: Endianness, nodeName: string,
              ranges: var seq[Range]): IFDInfo =
  ## Read the Image File Directory at the given offset and return its
  ## metadata information as a list of named nodes. The list contains
  ## at least an IFD node and it may contain other nodes as well. Also
  ## return a list of offsets to other IFDs found. The ranges list is
  ## filled in with the ranges found in the IFD.

  # Create a list of IFD offsets found. The first item in the list is
  # the offset to the next IFD (which may be 0), following that are
  # subifds or exif if there are any.
  var nextList = newSeq[tuple[name: string, offset: uint32]]()

  # The imageData contains information collected across multiple
  # entries used to build the image metadata section. It gets filled
  # in with the image width, height, pixel starts and pixel counts.
  var tiffImageData = TiffImageData(width: -1, height: -1, starts: newSeq[uint32](),
                            counts : newSeq[uint32]())

  # Read all the contiguous IFD bytes into a memory buffer.
  let start: uint32 = headerOffset + ifdOffset
  file.setFilePos((int64)start)
  var numberEntries = (int)readNumber[uint16](file, endian)
  let bufferSize = 12 * numberEntries
  let finish:uint32 = start + (uint32)bufferSize

  ranges.add(newRange(start, finish, name=nodeName, message = "entries"))

  var buffer = newSeq[uint8](bufferSize)
  if file.readBytes(buffer, 0, bufferSize) != bufferSize:
    raise newException(IOError, "Unable to read the file.")

  # Create a list to hold the ifd's list of nodes.
  var nodeList = newSeq[tuple[name: string, node: JsonNode]]()

  # Create an ifd node and add it to the list of nodes.
  var ifd = newJObject()
  nodeList.add((nodeName, ifd))

  # Add IFD start and the next offset into the ifd node dictionary.
  let next = readNumber[uint32](file, endian)
  ifd["offset"] = newJInt((BiggestInt)start)
  ifd["next"] = newJInt((BiggestInt)next)
  if next != 0'u32:
    nextList.add( ("ifd", next))

  # Loop through the IFD entries and process each one.
  if numberEntries > 0:
    for ix in 0..<numberEntries:
      let entry = getIFDEntry(buffer, endian, headerOffset, ix*12)

      let entryStart = headerOffset + ifdOffset + (uint32)(ix * 12)
      let entrySize  = (uint32)(kindSize(entry.kind) * (int)entry.count)
      var externalStart: uint32
      var externalFinish: uint32
      if entrySize > 4'u32:
        externalStart = length[uint32](entry.packed, 0, entry.endian)
        externalFinish = externalStart + entrySize
        ranges.add(newRange(externalStart, externalFinish, name=nodeName,
                            message=tagName(entry.tag)))

      try:
        handleEntry(file, entry, endian, ifd, nodeList, nextList, tiffImageData, ranges)
      except NotSupportedError:
        # Add the not supported entry as unknown to the ranges list.
        let error = getCurrentExceptionMsg()
        let name = nodeName & "-e"
        let message = "tag-" & $entry.tag & " " & error
        var start, finish: uint32
        if entrySize > 4'u32:
          start = externalStart
          finish = externalFinish
        else:
          start = entryStart
          finish = start + 12
        ranges.add(newRange(start, finish, name, false, message))

  # If the image exists, add its node and ranges.
  let oImage = getImage(ifdOffset, $id, tiffImageData, headerOffset)
  if isSome(oImage):
    let (image, imageNode, imageRanges) = oImage.get()
    nodeList.add(("image", imageNode))
    for item in imageRanges:
      ranges.add(item)

  # sort(ranges, cmpRanges)

  result = IFDInfo(nodeList: nodeList, nextList: nextList)


proc readExif*(file: File, headerOffset: uint32, finish: uint32,
               ranges: var seq[Range]): Metadata =
  ## Parse the exif bytes and return its metadata.  The ranges list is
  ## filled in with the ranges found in the IFD.

  # echo "current file pos = " & $getFilePos(file)
  # echo "headerOffset = " & $headerOffset
  # echo "finish = " & $finish

  # let buffer = readSection(file, start, finish)
  # echo hexDump(buffer)
  # raise newException(NotSupportedError, "exif: unknown format")

  var ifdRanges = newSeq[Range]()
  let (ifdOffset, endian) = readHeader(file, headerOffset)
  ranges.add(newRange(headerOffset, headerOffset+8'u32, "exif", true, "header"))

  let ifdInfo = readIFD(file, 1, headerOffset, ifdOffset, endian, "exif", ifdRanges)
  if ifdInfo.nodeList.len != 1:
    raise newException(NotSupportedError, "exif: more than one IFD.")
  # todo: support more than one ifd in exif. ifdInfo.nextList
  result = ifdInfo.nodeList[0].node

  # Add in the gaps.
  ifdRanges.add(newRange(headerOffset, headerOffset, name = "border"))
  ifdRanges.add(newRange((uint32)finish, (uint32)finish, name = "border"))
  let (_, gaps) = mergeOffsets(ifdRanges)
  for start, finish in gaps.items():
    let gapHex = readGap(file, start, finish)
    ifdRanges.add(Range(name: "gap", start: start, finish: finish,
                   known: false, message:gapHex))
  for range in ifdRanges:
    if range.name != "border":
      ranges.add(range)


proc readTiff*(file: File): Metadata =
  ## Read the given Tiff file and return its metadata.  Return
  ## UnknownFormatError when the file format is unknown. May return
  ## NotSupportedError exception.

  var ranges = newSeq[Range]()
  result = newJObject()
  var dups = initTable[string, int]()

  # Read the header.
  const headerOffset:uint32 = 0
  let (ifdOffset, endian) = readHeader(file, headerOffset)
  ranges.add(newRange(headerOffset, headerOffset+8'u32, "header", true, ""))

  # Read all the IFDs.
  var id = 1
  let ifdInfo = readIFD(file, id, headerOffset, ifdOffset, endian, "ifd1", ranges)
  for name, node in ifdInfo.nodeList.items():
    addSection(result, dups, name, node)
  for ifdName, offset in ifdInfo.nextList.items():
    if offset != 0:
      id = id + 1
      let ifdInfo = readIFD(file, id, headerOffset, offset, endian, ifdName & $id, ranges)
      for nodeName, node in ifdInfo.nodeList.items():
        addSection(result, dups, nodeName, node)

  let fileSize = (uint32)file.getFileSize()
  let rangesNode = createRangesNode(file, headerOffset, fileSize, ranges)
  addSection(result, dups, "ranges", rangesNode)

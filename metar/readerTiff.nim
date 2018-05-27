# See: test_readerTiff.nim(0):

##[
`Home <index.html>`_

readerTiff
==========

The readerTiff module reads TIFF images and returns its metadata. It
implements the reader interface.

]##

import metadata
import tpub
import strutils
import tiff
import tables
import json
import algorithm
import hexDump

proc keyNameTiff(section: string, key: string): string {.tpub.} =
  ## Return the name of the key for the given section of metadata or
  ## "" when not known.
  var tag: uint16
  try:
    tag = (uint16)key.parseUInt()
  except:
    return ""
  result = tagName(tag)

proc addSection(metadata: var Metadata, dups: var Table[string, int],
                sectionName: string, info: JsonNode) {.tpub.}  =
  ## Add the section to the given metadata.  If the section already
  ## exists in the metadata, put it in an array.

  if sectionName in dups:
    # More than one, store them in an array.
    var existingInfo = metadata[sectionName]
    if existingInfo.kind != JArray:
      var jarray = newJArray()
      jarray.add(existingInfo)
      existingInfo = jarray
    existingInfo.add(info)
    metadata[sectionName] = existingInfo
  else:
    metadata[sectionName] = info
  dups[sectionName] = 1

proc appendRanges(ranges: JsonNode, node: JsonNode) =
  ## Append the range node items to the bottom of the ranges list.

  assert(ranges.kind == JArray)
  assert(node.kind == JArray)

  for row in node.items():
    assert(row.kind == JArray)
    assert(row.len == 5)
    ranges.add(row)

proc readGap(file: File, start: uint32, finish: uint32): string =
  ## Read the range of the file and return the hex representation.

  let count = (int)(finish - start)
  var readCount: int
  if count > 8:
     readCount = 8
  else:
    readCount = count
  var buffer = newSeq[uint8](readCount)
  if file.readBytes(buffer, 0, readCount) != readCount:
    raise newException(UnknownFormatError, "Tiff: Unable to read all the gap bytes.")

  result = $count & " gap bytes:"
  for item in buffer:
    result.add(" $1" % [toHex(item)])
  if count != readCount:
    result.add("...")
  result.add("  ")
  for ascii in buffer:
    if ascii >= 0x20'u8 and ascii <= 0x7f'u8:
      result.add($char(ascii))
    else:
      result.add(".")


proc readTiff(file: File): Metadata {.tpub.} =
  ## Read the given Tiff file and return its metadata.  Return
  ## UnknownFormatError when the file format is unknown. May return
  ## NotSupportedError exception.

  var ranges = newSeq[Range]()
  result = newJObject()
  var dups = initTable[string, int]()

  # Read the header.
  const headerOffset:uint32 = 0
  let (ifdOffset, endian) = readHeader(file, headerOffset)
  ranges.add(Range(name: "header", start: headerOffset, finish: headerOffset+8'u32,
                   known: true, message:""))

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

  # Add in the gaps and sort the ranges.
  var offsetList = newSeq[tuple[start: uint32, finish: uint32]](ranges.len)
  for ix, item in ranges:
    offsetList[ix] = (item.start, item.finish)
  let fileSize = (uint32)file.getFileSize()
  offsetList.add((0'u32, 0'u32))
  offsetList.add((fileSize, fileSize))
  let (_, gaps) = mergeOffsets(offsetList)
  for start, finish in gaps.items():
    let gapHex = readGap(file, start, finish)
    ranges.add(Range(name: "gap", start: start, finish: finish,
                   known: false, message:gapHex))
  let sortedRanges = ranges.sortedByIt(it.start)

  # Create a ranges node from the ranges list.
  var rangesNodes = newJArray()
  for item in sortedRanges:
    rangesNodes.add(getRangeNode(item.name, item.start, item.finish, item.known, item.message))
  addSection(result, dups, "ranges", rangesNodes)


const reader* = (read: readTiff, keyName: keyNameTiff)

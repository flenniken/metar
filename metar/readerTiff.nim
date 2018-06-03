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
import tiffTags


proc keyNameTiff(section: string, key: string): string {.tpub.} =
  ## Return the name of the key for the given section of metadata or
  ## "" when not known.
  let name = tagName(key)
  if name == key:
    result = ""
  else:
    result = name


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


proc getRangeNode(name: string, start: uint32, finish: uint32,
              known: bool, error: string): JsonNode =
  ## Add a range to the ranges list.

  result = newJArray()
  result.add(newJString(name))
  result.add(newJInt((BiggestInt)start))
  result.add(newJInt((BiggestInt)finish))
  result.add(newJBool(known))
  result.add(newJString(error))


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
  var offsetList = newSeq[Range](ranges.len)
  for ix, item in ranges:
    offsetList[ix] = newRange(item.start, item.finish)
  let fileSize = (uint32)file.getFileSize()
  offsetList.add(newRange(0'u32, 0'u32))
  offsetList.add(newRange(fileSize, fileSize))
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

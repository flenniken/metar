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
  let ifdInfo = readIFD(file, headerOffset, ifdOffset, endian, "ifd", ranges)
  for name, node in ifdInfo.nodeList.items():
    addSection(result, dups, name, node)
  for ifdName, offset in ifdInfo.nextList.items():
    if offset != 0:
      let ifdInfo = readIFD(file, headerOffset, offset, endian, ifdName, ranges)
      for nodeName, node in ifdInfo.nodeList.items():
        addSection(result, dups, nodeName, node)

  # Create a ranges node from the ranges list.
  var rangesNodes = newJArray()
  for item in ranges:
    rangesNodes.add(getRangeNode(item.name, item.start, item.finish, item.known, item.message))
  addSection(result, dups, "ranges", rangesNodes)


const reader* = (read: readTiff, keyName: keyNameTiff)

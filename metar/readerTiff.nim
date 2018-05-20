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

  result = newJObject()
  var ranges = newJArray()
  var dups = initTable[string, int]()

  const headerOffset:uint32 = 0
  let (ifdOffset, endian) = readHeader(file, headerOffset)
  ranges.add(getRangeNode("header", headerOffset, headerOffset+8'u32, true, ""))

  let ifdInfo = readIFD(file, headerOffset, ifdOffset, endian)
  for item in ifdInfo.nodeList:
    let (name, node) = item
    if name == "ranges":
      appendRanges(ranges, node)
    else:
      addSection(result, dups, name, node)
  for nextTup in ifdInfo.nextList:
    let (nextName, offset) = nextTup
    if offset != 0:
      let ifdInfo = readIFD(file, headerOffset, offset, endian, nextName)
      for item in ifdInfo.nodeList:
        var (name, node) = item
        if name == "ranges":
          appendRanges(ranges, node)
        else:
          addSection(result, dups, name, node)

  addSection(result, dups, "ranges", ranges)


const reader* = (read: readTiff, keyName: keyNameTiff)

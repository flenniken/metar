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
import ranges

proc keyNameTiff(section: string, key: string): string {.tpub.} =
  ## Return the name of the key for the given section of metadata or
  ## "" when not known.
  let name = tagName(key)
  if name == key:
    result = ""
  else:
    result = name


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

  let fileSize = (uint32)file.getFileSize()
  let rangesNode = createRangesNode(file, headerOffset, fileSize, ranges)
  addSection(result, dups, "ranges", rangesNode)


const reader* = (read: readTiff, keyName: keyNameTiff)

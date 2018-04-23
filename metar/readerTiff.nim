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

proc readTiff(file: File): Metadata {.tpub.} =
  result = newJObject()

#[
proc readTiff(file: File): Metadata {.tpub.} =
  ## Read the given Tiff file and return its metadata.  Return
  ## UnknownFormatError when the file format is unknown. May return
  ## NotSupportedError exception.

  result = newJObject()
  var ranges = newJArray()
  var dups = initTable[string, int]()

  # The extra table contains information collected across multiple
  # sections used to build the images metadata section. It gets filled
  # in with the image width, height, start and end pixel offsets.
  var extra = initTable[string, int]()

  const headerOffset:int64 = 0
  let (ifdOffset, endian) = readHeader(file, headerOffset)

  var next = ifdOffset
  var nodeList: seq[JsonNode]
  while next != 0:
    (nodeList, next) = readIFD(file, headerOffset, next, endian)
    for node in nodeList:
      addSection(result, dups, "ifd", node)
]#

    # if ifd.hasKey($SubIFDs):
    #   # todo: recursively call itself instead
    #   var jArray = ifd[$SubIFDs]
    #   for jOffset in jArray.mitems():
    #     let ifdOffset = (int64)jOffset.getInt()
    #     let (ifd, _) = readIFD(file, headerOffset, ifdOffset, endian)

    #     var metadata = newJObject()
    #     metadata["ifd"] = ifd
    #     echo readable(metadata, "tiff")



  # # Add the IFD to the ranges.
  # # name, marker, start, finish, known, error
  # var ranges = newJArray()
  # var rItem = newJArray()
  # rItem.add(newJString("ifd"))
  # rItem.add(newJInt((int)0))
  # rItem.add(newJInt(start))
  # rItem.add(newJInt(start+bufferSize))
  # rItem.add(newJBool(true))
  # rItem.add(newJString(""))
  # ranges.add(rItem)

    # if ifd.hasKey($Exif_IFD):
    #   var jArray = ifd[$Exif_IFD]
    #   var jNumber = jArray[0]
    #   let ifdOffset = (int64)jNumber.getInt()
    #   echo $ifdOffset
    #   (ifd, next) = readIFD(file, headerOffset, ifdOffset, endian)

    #   var metadata = newJObject()
    #   metadata["exif"] = ifd
    #   echo readable(metadata, "tiff")

    # if ifd.hasKey($XMP):
    #   var jArray = ifd[$XMP]
    #   var jNumber = jArray[0]
    #   let ifdOffset = (int64)jNumber.getInt()

    #   var buffer = newSeq[uint8](length)
    #   file.setFilePos(startOffset)
    #   if file.readBytes(buffer, 0, length) != length:
    #     raise newException(IOError, "Unable to read the file.")


    #   let xml = bytesToString(buffer, 0, buffer.len-1)
    #   sectionName = "xmp"
    #   info = xmpParser(xml)

    #   var metadata = newJObject()
    #   metadata["xmp"] = ifd
    #   echo readable(metadata, "tiff")


const reader* = (read: readTiff, keyName: keyNameTiff)

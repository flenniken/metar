
## You use the readMetadata module to read an image file and return
## its metadata. It calls the reader modules to read the metadata and
## it generates the "meta" information section supported by all image
## types.

import os
import json
import tables
import ospaths
import version
import metadata
from readerJpeg import nil
from readerTiff import nil
import tpub
import nimpy

let readers = {
  "jpeg": readerJpeg.reader,
  "tiff": readerTiff.reader,
}.toOrderedTable

proc getMetaInfo(filename: string, readerName: string,
    fileSize: int64, problems: seq[tuple[reader: string,
    message: string]]): Metadata {.tpub.} =
  ## Return the meta information about the file and running system.

  result = newJObject()
  result["filename"] = newJString(extractFilename(filename))
  result["reader"] = newJString(readerName)
  result["size"] = newJInt(fileSize)
  result["version"] = newJString(versionNumber)
  result["nimVersion"] = newJString(NimVersion)
  result["os"] = newJString(hostOS)
  result["cpu"] = newJString(hostCPU)
  var p = newJArray()
  for item in problems:
    var jarray = newJArray()
    var jname = newJString(item.reader)
    var jmessage = newJString(item.message)
    jarray.add(jname)
    jarray.add(jmessage)
    p.add(jarray)
  result["problems"] = p

  var r = newJArray()
  for name in readers.keys():
    r.add(newJString(name))
  result["readers"] = r


proc getMetadata*(filename: string): Metadata =
  ## Read the given file and return its metadata.  Raise
  ## UnknownFormatError when the file format is unknown.
  ##
  ## Open the file and loop through the readers until one returns some
  ## results.

  # Verify we have a normal file, not a blocking pipe, directory, etc.
  if not fileExists(filename):
    raise newException(UnknownFormatError, "File not found.")

  var f: File
  if not open(f, filename, fmRead):
    raise newException(UnknownFormatError, "Cannot open file.")
  defer: f.close()

  # Record the readers that thought they could handle the image but
  # couldn't. These are the ones that raise NotSupportedError.
  var problems = newSeq[tuple[reader: string, message: string]]()

  result = nil
  var readerName: string
  for name, reader in readers.pairs():
    readerName = name
    try:
      result = reader.read(f)
      break
    except UnknownFormatError:
      continue
    except NotSupportedError:
      problems.add((name, getCurrentExceptionMsg()))
      continue

  # Return UnknownFormatError when none of the readers understand the
  # file.
  if result == nil:
    if problems.len == 0:
      raise newException(UnknownFormatError, "File type not recognized.")
    result = newJObject()

  # Add the meta dictionary information to the metadata.
  let fileSize = f.getFileSize()
  result["meta"] = getMetaInfo(filename, readerName, fileSize, problems)


proc keyNameImp*(readerName: string, section: string, key: string):
            string {.exportpy: "key_name".} =
  ## Return the name of the key for the given section of metadata or
  ## "" when not known.
  ##
  ## readerName is the name of the reader, 'jpeg', 'dng', etc. You can
  ## get this from the 'meta' section's reader key. Section is a top
  ## level key, 'xmp', 'iptc', etc. Key is a key in the section
  ## dictionary.
  ##
  ## .. code-block:: nim
  ##   import metar
  ##   echo keyName("dng", "exif", "40961")
  ##   ColorSpace

  if readerName in readers:
    result = readers[readerName].keyName(section, key)
  else:
    return ""

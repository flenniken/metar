
## You use the readers module to read an image file and return
## its metadata. It calls the reader modules to read the metadata and
## it generates the "meta" information section supported by all image
## types.

import os
import json
import version
import metadata
from readerJpeg import nil
from readerTiff import nil
import tpub

type
  # readerProc = proc (file: File): Metadata
  keyNameProc = proc (section: string, key: string): string


let readers = [
  readerJpeg.reader,
  readerTiff.reader,
]


proc readerToKeyName(name: string): keyNameProc =
  for t in readers:
    if t.name == name:
      return t.keyName
  return nil


proc getMetaInfo(filename: string, readerName: string,
    fileSize: int64, problems: seq[tuple[reader: string,
    message: string]]): Metadata {.tpub.} =
  ## Return the meta information about the file and running system.

  result = newJObject()
  result["filename"] = newJString(extractFilename(filename))
  result["reader"] = newJString(readerName)
  result["size"] = newJInt(fileSize)
  result["version"] = newJString(metarVersion)
  result["nimVersion"] = newJString(NimVersion)
  when not defined(release):
    result["build"] = newJString("debug")
  else:
    result["build"] = newJString("release")
  result["os"] = newJString(hostOS)
  result["cpu"] = newJString(hostCPU)
  when defined(buildingLib):
    result["nimpyVersion"] = newJString(nimpyVersion)
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
  for t in readers:
    r.add(newJString(t.name))
  result["readers"] = r


proc getMetadata*(filename: string): tuple[metadata: Metadata, readerName: string] =
  ## Read the given file and return its metadata.  Raise
  ## UnknownFormatError when the file format is unknown.
  ##
  ## Open the file and loop through the readers until one returns some
  ## results.

  # Verify we have a normal file, not a blocking pipe, directory, etc.
  if not fileExists(filename):
    raise newException(UnknownFormatError, "File not found.")

  # Open the file for reading.
  var f: File
  if not open(f, filename, fmRead):
    raise newException(UnknownFormatError, "Cannot open file.")
  defer: f.close()

  # Record the readers that thought they could handle the image but
  # couldn't. These are the ones that raise NotSupportedError.
  var problems = newSeq[tuple[reader: string, message: string]]()

  var metadata: Metadata = nil
  var readerName: string
  for t in readers:
    try:
      metadata = t.reader(f)
      # The readerName is set when the reader understands the file
      # format.
      readerName = t.name
      break
    except UnknownFormatError:
      continue
    except NotSupportedError:
      # This reader is used if none of the other readers can handle
      # the file.
      readerName = t.name
      problems.add((readerName, getCurrentExceptionMsg()))
      continue

  # Return UnknownFormatError when none of the readers understand the
  # file.
  if metadata == nil:
    if problems.len == 0:
      raise newException(UnknownFormatError, "File type not recognized.")
    metadata = newJObject()

  # Add the meta dictionary information to the metadata.
  let fileSize = f.getFileSize()
  metadata["meta"] = getMetaInfo(filename, readerName, fileSize, problems)
  result = (metadata, readerName)


proc keyName*(readerName: string, section: string, key: string):
            string =
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

  let keyNameProc = readerToKeyName(readerName)
  if keyNameProc == nil:
    result = ""
  else:
    result = keyNameProc(section, key)

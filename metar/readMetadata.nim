##[
`Home <index.html>`_

readMetadata
==========

The readMetadata module reads an image file and returns its
metadata. It calls the reader modules and generates the "meta"
information section supported by all image types.

]##

import json
import tables
import version
import metadata
import readerJpeg
import readerDng
import readerTiff

let readers = {
  # name: (name, Reader method, KeyName method)
  "jpeg": ("jpeg", readJpeg, jpegKeyName),
  "dng": ("dng", readDng, dngKeyName),
  "tiff": ("tiff", readTiff, tiffKeyName),
}.toOrderedTable

proc printMetadata*(metadata: Metadata) =
  ## Print human readable metadata.
  echo "printing metadata"

proc printMetadataJson*(metadata: Metadata) =
  ## Print metadata as JSON.
  echo pretty(metadata)

proc getMetaInfo(filename: string, readerName: string, fileSize: int64):
                Metadata =
  ## Return the meta information about the file and running system.

  result = newJObject()
  result["filename"] = %* filename
  result["reader"] = %* readerName
  result["size"] = %* fileSize
  result["version"] = %* versionNumber
  result["nimVersion"] = %* NimVersion
  result["os"] = %* hostOS
  result["cpu"] = %* hostCPU

proc readMetadata*(filename: string): Metadata =
  ## Read the given file and return its metadata.  When the file
  ## format is unknown, return nil.
  ##
  ## Open the file and loop through the readers until one returns some
  ## results.
  ##
  ## .. code-block:: nim
  ##   import metar
  ##   md = readMetadata("filename.jpg")
  ##   meta = md["meta"]
  ##   echo "reader = " & meta["reader"]
  ##   reader = jepg

  result = nil
  var f: File
  if not open(f, filename, fmRead):
    return
  defer: f.close()

  var readerName: string
  for readerName, reader, _ in readers.values():
    try:
      result = reader(f)
      if result != nil:
        break
    except UnknownFormatError:
      continue
    except NotSupportedError:
      echo "Not supported: " & getCurrentExceptionMsg()
      continue

  # Add the meta dictionary information to the metadata.
  let fileSize = f.getFileSize()
  result["meta"] = %* getMetaInfo(filename, readerName, fileSize)


proc keyName*(readerName: string, section: string, key: string): string =
  ## Return the name of the key for the given section of metadata or
  ## nil when not known.
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

  let (_, _, keyNameMethod) = readers.getOrDefault(readerName)
  if keyNameMethod == nil:
    return nil
  result = keyNameMethod(section, key)

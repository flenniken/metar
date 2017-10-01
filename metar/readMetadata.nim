## Read an image file and return metadata information.

import json
import tables
import version

type
  UnknownFormat* = object of Exception ## \
  ## UnknownFormat is raised when the image is not recognized. The
  ## image is recognized quickly by looking at the first few bytes of
  ## the file.

  NotSupported* = object of Exception ## \
  ## The reader recognized the image but it cannot handle it.  The
  ## image might be corrupt or using a feature the reader does not
  ## understand. NotSupported is raised when the reader cannot
  ## continue.

  Metadata* = JsonNode ## \
  ## Json representation of the metadata.

  Reader* = proc (file: File): Metadata ## \
  ## A procedure to read the given file and return its metadata.
  ## Return nil when the file format is unknown.  Readers can also
  ## generate UnknownFormat and NotSupported exceptions.

  KeyName* = proc (section: string, key: string): string ## \
  ## A procedure to return the name of the key for the given section
  ## of metadata or nil when not known.

proc readJpeg(file: File): Metadata =
  return nil
proc readDng(file: File): Metadata =
  return nil
proc readTiff(file: File): Metadata =
  return nil

proc jpegKeyName(section: string, key: string): string =
  return nil
proc dngKeyName(section: string, key: string): string =
  return nil
proc tiffKeyName(section: string, key: string): string =
  return nil

#var item = tuple[name: string, readm: Reader, keyn: KeyName]
var readers = {
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

  # Open the file and loop through the readers until one returns some
  # results.

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
    except UnknownFormat:
      continue
    except NotSupported:
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

  let (_, _, keyNameMethod) = readers.getOrDefault(readerName)
  if keyNameMethod == nil:
    return nil
  result = keyNameMethod(section, key)

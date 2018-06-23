
## The readerDng module reads DNG images and returns its metadata. It
## implements the reader interface.

import metadata
import tpub

proc readDng(file: File): Metadata {.tpub.} =
  ## Read the given JPEG file and return its metadata.  Return
  ## UnknownFormatError when the file format is unknown. May return
  ## NotSupportedError exception.
  raise newException(UnknownFormatError, "Dng: not implemented.")

proc keyNameDng(section: string, key: string): string {.tpub.} =
  ## Return the name of the key for the given section of metadata or
  ## "" when not known.
  return ""

const reader* = (read: readDng, keyName: keyNameDng)

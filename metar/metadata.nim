
## The metadata module contains types used by the metadata reader
## modules.
##
## Each metadata reader reads the meatadata from a file of their type
## and returns the metadata it contains. A reader implements the
## reader interface.
##
## The reader interface contains two procedures called read and keyName.
## The read procedure takes a file parameter and returns metadata as a
## JsonNode. The keyName procedure returns the name of a key. A reader module exposes the two procedures in a reader tuple.  For example:
##
## .. code-block:: nim
##   proc readJpeg(file: File): Metadata
##   proc keyNameJpeg(section: string, key: string): string
##   const reader* = (read: readJpeg, keyName: keyNameJpeg)


import json

type
  UnknownFormatError* = object of Exception ## \
  ## UnknownFormatError is raised when the image is not recognized. The
  ## image is recognized quickly by looking at the first few bytes of
  ## the file.

  NotSupportedError* = object of Exception ## \ The reader recognized
  ## the image but it cannot handle it.  The image might be corrupt or
  ## the reader cannot decode the file.  NotSupportedError is raised
  ## when the reader cannot continue. Readers are forgiving, they skip
  ## sections they do not understand and mark the unknown sections in
  ## the ranges.

  Metadata* = JsonNode ## \
  ## Representation of the metadata using a subset of json.
  ##
  ## Metadata is an ordered dictionary where each item is called a
  ## section. For example: meta, xmp, iptc sections.
  ##
  ## * A section is either an ordered dictionary or a list of dictionaries.
  ## * A dictionary contains strings, numbers, arrays or dictionaries.
  ## * An array contains strings, numbers, arrays or dictionaries.
  ## * No booleans, or nulls.
  ##
  ## .. code-block::
  ##   {
  ##     "meta": {}
  ##     "xmp": {}
  ##     "iptc": {}
  ##     "sof": [{},{},...]
  ##   }

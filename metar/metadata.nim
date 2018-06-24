
## The metadata module contains types used by the metadata reader
## modules.
##
## Each metadata reader reads the metadata from a file of their type
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
##
## The Read procedure reads the given file and returns its
## metadata. If the file format is unknown the UnknownFormatError is
## raised.  If the file is the correct type, but it cannot be handled,
## then NotSupportedError is raised. If the reader can handle the file
## but it has problem parts, the problems are noted in the "meta"
## section "problems" key, which is an array of problem strings.
##
## The keyName procedure returns the name of a key in the
## metadata. For example the Tiff reader IFD sections use number
## strings as keys.  You can translate the numbers to readable
## strings, "256" to "ImageWidth". Some sections use readable strings,
## in this case keyName returns the original name. The jpeg SOF
## section would return "precision" for "precision".


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
  ##     "ranges": {}
  ##   }
  ##
  ## The meta section is not created by the reader but the reader
  ## fills in the problems item if it finds problem areas in the file.
  ##
  ## Each reader is responsible for creating an images section. It
  ## contains the images found in the file. Each image has a width,
  ## height and pixels entry.
  ##
  ## Each reader is responsible for creating a ranges section. The
  ## ranges section discribes each section (range) of the file and
  ## whether it is known by the reader, where it is in the file, and
  ## what it is for.

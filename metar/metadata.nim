
## The metadata module contains types used by the metadata reader
## modules.
##
## Each metadata reader reads the metadata from a file of their type
## and returns the metadata it contains. A reader implements the
## reader interface.
##

import json

type
  UnknownFormatError* = object of ValueError ## \
  ## UnknownFormatError is raised when the image is not recognized. The
  ## image is recognized quickly by looking at the first few bytes of
  ## the file.

  NotSupportedError* = object of ValueError ## \ The reader recognized
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
  ## The meta section is not created by the reader. It contains
  ## information about the environment.
  ##
  ## Each reader is responsible for creating an images section. It
  ## contains the images found in the file. Each image has a width,
  ## height and pixels entry.
  ##
  ## Each reader is responsible for creating a ranges section. The
  ## ranges section discribes each section (range) of the file and
  ## whether it is known by the reader, where it is in the file, and
  ## what it is for.

  Reader* = object
    ## The Reader interface contains two procedures called reader and
    ## keyName.
    ##
    ## The reader procedure reads the given file and returns its
    ## metadata. If the file format is unknown the UnknownFormatError
    ## is raised.  If the file is the correct type, but it cannot be
    ## handled, then NotSupportedError is raised and the problem is
    ## noted in the "meta" section "problems" key, which is a list
    ## of problem strings. The reader is forgiving, if it doesn't
    ## understand part of the file it continues if possible, and notes
    ## the unknown sections in the ranges section.
    ##
    ## The keyName procedure returns the name of a key in the
    ## metadata. For example the Tiff reader IFD sections use number
    ## strings as keys.  You can translate the numbers to readable
    ## strings, "256" to "ImageWidth". Some sections use readable strings,
    ## in this case keyName returns the original name. The jpeg SOF
    ## section would return "precision" for "precision".
    name*: string
    reader*: proc (file: File): Metadata
    keyName*: proc (section: string, key: string): string

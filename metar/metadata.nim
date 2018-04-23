##[
`Home <index.html>`_

metadata
=====

The metadata module contains types used by the metadata reader
modules. It defines the interface required to be a reader.

]##

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

  # Read* = proc (file: File): Metadata ## \ Read the given file and
  # ## return its metadata.  Return UnknownFormatError when the file
  # ## format is unknown. May return NotSupportedError exception.

  # KeyName* = proc (section: string, key: string): string ## \
  # ## Return the name of the key for the given section of metadata or
  # ## "" when not known.

  Args* = tuple[files: seq[string], json: bool, help: bool, version: bool] ## \
  ## Command line arguments.  A list of filenames, and booleans for
  ## json, help and version output.

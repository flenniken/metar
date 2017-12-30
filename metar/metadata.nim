##[
`Home <index.html>`_

metadata
=====

The metadata module implements types used by the metadata reader
modules. It defines the interface required to be a reader.

]##

import json

type
  UnknownFormatError* = object of Exception ## \
  ## UnknownFormatError is raised when the image is not recognized. The
  ## image is recognized quickly by looking at the first few bytes of
  ## the file.

  NotSupportedError* = object of Exception ## \
  ## The reader recognized the image but it cannot handle it.  The
  ## image might be corrupt or using a feature the reader does not
  ## understand. NotSupportedError is raised when the reader cannot
  ## continue.

  Metadata* = JsonNode ## \
  ## Json representation of the metadata.

  Reader* = proc (file: File): Metadata ## \
  ## Read the given file and return its metadata.  Return nil when the
  ## file format is unknown. It may generate UnknownFormatError and
  ## NotSupportedError exceptions.

  KeyName* = proc (section: string, key: string): string ## \
  ## Return the name of the key for the given section of metadata or
  ## nil when not known.

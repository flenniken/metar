##[
`Home <index.html>`_

readerDng
==========

The readerDng module reads DNG images and returns its metadata. It
implements the reader interface.

]##

import metadata

proc readDng*(file: File): Metadata =
  ## Read the given file and return its metadata.  Return nil when the
  ## file format is unknown. It may generate UnknownFormatError and
  ## NotSupportedError exceptions.
  return nil

proc dngKeyName*(section: string, key: string): string =
  ## Return the name of the key for the given section of metadata or
  ## nil when not known.
  ##
  ## .. code-block:: nim
  ##   import readerJpeg
  ##   echo dngKeyName("ifd0", "256")
  ##   ImageWidth
  return nil

import metadata

## Read jpeg images and return its metadata.

proc readJpeg*(file: File): Metadata =
  ## Read the given file and return its metadata.  Return nil when the
  ## file format is unknown. It may generate UnknownFormat and
  ## NotSupported exceptions.
  return nil

proc jpegKeyName*(section: string, key: string): string =
  ## Return the name of the key for the given section of metadata or
  ## nil when not known.
  return nil

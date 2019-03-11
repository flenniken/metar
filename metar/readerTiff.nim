# See: test_readerTiff.nim(0):

## The readerTiff module reads TIFF images and returns its
## metadata. It implements the reader interface.

import metadata
import tiff
import tiffTags

let reader* = Reader(name: "tiff", reader: readTiff, keyName: keyNameTiff)

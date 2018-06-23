# See: test_readerTiff.nim(0):

## The readerTiff module reads TIFF images and returns its
## metadata. It implements the reader interface.

import tiff
import tiffTags

const reader* = (read: readTiff, keyName: keyNameTiff)

# See: test_readerTiff.nim(0):

##[
`Home <index.html>`_

readerTiff
==========

The readerTiff module reads TIFF images and returns its metadata. It
implements the reader interface.

]##

import tiff
import tiffTags

const reader* = (read: readTiff, keyName: keyNameTiff)

=================
 Metar
=================

Library & Program
=================

Metar is a library and command line program for reading image metadata.

It reads JPEG, DNG and TIFF images and it understands the standard
image metadata formats: XMP, IPTC, Exif, and Tiff tags.

API Documentation
=================

`metar <metar.html>`_ -- how to use the public procedures.

`index <theindex.html>`_ -- index to all the modules, procedures
and variables.


Install
=================

todo: add install instructions after posting it.


Command Line Usage
=================

You can display the command line usage information running metar
without any parameters.  For example::

  metar

  Show metadata information for the given image(s).
  Usage: metar [-j] [-v] file [file...]
  -j --json     Output JSON data.
  -v --version  Show the version number.
  -h --help     Show this help.
  file          Image filename to analyze.

You can display image metadata like this::

  metar testfiles/image.dng

  ========== ifd1 ==========
  offset = 8
  next = 0
  NewSubfileType(254) = [1]
  ImageWidth(256) = [256]
  ImageHeight(257) = [171]
  BitsPerSample(258) = [8, 8, 8]
  Compression(259) = [1]
  PhotometricInterpretation(262) = [2]
  Make(271) = ["Canon"]
  Model(272) = ["Canon EOS 20D"]
  ...

Only the first few lines are shown in the example above to save
space.  For this image there are 291 lines::

  metar testfiles/image.dng | wc -l
  291

Python
=================

You can use the metar python module to read image file metadata.

Metar contains four public methods: get_version, key_name,
read_metadata and read_metadata_json.

::
   
  >>> import metar
  >>> dir(metar)
  ['__doc__', '__file__', '__name__', '__package__',
  'get_version', 'key_name', 'read_metadata', 'read_metadata_json']

The metar module has help documentation in doc strings.

::

  >>> help(metar)

You can determine the metar version number with the get_version
function:

::

  >>> metar.get_version()
  '0.0.4'

You can read the metadata from jpeg and tiff image files using
the read_metadata and read_metadata_json functions.

The read_metadata_json function returns the metadata as a JSON
string. You can load that into a python dictionary with the json
loads function.

::

  >>> filename = "testfiles/IMG_6093.JPG"
  >>> string = metar.read_metadata_json(filename)
  >>> import json
  >>> metadata = json.loads(string)

Then you can extract the metadata you are interested in from the
dictionary.

::
   
  >>> image = metadata['image']
  >>> print('width = %s' % image['width'])
  width = 3329
  >>> print('height = %s' % image['height'])
  height = 2219


The read_metadata function returns a more human readable string.

::
   
  >>> string = metar.read_metadata(filename)
  >>> print(string[0:84]+'\n...')
  ========== APP0 ==========
  id = "JFIF"
  major = 1
  minor = 2
  units = 1
  x = 240
  y = 240
  ...

Reader Processing and Error Handling
=================

Metar loops through its readers jpeg and tiff (in the future
there could be many more readers, png, gif, etc).  The reader
quickly checks that the file is one that it understands by
looking at the first few bytes of the file.  For unrecognized
images it generates an UnknownFormatError and the next reader
runs.

If the reader understands the image, it reads the file's bytes
and generates the metadata. Image file formats are complicated
and have many different versions. The reader might not know how
to read every part of the file, especially while under
development.  If the reader comes across a part of the file it
doesn't no how to read, it marks that part as unknown and
continues. You can see the unknown parts in the ranges section
marked with an asterisk.

As the reader is processing the metadata and it finds a problem
in the image that it doesn't know how to recover from and
continue, it generates a NotSupportedError. The error is recorded
in the meta section problems list.  Then the next reader runs.

If no reader understands the image file, an empty string is
returned for the metadata.

  
Metadata Structure
=================

Metar returns metadata as a json dictionary. The dictionary consists of
key, value pairs called sections. The key is the section name and
the value contains the section information.

Metadata is an ordered dictionary where each item is called a
section. For example: meta, xmp, iptc, etc., sections.

* A section is either an ordered dictionary or a list of dictionaries.
* A dictionary contains strings, numbers, arrays or dictionaries.
* An array contains strings, numbers, arrays or dictionaries.
* No booleans, or nulls.

The metadata always contains the sections: images, ranges, meta
and these have a clearly defined format (see below). The sections
xmp, iptc and exif are common image metadata formats and you may
see them in both jpeg and tiff. Depending on the reader and the
image contents, you may see other sections as well.


Images Section
=================

The meta section contains information about the images inside the
image file. Jpeg files typically has one image.  Tiff files
typically have two or more. The image section is generated by all
image readers.  You can look here to determine the number of
images, to deterine their dimensions and to determine the byte
offsets of the image pixels.

Here is a sample image section for a dng image::

  ========== image ==========
  -- 1 --
  width = 256
  height = 171
  pixels = [[37312, 168640]]
  -- 2 --
  width = 3596
  height = 2360
  pixels = [[261420, 6777513]]
  -- 3 --
  width = 1024
  height = 683
  pixels = [[168640, 261420]]

* width -- the width of the image in pixels.
* height -- the height of the image in pixels.
* pixels -- a list of file offsets telling where the image pixels
  are in the file. Each tuple is a half open interval, [start,
  finish).

The Meta Section
=================

The meta section contains information about the environment.

Here is a sample meta section::
  
  ========== meta ==========
  filename = "image.jpg"
  reader = "jpeg"
  size = 2198
  version = "0.0.4"
  nimVersion = "0.19.0"
  os = "macosx"
  cpu = "amd64"
  problems = []
  readers = ["jpeg", "tiff"]

* filename -- the basename of the image file.
* reader -- the metar reader that generated the metadata.
* size -- the image file size in bytes.
* version -- the metar version number.
* nimVersion -- the nim compiler used to build metar.
* os -- the system OS.
* cpu -- the system CPU.
* problems -- a list of problems, for example: [['jpeg', "corrupt
  file at offset 2345"]]. Each problem entry contains the reader
  name, and the error message. You will see entries when a reader
  identified the file as one it understands but it encountered a
  unrecoverable problem when decoding the file.
* readers -- the list of available readers. The readers are
  processed in the order listed.

Ranges Section
=================

Xmp Section
=================

Exif Section
=================

Iptc Section
=================

Scan Disk for Images
=================

You can use metar to scan you disk and count image files it
recognizes.  The following command counts how many image are in
your home folder on linux. It uses the find command to list all
the files in your home folder then feed them to metar. It uses
grep, sort and uniq to origanize them by image type. On my
machine there are 5523 jpegs and 2207 tiff files::

  find ~ -type f -print0 | xargs -0 bin/metar | grep '^reader =' | sort | uniq -c

  5523 reader = "jpeg"
  2207 reader = "tiff"

The ranges section marks unknown ranges with a asterisk. As a
metar developer you may want to find areas to improve. You can
search for these unknown areas in all your files. For example to
search all the files in the testfiles folder use a command
similar to the following command::

  find testfiles -type f | xargs bin/metar | grep '^[a-zA-Z0-9]\+\* \|^file:'

The output is shown below. In this test several unknown ranges
were found. The APPD section has an unknown marker byte, the iptc
section has an unknown header and APP2 is unknown and some
unknown gaps.::
  
  ...
  file: testfiles/IMG_6093.JPG
  gap*   (2191, 2192) 1 gap byte: 00  .
  gap*   (2240, 4664) 2424 gap bytes: 6E 6F 6E 00 43 61 6E 6F...  non.Cano
  gap*   (4750, 4796) 46 gap bytes: 68 00 69 00 73 00 20 00...  h.i.s. .
  APPD*  (4796, 4948) Iptc: marker not 0x1c.
  iptc*  (4818, 4824) unknown header bytes
  APP2*  (4948, 5526)
  ...

=================
Metar Processing Details
=================

* `Reader Processing and Error Handling`_
* `Metadata Structure`_
* `Required & Common Sections`_
* `Image Section`_
* `The Meta Section`_
* `Ranges Section`_
* `Xmp Section`_
* `Exif Section`_
* `Iptc Section`_
* `Key Names`_
* `Scan Disk for Images`_
     
Reader Processing and Error Handling
=================

To read metadata, metar loops through its readers, jpeg and tiff
(in the future there could be many more readers, png, gif, etc).
The reader quickly checks that the file is one that it
understands by looking at the first few bytes of the file.  For
unrecognized images it generates an UnknownFormatError and the
next reader runs.

If the reader understands the image, it reads the file's bytes
and generates the metadata. Image file formats are complicated
and have many different versions. The reader might not know how
to read every part of the file, especially while under
development.  If the reader comes across a part of the file it
doesn't know how to read, it marks that part as unknown and
continues. You can see the unknown parts in the ranges section
lines marked with an asterisk.

As the reader is processing the metadata it might encounter a
problem in the image that it cannot recover from. In this case it
generates a NotSupportedError and the error is recorded in the meta
section problems list.  Then the next reader runs.

If no reader understands the image file, an empty string is
returned for the metadata.

  
Metadata Structure
=================

Metar returns metadata as an ordered json dictionary. The
dictionary consists of key, value pairs called sections. The key
is the section name and the value contains the section
information. Example section keys: "meta", "xmp", "iptc", "ranges".

In a json sudo notation::

  metadata = {
    key: sectionValue,  # section 1
    key: sectionValue,  # section 2
    key: sectionValue,  # section 3
    ...
  }

A section value is either an ordered dictionary or a list of dictionaries::

  sectionValue = {} or
  sectionValue = [{}, {}, {},...]

A sectionValue dictionary contains strings, numbers, lists or dictionaries::

  dict = {
    key, number,
    key, string,
    key, [],  # list
    key, {},  # dictionary
    ...
  }

A list contains strings, numbers, lists or dictionaries::

  list = [number, string, [], {}, ...]

Unlike regular JSON, no booleans, or nulls are used.

Required & Common Sections
=================

The metadata always contains the following three sections and
these have a clearly defined format as documented below:

* image
* ranges
* meta
  
The xmp, iptc and exif sections are common image metadata formats
and you may see them in both jpeg and tiff.

* xmp
* iptc
* exif

Depending on the reader and the image contents, you may see other
sections as well.


Image Section
=================

The image section always exist and it contains information about
the images inside the image file. The section must have at least
one image. Jpeg files typically have one, Tiff files typically
have two or more.  You can look here to determine the number of
images, their dimensions and the byte offsets of the image
pixels.

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

Image Fields:

* width -- the width of the image in pixels.
* height -- the height of the image in pixels.
* pixels -- a list of file offsets telling where the image pixels
  are in the file. Each tuple is a half open interval, [start,
  finish).

The Meta Section
=================

The meta section always exists and it contains information about
the environment.

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

These fields always exist:

* filename -- the basename of the image file.
* reader -- the metar reader that generated the metadata.
* size -- the image file size in bytes.
* version -- the metar version number following Semantic
  Versioning 2.0.0, see https://semver.org/. When new sections
  and fields are added, the minor version number is
  incremented. If any previous required section or field is
  removed or modified that is an incompatible change and the
  major version number is increased.  Care is taken to only make
  backward compatible changes.
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

The ranges section always exists. It describes the file as a list
of byte ranges. You can determine where the section exist in the
file.  It shows the unknown as well as known ranges.

Here is a sample ranges section from a Jpeg image::

  ========== ranges ==========
  SOI    (0, 2) 
  APP0   (2, 20) 
  APPE   (20, 36) 
  exif   (36, 46) id
  exif   (46, 54) header
  exif   (54, 162) entries
  exif   (122, 2182) Padding(59932)
  exif   (2182, 2191) ImageDescription(270)
  gap*   (2191, 2192) 1 gap byte: 00  .
  exif   (2192, 2198) Make(271)
  exif   (2198, 2212) Model(272)
  exif   (2212, 2232) ModifyDate(306)
  exif   (2232, 2240) Artist(315)
  gap*   (2240, 4664) 2424 gap bytes: 6E 6F 6E 00 43 61 6E 6F...  non.Cano
  exif   (4664, 4682) XPTitle(40091)
  exif   (4682, 4750) XPComment(40092)
  gap*   (4750, 4796) 46 gap bytes: 68 00 69 00 73 00 20 00...  h.i.s. .
  iptc   (4796, 4818) header
  APPD*  (4796, 4948) Iptc: marker not 0x1c.
  iptc*  (4818, 4824) unknown header bytes
  iptc   (4824, 4826) header
  iptc   (4826, 4843) 65
  iptc   (4843, 4856) Keywords(25)
  iptc   (4856, 4866) Keywords(25)
  iptc   (4866, 4877) Keywords(25)
  iptc   (4877, 4919) Description(120)
  iptc   (4919, 4933) Title(5)
  iptc   (4933, 4947) Headline(105)
  APP2*  (4948, 5526) 
  xmp    (5526, 11794) 
  DQT    (11794, 11863) 
  DQT    (11863, 11932) 
  SOF0   (11932, 11951) 
  DHT    (11951, 11984) 
  DHT    (11984, 12167) 
  DHT    (12167, 12200) 
  DHT    (12200, 12383) 
  DRI    (12383, 12389) 
  SOS    (12389, 12403) 
  scans  (12403, 758218) 
  EOI    (758218, 758220)

Each line describes a byte range of the file. The lines are
sorted.

Range columns:

* the first column is the name of the range. Often it is a
  section name. You can see where the section comes from in the
  file. If the reader leaves out a range, it appears here as a gap
  range and is marked with an asterisk.
* the next optional column is an asterisk.  The asterisk means
  the reader did not understand this part of the file.
* the next column, [start, finish) is the offset of the beginning
  of the range and finish is one past the end.
* the next optional column is a description of the range.


Xmp Section
=================

The Extensible Metadata Platform (XMP) is an ISO standard for
storing metadata in files. The format incorporates the exif, iptc and
other metadata so it is the most complete. It is an xml format
that metar converts to a key value dictionary.

Here is a sample xmp section from a dng image::

  ========== xmp ==========
  xpacket:begin = "﻿"
  xpacket:id = "W5M0MpCehiHzreSzNTczkc9d"
  crs:Version = "3.2"
  crs:RawFileName = "IMG_6093.dng"
  crs:WhiteBalance = "As Shot"
  crs:Temperature = "5000"
  crs:Tint = "0"
  crs:Exposure = "-0.20"
  --snip--
  exif:Function = "False"
  exif:RedEyeMode = "False"
  aux:SerialNumber = "620423455"
  aux:LensInfo = "24/1 70/1 0/0 0/0"
  aux:Lens = "24.0-70.0 mm"
  aux:ImageNumber = "205"
  aux:FlashCompensation = "0/1"
  xap:MetadataDate = "2014-10-14T20:32:57-07:00"
  dc:creator = ["unknown"]
  xpacket:end = "w'?"
  xmlns:x = "adobe:ns:meta/"
  x:xmptk = "XMP toolkit 3.0-28, framework 1.6"
  xmlns:rdf = "http://www.w3.org/1999/02/22-rdf-syn...
  xmlns:iX = "http://ns.adobe.com/iX/1.0/"
  xmlns:crs = "http://ns.adobe.com/camera-raw-setti...
  xmlns:exif = "http://ns.adobe.com/exif/1.0/"
  xmlns:aux = "http://ns.adobe.com/exif/1.0/aux/"
  xmlns:pdf = "http://ns.adobe.com/pdf/1.3/"
  xmlns:photoshop = "http://ns.adobe.com/photoshop/1.0/"
  xmlns:tiff = "http://ns.adobe.com/tiff/1.0/"
  xmlns:xap = "http://ns.adobe.com/xap/1.0/"
  xmlns:dc = "http://purl.org/dc/elements/1.1/"

Exif Section
=================

Exchangeable image file format (Exif) is a standard metadata
format used by digital camera and others. It is encoded in the
file using tiff tags.

Note:

  As you can see from the example data below, a lot of the
  information doesn't mean much to the casual user.  You can puzzle
  out the meaning of some of fields like the date/time, version
  number, ISO, but others like exposure time, fnumber mean
  little. Metar extracts and shows the file metadata content with
  very little interpretation.  Metar's current focus is to extract and
  decode as much information it can from the files. Interpreting at
  a higher level can be implemented post processing metar metadata.

Here is a sample exif section from a dng image::

  ========== exif4 ==========
  offset = 36962
  next = 0
  ExposureTime(33434) = [[1, 40]]
  FNumber(33437) = [[28, 10]]
  ExposureProgram(34850) = [2]
  ISO(34855) = [100]
  ExifVersion(36864) = [48, 50, 50, 49]
  DateTimeOriginal(36867) = ["2014:10:04 06:14:16"]
  CreateDate(36868) = ["2014:10:04 06:14:16"]
  ShutterSpeedValue(37377) = [[5321928, 1000000]]
  ApertureValue(37378) = [[2970854, 1000000]]
  ExposureCompensation(37380) = [[0, 2]]
  MeteringMode(37383) = [1]
  Flash(37385) = [16]
  FocalLength(37386) = [[27, 1]]
  FocalPlaneXResolution2(41486) = [[3504000, 885]]
  FocalPlaneYResolution2(41487) = [[2336000, 590]]
  FocalPlaneResolutionUnit2(41488) = [2]
  CustomRendered(41985) = [0]
  ExposureMode(41986) = [0]
  WhiteBalance(41987) = [1]
  SceneCaptureType(41990) = [0]


Iptc Section
=================

International Press Telecommunications Council (IPTC)
standardized the metadata used between new agencies and
newspapers created around 1990.

Here is a sample iptc section from an image::

  ========== iptc ==========
  City(90) = ["", "", "", "", "", "", "City (Core) (ref2016)"]
  Description(120) = "The description aka caption (ref2016)"
  CaptionWriter(122) = "Description Writer (ref2016)"
  Headline(105) = "The Headline (ref2016)"
  Instructions(40) = "An Instruction (ref2016)"
  Photographer(80) = "Creator1 (ref2016)"
  Photographer's Job Title(85) = "Creator's Job Title  (ref2016)"
  Credit(110) = "Credit Line (ref2016)"
  Source(115) = "Source (ref2016)"
  Title(5) = "The Title (ref2016)"
  DateCreated(55) = "20161121"
  60 = "160101+0000"
  Location(92) = "Sublocation (Core) (ref2016)"
  ProvinceState(95) = "Province/State (Core) (ref2016)"
  Country(101) = "Country (Core) (ref2016)"
  CountryCode(100) = "R16"
  Reference(103) = "Job Id (ref2016)"
  Keywords(25) = ["Keyword1ref2016", "Keyword2ref2016", "Keyword3ref2016"]
  Copyright(116) = "Copyright (Notice) 2016 IPTC - www.i...
  IntellectualGenre(4) = "A Genre (ref2016)"
  12 = ["IPTC:1ref2016", "IPTC:2ref2016", "IPTC:3ref2016"]


Key Names
=================

The metadata keys are often numbers to reflect the actual data in
the file.  You can convert these numbers to more human readable
names using the keyName procedure.

For example the iptc copyright key is "116".  The keyName
procedure will convert it to "Copyright". The getMetadata
procedure calls keyName and combines that with the original
number, for example, "Copyright(116)".


Scan Disk for Images
=================

You can use metar to scan your disk and count image files it
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
section has an unknown header and APP2 is unknown and there are
some unknown gaps.::
  
  ...
  file: testfiles/IMG_6093.JPG
  gap*   (2191, 2192) 1 gap byte: 00  .
  gap*   (2240, 4664) 2424 gap bytes: 6E 6F 6E 00 43 61 6E 6F...  non.Cano
  gap*   (4750, 4796) 46 gap bytes: 68 00 69 00 73 00 20 00...  h.i.s. .
  APPD*  (4796, 4948) Iptc: marker not 0x1c.
  iptc*  (4818, 4824) unknown header bytes
  APP2*  (4948, 5526)
  ...

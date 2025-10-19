=================
Metar
=================

Metar is a library and command line program for reading image metadata.

You can read metadata from JPEG, DNG and TIFF images. Metar
understands the standard image metadata formats: XMP, IPTC, Exif,
and Tiff tags.

How to Run Metar
=================

You can run metar from the command line to display image
metadata. Running metar without any parameters shows how to use
it.  For example::

  metar

  Show metadata information for the given image(s).
  Usage: metar [-j] [-v] file [file...]
  -j --json     Output JSON data.
  -v --version  Show the version number.
  -h --help     Show this help.
  file          Image filename to analyze.

You pass an image filename and metar outputs metadata to the
screen, for example::

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

More Pages
=================

You can learn how to build, test and install on the development page.

* `development <docs/project.rst>`_ -- how to build, test and install

You can learn how metar deals with special images with unknown
sections or corrupt files and other details on the details page.

* `details <docs/main.rst>`_ -- metadata processing details

Here is the metar module dependencies graph:

.. image:: docs/html/dependencies.svg

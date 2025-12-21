stf file, version 0.1.0

# Version

Analize a tiff file.

### File cmd.sh command

~~~
$metar $project/testfiles/image.tif | head >stdout 2>stderr
~~~

### File stdout.expected

~~~
========== ifd1 ==========
offset = 8
next = 0
NewSubfileType(254) = [0]
ImageWidth(256) = [124]
ImageHeight(257) = [124]
BitsPerSample(258) = [8, 8, 8]
Compression(259) = [1]
PhotometricInterpretation(262) = [2]
StripOffsets(273) = [243, 20703, 41163]
~~~

### Expected stdout == stdout.expected
### Expected stderr == empty

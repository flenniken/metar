stf file, version 0.1.0

# Version

Analize a dng file.

### File cmd.sh command

~~~
$metar $project/testfiles/image.dng | head >stdout 2>stderr
~~~

### File stdout.expected

~~~
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
~~~

### Expected stdout == stdout.expected
### Expected stderr == empty

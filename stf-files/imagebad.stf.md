stf file, version 0.1.0

# Version

Analize a bad jpg file.

### File cmd.sh command

~~~
$metar $project/testfiles/imagebad.jpg >stdout 2>stderr
~~~

### File stdout.expected

~~~
========== meta ==========
filename = "imagebad.jpg"
reader = "jpeg"
size = 2198
version = "0.1.26"
nimVersion = "2.2.4"
build = "release"
os = "linux"
cpu = "arm64"
problems = [["jpeg", "Jpeg: byte not 0xff."]]
readers = ["jpeg", "tiff"]
~~~

### Expected stdout == stdout.expected
### Expected stderr == empty

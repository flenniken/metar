stf file, version 0.1.0

# Version

Analize a jpg file and output json.

### File cmd.sh command

~~~
$metar -j $project/testfiles/image.jpg | jq | head >stdout 2>stderr
~~~

### File stdout.expected

~~~
{
  "APP0": {
    "id": "JFIF",
    "major": 1,
    "minor": 1,
    "units": 1,
    "x": 96,
    "y": 96,
    "width": 0,
    "height": 0
~~~

### Expected stdout == stdout.expected
### Expected stderr == empty

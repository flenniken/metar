stf file, version 0.1.0

# Test running without specifying any args.

### File cmd.sh command

~~~
$metar >stdout 2>stderr
~~~

### File stdout.expected

~~~
Show metadata information for the given image(s).
Usage: metar [-j] [-v] file [file...]
-j --json     Output JSON data.
-v --version  Show the version number.
-h --help     Show this help.
file          Image filename to analyze.

~~~

### Expected stdout == stdout.expected
### Expected stderr == empty

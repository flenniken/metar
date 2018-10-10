# Metar Python #

You can use the metar python module to read image file metadata.

## Public Methods ##

Metar contains four public methods: get_version, key_name,
read_metadata and read_metadata_json.

```
>>> import metar
>>> dir(metar)
['__doc__', '__file__', '__name__', '__package__', 'get_version', 'key_name', 'read_metadata', 'read_metadata_json']
```

## Doc String Help ##

The meta module has help documentation.

```
>>> help(metar)
```

## Version Number ##

You can determine the metar version number with the get_version function:

```
>>> metar.get_version()
'0.0.4'
```

## Read JSON Metadata ##

You can read the metadata from jpeg and tiff image files using the read_metadata and read_metadata_json functions.  The read_metadata_json function returns the metadata as a JSON string. You can load that into a python dictionary with the json loads function.

```
>>> filename = "testfiles/IMG_6093.JPG"
>>> string = metar.read_metadata_json(filename)
>>> import json
>>> metadata = json.loads(string)
```

Then you can extract the metadata you are interested in from the dictionary.

```
>>> image = metadata['image']
>>> print('width = %s' % image['width'])
width = 3329
>>> print('height = %s' % image['height'])
height = 2219
```

## Human Readable Metadata ##

The read_metadata function returns a more human readable string.

```
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
```

## More Info ##

See the project readme file for more information.

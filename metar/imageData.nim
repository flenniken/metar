import options
import json
import metadata
import ranges

## You use imageData to store and work with image width, height and pixel ranges.

type
  ImageData* = ref object
    ## ImageData holds an the image's width, height and pixel
    ## location.  The pixelOffsets list contains ranges in the file
    ## where the image pixel are located. The tuples are half open
    ## intervals, [start, finish).
    width*: int
    height*: int
    pixelOffsets*: seq[tuple[start: int64, finish: int64]]


proc newImageData*(width: int32, height: int32, starts: seq[uint32],
                   counts: seq[uint32]): Option[ImageData] =
  ## Optionally return a new ImageData object. The starts and count
  ## lists describe the pixel location of the image.  Both lists must
  ## be the same size. Starts is an offset into the file and counts
  ## are the associated lengths.

  # Make sure the imageData has all its fields filled in.
  if width <= 0 or height <= 0 or starts.len == 0 or
      counts.len == 0:
    return

  # The two lists must have the same number of items.
  if starts.len != counts.len:
    raise newException(NotSupportedError, "invalid image parameters.")

  # Create a list of ranges.
  var offsets = newSeq[Range](starts.len)
  for ix in 0..<starts.len:
    let start = (int64)starts[ix]
    let finish = start + (int64)counts[ix]
    offsets[ix] = newRange(start, finish)

  # Merge the ranges.
  let (sections, _) = mergeRanges(offsets, paddingShift = 1)

  var pixelOffsets = newSeq[tuple[start: int64, finish: int64]](sections.len)
  for ix, section in sections:
    pixelOffsets[ix] = (section.start, section.finish)

  result = some(ImageData(width: width, height: height, pixelOffsets: pixelOffsets))


proc createImageNode*(imageData: ImageData): Option[JsonNode] =
  ## Optionally return an image json node created from the given image
  ## data.  If none of the ImageData fields are filled in, none is
  ## returned, otherwise missing fields become error strings in the
  ## json output.

  # Return none when the image data has no fields filled in.
  if imageData.width <= 0 and imageData.height <= 0 and imageData.pixelOffsets.len == 0:
    return none(JsonNode)

  var jObject = newJObject()

  if imageData.width == 0:
     jObject["width*"] = newJString("width not found")
  else:
    jObject["width"] = newJInt((BiggestInt)imageData.width)

  if imageData.height == 0:
     jObject["height*"] = newJString("height not found")
  else:
    jObject["height"] = newJInt((BiggestInt)imageData.height)

  if imageData.pixelOffsets.len == 0:
     jObject["pixels*"] = newJString("no image pixels")
  else:
    var pixels = newJArray()
    for offset in imageData.pixelOffsets:
      var part = newJArray()
      part.add(newJInt((BiggestInt)offset.start))
      part.add(newJInt((BiggestInt)offset.finish))
      pixels.add(part)
    jObject["pixels"] = pixels

  result = some(jObject)

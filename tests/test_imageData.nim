import unittest
import imageData
import options # todo: why is options necessary when imageData imports it?
import json
import metadata
import strutils

static:
  doAssert defined(test), ": test not defined."

proc `$`(self: ImageData): string =
  ## Return a string representation of the given ImageData object ref.

  var lines = newSeq[string]()
  lines.add("ImageData: width: $1, height: $2, offsets: $3" %
    [$self.width, $self.height, $self.pixelOffsets.len])
  for po in self.pixelOffsets:
    lines.add("($1, $2)" % [$po.start, $po.finish])
  result = lines.join("\n")


suite "Test imageData":

  test "test newImageData":
    let imageData = ImageData()
    check(imageData.width == 0)
    check(imageData.height == 0)
    check(imageData.pixelOffsets.len == 0)

  test "test newImageData2":
    var starts = @[200'u32, 400, 300]
    var counts = @[2'u32, 4, 3]
    let imageData = newImageData(1000, 400, starts, counts).get()
    check(imageData.width == 1000)
    check(imageData.height == 400)
    check(imageData.pixelOffsets.len == 3)
    check(imageData.pixelOffsets[0] == (200'i64, 202'i64))
    check(imageData.pixelOffsets[1] == (300'i64, 303'i64))
    check(imageData.pixelOffsets[2] == (400'i64, 404'i64))

  test "test ImageData to string":
    var starts = @[200'u32, 400, 300]
    var counts = @[2'u32, 4, 3]
    let imageData = newImageData(1000, 400, starts, counts).get()
    let expected = """
ImageData: width: 1000, height: 400, offsets: 3
(200, 202)
(300, 303)
(400, 404)"""
    check($imageData == expected)

  test "test newImageData merge":
    var starts = @[200'u32, 400, 300]
    var counts = @[100'u32, 50, 100]
    let imageData = newImageData(1000, 400, starts, counts).get()
    check(imageData.width == 1000)
    check(imageData.height == 400)
    check(imageData.pixelOffsets.len == 1)
    check(imageData.pixelOffsets[0] == (200'i64, 450'i64))

  test "test newImageData error":
    var starts = @[200'u32]
    var counts = @[2'u32, 4, 3]
    expect NotSupportedError:
      discard newImageData(1000, 400, starts, counts)

  test "test newImageData nil":
    var starts = @[200'u32, 400, 300]
    var counts = @[100'u32, 50, 100]
    let im = newImageData(-2, 0, starts, counts)
    check(im.isNone == true)

  test "test createImageNode":
    var imageData = ImageData()
    imageData.width = 1000
    imageData.height = 500
    imageData.pixelOffsets.add((111'i64, 222'i64))
    let imageNode = createImageNode(imageData).get()
    check(imageNode != nil)
    check($imageNode == """{"width":1000,"height":500,"pixels":[[111,222]]}""")

  test "test createImageNode no width":
    var imageData = ImageData()
    # imageData.width = 1000
    imageData.height = 500
    imageData.pixelOffsets.add((111'i64, 222'i64))
    let imageNode = createImageNode(imageData).get()
    # echo $imageNode
    check($imageNode == """{"width*":"width not found","height":500,"pixels":[[111,222]]}""")

  test "test createImageNode no height":
    var imageData = ImageData()
    imageData.width = 1000
    #imageData.height = 500
    #imageData.pixelOffsets.add((111'i64, 222'i64))
    let imageNode = createImageNode(imageData).get()
    # echo $imageNode
    check($imageNode == """{"width":1000,"height*":"height not found","pixels*":"no image pixels"}""")

  test "test createImageNode missing":
    var imageData = ImageData()
    check(createImageNode(imageData).isNone() == true)

  test "test toString":
    var imageData = ImageData()
    # echo $imageData
    check($imageData == "ImageData: width: 0, height: 0, offsets: 0")

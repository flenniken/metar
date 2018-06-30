import unittest
import imageData
import json
import metadata


suite "Test imageData":

  test "test newImageData":
    let imageData = newImageData()
    check(imageData.width == -1)
    check(imageData.height == -1)
    check(imageData.pixelOffsets.len == 0)

  test "test newImageData2":
    var starts = @[200'u32, 400, 300]
    var counts = @[2'u32, 4, 3]
    let imageData = newImageData(1000, 400, starts, counts)
    check(imageData.width == 1000)
    check(imageData.height == 400)
    check(imageData.pixelOffsets.len == 3)
    check(imageData.pixelOffsets[0] == (200'i64, 202'i64))
    check(imageData.pixelOffsets[1] == (300'i64, 303'i64))
    check(imageData.pixelOffsets[2] == (400'i64, 404'i64))

  test "test newImageData merge":
    var starts = @[200'u32, 400, 300]
    var counts = @[100'u32, 50, 100]
    let imageData = newImageData(1000, 400, starts, counts)
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
    let im = newImageData(-2, -1, starts, counts)
    check(im == nil)

  test "test createImageNode":
    var imageData = newImageData()
    imageData.width = 1000
    imageData.height = 500
    imageData.pixelOffsets.add((111'i64, 222'i64))
    let imageNode = createImageNode(imageData)
    check(imageNode != nil)
    check($imageNode == """{"width":1000,"height":500,"pixels":[[111,222]]}""")

  test "test createImageNode incomplete":
    var imageData = newImageData()
    # imageData.width = 1000
    imageData.height = 500
    imageData.pixelOffsets.add((111'i64, 222'i64))
    let imageNode = createImageNode(imageData)
    check(imageNode == nil)

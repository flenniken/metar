import unittest
import ranges
import json
import testFile
import metadata
# import tables

suite "Test ranges":

  test "test newRange":
    let range = newRange(111, 222)
    check(range.start == 111)
    check(range.finish == 222)
    check(range.name == "")
    check(range.known == true)
    check(range.message == "")

  test "test createRangeNode":
    var range = newRange(123, 456)
    range.name = "name"
    range.message = "message"
    let rangeNode = createRangeNode(range)
    check($rangeNode == """["name",123,456,true,"message"]""")

  test "test mergeRanges empty":
    var list = newSeq[Range]()
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 0)
    check(gapList.len == 0)

  test "test mergeRanges 1":
    var list = newSeq[Range]()
    let item: Range = newRange(5, 10)
    list.add(item)
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 1)
    check(gapList.len == 0)
    let expected = @[(start: 5'i64, finish: 10'i64)]
    check(minList == expected)

  test "test mergeRanges 2":
    var list = newSeq[Range]()
    list.add(newRange(5, 10))
    list.add(newRange(10, 30))
    let expected = @[(5'i64, 30'i64)]
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 1)
    check(gapList.len == 0)
    check(minList == expected)

  test "test mergeRanges 3":
    var list = newSeq[Range]()
    list.add(newRange(5, 10))
    list.add(newRange(20, 30))
    let expectedGap = @[(10'i64, 20'i64)]
    let expectedList = @[(5'i64, 10'i64), (20'i64, 30'i64)]
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 2)
    check(gapList.len == 1)
    check(minList == expectedList)
    check(gapList == expectedGap)

  test "test mergeRanges 4":
    var list = newSeq[Range]()
    list.add(newRange(0, 0))
    list.add(newRange(20, 30))
    let expectedMin = @[(20'i64, 30'i64)]
    let expectedGap = @[(0'i64, 20'i64)]
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 1)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeRanges 5":
    var list = newSeq[Range]()
    list.add(newRange(20, 30))
    list.add(newRange(40, 40))
    let expectedMin = @[(20'i64, 30'i64)]
    let expectedGap = @[(30'i64, 40'i64)]
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 1)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeRanges 6":
    var list = newSeq[Range]()
    list.add(newRange(0, 0))
    list.add(newRange(20, 30))
    list.add(newRange(40, 40))
    let expectedMin = @[(20'i64, 30'i64)]
    let expectedGap = @[(0'i64, 20'i64), (30'i64, 40'i64)]
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 1)
    check(gapList.len == 2)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeRanges 7":
    var list = newSeq[Range]()
    list.add(newRange(0, 40))
    list.add(newRange(20, 45))
    list.add(newRange(40, 60))
    let expectedMin = @[(0'i64, 60'i64)]
    let (minList, gapList) = mergeRanges(list)
    check(minList.len == 1)
    check(gapList.len == 0)
    check(minList == expectedMin)

  # padding is on even byte boundaries.

  test "test mergeRanges padding 1":
    # Not on padding value.
    var list = newSeq[Range]()
    list.add(newRange(0, 39))
    list.add(newRange(41, 45))
    let expectedMin = @[(0'i64, 39'i64), (41'i64, 45'i64)]
    let expectedGap = @[(39'i64, 41'i64)]
    let (minList, gapList) = mergeRanges(list, paddingShift = 1)
    check(minList.len == 2)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeRanges padding 2":
    # On padding value.
    var list = newSeq[Range]()
    list.add(newRange(0, 39))
    list.add(newRange(40, 49))
    let expectedMin = @[(0'i64, 49'i64)]
    let (minList, gapList) = mergeRanges(list, paddingShift = 1)
    check(minList.len == 1)
    check(gapList.len == 0)
    check(minList == expectedMin)

  test "test mergeRanges padding 3":
    # Not on padding
    var list = newSeq[Range]()
    list.add(newRange(0, 37))
    list.add(newRange(49, 55))
    let expectedMin = @[(0'i64, 37'i64), (49'i64, 55'i64)]
    let expectedGap = @[(37'i64, 49'i64)]
    let (minList, gapList) = mergeRanges(list, paddingShift = 1)
    check(minList.len == 2)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "readGap":
    var file = openTestFile("testfiles/image.tif")
    defer: file.close()
    check(readGap(file, 0, 20) == "20 gap bytes: 49 49 2A 00 08 00 00 00...  II*.....")
    check(readGap(file, 0, 8) == "8 gap bytes: 49 49 2A 00 08 00 00 00  II*.....")
    check(readGap(file, 0, 7) == "7 gap bytes: 49 49 2A 00 08 00 00  II*....")
    check(readGap(file, 0, 1) == "1 gap byte: 49  I")

    expect NotSupportedError:
      discard readGap(file, 0, 0)
    expect NotSupportedError:
      discard readGap(file, 10, 0)
    expect NotSupportedError:
      discard readGap(file, 999999, 9999999)
    expect NotSupportedError:
      discard readGap(file, 9999991, 9999999)


      
  test "createRangesNode":
    var ranges = newSeq[Range]()
    ranges.add(newRange(0, 500, name="range1"))
    ranges.add(newRange(500, 1000, name="range2"))
    let rangesNode = createRangesNode(nil, 0, 1000, ranges)
    check($rangesNode == """[["range1",0,500,true,""],["range2",500,1000,true,""]]""")

  test "createRangesNode u32":
    var ranges = newSeq[Range]()
    ranges.add(newRange(0, 500, name="range1"))
    ranges.add(newRange(500, 1000, name="range2"))
    let rangesNode = createRangesNode(nil, 0'u32, 1000'u32, ranges)
    check($rangesNode == """[["range1",0,500,true,""],["range2",500,1000,true,""]]""")

  test "createRangesNode gap":
    var file = openTestFile("testfiles/image.tif")
    defer: file.close()

    var ranges = newSeq[Range]()
    ranges.add(newRange(0, 999, name="range"))
    let rangesNode = createRangesNode(file, 0, 1000, ranges)
    check($rangesNode == """[["range",0,999,true,""],["gap",999,1000,false,"1 gap byte: F8  ."]]""")

  test "createRangesNode sorted":
    var ranges = newSeq[Range]()
    ranges.add(newRange(500, 1000, name="range2"))
    ranges.add(newRange(0, 500, name="range1"))
    let rangesNode = createRangesNode(nil, 0, 1000, ranges)
    check($rangesNode == """[["range1",0,500,true,""],["range2",500,1000,true,""]]""")

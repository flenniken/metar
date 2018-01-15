import Metadata
import json
import tpub
import strutils
import readMetadata
import unicode

const maxKeyLength = 15
const maxStringLength = 40

proc controlToDot(str: string): string =
  ## Replace control characters in the given string with dots and
  ## return the new string.

  result = newStringOfCap(str.len)
  for ch in runes(str):
    if ch <% (Rune)32:
      result.add('.')
    else:
      var utf8 = toUTF8(ch)
      result.add(utf8)

proc ellipsize(str: string, maxLen: Natural): string {.tpub.} =
  ## If the string is longer than maxLen, truncate it and add "...".

  if maxLen < str.len:
    if maxLen < 3:
      result = ""
    else:
      result = str[0..<maxLen-3] & "..."
  else:
    result = str


proc getLeafString(node: JsonNode, maxLen: Natural): string  {.tpub.} =
  ## Return a one line string representation of the node.
  ## The maxLen parameter is the maximum length
  ## of the string to return. Truncate long strings and add
  ## "..." where appropriate.

  if maxLen < 1:
    return ""

  case node.kind:
    of JNull:
      result = "-"
    of JBool:
      if node.getBVal():
        result = "t"
      else:
        result = "f"
    of JInt:
      result = ellipsize($node.getNum(), maxLen)
    of JFloat:
      result = ellipsize($node.getFNum(), maxLen)
    of JString:
      let length = if maxLen < maxStringLength: maxLen else: maxStringLength
      result = ellipsize("\"" & $node.getStr() & "\"", length)
    of JObject:
      if maxLen < 2:
        result = ""
      elif maxLen < 5:
        result = "{}"
      else:
        var parts = newSeq[string]()
        var lenParts = 0
        for key, value in node.pairs():
          let one = "\"" & ellipsize(key, maxKeyLength) & "\": "
          let two = getLeafString(value, maxLen)
          let item = one & two
          let last = if node.len == parts.len-1: 2 else: 7
          if lenParts + parts.len*2 + item.len + last > maxLen:
            parts.add("...")
            break
          lenParts += item.len
          parts.add(item)
        result = "{" & parts.join(", ") & "}"
    of JArray:
      if maxLen < 2:
        result = ""
      elif maxLen < 5:
        result = "[]"
      else:
        var parts = newSeq[string]()
        var lenParts = 0
        for value in node.items():
          let item = getLeafString(value, maxLen)
          let last = if node.len == parts.len-1: 2 else: 7
          if lenParts + parts.len*2 + item.len + last > maxLen:
            parts.add("...")
            break
          lenParts += item.len
          parts.add(item)
        result = "[" & parts.join(", ") & "]"


proc printMetadata*(metadata: Metadata) =
  ## Print the metadata in a human readable format.

  # var meta = metadata["meta"]
  # var reader = meta["reader"]

  # metadata is an ordered dictionary containing dicts, meta, xmp, iptc,...
  # dicts are dictionaries containing items, filename, width, height,...
  # items are strings, numbers, arrays or dictionaries

#[
========== xmp ==========
width = 1234
height = 568
components = [1, 2, 3]
values = {"one": 1, "two": 2}
========== sof0 ==========
width = 1234
height = 568
components = [1, 2, 3, 4, 5, 6,...]
---------- sof4-0 ----------
"one": 1
"two": 2
"three": 3
---------- sof4-1 ----------
"one": 1
"two": 2
"three": 3

]#

  for section, d in metadata.pairs():
    echo "========== $1 ==========" % [section]
    for key, node in d.pairs():
      # var name = keyName(reader, section, key)
      var name = keyName("jpeg", section, key)
      if name.len > 0:
        name = "$1($2)" % [name, key]
      else:
        name = key
      var leafString = getLeafString(node, 30)
      if leafString != nil:
        echo "$1 = $2" % [name, leafString]
      else:
        if node.kind == JObject:
          echo "$1 = {...}" % [name]
        else:
          echo "$1 = [...]" % [name]


#JNull, JBool, JInt, JFloat, JString, JObject, JArray


#[
  if node.kind != JArray:
    return leaf(node, maxLength)

  var parts = newSeq[string]()
  var length = 2
  for item in node:
    string = leaf(item, maxLeafLength)
    if length + len(string) + len(parts) * 2 + len(", ...") > maxLength:
      parts.append("...")
      break
    parts.append(string)
    length += len(string)
  result = "[$1]" % [parts.join(", ")]
]#


## You use the readable module to display the metadata in a human
## readable format.

import metadata
import json
import tpub
import strutils
import readers

const maxKeyLength = 15
const maxStringLength = 40
const maxLineLength = 72

#todo: use controlToDot
# proc controlToDot(str: string): string =
#   ## Replace control characters in the given string with dots and
#   ## return the new string.

#   result = newStringOfCap(str.len)
#   for ch in runes(str):
#     if ch <% (Rune)32:
#       result.add('.')
#     else:
#       var utf8 = toUTF8(ch)
#       result.add(utf8)

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
      if node.getBool():
        result = "t"
      else:
        result = "f"
    of JInt:
      result = ellipsize($node.getInt(), maxLen)
    of JFloat:
      result = ellipsize($node.getFloat(), maxLen)
    of JString:
      var value = node.getStr()
      let length = if maxLen < maxStringLength: maxLen else: maxStringLength
      result = ellipsize("\"" & value & "\"", length)
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
            # parts.add("...($1)" % $node.len)
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
            # parts.add("...($1)" % $node.len)
            parts.add("...")
            break
          lenParts += item.len
          parts.add(item)
        result = "[" & parts.join(", ") & "]"


proc getRangeString(node: JsonNode): string {.tpub.} =
  ## Return the range string for the range node.

  assert(node.kind == JArray)
  assert(node.len == 5)

  var name = node[0].getStr()
  let start = node[1].getInt()
  let finish = node[2].getInt()
  let known = node[3].getBool()
  let message = node[4].getStr()

  if not known:
    name = name & "*"
  result = "$1 ($2, $3) $4" % [strutils.alignLeft(name, 6), $start, $finish, message]


proc keyNameDefault(readerName: string, section: string,
                    key: string): string {.tpub.} =
  # If the key name doesn't exist, return the key parameter, else return the key name.

  var name = keyName(readerName, section, key)
  if name.len == 0:
    result = key
  else:
    result = name


iterator forLines*(metadata: Metadata, readerName: string): string =
  ## Iterate through the metadata line by line in a human readable
  ## form.

  if metadata.kind != JObject:
    raise newException(ValueError, "Expected top level object.")
  for section, d in metadata.pairs():
    yield("========== $1 ==========" % [section])
    # The second level must be an object or array of objects.
    if d.kind == JObject:
      for key, node in d.pairs():
        var name = keyNameDefault(readerName, section, key)
        # Show the full path for the meta:filename.
        var leafString: string
        if section == "meta" and key == "filename":
          leafString = "\"" & node.getStr() & "\""
        else:
          leafString = getLeafString(node, maxLineLength)
        yield("$1 = $2" % [name, leafString])
    elif d.kind == JArray:
      var num = 1
      for nestedNode in d.items():
        if nestedNode.kind == JObject:
          yield("-- $1 --" % [$num])
          for key, node in nestedNode.pairs():
            var name = keyNameDefault(readerName, section, key)
            var leafString = getLeafString(node, maxLineLength)
            yield("$1 = $2" % [name, leafString])
        elif nestedNode.kind == JArray:
          if section == "ranges":
            yield(getRangeString(nestedNode))
          else:
            let leaf = getLeafString(nestedNode, maxLineLength)
            yield("$1: $2" % [$num, leaf])
        else:
          raise newException(ValueError, "Expected nested node container.")
        num += 1
    else:
      raise newException(ValueError, "Expected second level object.")


proc readable*(metadata: Metadata, readerName: string): string =
  ## Return the metadata as a human readable string.

  var lines = newSeq[string]()
  for line in metadata.forLines(readerName):
    lines.add(line)
  result = lines.join("\n")

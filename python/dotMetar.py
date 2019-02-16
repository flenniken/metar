

import os
import sys
import argparse
import re


line_pattern = re.compile('^([0-9a-zA-Z]+) -> \"([0-9a-zA-Z]+)\";$')

def parse_line(line):
  """
  Parse a dot line and return the left and right names.
  """
  # example line:
  # strutils -> "algorithm";

  match = line_pattern.match(line)
  if not match:
    return "", ""
  left = match.group(1)
  right = match.group(2)
  return left, right



def dotFilter(names, filename):
  """
  Read dot file lines and output lines containing names.
  """
  print 'digraph metar {'

  with open(filename, 'r') as fh:
    for line in fh:
      left, right = parse_line(line)
      if left != '' and left in names and right in names:
        print '%s -> %s;' % (left, right)

  # Add dotted line between version.nim and ver.nim.
  # print 'version -> ver [style = dotted];'
  print '}'

def readNames(filename):
  """
  Read names from a file, one name per line.
  """
  names = {}
  with open(filename, 'r') as fh:
    for line in fh:
      names[line.strip()] = 1
  return names


def main(args):
  # print args
  if not os.path.exists(args.filename):
    print "file doesn't exist: " + args.filename
    return
  if not os.path.exists(args.dotFilename):
    print "file doesn't exist: " + args.dotFilename
    return
  names = readNames(args.filename)
  # for k, v in names.items():
  #   print '%s = %s' % (k, v)

  dotFilter(names, args.dotFilename)
  # with open(args.dotFilename, 'r') as fh:
  #   for line in fh:
  #     print line

def parse_command_line():
  """
  Parse the command line and return an object that has the parameters.
  """

  parser = argparse.ArgumentParser(description="""\
Filter dot files.
""")
  parser.add_argument("filename", help="File of names one name per line.")
  parser.add_argument("dotFilename", help="Dot filename to filter.")
  args = parser.parse_args()
  return args

if __name__ == "__main__":
  args = parse_command_line()
  main(args)

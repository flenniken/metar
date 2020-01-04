'''
This script is used to remove the system module lines from the dot
output so only the dependencies of metar are shown. It's used by the
nimble dot task shown here:

task dot, "Show dependency graph":
  exec "nim genDepend metar/metar.nim"
  # Create my.dot file with the contents of metar.dot after stripping
  # out nim modules.
  exec """find metar -maxdepth 1 -name \*.nim | sed "s:metar/::" | sed "s:.nim::" >names.txt"""
  exec "python python/dotMetar.py names.txt metar/metar.dot >metar/my.dot"
  exec "dot -Tsvg metar/my.dot -o bin/dependencies.svg"
  exec "open -a Firefox bin/dependencies.svg"
'''

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
  Print out a dot file that contains all the lines specified in
  filename except the lines where the right side name is in the names
  dictionary.
  """
  print('digraph metar {')

  with open(filename, 'r') as fh:
    for line in fh:
      left, right = parse_line(line)
      if left != '' and left in names and right in names:
        print('%s -> %s;' % (left, right))

  # Add dotted line between version.nim and ver.nim.
  # print 'version -> ver [style = dotted];'
  print('}')

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
    print("file doesn't exist: " + args.filename)
    return
  if not os.path.exists(args.dotFilename):
    print("file doesn't exist: " + args.dotFilename)
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

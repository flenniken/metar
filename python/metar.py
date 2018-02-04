import sys
# todo: remove hard coded path.
sys.path.append("/Users/steve/code/metarnim/bin")
import metarpy

__version__ = metarpy.get_version()

# def read_metadata(filename):
#   return metarpy.py_read_metadata(filename)

read_metadata = metarpy.py_read_metadata

read_metadata_human = metarpy.py_read_metadata_human

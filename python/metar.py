import sys
# todo: remove hard coded path.
sys.path.append("/Users/steve/code/metarnim/bin")
import metarpy

__version__ = metarpy.py_get_version()
read_metadata_json = metarpy.py_read_metadata_json
read_metadata = metarpy.py_read_metadata

import os
import re
from setuptools import setup, find_packages

# This python package installs the metar library built locally by nim.
# pip will search folder for a setup.py, then install it.
#
# pip install ~/code/metar/python/metar


base_folder = os.path.dirname(os.path.abspath(__file__))

def get_version():
  """
  Get the metar version number string.
  """
  # The version.nim file in the metar nim project is the true version
  # number. The file is copied to the python project when building the
  # library.  This allows the python project to be independent of the
  # nim project and keeps the two versions in sync.

  version_file = os.path.join(base_folder, 'version.nim')
  assert(os.path.exists(version_file))

  # Get the one true version number.
  # const metarVersion* = "0.1.22"
  version = re.search(
    'metarVersion.*"(.*)"',
    open(version_file).read(),
    re.M
    ).group(1)

  return version

def get_long_description():
  readme_file = os.path.join(base_folder, 'README.rst')
  assert(os.path.exists(readme_file))

  # Use the readme text for the long description.
  with open(readme_file, "rb") as f:
    long_description = f.read().decode("utf-8")

  return long_description

def main():
  setup(
    # todo: figure out how to package metar.so.
    ext_modules=[Extension("metar", ["asdfasfd.c"])],
    name='metar',
    version=get_version(),
    description='Metadata reader and library.',
    long_description=get_long_description(),
    url='http://github.com/sflennik/metar/python',
    license='MIT',
    author='Steve Flenniken',
    author_email='steve.flenniken@gmail.com',

    packages=find_packages(exclude=['test*']),
    include_package_data=True,
    classifiers=[
      'Development Status :: Beta',
      'Intended Audience :: Developers',
      'Natural Language :: English',
      'Operating System :: Max OS, Linux Debian',
      'Programming Language :: Python :: 2.7',
      'Programming Language :: Python :: 3.x',
      'Topic :: Software Development :: Libraries :: Python Modules',
    ],
  )

if __name__ == "__main__":
    main()

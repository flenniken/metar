import sys
from setuptools import setup

def main():
  setup(
    name='metar',
    version="0.1.25", # metarVersion*
    description='Image metadata reader.',
    long_description='See: https://github.com/flenniken/metar',
    url='http://github.com/sflennik/metar/python/metar',
    license='MIT',
    author='Steve Flenniken',
    author_email='steve.flenniken@gmail.com',

    packages=[''],
    package_data={'': ['metar.so']},

    platforms = [sys.platform],

    # sys_platform = 'darwin', # from sys.platform
    # platform_machine = 'x86_64', # platform.machine()

    classifiers=[
      'Development Status :: Beta',
      'Intended Audience :: Developers',
      'Natural Language :: English',
      'Operating System :: Mac OS',
      'Programming Language :: Python :: 3.x',
      'Topic :: Software Development :: Libraries :: Python Modules',
    ],
  )

if __name__ == "__main__":
    main()

import re
from setuptools import setup, find_packages


version = re.search(
    '^__version__\s*=\s*"(.*)"',
    open('metar/version.py').read(),
    re.M
    ).group(1)


with open("README.rst", "rb") as f:
    long_descr = f.read().decode("utf-8")

setup(
    name='metar',
    version = version,
    description='Metadata reader and library.',
    long_description = long_descr,
    url='git@keypict.unfuddle.com:keypict/metar.git',
    license='MIT',
    author='Steve Flenniken',
    author_email='steve.flenniken@gmail.com',
    entry_points = {
        "console_scripts": ['metar = metar.metar:main']
        },
    packages=find_packages(exclude=['test*']),
    include_package_data=True,
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3.4',
        'Topic :: Software Development :: Libraries :: Python Modules',
    ],
)

setup(
  name='metar',
  version='0.0.1', # todo: use real version number.
  description='Metadata reader and library.',
  url='http://github.com/sflennik/metar',
  author='Steve Flenniken',
  author_email='steve.flenniken@gmail.com',
  license='MIT',
  packages=['metar'],
  zip_safe=False
)

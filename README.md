# get-location

This is `get-location`: a simple command-line tool to get location
from CoreLocation service.

## Description

This tool uses the
[CoreLocation framework](http://developer.apple.com/library/mac/documentation/CoreLocation/Reference/CoreLocation_Framework/)
to find the current location of the machine it's running on.  When
found, the output is printed to
[stdout](http://en.wikipedia.org/wiki/Standard_streams#Standard_output_.28stdout.29).

## Requirements:

* MacOS X (probably 10.6 or later?)

## building:

Hopefully, just type `make`.

## Future plans:

It would be good if this tool had configuration for such things as:

* amount of accuracy required

If you'd like to help make any of these happen, feel free to fork the
github repo for this, and/or send me money to encourage my further
development.  :)

## Past wish-list, now completed!

* whether or not to wait for a non-cached result (added 2012-04-10) -- `-r <results>`
* choosing (or even specifying) different output formats -- `-f <format>`

## Author:

David Lindes.

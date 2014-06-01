A cmake based multi-platform build system.

It can be used to build c++ source code with dependencies and to build [sphinx](http://sphinx-doc.org) and [doxygen](http://doxygen.org) documentation.

There are helper modules to build [pyside](https://github.com/PySide) uic and resource files.

The idea is to declare everything there is to know about a project, and have the details handled by cmake on all platforms it can support.

### Prerequisites

* Cmake 2.8 or newer


### Development Status

The code base is still pretty much what I wrote 1.5 years ago, and needs a thorough review to be ported into the present time.

No such work as been conducted yet, and I believe the project is not operational.

### Goals

* Review CMake code and assure it is operational
* Integrate with [bcore](https://github.com/Byron/bcore) wrapper system to prepare distributions for any software configured by [bprocess](http://byron.github.io/bcore/bprocess/)

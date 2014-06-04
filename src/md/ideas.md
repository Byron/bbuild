
### Problem: travis dependencies
* Currently it's difficult to get standalone/no-assembly travis tests right as plenty of dependencies have to be pulled in manually, and recursively. Doing this is cumbersome. In any way, it will break if new dependencies upstream don't propagate downstream, however, a tool would help tremendously to get it right from the start.
    + provide utilities which allow to retrieve dependencies, in a particular format, recursively. For example, it could write a shell script to pip-install everything from repositories right away.

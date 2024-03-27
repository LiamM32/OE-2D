# Open Emblem Raylib front-end

This is a graphical front-end program for Open Emblem using Raylib. It is currently the only way to run Open Emblem.

To build without running in the standard configuration, enter the command `dub build` in this directory. Running `dub` (on it's own) will both build and launch the game.

##Build
If the program fails to build due to problems in `app.d`, this may be because of the function used to get the monitor's refresh rate. In this case, build the fixed-refresh-rate version with `dub --build=FixedRefresh`.
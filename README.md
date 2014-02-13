Vanubi Programming Editor
==========================

"All editors suck. This one just sucks less." -mutt like, circa 1995

Install:

```
# apt-get install autotools-dev autoconf libtool valac libgtksourceview-3.0-dev libvte-2.90-dev libwnck-3-dev
$ git clone https://github.com/vanubi/vanubi.git
$ cd vanubi
$ ./autogen.sh
$ make
$ gui/vanubi # to run without installing
# make install
# ldconfig
```

Instead of using `git`, you can also [grab tarballs here](https://github.com/vanubi/vanubi/releases).

Vanubi is only tested on Linux systems.

Make sure to have the most recent Vala compiler at your disposal.

More information at the [Vanubi homepage](http://vanubi.github.io/vanubi)

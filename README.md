Build CouchDB
=============

Build CouchDB is a wrapper or master project which pulls in, from official
sources, CouchDB plus all of its dependencies. It is the most straightforward
and reliable procedure to build official CouchDB releases from source.

Build CouchDB builds an isolated, independent server. You do not need
administrator access to run it. You can run several couches (for example, 0.10,
0.11, 1.0 releases) side-by-side.

<a name="platforms"></a>
## Supported Platforms

Build CouchDB is developed and tested on the following operating systems:

* Red Hat Enterprise Linux Server release 5.5 (Tikanga)
* CentOS 5.5
* Debian GNU/Linux
  * 5.0 (Lenny)
  * 6.0 (Squeeze)
* Ubuntu
  * 9.10 (Karmic Koala)
  * 10.04 LTS (Lucid Lynx)
  * 10.10 (Maverik Meerkat)
  * 11.04 (Natty Narwhal)
  * 11.10 (Oneiric Ocelot)
* Fedora 13
* Mac OS X
* OpenSUSE 11.3
* Scientific Linux 5.3
* Solaris 10, OpenSolaris

The following systems are planned for support in the near future:

 * MS Windows Vista, Windows 7

## Requirements

You need only a few packages provided by the operating system. Copy and paste
the commands below.

On **Fedora**:

    sudo yum install gcc gcc-c++ make libtool zlib-devel openssl-devel rubygem-rake

On **Red Hat Enterprise Linux**:

The procedure is the same as Fedora, but also install the `ruby-rdoc` package.

On **Debian**, first install `sudo` and add yourself to `/etc/sudoers`.

    su -
    apt-get install sudo
    visudo

On **Ubuntu and Debian**:

    sudo apt-get install make gcc zlib1g-dev libssl-dev rake

On **OpenSUSE**:

    sudo zypper install flex lksctp-tools-devel zip \
				rubygem-rake gcc-c++ make m4 zlib-devel \
				libopenssl-devel libtool automake

On **Scientific Linux**

    sudo yum install --enablerepo=dag gcc gcc-c++ libtool zlib-devel openssl-devel \
				autoconf213

On **Solaris**

This build only supports the OpenCSW toolchain. If you do not use OpenCSW, I
wish you the best. If you have success, let me know!

The SunStudio tools are required:

    sudo pkg install ss-dev

Also, OpenCSW packages are needed.

    pkgadd -d http://mirror.opencsw.org/opencsw/pkg_get.pkg # Answer all questions affirmatively

Add CSW to your path. **This must always be in the PATH.** Every time you log
in, you must set the correct `$PATH` (or make it automatic in `.profile`).

    PATH=/opt/csw/bin:$PATH

Change the package archive (ibiblio URL is down) by running
`vi /opt/csw/etc/pkg-get.conf` and setting
`url=ftp://ftp.ibiblio.org/pub/mirrors/opencsw/current`. Save and exit, then
run:

    pkg-get updatecatalog

Finally, install Rake from OpenCSW:

    sudo pkg-get install ruby rake # Also perhaps "git"

On **Mac OS X**

Install Xcode from Mac App Store. Launch XCode.app, then go to Perferences, select Downloads tab and Install Command Line Tools (You will need Apple Developer ID to download CLT).

## Getting the Code

You will need the Git tool. Check out the code and pull in the third-party
submodules.

    git clone git://github.com/iriscouch/build-couchdb
    cd build-couchdb
    git submodule init
    git submodule update

## How to Build CouchDB

Just run Rake.

    rake

CouchDB and all its dependencies will install in the `build/`. To uninstall,
simply delete that directory.

## Usage

It's CouchDB! Just type `couchdb`. (But remember the path)

    $ build/bin/couchdb
    Apache CouchDB 0.12.0aa63efb6-git (LogLevel=info) is starting.
    Apache CouchDB has started. Time to relax.
    [info] [<0.33.0>] Apache CouchDB has started on http://127.0.0.1:5984/

You can of course call it by absolute path. If your username is `amit` and you
checked out the code in your home directory, you would run:

    /home/amit/build-couchdb/build/bin/couchdb

## Conveniently Add CouchDB to the PATH

The build process creates a small shell script, `build/env.sh`. The script
will add the buid to your shell's `$PATH`. This will *only* affect that shell
session, other terminals or shell sessions will not change. (This is on
purpose, to isolate CouchDB, so that it is easy to remove, or so multiple
versions can be installed side-by-side.)

Simply source the script when you want to use CouchDB.

    . build/env.sh

Your working directory needn't be anywhere special when sourcing the file.
It can be processed from anywhere. The idea is, when you are working, you
realize you need couchdb, just type
`. ~/my/stuff/code/build-couchdb/build/env.sh` or whatever and it will work.

You can source the file as often as you like. Subsequent execution will not
do anything.

    . build/env.sh
    . build/env.sh # Sourcing with wild abandon!

If the file is read from a script or in a pipeline, it will execute silently
(by detecting whether it is connected to a TTY terminal).

## Cheat Codes

Build CouchDB supports some fancy tricks by entering cheat codes to the Rake
command.

### Build any Git branch or tag of Erlang/OTP

Add a `erl_checkout` parameter with the commit id, branch name, or tag name.

For example, to build with Erlang R13B04 release:

    rake erl_checkout="OTP_R13B04"

### Build any Git branch or tag of CouchDB

Add a `git` parameter with the repository URL, then a space, then the branch,
tag, or commit hash. (Remember to quote all of those so Rake sees the space.)

### CouchDB Plugins

Any CouchDB plugin can be loaded remotely from Git, built, and installed
into the final CouchDB system.

    rake plugin="git://github.com/couchbase/geocouch origin/couchdb1.2.x"
    # (Or perhaps origin/couchdb_1.1.x)

Multiple plugins can be processed together:

    rake plugins="git://github.com/vmx/couchdb origin/gc-separate,git://github.com/somebody/whatever some_tag"

(Both `plugin` and `plugins` supports comma-separated lists; use whichever
you remember better.)

### Install CouchDB somewhere besides `build/`.

Add an `install` parameter to place the final couchdb binaries anywhere.

Build CouchDB makes it simple to install several couchdb versions side-by-side.

    rake install=stable
    rake git="git://git.apache.org/couchdb.git trunk" install=trunk
    for tag in 1.0.1 11.0 11.1; do
        rake git="git://git.apache.org/couchdb.git tags/$tag" install=$tag
    done

Note that `install` needs to be an absolute path.

For **side-by-side installs** there is a small shortcut to avoid rebuilding Erlang:
use the `couchdb_build` variable instead, which will install CouchDB separately
from its dependencies. Just remember never to move or delete the dependencies!

    rake install=/dependencies/go/here couchdb_build=/but/couch/goes/here

### Support "unclean" builds.

Build CouchDB confirms that the Git checkout looks good before attempting a
build. If you see this error message, then Build CouchDB is suspicious of your
checkout:

    This checkout is not clean:
    <list of changed files>

Heed this warning. Why is your checkout unclean? Shouldn't you build from a
nice, clean checkout, with no funny business?

Nevertheless, if you wish to proceed, add an `unclean` parameter to Rake:

    rake unclean=1

### Get a manifest of all the components

To get a better idea of exactly what is going on, add a `manifest` parameter.

    rake manifest=1

That will produce additional files in `build/manifest` which indicate which
package (icu, erlang, spidermonkey, etc) owns which files within `build`. A
trick I do a lot is `cat build/manifest/couchdb | xargs rm` to "uninstall" only
couchdb so I can try a rebuild.

I have no idea how `manifest` interacts with `install` as I have never
used them together.

 [geocouch]: http://vmx.cx/cgi-bin/blog/index.cgi/geocouch-the-future-is-now:2010-05-03:en,CouchDB,Python,Erlang,geo

### Do not strip down Erlang/OTP

Build CouchDB strips many modules out of the Erlang platform to reduce disk
usage. (You can see which ones at the top of `tasks/erlang.rake`.) To indicate
that a package should be kept, set the `otp_keep` variable to space-separated
library names.

    rake otp_keep="compiler eunit"

Or, you can keep them all this way:

    rake otp_keep="*"

### How to build only Erlang, couchjs, and OTP so you can build your own CouchDB elsewhere

There is a special shortcut task to build everything CouchDB needs (i.e. its dependencies).

    rake couchdb:deps otp_keep="*"

Be careful not to build the `couchdb` target because after it completes, it will delete Erlang components needed for building (but not running).
Next, there is a simple task which outputs a `sh` script used to configure any CouchDB checkout.

    rake --silent environment:configure

The output will look similar to this:

    export PATH="/Users/jhs/src/build-couchdb/build/bin:$PATH"
    LDFLAGS='-R/Users/jhs/src/build-couchdb/build/lib -L/Users/jhs/src/build-couchdb/build/lib' CFLAGS='-I/Users/jhs/src/build-couchdb/build/include/js -I/Users/jhs/src/build-couchdb/build/lib/erlang/usr/include' ./configure

In the CouchDB source, paste the above code after running `./bootstrap`. Next, you can run `make` or `make dev`, or anything.

vim: tw=80

#!/bin/sh

NAME="IO-File-Cached"

set -e

# Make things clean.

make -k realclean ||:
rm -rf MANIFEST blib

# Make makefiles.

perl Makefile.PL PREFIX=$AUTO_BUILD_PREFIX
make manifest
echo $NAME.spec >> MANIFEST

# Build the RPM.
make
make test

make install INSTALLMAN3DIR=$AUTO_BUILD_PREFIX/man/man3

rm -f $NAME-*.tar.gz
make dist
rpm -ta --clean $NAME-*.tar.gz

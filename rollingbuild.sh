#!/bin/sh

NAME="Config-Record"

set -e

# Make things clean.

make -k realclean ||:
rm -rf MANIFEST blib

# Make makefiles.

perl Makefile.PL PREFIX=$AUTO_BUILD_ROOT
make manifest
echo $NAME.spec >> MANIFEST

# Build the RPM.
make
perl -MDevel::Cover -e '' 1>/dev/null 2>&1 && USE_COVER=1 || USE_COVER=0
if [ "$USE_COVER" = "1" ]; then
  cover -delete
  HARNESS_PERL_SWITCHES=-MDevel::Cover make test
  cover
  mkdir blib/coverage
  cp -a cover_db/*.html cover_db/*.css blib/coverage
  mv blib/coverage/coverage.html blib/coverage/index.html
else
  make test
fi

make install

rm -f $NAME-*.tar.gz
make dist

if [ -f /usr/bin/rpmbuild ]; then
  rpmbuild -ta --clean $NAME-*.tar.gz
fi

if [ -f /usr/bin/fakeroot ]; then
  fakeroot debian/rules clean
  fakeroot debian/rules DESTDIR=$HOME/packages/debian binary
fi

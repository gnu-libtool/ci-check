#!/bin/sh

# Copyright (C) 2024 Free Software Foundation, Inc.
#
# This file is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script builds the package.
# Usage: build-tarball.sh PACKAGE
# Its output is a tarball: $package/$package-*.tar.gz

package="$1"
branch="$2"

if test -z $branch; then
    branch="master"
fi

set -e

# Fetch sources (uses package 'git').
# The depth here needs to be at least 2, because the number of commits in the
# git history of HEAD is stored as "serial" number in m4/ltversion.m4, and if
# it is not at least 2 the unit test
#   libtoolize.at: "14: verbatim aclocal.m4 w/o AC_CONFIG_MACRO_DIRS"
# fails.
git clone --depth 2 -b "$branch" https://git.savannah.gnu.org/git/"$package".git
git clone --depth 1 https://git.savannah.gnu.org/git/gnulib.git

# Apply patches.
(cd "$package" && patch -p1 < ../patches/0001-libtool-Additional-flag-for-test-on-NetBSD.patch)

export GNULIB_SRCDIR=`pwd`/gnulib
cd "$package"
# Force use of the newest gnulib.
rm -f .gitmodules

# Fetch extra files and generate files (uses packages wget, python3, automake, autoconf, m4,
# texinfo, xz-utils).
date --utc --iso-8601 > .tarball-version
./bootstrap --no-git --gnulib-srcdir="$GNULIB_SRCDIR"

# Configure (uses package 'file').
./configure --config-cache CPPFLAGS="-Wall" > log1 2>&1; rc=$?; cat log1; test $rc = 0 || exit 1
# Build (uses packages make, gcc, ...).
make > log2 2>&1; rc=$?; cat log2; test $rc = 0 || exit 1
# Run the tests.
make check TESTSUITEFLAGS="--debug" > log3 2>&1; rc=$?; cat log3; test $rc = 0 || exit 1
# Check that tarballs are correct.
make distcheck > log4 2>&1; rc=$?; cat log4; test $rc = 0 || exit 1

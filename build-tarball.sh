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
# Usage: build-tarball.sh PACKAGE BRANCH COMMIT_MESSAGE
# Its output is a tarball: $package/$package-*.tar.gz

package="$1"
branch="$2"
commit_message="$3"

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
(cd "$package" && patch -p1 < ../patches/0001-libtool.texi-Documentation-inconsitent-with-libltdl3.patch && \
                  patch -p1 < ../patches/0002-libtool.texi-Wrong-names-for-structure-members.patch && \
                  patch -p1 < ../patches/0003-libtool.m4-Add-run-path-when-linking-with-tcc.patch && \
                  patch -p1 < ../patches/0004-libtool.m4-Avoid-a-broken-AC_TRY_EVAL-macro.patch && \
                  patch -p1 < ../patches/0005-libtool.m4-Add-spaces-before-L-in-grep-searches.patch && \
                  patch -p1 < ../patches/0006-Makefile.am-Generate-description-for-whatis-command.patch && \
                  patch -p1 < ../patches/0007-libtool-Add-support-for-netbsdelf.patch && \
                  patch -p1 < ../patches/0008-libtool-Change-how-version-is-derived.patch && \
                  patch -p1 < ../patches/0009-ltmain.in-Add-error-message-for-unknown-version-type.patch)

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

case "$commit_message" in
  *"[pre-release]"*)
    # Run pre-release testing.
    make distcheck CXX=g++ > log4 2>&1; rc=$?; cat log4; test $rc = 0 || exit 1
    ;;
  *)
    # Check that tarballs are correct.
    make distcheck > log4 2>&1; rc=$?; cat log4; test $rc = 0 || exit 1
    ;;
esac

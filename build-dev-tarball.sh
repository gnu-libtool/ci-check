#!/bin/sh

# Copyright (C) 2024-2025 Free Software Foundation, Inc.
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
# Usage: build-dev-tarball.sh PACKAGE BRANCH COMMIT_MESSAGE
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
git clone --depth 1 "${gnulib_url}"

# Apply patches.
(cd "$package" && patch -p1 < ../patches/Skip-test-option-parser.sh-for-ksh-shell-on-NetBSD.patch \
               && patch -p1 < ../patches/0001-libtool-Fix-mishandling-compiler-flags-with-MSVC-too.patch \
               && patch -p1 < ../patches/0002-testsuite.at-Update-testsuite-config-for-MSVC.patch \
               && patch -p1 < ../patches/0003-libtool-Alter-expected-line-endings-in-testsuite.patch \
               && patch -p1 < ../patches/0004-tagdemo.at-Update-for-MSVC.patch \
               && patch -p1 < ../patches/0005-tests-Include-check-for-__CYGWIN__-for-crossbuilds.patch \
               && patch -p1 < ../patches/0006-libtoolize.in-Create-symlinks-with-mklink-for-MSVC.patch \
               && patch -p1 < ../patches/0007-libtool.m4-For-MS-dumpbin-drop-CR-first.patch \
               && patch -p1 < ../patches/0008-libtool.m4-preload-valid-C-symbol-names-only.patch \
               && patch -p1 < ../patches/0009-libtoolize.at-Update-checks-based-on-linker-used.patch \
               && patch -p1 < ../patches/0010-ltmain.in-Fix-hang-with-cmd.exe-in-MSYS.patch \
               && patch -p1 < ../patches/0011-ltmain.in-Add-S_ISDIR-definition-for-MSVC.patch \
               && patch -p1 < ../patches/0012-libtool-Fix-MSVC-cl.exe-.exp-extension-collision.patch \
               && patch -p1 < ../patches/0013-inherited_flags.at-Fix-test-on-MSVC.patch \
               && patch -p1 < ../patches/0014-MSVC-debugging.patch)

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

case "$commit_message" in
  *"[pre-release]"*)
    # Run pre-release testing.
    make distcheck CXX=g++ > log4 2>&1; rc=$?; cat log4; test $rc = 0 || exit 1
    ;;
  *)
    # Check that tarballs are correct.
    make distcheck TESTSUITEFLAGS="-d 1" > log4 2>&1; rc=$?; cat log4; test $rc = 0 || exit 1
    ;;
esac

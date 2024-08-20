#!/bin/bash

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

# This script builds a tarball of the package on a single platform.
# Usage: build-on.sh PACKAGE CONFIGURE_OPTIONS MAKE

package="$1"
configure_options="$2"
make="$3"
commit_message="$4"

set -x

# Unpack the tarball.
tarfile=`echo "$package"-*.tar.gz`
packagedir=`echo "$tarfile" | sed -e 's/\.tar\.gz$//'`
tar xfz "$tarfile"
cd "$packagedir" || exit 1

mkdir build
cd build

# Configure.
../configure --config-cache $configure_options > log1 2>&1; rc=$?; cat log1; test $rc = 0 || exit 1

# Build.
$make > log2 2>&1; rc=$?; cat log2; test $rc = 0 || exit 1

if [[ "$commit_message" == *"[pre-release]"* ]]; then
  # Run pre-release testing.
  c=check ve=check-very-expensive; git grep -q "^$ve:\$" && c=$ve
  $make $c syntax-check distcheck > log5 2>&1; rc=$?; cat log5; test $rc = 0 || exit 0
  $make distcheck DISTCHECK_CONFIGURE_FLAGS=--disable-ltdl-install > log6 2>&1; rc=$?; cat log6; test $rc = 0 || exit 0
  $make distcheck DISTCHECK_CONFIGURE_FLAGS=--program-prefix=g > log7 2>&1; rc=$?; cat log7; test $rc = 0 || exit 0
  $make distcheck DISTCHECK_CONFIGURE_FLAGS=--disable-shared > log8 2>&1; rc=$?; cat log8; test $rc = 0 || exit 0
  $make distcheck CC=g++ > log9 2>&1; rc=$?; cat log9; test $rc = 0 || exit 0
else
  # Run the tests.
  $make check TESTSUITEFLAGS="--debug" > log3 2>&1; rc=$?; cat log3; test $rc = 0 || exit 1
fi

cd ..

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

# This script builds a tarball of the package on a single platform.
# Usage: build-on.sh PACKAGE CONFIGURE_OPTIONS MAKE MAKE_OPTIONS COMMIT_MESSAGE

package="$1"
configure_options="$2"
make="$3"
make_options="$4"
commit_message="$5"

set -x

case "$configure_options" in
  --host=riscv*) cross_compiling=true ;;
  *)             cross_compiling=false ;;
esac

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
$make V=1 > log2 2>&1; rc=$?; cat log2; test $rc = 0 || exit 1

if ! $cross_compiling; then
  case "$commit_message" in
    *"[pre-release]"*)
      # Run pre-release testing.
      ret_code=0
      inc=3
      for configure_flag in "--disable-ltdl-install" \
                            "--program-prefix=g" \
                            "--disable-shared"
      do
        ../configure $configure_options $configure_flag >> log"$inc" 2>&1; rc=$?; test $rc = 0 || ret_code=$rc
        test $rc = 0 || echo "Failed: 'configure $configure_flag'" >> log"$inc"
        $make check V=1 >> log"$inc" 2>&1; rc=$?; test $rc = 0 || ret_code=$rc
        test $rc = 0 || echo "Failed: '$make check V=1' for 'configure $configure_flag'" >> log"$inc"
        cat log"$inc"
        inc=$(( $inc + 1 ))
      done
      ../configure $configure_options CXX=g++ >> log"$inc" 2>&1; rc=$?; test $rc = 0 || ret_code=$rc
      $make check V=1 CXX=g++ >> log"$inc" 2>&1; rc=$?; test $rc = 0 || ret_code=$rc
      test $rc = 0 || echo "Failed: '$make check V=1 CXX=g++'" >> log"$inc"
      cat log"$inc"
      test $ret_code = 0 || exit 1
      ;;
    *)
      # Run the tests.
      $make check $make_options V=1 TESTSUITEFLAGS="--debug 179 185" > log3 2>&1; rc=$?; cat log3; test $rc = 0 || exit 1
      ;;
  esac
fi

cd ..

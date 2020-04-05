#!/bin/bash

if which -s cmake; then
  which cmake
  exit 0
fi

known_cmake_paths="/usr/local/bin/cmake \
  /opt/local/bin/cmake \
  /Applications/CMake.app/Contents/bin/cmake"
  
for cmake_path in $known_cmake_paths; do
  if [[ -e $cmake_path ]]; then
    echo $cmake_path
    exit 0
  fi
done

echo "Could not find cmake; install it from the official distribution, Homebrew or MacPorts" > /dev/stderr
exit 1

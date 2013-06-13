#!/bin/sh

libname='ufront-mvc'
rm -f "${libname}.zip"
zip -r "${libname}.zip" haxelib.json src LICENSE.txt README.md
cd thx
zip -r "../${libname}.zip" src
cd ..
echo "Saved as ${libname}.zip"

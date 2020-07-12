#!/bin/bash

mkdir -p build

zip -9 -r build/doom-tower.love *.lua data/

pushd build

wget https://github.com/love2d/love/releases/download/11.3/love-11.3-win64.zip
unzip -o love-11.3-win64.zip
mkdir -p doom-tower
cat love-11.3-win64/love.exe doom-tower.love > doom-tower/doom-tower.exe
cp love-11.3-win64/*.dll doom-tower/
zip -9 -r doom-tower-win64.zip doom-tower/

popd

#!/bin/bash

for FILE in *.zip
do
    NAME=`basename "$FILE" .zip`
    rm -rf "$NAME"
    mkdir "$NAME"
    unzip -n -j -d "$NAME" "$FILE"
done

for FILE in *.rar
do
    NAME=`basename "$FILE" .rar`
    rm -rf "$NAME"
    mkdir "$NAME"
    pushd "$NAME"
    unrar e -o- ../"$FILE"
    popd
done

for FILE in *.cpp
do
    NAME=`basename "$FILE" .cpp`
    rm -rf "$NAME"
    mkdir "$NAME"
    mv "$FILE" "$NAME"
done

for FILE in *.c
do
    NAME=`basename "$FILE" .c`
    rm -rf "$NAME"
    mkdir "$NAME"
    mv "$FILE" "$NAME"
done

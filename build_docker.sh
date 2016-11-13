#!/bin/sh

BASE_IMAGE=up-hw-test

if [ $# -gt 0 -a -d "$1" ]; then
    # build an image for a specific set of tests
    DIR="$1"
    DIR_NAME=`basename "$DIR"`
    IMAGE_NAME=$BASE_IMAGE-$DIR_NAME
    echo "Building image $IMAGE_NAME"

    # copy Dockerfile to build context
    cp Dockerfile.tests "$DIR"/Dockerfile

    docker build -t $IMAGE_NAME "$DIR"
else
    # build the generic image in which tests are attached as a volume
    echo "Building image $BASE_IMAGE"
    docker build -t $BASE_IMAGE .
fi

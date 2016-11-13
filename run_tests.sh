#!/bin/bash

function run_docker()
{
    echo "Running image $IMAGE..."
    docker run --rm \
           -v `pwd`/$RESULTS_DIR:$BASE/results \
           -v `pwd`/progs:$BASE/progs:ro \
           $OPTS \
           $IMAGE
}


BASE=/usr/src/up-hw-test
BASE_IMAGE=trifon/up-hw-test

if [ $# -lt 1 ]; then
    echo "Usage: run_tests.sh <directory_to_test>"
    exit 1
fi

DIR="$1"

cd "$DIR"

# create a fresh results dir each time
TIMESTAMP=`date +%Y%m%d%H%M%S`
RESULTS_DIR=results-$TIMESTAMP
mkdir $RESULTS_DIR

# prepare image parameters
DIR_NAME=`basename "$DIR"`
IMAGE=$BASE_IMAGE:$DIR_NAME
OPTS=

# which image to run? Try the specific one first
if ! run_docker; then
    # no specific image, run the general one
    # and hope there are tests
    IMAGE=$BASE_IMAGE:latest
    OPTS="-v `pwd`/tests:$BASE/tests:ro"
    run_docker
fi
echo "Done, results written to $RESULTS_DIR"

# archiving results
ARCHIVE="$RESULTS_DIR.zip"

echo "Archiving results to $ARCHIVE..."
zip -q "$ARCHIVE" "$RESULTS_DIR"/* > /dev/null
echo "Done"

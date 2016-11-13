#!/bin/sh

BASE=/usr/src/up-hw-test
BASE_IMAGE=up-hw-test

if [ $# -lt 1 ]; then
    echo "Usage: run_tests.sh <directory_to_test>"
    exit 1
fi

DIR="$1"

cd "$DIR"

DIR_NAME=`basename "$DIR"`
DIR_IMAGE=$BASE_IMAGE-$DIR_NAME

# which image to run? The generic one or the specific one?
if docker images | grep $DIR_IMAGE > /dev/null 2> /dev/null; then
    # there is a specific image run it
    IMAGE=$DIR_IMAGE
    OPTS=
else
    # no specific image, run the general one
    # and hope there are tests
    IMAGE=$BASE_IMAGE
    OPTS="-v `pwd`/tests:$BASE/tests:ro"
fi

# create a fresh results dir each time
TIMESTAMP=`date +%Y%m%d%H%M%S`
RESULTS_DIR=results-$TIMESTAMP
mkdir $RESULTS_DIR

# run the image

echo "Running image $IMAGE..."
docker run --rm \
       -v `pwd`/$RESULTS_DIR:$BASE/results \
       -v `pwd`/progs:$BASE/progs:ro \
       $OPTS \
       $IMAGE

echo "Done, results written to $RESULTS_DIR"

# archiving results
ARCHIVE="$RESULTS_DIR.zip"

echo "Archiving results to $ARCHIVE..."
zip -q "$ARCHIVE" "$RESULTS_DIR" > /dev/null
echo "Done"

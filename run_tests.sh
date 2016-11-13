#!/bin/sh

BASE=/usr/src/up-hw-test

cd "$1"

# create a fresh results dir each time
TIMESTAMP=`date +%Y%m%d%H%M%S`
RESULTS_DIR=results-$TIMESTAMP


mkdir $RESULTS_DIR
docker run --rm \
       -v `pwd`/$RESULTS_DIR:$BASE/results \
       -v `pwd`/progs:$BASE/progs:ro \
       -v `pwd`/tests:$BASE/tests:ro \
       up-hw-test

# archiving results
zip $RESULTS_DIR.zip $RESULTS_DIR

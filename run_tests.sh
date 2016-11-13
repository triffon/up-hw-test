#!/bin/sh

BASE=/usr/src/up-hw-test

cd "$1"
docker run --rm \
       -v `pwd`/results:$BASE/results \
       -v `pwd`/progs:$BASE/progs:ro \
       -v `pwd`/tests:$BASE/tests:ro \
       up-hw-test

#!/bin/bash

if [ "$#" -lt 1 ]
then
    echo "Usage: $0 <dir-name>"
    exit
fi

cd "$1"
for TESTLIST in *.tests
do
    TASK=`basename "$TESTLIST" .tests`
    for TEST in {A..Z}
    do
	if ! read LINE
	then
	    break
	fi
        TESTNAME="$TASK$TEST"
	echo "Generating test $TESTNAME" 
	echo "$LINE" > $TESTNAME.test
	echo "$LINE" > $TESTNAME.test.ans
    done < "$TESTLIST"
done

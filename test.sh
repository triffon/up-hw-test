#!/bin/bash

BASEDIR=`pwd`
TESTDIR=$BASEDIR/tests
PROGDIR=$BASEDIR/progs
RESULTDIR=$BASEDIR/results
TOTALSFILE=$RESULTDIR/results.csv
TIMEOUT=10
LIMIT=2K
MAX=10
GCC=g++
SHELL="/bin/sh -c"

function create_totals()
{
    rm -f "$TOTALSFILE"
    echo -n "ID" >> "$TOTALSFILE"
    for ID in `seq 1 $MAX`
    do
	for TESTIN in "$TESTDIR"/$ID?.test; do
	    TESTBASE=`basename "$TESTIN" .test`
	    echo -n ",$TESTBASE" >> "$TOTALSFILE"
	done
    done
    echo >> "$TOTALSFILE"
}

function log()
{
    echo "$@" >&2
}

function write_status()
{
    log "$1"
    echo -n ",$1" >> "$TOTALSFILE"
}

function do_extract()
{
    FILE="$1"
    EXTENSION="${FILE##*.}"
    case $EXTENSION in
	zip) unzip -n -j "$FILE" ;;
	rar) unrar e -o- "$FILE" ;;
    esac
}

function quirk_nested
{
    if ls *.zip >/dev/null 2> /dev/null || ls *.rar >/dev/null 2> /dev/null
    then
	for SUBFILE in *.{zip,rar}
	do
	    log "QUIRK: Extracting nested archive $SUBFILE"
	    do_extract "$SUBFILE"
	done
    fi
}

function quirk_wrong_names
{
    if ls *.cpp 2> /dev/null | grep -v '^prog[0-9]*.cpp$' >/dev/null 2>/dev/null
    then
	for SUBFILE in *.cpp
	do
	    if ! echo $SUBFILE | grep ^prob > /dev/null 2> /dev/null
	    then
	        # wrong name, try to recover...
		NEWNAME=`echo "$SUBFILE" | sed -e 's/^\(\|.*[^0-9]\)\([0-9]\+\)\.\(cpp\|c\|cc\)/prog\2.cpp/'`
		log "QUIRK: Autorenaming $SUBFILE to $NEWNAME"
		mv "$SUBFILE" "$NEWNAME"
	    fi
	done
    fi

}

function quirk_stdafx
{
    if cat *.cpp 2> /dev/null | grep stdafx >/dev/null 2>/dev/null
    then
	log "QUIRK: Creating dummy stdafx.h"
	cat > stdafx.h <<EOF
#define _TCHAR char
#define _tmain main
#include <cmath>
#include <cstring>
EOF
	CPPOPTS="-I$TMPDIR $CPPOPTS"
    fi
}

function quirk_system_pause
{
    if grep 'system' *.cpp >/dev/null 2>/dev/null
    then
	log "QUIRK: Faking system function"
	CPPOPTS=-D'system(x)=0'" $CPPOPTS"
    fi
}

function quirks()
{
    # some archives have nested zips/rars in them :(
    quirk_nested

    # some cpp files are named wrongly :(
    quirk_wrong_names

    # some programs expect stdafx.h :(
    quirk_stdafx

    # some programs use system("pause")
    quirk_system_pause
}

function extract_archive()
{
    # handles zip and rar
    DIR="$2"

    rm -rf "$DIR"
    mkdir "$DIR"
    pushd "$DIR" > /dev/null

    do_extract "$1"

    # attempt to recover broken solutions
    quirks

    popd > /dev/null
}

function run_tests()
{
    SOLUTION="$1"

    SOLUTION_BASE=`basename "$SOLUTION" .zip`
    SOLUTION_BASE=`basename "$SOLUTION_BASE" .rar`

    SOLUTION_ID=`echo "$SOLUTION_BASE" | cut -d_ -f1`

    TMPDIR="$PROGDIR/tmp"
 
    CPPOPTS=

    echo -n "$SOLUTION_ID" >> "$TOTALSFILE"

    log "Testing $SOLUTION_ID"
    extract_archive "$SOLUTION" "$TMPDIR"

    for ID in `seq 1 $MAX`
    do
	log "Testing program $ID"
	SRC="$TMPDIR/prog$ID.cpp"
	EXE="$TMPDIR/prog$ID"
	if [ -f "$SRC" ]
	then
	    # try to compile first
	    # be quiet, and if it doesn't work, include standard headers
	    if ! g++ -o "$EXE" $CPPOPTS "$SRC" 2>/dev/null
	    then
		log "QUIRK: autoincluding standard headers"
		INCLUDES="-include cmath -include cstring -include climits -include cstdio"
		# now yell all the errors and warnigns at the world :)
		g++ -o "$EXE" $INCLUDES $CPPOPTS "$SRC"
	    fi
	    if [ -x "$EXE" ]
	    then
		# start tests for this program one by one
		for TESTIN in "$TESTDIR/$ID"?.test
		do
		    TESTBASE=`basename "$TESTIN" .test`
		    TESTOUT="$TESTIN".ans
		    PROGRESULT="$RESULTDIR"/"$SOLUTION_ID"_"$TESTBASE"
		    PROGOUT="$PROGRESULT".out
		    PROGERR="$PROGRESULT".err

		    log -n "Running test $TESTBASE: "

		    # cleanup first
		    rm -f "$PROGOUT" "$PROGERR"

		    # run in a subshell, timeboxed and with limited output
		    STATUS=`timeout $TIMEOUT "$EXE" < "$TESTIN" 2> "$PROGERR" | head -c $LIMIT > "$PROGOUT"; echo ${PIPESTATUS[0]}`

		    # check for timeout
		    if [ $STATUS = 124 ]
		    then
			write_status "TO"
		    # check for output limit
		    elif [ $STATUS = 141 ]
		    then
			write_status "OL"
		    # check for runtime error
		    elif [ $STATUS != 0 ]
		    then
			write_status "RE"
		    else
			# check against expected output
			if diff -w "$PROGOUT" "$TESTOUT" > /dev/null 2> /dev/null
			then
			    write_status "OK"
			else
			    write_status "WA"
			fi
		    fi
		done
	    else
		for TESTIN in "$TESTDIR/$ID"?.test
		do
		    write_status "CE"
		done
	    fi
	else
	    for TESTIN in "$TESTDIR/$ID"?.test
	    do
		write_status "NA"
	    done
	fi
    done
    
    echo >> "$TOTALSFILE"

}

if [ $# -gt 0 ]; then
    # this program should run one test
    run_tests "$1"
else
    # this program should run all tests
    create_totals
    for PROG in "$PROGDIR"/*.{zip,rar}; do
	run_tests "$PROG"
    done
fi

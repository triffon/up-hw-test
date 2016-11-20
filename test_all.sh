#!/bin/bash

BASEDIR=`pwd`
TESTDIR=$BASEDIR/tests
PROGDIR=$BASEDIR/progs
RESULTDIR=$BASEDIR/results
TOTALSFILE=$RESULTDIR/results.csv
TIMEOUT=10
LIMIT=100K
MAX=10
GCC=g++
SHELL="/bin/sh -c"

function create_totals()
{
    rm -f "$TOTALSFILE"
    echo -n "ID" >> "$TOTALSFILE"
    for ID in `seq 1 $MAX`
    do
	for TESTIN in "$TESTDIR"/$ID[A-Z]*.test; do
	    TESTBASE=`basename "$TESTIN" .test`
	    echo -n ",$TESTBASE" >> "$TOTALSFILE"
	done
    done
    echo ",notes" >> "$TOTALSFILE"
}

function log()
{
    echo "$@" >&2
}

function log_quirk()
{
    log "QUIRK: $1"
    NOTES="$NOTES $1;"
}

function write_status()
{
    log "$1"
    echo -n ",$1" >> "$TOTALSFILE"
}

function do_copy()
{
    FILE="$1"
    # copy recursively in case there are nested directories
    cp -r "$FILE"/* .
}

function do_extract()
{
    FILE="$1"
    EXTENSION="${FILE##*.}"
    case $EXTENSION in
	zip) unzip -n -j "$FILE" ;;
	rar) unrar e -o- "$FILE" ;;
	7z) 7z e -y "$FILE" ;;
    esac
}

function quirk_nested
{
    if ls *.zip >/dev/null 2> /dev/null || ls *.rar >/dev/null 2> /dev/null
    then
	for SUBFILE in *.{zip,rar}
	do
	    log_quirk "Extracting nested archive $SUBFILE"
	    do_extract "$SUBFILE"
	done
    fi
}

function quirk_nested_dirs
{
    find . -type d | while read DIR
    do
        if [ "$DIR" != "." ]
        then
            # there is another directory inside other than .
            log_quirk "Moving files from nested directory $DIR"
            mv "$DIR"/* .
        fi
    done
}

function quirk_wrong_names
{
    if ls *' '*.cpp >/dev/null 2>/dev/null
    then
        for SUBFILE in *' '*.cpp
        do
            # spaces in filenames, remove them :(
	    NEWNAME=`echo "$SUBFILE" | sed -e 's/ //g'`
	    log_quirk "Autorenaming $SUBFILE to $NEWNAME"
	    mv "$SUBFILE" "$NEWNAME"
        done
    fi

    if ls *'-'*.cpp >/dev/null 2>/dev/null
    then
        for SUBFILE in *'-'*.cpp
        do
            # dashes in filenames, replace them with underscores :(
	    NEWNAME=`echo "$SUBFILE" | sed -e 's/-/_/g'`
	    log_quirk "Autorenaming $SUBFILE to $NEWNAME"
	    mv "$SUBFILE" "$NEWNAME"
        done
    fi

    if ls fn_*.cpp >/dev/null 2>/dev/null
    then
        for SUBFILE in fn_*.cpp
        do
            # fn_XXXXX instead of fnXXXXX, remove first underscore
	    NEWNAME=`echo "$SUBFILE" | sed -e 's/fn_/fn/'`
	    log_quirk "Autorenaming $SUBFILE to $NEWNAME"
	    mv "$SUBFILE" "$NEWNAME"
        done
    fi

    for SUBFILE in *.cpp
    do
        if [[ "$SUBFILE" =~ [A-Z] ]]
        then
            # file name has capital letters, convert to lowercase
	    NEWNAME=`echo "$SUBFILE" | tr '[:upper:]' '[:lower:]'`
	    log_quirk "Autorenaming $SUBFILE to $NEWNAME"
	    mv "$SUBFILE" "$NEWNAME"
        fi
    done
}

function quirk_stdafx
{
    if grep stdafx *.cpp >/dev/null 2>/dev/null
    then
	log_quirk "Creating dummy stdafx.h"
	cat > stdafx.h <<EOF
#define _TCHAR char
#define _tmain main
#include <cmath>
#include <cstring>
EOF
	CPPOPTS="$CPPOPTS -I\"$TMPDIR\""
    fi
}

function quirk_header
{
    HEADER="$1"
    if grep "$HEADER" *.cpp >/dev/null 2>/dev/null
    then
	log_quirk "Creating dummy $HEADER"
	touch "$HEADER"
	CPPOPTS="$CPPOPTS -I\"$TMPDIR\""
    fi
}

function quirk_system_pause
{
    for FILE in *.cpp
    do
        if grep system "$FILE" >/dev/null 2>/dev/null
        then
	    log_quirk "Faking system function for $FILE"
            # the below quirk doesn't work anymore... let's append to the .cpp files instead
	    # CPPOPTS="-D'system(x)=0' $CPPOPTS"

            cat >> "$FILE" <<EOF
int system(const char*) {}
EOF
        fi
    done
}

function quirk_int64()
{
    if grep __int64 *.cpp >/dev/null 2>/dev/null
    then
        log_quirk "Simulating __int64"
        CPPOPTS="$CPPOPTS -D'__int64=long long'"
    fi
}

function quirk_utf()
{
    if file *.cpp | grep 'UTF-' >/dev/null 2>/dev/null
    then
	# there are some UTF-encoded source files, try to convert
	for FILE in *.cpp
	do
	    FORMAT=`file "$FILE"`
	    ENCODING=
	    if echo "$FORMAT" | grep -i 'UTF-8' >/dev/null 2>/dev/null
	    then
		ENCODING=utf8
	    fi
	    if echo "$FORMAT" | grep -i 'UTF-16' >/dev/null 2>/dev/null
	    then
		ENCODING=utf16
	    fi
	    if [ "$ENCODING" != "" ]
	    then
		log_quirk "Decoding $FILE using $ENCODING"
		iconv -f $ENCODING -t ascii//TRANSLIT <"$FILE" >"$FILE".iconv
	    fi
	done
	for FILE in *.iconv
	do
	    BASENAME=`basename "$FILE" .iconv`
	    mv "$FILE" "$BASENAME"
	done
    fi
}

function quirk_void_main
{
    for FILE in *.cpp
    do
        if grep "void\s*main" "$FILE" >/dev/null 2>/dev/null
        then
            # substituting void main with int main
            log_quirk "Changing void main() to int main() in $FILE"
            sed -e 's/void\s*main/int main/' < "$FILE" >"$FILE".new
            mv "$FILE".new "$FILE"
        fi
    done
}

function quirk_itoa
{
    if grep "itoa\|ltoa" *.cpp >/dev/null 2>/dev/null
    then
        # simulation of itoa needed
        log_quirk "Simulating non-standard function itoa"
        CPPOPTS="$CPPOPTS -I\"$TMPDIR\" -include itoa.h"
        cat > itoa.h <<EOF
	/**
	 * C++ version 0.4 char* style "itoa":
	 * Written by Lukás Chmela
	 * Released under GPLv3.
	 */
	char* ltoa(long value, char* result, int base) {
		// check that the base if valid
		if (base < 2 || base > 36) { *result = '\0'; return result; }

		char* ptr = result, *ptr1 = result, tmp_char;
		long tmp_value;

		do {
			tmp_value = value;
			value /= base;
			*ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz" [35 + (tmp_value - value * base)];
		} while ( value );

		// Apply negative sign
		if (tmp_value < 0) *ptr++ = '-';
		*ptr-- = '\0';
		while(ptr1 < ptr) {
			tmp_char = *ptr;
			*ptr--= *ptr1;
			*ptr1++ = tmp_char;
		}
		return result;
	}

        char* itoa(int value, char* result, int base) {
          return ltoa(value, result, base);
        }

        char* _itoa(int value, char* result, int base) {
          return itoa(value, result, base);
        }

        char* _ltoa(long value, char* result, int base) {
          return ltoa(value, result, base);
        }
EOF
    fi
}

function quirk_s()
{
    if grep "strcpy_s\|scanf_s\|strcat_s" *.cpp >/dev/null 2>/dev/null
    then
        # fake _s functions via their insecure counterparts
        log_quirk "Faking strcpy_s, scanf_s, strcat_s"
        cat > fake_s.h <<EOF
#include <cstring>
int strcat_s(char * dest, size_t, const char *src) {
  strcat(dest, src);
  return 0;
}
template <size_t size>
int strcat_s(
   char (&strDestination)[size],
   const char *strSource
) {
  strcat(strDestination, strSource);
  return 0;
}

int strcpy_s(char * dest, size_t, const char *src) {
  strcpy(dest, src);
  return 0;
}
template <size_t size>
int strcpy_s(
   char (&strDestination)[size],
   const char *strSource
) {
  strcpy(strDestination, strSource);
  return 0;
}
EOF
        CPPOPTS="$CPPOPTS -D'scanf_s=scanf' -I\"$TMPDIR\" -include fake_s.h"

    fi
}

# these quirks need to be run in advance to prepare for the parsing of the solution ID
function quirks_naming()
{
    # some archives have nested zips/rars in them :(
    quirk_nested

    # some files are inside a second directory :(
    quirk_nested_dirs

    # some cpp files are named wrongly :(
    # disable quirks because of new file naming
    quirk_wrong_names
}

# these quirks are run after the solution ID is detected
function quirks()
{
    DIR="$1"
    pushd "$DIR" >/dev/null

    # some programs expect stdafx.h, conio.h, windows.h, tchar.h :(
    quirk_stdafx
    quirk_header "conio.h"
    quirk_header "windows.h"
    quirk_header "tchar.h"

    # some programs use the non-standard funcitons itoa, _itoa, ltoa, _ltoa
    quirk_itoa

    # some programs use the Annex K C11 _s funcitons (strcat_s, strcpy_s, scanf_s)
    quirk_s

    # some programs use system("pause")
    quirk_system_pause

    # some programs are UTF-encoded :(
    quirk_utf

    # some programs use VC-specific __int64
    quirk_int64

    # some programs use void main, which is non-standard
    quirk_void_main

    popd >/dev/null
}

function extract_archive()
{
    DIR="$2"

    rm -rf "$DIR"
    mkdir "$DIR"
    pushd "$DIR" > /dev/null

    # extraction of archives no longer necessary
    # do_extract "$1"
    # copy files to target dir instead
    do_copy "$1"

    # attempt to recover solutions with wrong naming and structure
    quirks_naming

    popd > /dev/null
}

function run_tests()
{
    SOLUTION="$1"
    TMPDIR=`readlink -f "$PROGDIR/../tmp"`
    CPPOPTS=-std=c++11
    NOTES=

    # prepare files
    extract_archive "$SOLUTION" "$TMPDIR"

    # try to detect solution ID
    FIRST_PROGRAM_PATH=("$TMPDIR"/fn*)
    FIRST_PROGRAM_BASENAME=`basename "$FIRST_PROGRAM_PATH"`

    # extract FN
    SOLUTION_ID=`echo "$FIRST_PROGRAM_BASENAME" | cut -d_ -f1 | cut -c3-8`

    REGEXP_NUMBER='^[0-9]+$'
    if ! [[ $SOLUTION_ID =~ $REGEXP_NUMBER ]]
    then
        log "Could not parse ID from file name $FIRST_PROGRAM_BASENAME in solution $SOLUTION containing files "`ls "$TMPDIR"`
        return
    fi

    # prepare for testing
    echo -n "$SOLUTION_ID" >> "$TOTALSFILE"

    log "Testing $SOLUTION_ID"

    # attempt to recover broken solutions
    quirks "$TMPDIR"

    for ID in `seq 1 $MAX`
    do
	log "Testing program $ID"
	SRC=`find "$TMPDIR" -name "fn*_prob$ID\_*.cpp" -print0`
	EXE="$TMPDIR/prog$ID"
	if [ -f "$SRC" ]
	then
	    # try to compile first
	    # be quiet, and if it doesn't work, include standard headers
	    if ! eval $GCC -o "$EXE" $CPPOPTS "$SRC" 2>/dev/null
	    then
		log_quirk "Autoincluding standard headers, adding -fpermissive for $SRC"
		MORECPPOPTS="-include cmath -include cstring -include climits -include cstdio -include cfloat -include iomanip -fpermissive"
		# now yell all the errors and warnings at the world :)
		eval $GCC -o "$EXE" $CPPOPTS $MORECPPOPTS "$SRC"
	    fi
	    if [ -x "$EXE" ]
	    then
		# start tests for this program one by one
		for TESTIN in "$TESTDIR/$ID"[A-Z]*.test
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
                        # ignore space changes to permit multiple spaces instead of one
                        # and to handle different Windows/Unix/MacOSX EOLs correctly
			# check against expected output
			if diff -b "$PROGOUT" "$TESTOUT" > /dev/null 2> /dev/null
			then
			    write_status "OK"
			else
			    write_status "WA"
			fi
		    fi
		done
	    else
		for TESTIN in "$TESTDIR/$ID"[A-Z]*.test
		do
		    write_status "CE"
		done
	    fi
	else
	    for TESTIN in "$TESTDIR/$ID"[A-Z]*.test
	    do
		write_status "NA"
	    done
	fi
    done

    echo ",\"$NOTES\"" >> "$TOTALSFILE"

}

if [ $# -gt 0 ]; then
    # this program should run one test
    run_tests "$1"
else
    # this program should run all tests
    create_totals
    for PROG in "$PROGDIR"/*; do
	run_tests "$PROG"
    done
fi

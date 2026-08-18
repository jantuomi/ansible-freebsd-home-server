#!/bin/sh

PATH=$PATH:/usr/local/bin

BASENAME="$1"
EXTENSION="${BASENAME##*.}"

[ "${BASENAME}" = "${EXTENSION}" ] && EXTENSION=txt
[ -z "${EXTENSION}" ] && EXTENSION=txt
[ "${BASENAME%%.*}" = "Makefile" ] && EXTENSION=mk

highlight --force -f -I --inline-css -s night -O xhtml -S "$EXTENSION"

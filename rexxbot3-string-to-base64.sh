#!/bin/sh

# option 'w0' means: never wrap lines / allow long lines

printf '%s' "$@" | base64 -w0
printf '\n'

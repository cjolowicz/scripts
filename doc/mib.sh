#!/bin/bash

# http://www.simpleweb.org/ietf/mibs/modules/microsoft/win2000/txt/FtpServer-MIB

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "$prog [options] [mibs]

options:

    -h, --help              display this message
    -v, --verbose           be verbose
    -d, --download          download the MIB
    -w, --vendor STRING     vendor string

Valid vendor strings are:

  IETF
  IANA
  microsoft/win2000
  HP/printers
"
}

### parse command line #################################################

bad_option () {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

missing_arg () {
    echo "$prog: option \`$1' requires an argument" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

vendor=IETF
verbose=no
download=no
while [ $# -gt 0 ] ; do
    opt=$1
    shift

    case $opt in
        -d | --download) download=yes ;;
        -h | --help) usage ; exit ;;
        -v | --verbose) verbose=yes ;;
        -w | --vendor) [ $# -ne 0 ] || missing_arg $opt ; vendor="$1" ; shift ;;
        --) break ;;
        -*) bad_option $opt ;;
        *) set -- "$opt" "$@" ; break ;;
    esac
done

### main ###############################################################

say () {
    [ $verbose = no ] || echo "$prog: $@" >&2
}

for mib
do
    url=http://www.simpleweb.org/ietf/mibs/modules/$vendor/txt/$mib
    say $url
    if [ $download = yes ] ; then
        wget -O$mib.mib $url
    else
        wget -qO- $url | less
    fi
done

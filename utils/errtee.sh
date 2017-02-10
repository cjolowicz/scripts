#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "$prog [options] command [arguments]
Copy standard error to a file.

options:

    -f, --file FILE           copy to this file [+]
    -a, --append              append, do not overwrite
    -i, --ignore-interrupts   ignore interrupt signals
    -h, --help                display this message

If FILE is -, copy again to standard error.
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

files=()
options=()
while [ $# -gt 0 ] ; do
    option=$1
    shift

    case $option in
        -f | --file)
            [ $# -gt 0 ] || missing_arg $option
            files+=("$1")
            shift
            ;;

        -a | --append | \
        -i | --ignore-interrupts)
            options+=($option)
            ;;

        -h | --help)
            usage
            exit
            ;;

        --)
            break
            ;;

        -*)
            bad_option $option
            ;;

        *)
            set -- "$option" "$@"
            break
            ;;
    esac
done

### main ###############################################################

if [ ${#files[@]} -eq 0 ] ; then
    "$@"
else
    exec 3>&1
    "$@" 2>&1 1>&3 | tee "${options[@]}" "${files[@]}" 1>&2
fi

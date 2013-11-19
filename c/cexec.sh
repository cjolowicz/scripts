#!/bin/bash

usage () {
    echo "$(basename $0) [-vh] [-H HEADER] [-e CODE]"
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

verbose=false
headers=('<stdlib.h>'
         '<sys/types.h>'
         '<inttypes.h>'
         '<stdint.h>'
         '<string.h>'
         '<stdbool.h>'
         '<unistd.h>'
         '<stdio.h>')

while [ $# -gt 0 ]
do
    opt="$1"
    shift

    case $opt in
        -H | --header)
            [ $# -gt 0 -a -n "$1" ] || missing_arg $opt
            case $1 in
                '<'*'>'|'"'*'"') headers+=("$1") ;;
                *) headers+=("<$1>") ;;
            esac
            shift
            ;;

        -e | --execute)
            [ $# -gt 0 ] || missing_arg $opt
            body="${body}${body:+
}$1;"
            shift
            ;;

        -v | --verbose) verbose=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $opt ;;
        *) set -- "$opt" "$@" ; break ;;
    esac
done

### main ###############################################################

CC=${CC:-gcc}

cwd=$(pwd)
tmpdir=$(mktemp -d)
trap 'cd $cwd && rm -rf $tmpdir' 0
cd $tmpdir

if [ $# -ne 0 -o -z "$body" ] ; then
    body="${body}${body:+
}$(cat "$@")"
fi

(
    for header in "${headers[@]}" ; do
        printf '#include %s\n' "$header"
    done
    printf '\nint main()\n{\n%s;\nreturn 0;\n}\n' "$body"
) > main.c

if $verbose ; then
    cat main.c
    echo
    echo "/* build log */"
    $CC -o main main.c || exit $?
    echo
    echo "/* output */"
    ./main
else
    $CC -o main main.c && ./main
fi


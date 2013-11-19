#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

case $(pwd) in
    */src/*) directory="$(pwd | sed 's,/src/,/build/,')" ;;
    *)       directory=$HOME/build ;;
esac

repeat=0
progress=false
no_file=false
no_make=false
no_run=false

usage () {
    echo "\
$prog [options] [target] [arguments]

Build and run the target.
Without a target, build and run the test suite.

options:

    -h, --help              display this message
    -d, --directory DIR     directory to build in (default: $directory)
    -n, --repeat NUM        number of times to run target
    -p, --progress          show progress bar
    -F, --no-file           target is not an executable file
    -M, --no-make           do not build the target
    -R, --no-run            do not run the target
"
    exit $1
}

### parse command line #################################################

while [ $# -gt 0 ]
do
    arg="$1"
    shift

    case $arg in
        -d | --directory) directory="$1" ; shift ;;
        -h | --help) usage 0 ;;
        -n | --repeat) repeat="$1" ; shift ;;
        -p | --progress) progress=true ;;
        -F | --no-file) no_file=true ; no_run=true ;;
        -M | --no-make) no_make=true ;;
        -R | --no-run) no_run=true ;;
        --) set -- "$arg" "$@" ; break ;;
        -*) usage 2 ;;
        *) set -- "$arg" "$@" ; break ;;
    esac
done

if [ $# -gt 0 ] ; then
    target="$1" ; shift

    if ! $no_file ; then
        case $target in */*) ;; *)
            target="./$target"
        esac
    fi
fi

[[ "$repeat" =~ ^[0-9]+$ ]] || {
    echo "bad option argument for -n: $repeat"
    usage 2
}

### functions ##########################################################

if [ -t 1 ] ; then
  print_header_begin="$(tput setf 2)"
  print_header_end="$(tput setf 7)"
fi

function print_header() {
    echo
    echo "${print_header_begin}==> $* <==${print_header_end}"
    echo
}

function run_n() {
    n="$1" ; shift

    if [ $n -eq 0 ] ; then
        "$@"
        return
    fi

    if $progress ; then
        echo "Running tests..."
        for i in $(seq $n); do
            if ! output="$("$@")" ; then
                print_header "$@ ($i/$n)" >&2
                echo "$output" >&2
                echo >&2
                break
            fi
            echo .
        done | pv -ls $n >/dev/null
    else
        for i in $(seq $n); do
            print_header "$@ ($i/$n)"
            "$@" || break
        done
    fi
}

### main ###############################################################

cd $directory &&

if [ -n "$target" ] ; then
    ( $no_make || make "$target" ) &&
    ( $no_run  || run_n "$repeat" "$target" "$@" )
else
    ( $no_make || make ) &&
    ( $no_run  || run_n "$repeat" make test )
fi

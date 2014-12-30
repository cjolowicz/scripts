#!/bin/bash

prog=$(basename $0)
confdir=/etc

### usage ##############################################################

usage () {
    echo "usage: $prog [options] [hg-options] [hg-command [options] [args]]
Invoke mercurial on multiple repositories.

options:
    -l, --list              Print the list of repositories.
    -n, --dry-run           Print commands without executing them.
    -k, --keep-going        Continue even if the command fails in a repository.
    -C, --cwd DIR           Change working directory.
    -R, --repository DIR    Include directory in the list of repositories.
    -c, --config FILE       Specify a different configuration file.
    -h, --help              Display this message.

The program reads $confdir/$prog.conf and \$HOME/.$prog if they exist.
Each line in these files may contain a long option without the leading
hyphens. Options must be separated from their arguments by an \`='
without whitespace. Empty lines and lines starting with a \`#' are
ignored. Boolean options take \`yes' and \`no' as arguments."
}

### configuration ######################################################

parse_configuration_file () {
    printf 'configuration_options=()\n'
    sed '/^[ \t]*\(#\|$\)/d' "$1" |
    while read line ; do
        case $line in
            *'=yes')
                printf 'configuration_options+=(--%q)\n' \
                    "${line%%=*}"
                ;;

            *'=no')
                printf 'configuration_options+=(--no-%q)\n' \
                    "${line%%=*}"
                ;;

            *'='*)
                printf 'configuration_options+=(--%q %q)\n' \
                    "${line%%=*}" \
                    "${line#*=}"
                ;;

            *)
                printf 'configuration_options+=(--%q)\n' \
                    "${line}"
                ;;
        esac
    done
}

for configuration_file in $confdir/$prog.conf $HOME/.$prog ; do
    if [ -f $configuration_file ] ; then
        if ! eval "$(parse_configuration_file "$configuration_file")" ; then
            echo "cannot read \`$configuration_file'" >&2
            exit 1
        fi
        set -- "${configuration_options[@]}" "$@"
    fi
done

### command line #######################################################

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

cwd=
repositories=()
keep_going=false
list=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -c | --config)
            [ $# -gt 0 ] || missing_arg "$option"
            configuration_file="$1"
            shift
            if ! [ -f $configuration_file ] && eval "$(parse_configuration_file "$configuration_file")" ; then
                echo "cannot read \`$configuration_file'" >&2
                exit 1
            fi
            set -- "${configuration_options[@]}" "$@"
            ;;

        -C | --cwd) [ $# -gt 0 ] || missing_arg "$option" ; cwd="$1" ; shift ;;
        -R | --repository) [ $# -gt 0 ] || missing_arg "$option" ; repositories+=("$1") ; shift ;;
        -k | --keep-going) keep_going=true ;;
        --no-keep-going) keep_going=false ;;
        -l | --list) list=true ;;
        -n | --dry-run) dry_run=true ;;
        --no-dry-run) dry_run=false ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

### hg command line ####################################################

hg_options=()
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -R | --repository | --cwd | --config | --encoding | --encodingmode | --pager | --color)
            [ $# -gt 0 ] || missing_arg "$option"
            hg_options+=("$option" "$1")
            shift
            break
            ;;

        --) hg_options+=("$option") ; break ;;
        -*) hg_options+=("$option") ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

if [ $# -gt 0 ] ; then
  hg_command="$1"
  shift
fi

hg_clone_options=()
case $hg_command in
    clone)
        while [ $# -gt 0 ]
        do
            option="$1"
            shift

            case $option in
                -u | --updaterev | -r | --rev | -b | --branch | -e | --ssh | --remotecmd)
                    [ $# -gt 0 ] || missing_arg "$option"
                    hg_clone_options+=("$option" "$1")
                    shift
                    break
                    ;;

                --) hg_clone_options+=("$option") ; break ;;
                -*) hg_clone_options+=("$option") ;;
                *) set -- "$option" "$@" ; break ;;
            esac
        done
        ;;

    qclone)
        while [ $# -gt 0 ]
        do
            option="$1"
            shift

            case $option in
                -p | --patches | -e | --ssh | --remotecmd)
                    [ $# -gt 0 ] || missing_arg "$option"
                    hg_clone_options+=("$option" "$1")
                    shift
                    break
                    ;;

                --) hg_clone_options+=("$option") ; break ;;
                -*) hg_clone_options+=("$option") ;;
                *) set -- "$option" "$@" ; break ;;
            esac
        done
        ;;
esac

### main ###############################################################

if [ -z "$cwd" ] ; then
    if cwd="$(hg root 2>/dev/null)" ; then
        cwd="$(realpath "$cwd"/..)"
    fi
fi

if [ -n "$cwd" ] ; then
    if $dry_run ; then
        echo "cd $cwd"
    fi

    cd "$cwd"
fi

if [ -t 1 -a -x /usr/bin/tput ] ; then
    BEGIN="$(tput setf 2)"
    END="$(tput setf 7)"
fi

if [ -z "$hg_command" ] && ! $list ; then
    echo "$prog: missing command" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
fi

error=0

if [ ${#repositories[@]} -eq 0 ] ; then
    repositories=($(
        find . -mindepth 2 -maxdepth 2 -type d -name '.hg' |
        while read dir ; do
            if [ -f "$dir/hgrc" ] ; then
                basename "$(realpath "$dir/..")"
            fi
        done
    ))
fi

for repository in "${repositories[@]}"
do
    if $list ; then
        echo "$repository"
        continue
    fi

    echo "${BEGIN}==> $repository <==${END}"

    case $hg_command in
        clone | qclone)
            options=("${hg_options[@]}" "$hg_command" "${hg_clone_options[@]}")

            if [ $# -ge 1 ] ; then
                options+=("$1/$repository")
            fi

            if [ $# -ge 2 ] ; then
                options+=("$2/$repository")
            fi

            options+=("${@:3}") # Let hg produce the usage error message.
            ;;
        *)
            options=(--cwd "$repository" "${hg_options[@]}" "$hg_command" "$@")
            ;;
    esac

    if $dry_run ; then
        echo "hg ${options[@]}"
    elif ! hg "${options[@]}" ; then
        error=$?

        $keep_going || exit $error
    fi
done

exit $error

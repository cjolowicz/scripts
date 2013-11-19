#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "$prog [options] [files]

options:

    -h, --help              display this message
    -v, --verbose           be verbose
    -x, --xaxis COL         column number of the X axis data (1)
    -y, --yaxis COL         column number of the Y axis data (2)
    -X, --xlabel TEXT       label for the X axis (none)
    -Y, --ylabel TEXT       label for the Y axis (none)
        --xrange NUM:NUM    range for the X axis (all)
        --yrange NUM:NUM    range for the Y axis (all)
        --xtime FORMAT      X axis is time using the specified format
        --style STYLE       graph style (lines)
    -s, --smooth            smooth the data using csplines
        --smooth-csplines
    -S, --smooth-bezier     smooth the data using bezier
    -t, --title TEXT        graph title ($prog)
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

title=$prog
xaxis=1
yaxis=2
xtime=
style=lines
smooth=
only_smooth=yes
verbose=no
while [ $# -gt 0 ] ; do
    opt=$1
    shift

    case $opt in
        -x | --xaxis)  [ $# -ne 0 ] || missing_arg $opt ; xaxis=$1 ; shift ;;
        -y | --yaxis)  [ $# -ne 0 ] || missing_arg $opt ; yaxis=$1 ; shift ;;
        -X | --xlabel) [ $# -ne 0 ] || missing_arg $opt ; xlabel=$1 ; shift ;;
        -Y | --ylabel) [ $# -ne 0 ] || missing_arg $opt ; ylabel=$1 ; shift ;;
             --xrange) [ $# -ne 0 ] || missing_arg $opt ; xrange=$1 ; shift ;;
             --yrange) [ $# -ne 0 ] || missing_arg $opt ; yrange=$1 ; shift ;;
             --xtime)  [ $# -ne 0 ] || missing_arg $opt ; xtime=$1 ; shift ;;
             --style)  [ $# -ne 0 ] || missing_arg $opt ; style=$1 ; shift ;;
        -s | --smooth-csplines | --smooth) smooth='smooth csplines' ;;
        -S | --smooth-bezier) smooth='smooth bezier' ;;
        +s) smooth='smooth csplines' ; only_smooth=no ;;
        +S) smooth='smooth bezier' ; only_smooth=no ;;
        -t | --title)  [ $# -ne 0 ] || missing_arg $opt ; title=$1 ; shift ;;
        -h | --help) usage ; exit ;;
        -v | --verbose) verbose=yes ;;
        --) break ;;
        -*) bad_option $opt ;;
        *) set -- "$opt" "$@" ; break ;;
    esac
done

### prepare ############################################################

say () {
    [ $verbose = no ] || echo "$prog: $@" >&2
}

if [ $# -eq 0 ] ; then
    set -- -
fi

if [ -n "$xtime" -a -z "$xlabel" ] ; then
    xlabel=time
fi

rm -f tmp-$prog.*

index=0
data=$(mktemp tmp-$prog.XXXXXX)

say "created data file $data"

:> $data

for file
do
    say "processing $file..."

    # append to data file
    [ ! -s "$data" ] || ( echo ; echo ) >> $data
    cat "$file" >> $data

    # append to plot command
    plot_title=$(basename "${file%.???}")
    linecolor=$(($index + 2))

    if [ -z "$smooth" -o $only_smooth = no ] ; then
        [ -z "$plots" ] || plots="$plots,"
        plots="${plots} \"$data\" index $index using $xaxis:$yaxis with $style linecolor $linecolor title \"$plot_title\""
    fi

    if [ -n "$smooth" ] ; then
        [ -z "$plots" ] || plots="$plots,"
        plots="${plots} \"$data\" index $index using $xaxis:$yaxis $smooth with lines linecolor $linecolor title \"$plot_title ($smooth)\""
    fi

    ((index++))
done

### plot ###############################################################

say "plotting data..."

if [ -n "$xtime" ] ; then
    set_xdata="set xdata time"
    set_timefmt="set timefmt \"$xtime\""
fi

# generate the graph
gnuplot -persist <<EOF
set title "$title"
set key outside
set xlabel "$xlabel"
set ylabel "$ylabel"
set xrange [$xrange]
set yrange [$yrange]
$set_xdata
$set_timefmt
plot $plots
EOF

#!/bin/bash
# pipx install youtube-dl

set -euo pipefail

url="$1"
shift

start_ts="$1"
shift

end_ts="$1"
shift

fade_start_secs="$1"
shift

fade_duration_secs="$1"
shift

filename="$(youtube-dl --get-filename "$url")"

youtube-dl "$url"

input="${filename%.*}.mkv"
output="${filename%.*}.mp4"

options=(
    -i "$input"
    -ss "$start_ts"
    -t "$end_ts"
    -vf "fade=t=out:st=$fade_start_secs:d=$fade_duration_secs"
    -af "afade=t=out:st=$fade_start_secs:d=$fade_duration_secs"
)

ffmpeg "${options[@]}" "$output"

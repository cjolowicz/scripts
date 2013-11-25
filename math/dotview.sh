#!/bin/bash

read height width <<< $(xwininfo -root | sort | sed -nr 's/ *(Width|Height): *//p')

aspect=$(($height * 10 / $width))
aspect=${aspect%?}.${aspect:(-1)}

dot -Tpng -Gratio=$aspect "$@" |
display -resize ${width}x${height} -

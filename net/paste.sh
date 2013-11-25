#!/bin/sh

if [ $# -gt 0 ] ; then
    echo "$@" | curl -F 'content=<-' http://bin.z80.us/api
else
    curl -F 'content=<-' http://bin.z80.us/api
fi

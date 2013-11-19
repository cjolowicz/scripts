#!/bin/bash

while read line
do
    echo "$RANDOM $line"
done |
sort |
while read _ line
do
    echo "$line"
done

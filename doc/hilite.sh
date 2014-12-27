#!/bin/bash

for file
do
  enscript -q -E --color -whtml $file -o- | 
  grep -v '^<H1>' | 
  tidy -asxhtml -q -i -o $file.html
done

#!/bin/bash
dd if=/dev/urandom count=1 2>/dev/null | tr -d -c '[:graph:]' | cut -c-${1:-8}

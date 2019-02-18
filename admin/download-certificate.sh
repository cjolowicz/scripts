#!/bin/bash

for host
do
    openssl s_client -showcerts -connect $host:443 </dev/null 2>/dev/null |
	openssl x509 -outform PEM
done

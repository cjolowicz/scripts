#!/bin/bash

for host
do
    echo quit |
    openssl s_client -showcerts -servername $host -connect $host:443 |
	openssl x509 -outform PEM
done

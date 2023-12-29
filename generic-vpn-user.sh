#!/bin/bash

# test firt arg
if [[ -z "${1}" ]]; then
    echo "Usage: $0 <number of generic users to create>"
    exit 1
fi

for i in $(seq 1 $1); do
    if [! -f ./certs/clients/generic-user-${i}.pfx ]; then
        ./new-vpn-user.sh generic-user-${i} 90
    fi
done
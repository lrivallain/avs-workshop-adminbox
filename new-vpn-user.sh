#!/bin/bash

client_certs_path="./certs/clients"
mkdir -p ${client_certs_path}

# test $1 not empty
if [ -z "$1" ]; then
  read -p "Enter the VPN user name: " vpn_user
else
  vpn_user=$1
fi
echo "Creating a new VPN user: $vpn_user"

# test $2 not empty
if [ -z "$2" ]; then
  # ask for a validity period with a default value of 365 days
  read -p "Enter the validity period in days [365]: " validity_period
  validity_period=${validity_period:-365}
else
  validity_period=$2
fi
echo "The validity period is ${validity_period} days"

# create the certificate key and certificate signing request
openssl req -new -subj "/CN=${vpn_user}" -newkey rsa:2048 \
  -keyout "${client_certs_path}/${vpn_user}.key" \
  -out "${client_certs_path}/${vpn_user}.csr" -passout file:./certs/pass-phrase \
  2>/dev/null

# create the temporary v3.ext file
echo "[v3_req]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints=critical,CA:false
subjectAltName=email:${vpn_user}@microsoft.com
extendedKeyUsage=critical,clientAuth
keyUsage=critical,nonRepudiation,digitalSignature,keyEncipherment" > /tmp/.vpn-v3.ext

# sign the certificate
openssl x509 -req -days ${validity_period} \
  -extensions v3_req -extfile /tmp/.vpn-v3.ext \
  -CA ./certs/P2S_RootCert.crt -CAkey ./certs/P2S_RootCert.key -passin file:./certs/pass-phrase -CAcreateserial \
  -in "${client_certs_path}/${vpn_user}.csr" -out "${client_certs_path}/${vpn_user}.crt"

# create the pfx file
openssl pkcs12 -export -out "${client_certs_path}/${vpn_user}.pfx" \
  -inkey "${client_certs_path}/${vpn_user}.key" -in "${client_certs_path}/${vpn_user}.crt" \
  -certfile ./certs/P2S_RootCert.crt -passin file:./certs/pass-phrase -passout pass:""

# Display the certificate path
echo "Use the following PFX file to import in windows certificate store: ${client_certs_path}/${vpn_user}.pfx"

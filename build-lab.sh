#!/bin/bash

echo "Testing env variables"
missing_var=false
# iter over list of required env variables
for var in AVS_LAB_ADMIN_PASSWORD AVS_LAB_ADMIN_RG VPN_CA_PASSPHRASE AVS_EXPRESSROUTE_ID AVS_EXPRESSROUTE_AUTHKEY; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Missing ${var} env variable"
        missing_var=true
        if [[ "${var}" == "AVS_LAB_ADMIN_PASSWORD" ]]; then
            echo "  export AVS_LAB_ADMIN_PASSWORD=xxx    # This is the password used to access the admin VM"
        fi
        if [[ "${var}" == "AVS_LAB_ADMIN_RG" ]]; then
            echo "  export AVS_LAB_ADMIN_RG=xxx          # This is the name of the resource group where the admin ressources will be deployed"
        fi
        if [[ "${var}" == "VPN_CA_PASSPHRASE" ]]; then
            echo "  export VPN_CA_PASSPHRASE=xxx         # This is the passphrase used to protect the VPN CA private key"
        fi
        if [[ "${var}" == "AVS_EXPRESSROUTE_ID" ]]; then
            echo "  export AVS_EXPRESSROUTE_ID=xxx       # This is the ID of the ExpressRoute circuit used to connect to AVS"
        fi
        if [[ "${var}" == "AVS_EXPRESSROUTE_AUTHKEY" ]]; then
            echo "  export AVS_EXPRESSROUTE_AUTHKEY=xxx  # This is the auth key of the ExpressRoute circuit used to connect to AVS"
        fi
    fi
done
if [[ "${missing_var}" == "true" ]]; then
  exit -1
fi
echo "All required env variables are set"

# Test if unzip is installed
if ! command -v unzip &> /dev/null
then
    echo "unzip could not be found: please install it."
    exit -1
fi

mkdir -p ./certs
if [ ! -f ./certs/P2S_RootCert.crt ]; then
    echo "Create a new VPN CA"
    echo ${VPN_CA_PASSPHRASE} > ./certspass-phrase
    chmod 600 ./certs/pass-phrase
    openssl req -x509 -new -sha256 -days 9125 -subj "/CN=AVS Lab VPN" \
      -newkey rsa:4096 -keyout ./certs/P2S_RootCert.key \
      -out ./certs/P2S_RootCert.crt --passout file:./certs/pass-phrase 2>/dev/null
    cat ./certs/P2S_RootCert.crt | grep -v "CERTIFICATE" | tr -d '\n' > ./certs/P2S_RootCert_for_import.crt
    echo "New VPN CA created"
fi

echo "Starting the deployment of admin resources"
timestamp=$(date +%s)
deployment_name="avs-workshop-admin-${timestamp}"
az deployment group create \
  --name ${deployment_name} \
  --resource-group ${AVS_LAB_ADMIN_RG} \
  --template-file ./bicep/main.bicep \
  --parameters adminPassword=${AVS_LAB_ADMIN_PASSWORD} \
  --parameters avsErCircuitId=${AVS_EXPRESSROUTE_ID} \
  --parameters avsErAuthorizationKey=${AVS_EXPRESSROUTE_AUTHKEY} \
  --output none

# if the deployment failed, exit
if [[ $? != 0 ]]; then
  echo "Deployment failed"
  exit -1
fi

# Getting outputs from the deployment
jumpbox_ip=$( az deployment group show \
  --name ${deployment_name} \
  --resource-group ${AVS_LAB_ADMIN_RG} \
  --query properties.outputs.jumpboxIpAddress.value \
  --output tsv)
jumpbox_username=$( az deployment group show \
  --name ${deployment_name} \
  --resource-group ${AVS_LAB_ADMIN_RG} \
  --query properties.outputs.jumpboxUsername.value \
  --output tsv)

# if vpn-config folder does not exist
if [ ! -d ./vpn-config ]; then
    echo "Getting the VPN client configuration"
    mkdir -p ./vpn-config
    # Getting the VPN client configuration URI for download
    vpn_config_url=$( az network p2s-vpn-gateway vpn-client generate \
        --name user-p2s-vpn-gateway --resource-group ${AVS_LAB_ADMIN_RG} \
        --authentication-method EAPTLS | jq ".profileUrl" | tr -d '"')
    # Downloading the VPN client configuration
    wget -qO ./vpn-config/vpn-config.zip ${vpn_config_url}
    # Unzipping the VPN client configuration
    unzip -qqf ./vpn-config/vpn-config.zip -d ./vpn-config 2>/dev/null && rm ./vpn-config/vpn-config.zip
fi
echo "VPN configuration is available in the $(pwd)/vpn-config folder"

if [ ! -f ./certs/clients/avslab-admin.pfx ]; then
    ./new-vpn-user.sh avslab-admin 90
fi
echo "You can use the following command to create a other VPN clients:"
echo "  ./new-vpn-user.sh <username>"

echo ""
echo "Jumpbox IP: ${jumpbox_ip}"
echo "Jumpbox username: ${jumpbox_username}"


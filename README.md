# AVS Labs Admin Box

This repository aims to be an helper to setup a quick [AVS labs](https://github.com/Azure/avslabs/) setup that can later be shared with workshop participants.

It will help to deploy:

* an Azure vWAN Hub
* an P2S VPN configuration to provide network connectivity to AVS directly from their workstation
* a jump server used as the "admin-box" to deploy nested lab content

By providing P2S VPN connectivity for workshop attendees, there is no need to setup a jumpbox per attendee or per-lab to access AVS resources or nested lab ones.

This repository only provide resources to deploy the above mentionned resources. Nested lab content is deploy through the following repository content: [Azure/avslabs](https://github.com/Azure/avslabs/).

## Pre-requisites

A linux based distribution with [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) is required to deploy the content of the content of this repository.

On top of this, the following packages are required:

* openssl
* unzip

## Configure

The configuration is made through environment variables:

```bash
export AVS_LAB_ADMIN_PASSWORD=xxx    # This is the password used to access the admin VM"
export AVS_LAB_ADMIN_RG=xxx          # This is the name of the resource group where the admin ressources will be deployed"
export VPN_CA_PASSPHRASE=xxx         # This is the passphrase used to protect the VPN CA private key"
export AVS_EXPRESSROUTE_ID=xxx       # This is the ID of the ExpressRoute circuit used to connect to AVS"
export AVS_EXPRESSROUTE_AUTHKEY=xxx  # This is the auth key of the ExpressRoute circuit used to connect to AVS"
```

## Deploy the content with bicep

Run the `./build-lab.sh` script to initiate the admin box content creation.

```bash
./build-lab.sh

# Output
Testing env variables                                                                         
All required env variables are set
Starting the deployment of admin resources
VPN configuration is available in the vpn-config/ folder
You can use the following command to create VPN clients:
  ./new-vpn-user.sh <username> <validity-in-days>
   
Jumpbox IP: 10.123.123.4
Jumpbox username: avsjump
```

## Connectivity

### P2S VPN

Connectivity is build on top of Azure vWAN with:

* Express Route connection to AVS
* P2S VPN for admin and user access

The P2S VPN is configured to accept certificate based authentication based on a local root certificate.

You can create a new certificate for user (or admin) by using the provided `new-vpn-user.sh` script:

```bash
./new-vpn-user.sh <username>
```

You can repeat the command for each new user.

Each user needs a certificate and (common) Azure VPN configuration file to be able to connect.

### User certificate

Navigate to `certs\clients` folder.

Provide the `.pfx` or the `.crt` matching username provided during the user creation process to the target user.

They will need to install the certificate in their local certificate store.

For example on Windows:

1. double click on the `.pfx` file
1. *"Current User"*
1. *Next*
1. *Next*
1. (No password) *Next*
1. (Automatically select...) *Next*
1. **Finish**

### Azure VPN configuration file

Azure VPN configuration file is common to all users of the labs and is available in folder `vpn-config\AzureVPN`.

Share the `azurevpnconfig.xml` with users.

### Connect

When users are created, you can use **Azure VPN** to connect to lab resources.

* For Windows:
  * Install using Client Install files: https://aka.ms/azvpnclientdownload.
  * Install the Azure VPN Client from the [Microsoft Store](https://go.microsoft.com/fwlink/?linkid=2117554).
* For MacOS:
  * Install the Azure VPN Client from the [Apple Store](https://apps.apple.com/us/app/azure-vpn-client/id1553936137).

1. Import the configuration `azurevpnconfig.xml` in Azure VPN client
1. Select the appropriate certificate for **client authentication**.
1. Connect to the newly created VPN connection to get access to the deployed resources.

## Nested Labs

When the admin box is deployed, you can use the admin jump box to deploy nested labs.

You can rely on this repository to do so: [Azure/avslabs](https://github.com/Azure/avslabs/):

  * `bootstrap.ps1` is alreay ready to be used in the `C:\Temp` folder.

### Example

1. Open a PowerShell session
1. `cd C:\Temp`
1. `powershell.exe -ExecutionPolicy Unrestricted -File .\bootstrap.ps1 -NoAuto`
1. Download and customize [nestedlabs.yml](https://raw.githubusercontent.com/Azure/avslabs/main/scripts/nestedlabs.yml) in the `C:\Temp`
1. Open a new PowerShell 7 (!) session
1. Run the lab creation command based on the number of labs to create:

```powershell
# to deploy 9 nested labs with group number 1
c:\temp\bootstrap-nestedlabs.ps1 -GroupId 1 -Labs 9
```

### Connectivity with nested labs

It could be required to restart the VPN connection in order to get the newly created network available through the VPN.

By default everything available from AVS will be advertised to both the Admin jump VM and the VPN connections.
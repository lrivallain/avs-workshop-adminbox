@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix for all resources.')
param prefix string

@description('Name of the virtual network.')
var virtualNetworkName = '${prefix}-avs-vnet'

@description('Network prefix for the virtual network.')
param vnetPrefix string = '10.123.123.0/24'

@description('Name of the admin subnet.')
var subnetName = '${prefix}-admin-subnet'

@description('Network prefix for the admin subnet.')
param subnetPrefix string = '10.123.123.0/27'



resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${subnetName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-rdp-in'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'Allow RDP from anywhere'
        }
      }
    ]
  }
}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

output subnetId string = virtualNetwork.properties.subnets[0].id
output vnetId string = virtualNetwork.id


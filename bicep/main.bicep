@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix for all resources.')
@minLength(3)
param prefix string = 'demo1'

@description('Admin password for jumpbox.')
@secure()
@minLength(12)
param adminPassword string = newGuid()

@description('Azure VMware Solution ExpressRoute circuit ID.')
param avsErCircuitId string = ''

@description('Azure VMware Solution ExpressRoute circuit authorization key.')
@secure()
param avsErAuthorizationKey string = ''


module network './vnet.bicep' = {
  name: 'Network'
  params: {
    location: location
    prefix: prefix
  }
}

module jumpadmin './jumpadmin.bicep' = {
  name: 'JumpAdmin'
  params: {
    location: location
    prefix: prefix
    subnetId: network.outputs.subnetId
    adminPassword: adminPassword
  }
}

output jumpboxIpAddress string = jumpadmin.outputs.jumpboxIpAddress
output jumpboxUsername string = jumpadmin.outputs.jumpboxUsername

module vwan './vwan.bicep' = {
  name: 'vWAN'
  params: {
    location: location
    prefix: prefix
    vnetId: network.outputs.vnetId
    avsErCircuitId: avsErCircuitId
    avsErAuthorizationKey: avsErAuthorizationKey
  }
}

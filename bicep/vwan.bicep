@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix for all resources.')
param prefix string

@description('Reference to the vnet.')
param vnetId string

@description('vWAN Hub network prefix.')
param vWanHubPrefix string = '10.123.124.0/24'

@description('Name of the vWAN.')
var vWanName = '${prefix}-vwan'

@description('Name of the vWAN hub.')
var vWanHubName = '${prefix}-vwan-hub'

@description('Network prefix of VPN clients.')
param vpnClientPrefix string = '10.123.125.0/24'

@description('ID of the ExpressRoute circuit.')
param avsErCircuitId string

@description('Authorization key for ExpressRoute.')
param avsErAuthorizationKey string


resource vWan 'Microsoft.Network/virtualWans@2023-04-01' = {
  name: vWanName
  location: location
  properties: {
    allowBranchToBranchTraffic: true
    allowVnetToVnetTraffic: true
    disableVpnEncryption: false
    type: 'Standard'
  }
}

resource vWanHub 'Microsoft.Network/virtualHubs@2023-04-01' = {
  name: vWanHubName
  location: location
  properties: {
    virtualWan: {
      id: vWan.id
    }
    addressPrefix: vWanHubPrefix
    sku: 'Standard'
  }
}

resource vWanHubVnetConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-04-01' = {
  name: '${vWanHubName}-admin-vnet'
  parent: vWanHub
  properties: {
    remoteVirtualNetwork: {
      id: vnetId
    }
  }
}

// VPN server configuration
resource vpnServerConfiguration 'Microsoft.Network/vpnServerConfigurations@2023-04-01' = {
  name: 'user-p2s-vpn-config'
  location: location
  properties: {
    vpnProtocols: [
      'IkeV2'
      'OpenVPN'
    ]
    vpnAuthenticationTypes: [
      'Certificate'
    ]
    vpnClientRootCertificates: [
      {
        name: 'P2SRootCert'
        // frm local file
        publicCertData: loadTextContent('../certs/P2S_RootCert_for_import.crt')
      }
    ]
  }
}

// VPN gateway
resource p2svpnGateways 'Microsoft.Network/p2svpnGateways@2023-04-01' = {
  name: 'user-p2s-vpn-gateway'
  location: location
  properties: {
    virtualHub: {
      id: vWanHub.id
    }
    vpnServerConfiguration: {
      id: vpnServerConfiguration.id
    }
    p2SConnectionConfigurations: [
      {
        name: 'user-p2s-vpn-config'
        properties: {
          vpnClientAddressPool: {
            addressPrefixes: [
              vpnClientPrefix
            ]
          }
        }
      }
    ]
  }
}

// ExpressRoute gateway
resource expressRouteGateway 'Microsoft.Network/expressRouteGateways@2023-04-01' = {
  name: 'avs-er-gateway'
  location: location
  properties: {
    virtualHub: {
      id: vWanHub.id
    }
    expressRouteConnections: [
      {
        name: 'avs-er-connection'
        properties: {
          authorizationKey: avsErAuthorizationKey
          expressRouteCircuitPeering: {
            id: avsErCircuitId
          }
        }
      }
    ]
    autoScaleConfiguration: {
      bounds: {
          min: 1
      }
    }
  }
}

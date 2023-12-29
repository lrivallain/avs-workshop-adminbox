@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix for all resources.')
param prefix string

@description('Reference to the subnet.')
param subnetId string

@description('Name of the admin user.')
param adminUsername string = 'avsjump'

@description('Password of the admin user.')
@secure()
param adminPassword string = newGuid()

@description('Size of the VM.')
param vmSize string = 'Standard_D2s_v3'

@description('Name of the jump box.')
var vmName = '${prefix}-admin-jump'


resource nicJumpbox 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource jumpbox 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicJumpbox.id
        }
      ]
    }
    osProfile: {
      computerName: substring(toLower(vmName), 0, 14)
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output jumpboxIpAddress string = nicJumpbox.properties.ipConfigurations[0].properties.privateIPAddress
output jumpboxUsername string = jumpbox.properties.osProfile.adminUsername


resource extension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: 'prepare-avs-labs-ressources'
  parent: jumpbox
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "New-Item -Path C:\\ -Name Temp -ItemType Directory -ErrorAction Ignore; Invoke-WebRequest -Uri https://raw.githubusercontent.com/Azure/avslabs/main/scripts/bootstrap.ps1 -OutFile C:\\Temp\\bootstrap.ps1; Unblock-File -Path C:\\Temp\\bootstrap.ps1"'
    }
  }
}

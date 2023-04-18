param name string
param location string = resourceGroup().location

// ------------------------------------ Private Networking
var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'

resource virtualNetwork  'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: 'vnet-${name}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: subnetAddressPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
  resource integrationSubnet 'subnets' existing = {
    name: 'default'
  }
}


// ------------------------------------ App Service Plan & WebApp --------------

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: name
  location: location
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource site 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: virtualNetwork::integrationSubnet.id // Specify a virtual network subnet resource ID to enable regional virtual network integration.
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      alwaysOn: true
      linuxFxVersion: 'PYTHON|3.10'
    }
  }

  resource authv2 'config' = {
    name: 'authsettingsV2'
    kind: 'string'
    properties: {
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            openIdIssuer: 'https://login.microsoftonline.com/d56e3ccd-1bc4-4000-b0a0-456f35d4bdf2/v2.0'
            clientId: 'dfce9232-4e96-4043-8a98-3cf0266c1c46'
            clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
          }
          login: {
            disableWWWAuthenticate: false
            loginParameters: [
              'scope=openid profile email offline_access'
            ]
          }
        }
      }
    }
  }
}

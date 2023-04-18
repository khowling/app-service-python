param name string
param location string = resourceGroup().location

// ------------------------------------ Private Networking
var vnetAddressPrefix = '10.0.0.0/16'
var backendAddressPrefix = '10.0.0.0/24'
var frontendAddressPrefix = '10.0.1.0/24'

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
        name: 'frontend'
        properties: {
          addressPrefix: frontendAddressPrefix
        }
      }
      {
        name: 'backend'
        properties: {
          addressPrefix: backendAddressPrefix
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
  resource backendIntegrationSubnet 'subnets' existing = {
    name: 'backend'
  }
  resource frontendIntegrationSubnet 'subnets' existing = {
    name: 'frontend'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'vnet-frontend-${name}'
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::frontendIntegrationSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'appservice-private-link-connection'
        properties: {
          privateLinkServiceId: site.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }

  resource privateDNSZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-database-windows-net'
          properties: {
            privateDnsZoneId: privateDnsZone.id
          }
        }
      ]
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  properties: {}

  resource privateDnsZoneLink 'virtualNetworkLinks' = {
    name: 'privatelink.azurewebsites.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
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
    virtualNetworkSubnetId: virtualNetwork::backendIntegrationSubnet.id // Specify a virtual network subnet resource ID to enable regional virtual network integration.
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      alwaysOn: true
      linuxFxVersion: 'PYTHON|3.10'
    }
  }

  resource authv2 'config' = {
    name: 'authsettingsV2'

    properties: {
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            openIdIssuer: 'https://login.microsoftonline.com/828514f2-d386-436c-8148-4bea696025bd/v2.0'
            clientId: '9d41b0a7-839f-49ba-8350-8b0271fad878'
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

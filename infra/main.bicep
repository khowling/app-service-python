param name string
param tenentId string = '828514f2-d386-436c-8148-4bea696025bd'
param clientId string = '9d41b0a7-839f-49ba-8350-8b0271fad878'
param location string = resourceGroup().location


@description('Allow Public Network Access to the App Serivce WebApp.')
param allowPublicNetworkAccess bool = true


// ------------------------- Private Networking -------------------------  
resource virtualNetwork  'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: 'vnet-${name}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'frontend'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'dependencies'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'backend'
        properties: {
          addressPrefix: '10.0.0.0/24'
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
  resource dependenciesIntegrationSubnet 'subnets' existing = {
    name: 'dependencies'
  }
}

// ------------------ App Service Frontend Private endpoint --------------------

resource appServiceFrontend 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'appservice-frontend-${name}'
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::frontendIntegrationSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'private-link-connection'
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
    name: 'sites-PrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-database-windows-net'
          properties: {
            privateDnsZoneId: appServiceFrontendDnsZone.id
          }
        }
      ]
    }
  }
}

resource appServiceFrontendDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  properties: {}

  resource privateDnsZoneLink 'virtualNetworkLinks' = {
    name: 'azurewebsites-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

// ------------------ Storage Private endpoint --------------------

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'blob-${name}'
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::dependenciesIntegrationSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'private-link-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }

  resource privateDNSZoneGroup 'privateDnsZoneGroups' = {
    name: 'blob-PrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-database-windows-net'
          properties: {
            privateDnsZoneId: storageDnsZone.id
          }
        }
      ]
    }
  }
}

resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  properties: {}

  resource privateDnsZoneLink 'virtualNetworkLinks' = {
    name: 'storage-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

// ------------------------------------ App Service Managed Identity ---------
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'appidentity-${name}'
  location: location
}

var BLOB_DATA_CONTRIBUTOR = resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource blobroleassign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount::blobServices::container
  name: guid(storageAccount.id, appIdentity.name , BLOB_DATA_CONTRIBUTOR)
  properties: {
    roleDefinitionId: BLOB_DATA_CONTRIBUTOR
    principalType: 'ServicePrincipal'
    principalId: appIdentity.properties.principalId
  }
}


// ------------------------------------- Storage Account ----------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: 'store${uniqueString(name)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
  }

  resource blobServices 'blobServices' = {
    name: 'default'

    resource container 'containers' = {
      name: 'pythonfiles'
      properties: {
        publicAccess: 'None'
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
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: virtualNetwork::backendIntegrationSubnet.id // Specify a virtual network subnet resource ID to enable regional virtual network integration.
    publicNetworkAccess: allowPublicNetworkAccess ? 'Enabled' : 'Disabled'
    siteConfig: {
      alwaysOn: true
      linuxFxVersion: 'PYTHON|3.10'
    }
  }

  resource appsettings 'config' = {
    name: 'appsettings'
    properties: {
      AZURE_CLIENT_ID: appIdentity.properties.clientId
      BLOB_ACCOUNT_URL: storageAccount.properties.primaryEndpoints.blob
      BLOB_CONTAINER_NAME: storageAccount::blobServices::container.name
    }

  }
  resource authv2 'config' = {
    name: 'authsettingsV2'

    properties: {
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            openIdIssuer: '${environment().authentication.loginEndpoint}${tenentId}/v2.0'
            clientId: clientId
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

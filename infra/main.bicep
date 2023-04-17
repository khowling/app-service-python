

param name string
var location = resourceGroup().location

// ------------------------------------ App Service Plan & WebApp --------------

resource farm 'Microsoft.Web/serverfarms@2020-09-01' = {
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

resource site 'Microsoft.Web/sites@2020-10-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: farm.id
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: true
      linuxFxVersion: 'PYTHON|3.9'
    }
  }
}

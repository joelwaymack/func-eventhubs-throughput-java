targetScope = 'subscription'

param location string = deployment().location
param name string = deployment().name

// resource group created in target subscription
resource rg 'Microsoft.Resources/resourceGroups@2020-10-01' = {
  name: '${name}-rg'
  location: location
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    name: name
  }
}

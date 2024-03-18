param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'aca'
param exists bool
param openAiDeploymentName string
param openAiEndpoint string
param openAiApiVersion string

@description('Enable Auth')
param useAuthentication bool

param tenantId string
param loginEndpoint string

param clientId string = ''
@secure()
param clientCertificateThumbprint string = ''

// the issuer is different depending if we are in a workforce or external tenant
var openIdIssuer = empty(tenantId) ? '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0' : 'https://${loginEndpoint}/${tenantId}/v2.0'

resource acaIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}


module app 'core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: acaIdentity.name
    exists: exists
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    env: [
      {
        name: 'AZURE_OPENAI_CHATGPT_DEPLOYMENT'
        value: openAiDeploymentName
      }
      {
        name: 'AZURE_OPENAI_ENDPOINT'
        value: openAiEndpoint
      }
      {
        name: 'AZURE_OPENAI_API_VERSION'
        value: openAiApiVersion
      }
      {
        name: 'RUNNING_IN_PRODUCTION'
        value: 'true'
      }
      {
        name: 'AZURE_OPENAI_CLIENT_ID'
        value: acaIdentity.properties.clientId
      }
    ]
    targetPort: 50505
    secrets: []
  }
}


module auth 'core/host/container-apps-auth.bicep' = if (useAuthentication) {
  name: '${serviceName}-container-apps-auth-module'
  params: {
    name: app.outputs.name
    clientId: clientId
    clientCertificateThumbprint: clientCertificateThumbprint
    openIdIssuer: openIdIssuer
  }
}

output SERVICE_ACA_IDENTITY_PRINCIPAL_ID string = acaIdentity.properties.principalId
output SERVICE_ACA_NAME string = app.outputs.name
output SERVICE_ACA_URI string = app.outputs.uri
output SERVICE_ACA_IMAGE_NAME string = app.outputs.imageName

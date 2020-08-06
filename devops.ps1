# az login
# az account list
# az account set --subscription <guid>

# May be needed (and restarting the command lines): az extension add --name application-insights.

az login --identity -u

$resourceGroupName = "testresourcegroup1"
$location = "westeurope"

$keyVaultName = "testvaultxyz123"
$sqlServerName = "testsqlserver123x123"
$sqlDatabaseName = "testdatabase123"
$sqlServerRootLoginName = "RootAdmin"
$sqlServerRootPassword = "somethingsomething"

$vnetName = "testvnet"
$vnetAddressPrefix = "10.0.0.0/16"
$frontEndSubVnetAddressPrefix = "10.0.0.0/24"
$backEndSubVnetAddressPrefix = "10.0.1.0/24"
$frontEndSubVnetName = "frontendtestsubvnet"
$backEndSubVnetName = "backendtestsubvnet"

$frontEndNsgName = "frontendnsg"
$backEdNsgName = "backendnsg"

$containerName = "testcontainer"
$registryName = "testregistryxyz123"
$containerDnsName = "testcontainerxyz123"

$appServicePlanName = "testserviceplan"
$appServiceSku = "B1"
$appName = "frontendapptestxyz123"
$appIdentityName = "$appName-identity"

$applicationInsightsName = "test-applicationinsights";

$webApiContainerName = "webapi"
$containerName1 = "container-1"
$containerName2 = "container-2"
$containerIdentityName = "container-identity"

$frontEndDeploymentImage = "testregistryxyz123.azurecr.io/webapi:dev"


Write-Host "Creating resources in $location`:" -ForegroundColor Blue
Write-Host ""
Write-Host "Resource Group       : $resourceGroupName" -ForegroundColor Blue
Write-Host "App Service Plan     : $appServicePlanName" -ForegroundColor Blue
Write-Host "Application Insights : $applicationInsightsName" -ForegroundColor Blue
Write-Host "Application Service  : $appName" -ForegroundColor Blue
Write-Host ""

# This script relies on idempotent operations.
Write-Output "Creating resource group `"$resourceGroupName`"..."
if(!(az group exists --name $resourceGroupName))
{
    az group create `
        --name $resourceGroupName `
        --location $location

    Write-Output "Resource group `"$resourceGroupName`" created."
}
else
{
    Write-Output "Resource group `"$resourceGroupName`" exists and was not created."
}

Write-Output "Creating app service plan `"$appServicePlanName`"..."
if((az appservice plan list --query "[?name=='$appServicePlanName'] | length(@)") -lt 1)
{
    az appservice plan create `
        --name $appServicePlanName `
        --resource-group $resourceGroupName `
        --sku $appServiceSku `
        --is-linux `
        --number-of-workers 1

    Write-Output "App service plan `"$appServicePlanName`" created."
}
else
{
    Write-Output "App service plan `"$appServicePlanName`" exists and was not created."
}

Write-Output "Creating Application Insights `"$applicationInsightsName`" monitoring..."
$applicationInsightsObject =
(
    az monitor app-insights component create `
        --app $applicationInsightsName `
        --location $location `
        --resource-group $resourceGroupName
) | ConvertFrom-Json

Write-Output "Application Insights `"$applicationInsightsName`" monitoring created."


# The VNET, its subnetworks and rules will created if they do not exist already.
Write-Output "Creating deployment virtual network `"$vnetName`" and sub-resources..."
if((az network vnet list --query "[?name=='$vnetName'] | length(@)") -lt 1)
{
    # The deployment is created in one VNET that is divided into
    # a subnet for the front-end and a subnet for the containers.
    az network vnet create `
        --name $vnetName `
        --resource-group $resourceGroupName `
        --address-prefix $vnetAddressPrefix `
        #--subnet-name $SubVnetName `
        #--subnet-prefix $SubVnetAddressPrefix

    # The front-end subnet.
    az network vnet subnet create `
        --resource-group $resourceGroupName `
        --name $frontEndSubVnetName `
        --vnet-name $vnetName `
        --address-prefixes $frontEndSubVnetAddressPrefix `    
    
    az network nsg create `
        --resource-group $resourceGroupName `
        --name $frontEndNsgName

    az network nsg rule create `
        --name $frontEndNsgRuleName `
        --nsg-name $frontEndNsgName `
        --resource-group $resourceGroupName `
        --priority 1001 `
        --access Allow `
        --source-address-prefixes Internet `
        --destination-address-prefixes VirtualNetwork `
        --source-port-ranges '*' `
        --destination-port-ranges 443 `
        --protocol Tcp `
        --description "Allow access to port 443 only from Internet."

     az network vnet subnet update `
        --resource-group $resourceGroupName `
        --name $frontEndSubVnetName `
        --vnet-name $vnetName `
        --network-security-group $frontEndNsgName

    # The backend subnet.
    az network vnet subnet create `
        --resource-group $resourceGroupName `
        --name $backEndSubVnetName `
        --vnet-name $vnetName `
        --address-prefixes $backEndSubVnetAddressPrefix `
        #--delegations "Microsoft.Web/serverFarms" `
        #--service-endpoints "Microsoft.Web"

    az network nsg create `
        --resource-group $resourceGroupName `
        --name $backEndNsgName
   
    az network vnet subnet update `
        --resource-group $resourceGroupName `
        --name $backEndSubVnetName `
        --vnet-name $vnetName `
        --network-security-group $backEndNsgName

    az network vnet subnet show `
       --resource-group $resourceGroupName `
       --name $frontEndSubVnetName `
       --vnet-name $vnetName `
       --query delegations

}
else
{
    Write-Output "Virtual network `"$vnetName`" exists. It and subresources were not created."
}

#az keyvault create `
#    --name $keyVaultName `
#    --resource-group $resourceGroupName `
#    --location $location `
#    --enable-soft-delete true

# This identity is used for the front-end Web APIs.
Write-Output "Creating user managed identity `"$appIdentityName`" for Web APIs..."
az identity create `
    --name $appIdentityName `
    --resource-group $resourceGroupName
Write-Output "Creating user managed identity `"$appIdentityName`" for Web APIs done."

# This identity is used for the containers.
Write-Output "Creating user managed identity `"$containerIdentityName`" for containers..."
az identity create `
    --name $containerIdentityName `
    --resource-group $resourceGroupName
Write-Output "Creating user managed identity `"$containerIdentityName`" for containers done."

# The Web API service principal ID of the user-assigned identity.
$appIdentitySpID =
(
    az identity show `
        --resource-group $resourceGroupName `
        --name $appIdentityName `
        --query principalId `
        --output tsv
)

# The Web API resource identifier of the user-assigned identity.
$appIdentityResourceID =
(
    az identity show `
        --resource-group $resourceGroupName `
        --name $appIdentityName `
        --query id `
        --output tsv
)

# The container service principal ID of the user-assigned identity.
$containerIdentitySpID =
(
    az identity show `
        --resource-group $resourceGroupName `
        --name $containerIdentityName `
        --query principalId `
        --output tsv
)

# The container resource identifier of the user-assigned identity.
$containerIdentityResourceID =
(
    az identity show `
        --resource-group $resourceGroupName `
        --name $containerIdentityName `
        --query id `
        --output tsv
)

$containerIdentityObjectID =
(
    az identity show `
        --resource-group $resourceGroupName `
        --name $containerIdentityName `
        --query objectId `
        --output tsv
)

Write-Output "Create SQL Server `"$sqlServerName`" in location `"$location`"..."


# The database needs to have a human root user.
# This does not work when called from a pipeline. The pipeline should not be run using user credentials that are in AD.
$azureADUser = (az ad signed-in-user show --query objectId --output tsv)

# Alternatively one can use the following where <user-principal-name> is the email of the user in the AD.
# $azureADUser= (az ad user list --filter "userPrincipalName eq '<user-principal-name>'" --query [].objectId --output tsv)

# Look at enabling https://docs.microsoft.com/en-us/azure/azure-monitor/insights/azure-sql.
az sql server create `
    --resource-group $resourceGroupName `
    --name $sqlServerName `
    --admin-user $sqlServerRootLoginName `
    --admin-password $sqlServerRootPassword `
    --location $location

# Allow Azure services to connect to the SQL Server.
az sql server firewall-rule create `
    --resource-group $resourceGroupName `
    --server $sqlServerName `
    --name "AllowAzure" `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0

# Allow connection to the server from this location.
$thisClientIp = Invoke-WebRequest "https://api.ipify.org" | Select-Object -ExpandProperty Content
az sql server firewall-rule create `
    --resource-group $resourceGroupName `
    --server $sqlServerName `
    --name "AllowClient1" `
    --start-ip-address $thisClientIp `
    --end-ip-address $thisClientIp

# For a full list of editions use "az sql db list-editions --available --output table --location $location".
az sql db create `
    --name $sqlDatabaseName `
    --server $sqlServerName `
    --resource-group $resourceGroupName `
    --edition Basic `
    --collation "Latin1_General_100_CS_AS_SC_UTF8"

# Adds the currently logged in user as an AD admin to the server.
az sql server ad-admin create `
    --resource-group $resourceGroupName `
    --server-name $sqlServerName `
    --display-name "Admin" `
    --object-id $azureADUser

# Gives access to the managed identity in the backed containers to the database.
$objectId = (az identity show --resource-group $resourceGroupName --name $containerIdentityName --query principalId --output tsv)
[guid]$guid = [System.Guid]::Parse($objectId)
$backEndSid = "0x"
foreach ($byte in $guid.ToByteArray())
{
    $backEndSid += [System.String]::Format("{0:X2}", $byte)
}

# Gets Access Token for the database with the current user principal.
$token = az account get-access-token --resource https://database.windows.net/ | ConvertFrom-Json
Write-Host "Retrieved JWT token for SPN [$objectId]"
Write-Host "AccessToken [$token]" -ForegroundColor Green
Write-Host "Backend SID [$backEndSid]" -ForegroundColor Green
 
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Data Source=$sqlServerName.database.windows.net;Initial Catalog=$sqlDatabaseName"
$SqlConnection.AccessToken = $token.accessToken
 
$SqlConnectionMaster = New-Object System.Data.SqlClient.SqlConnection
$SqlConnectionMaster.ConnectionString = "Data Source=$sqlServerName.database.windows.net;Initial Catalog=master"
$SqlConnectionMaster.AccessToken = $token.accessToken

$queryMaster = ""
$queryMaster = $queryMaster + "DROP USER IF EXISTS [$containerIdentityName];"
$queryMaster = $queryMaster + "CREATE USER [$containerIdentityName] WITH SID = $backEndSid, TYPE=E;"
$queryMaster = $queryMaster + "ALTER ROLE db_owner ADD MEMBER [$containerIdentityName];"

$SqlCmdMaster = New-Object System.Data.SqlClient.SqlCommand
$SqlCmdMaster.Connection = $SqlConnectionMaster
$SqlCmdMaster.CommandText = $queryMaster
$SqlConnectionMaster.Open()
$SqlCmdMaster.ExecuteNonQuery()
$SqlConnectionMaster.Close()
 
$query = ""
$query = $query + "DROP USER IF EXISTS [$containerIdentityName];"
$query = $query + "CREATE USER [$containerIdentityName] WITH SID = $backEndSid, TYPE=E;"
$query = $query + "ALTER ROLE db_datareader ADD MEMBER [$containerIdentityName];"
$query = $query + "ALTER ROLE db_datawriter ADD MEMBER [$containerIdentityName];"
 
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $query
$SqlCmd.Connection = $SqlConnection
$SqlConnection.Open()
$SqlCmd.ExecuteNonQuery()
$SqlConnection.Close()
 


# The front-end Web APIs are granted get access to the Key Vault.
Write-Output "Assigning Web APIs identity `"$appIdentityName`" get rights for KeyVault `"$keyVaultName`"..."
az keyvault set-policy `
    --name $keyVaultName `
    --resource-group $resourceGroupName `
    --object-id $appIdentitySpID `
    --secret-permissions get
Write-Output "Assigning Web APIs identity `"$appIdentityName`" get rights for KeyVault `"$keyVaultName`" done."

# The containers are granted get access to the Key Vault.
Write-Output "Assigning container identity `"$containerIdentityName`" get rights for KeyVault `"$keyVaultName`"..."
az keyvault set-policy `
    --name $keyVaultName `
    --resource-group $resourceGroupName `
    --object-id $containerIdentitySpID `
    --secret-permissions get
Write-Output "Assigning container identity `"$containerIdentityName`" get rights for KeyVault `"$keyVaultName`" done."

# See a bug at
# https://feedback.azure.com/forums/169385-web-apps/suggestions/36145444-web-app-for-containers-acr-access-requires-admin.
az acr create `
    --resource-group $resourceGroupName `
    --name $registryName `
    --sku Basic `
    --location $location `
    #--public-network-enabled false

# Remove this once the bug mentioned has been fixed and using higher functionality tier.
# See more at https://docs.microsoft.com/en-us/azure/container-registry/container-registry-vnet also.
az acr update `
    --name $registryName `
    --admin-enabled true


# Azure Container Registry (ACR) does not yet support managed identity access.
# See https://github.com/MicrosoftDocs/azure-docs/issues/49186 and
# https://github.com/Azure/azure-cli/pull/14233#issuecomment-665946436
#
# A service principal for registry operations.
# Create service principal, store its password in vault (the registry *password*)
# The RBAC principal expires within one year.
# az keyvault secret set `
#  --vault-name $keyVaultName `
#  --name $registryName-pull-pwd `
#  --value $(az ad sp create-for-rbac `
#                --name http://$registryName-pull `
#                --scopes $(az acr show --name $registryName --query id --output tsv) `
#                --role acrpull `
#                --query password `
#                --output tsv)


$password = az acr credential show -n $registryName --query "passwords[0].value" -o tsv
az webapp create `
    --resource-group $resourceGroupName `
    --plan $appServicePlanName `
    --name $appName `
    --docker-registry-server-user $registryName `
    --docker-registry-server-password $password `
    --deployment-container-image-name $frontEndDeploymentImage `

Write-Output "Updating `"$frontEndSubVnetName`" service endpoints and subnet configuration..."
az network vnet subnet update `
  --name $frontEndSubVnetName `
  --vnet-name $vnetName `
  --resource-group $resourceGroupName `
  --service-endpoints Microsoft.ContainerRegistry

az webapp vnet-integration add `
    --resource-group $resourceGroupName `
    --name $appName `
    --vnet $vnetName `
    --subnet $frontEndSubVnetName

Write-Output "Updating `"$frontEndSubVnetName`" service endpoint and subnet configuration done."

# Azure WebApp does not yet support user managed identity.
# See more at https://github.com/Azure/azure-cli/issues/9887.
# az identity create `
#    --name $appIdentityName
#    -resource-group $resourceGroupName

# az resource update `
#    --name $appName `
#    --resource-group $resourceGroupName `
# --resource-type "Microsoft.Web/sites" --set identity="{\"type\": \"UserAssigned\", \"userAssignedIdentities\": {\"/subscriptions/-aa79-488b-b37b-d6e892009fdf/resourceGroups/jongrg4/providers/Microsoft.ManagedIdentity/userAssignedIdentities/jonguserassignedmi\": {}}}


#az webapp identity assign `
#    --resource-group $resourceGroupName `
#    --name $appName `
#    #--query principalId --output tsv

# This instructs the WebApp to pull this container image from the registry (update).
# az webapp config container set `
#    --name $appName `
#    --resource-group $resourceGroupName `
#    --docker-custom-image-name $frontEndDeploymentImage `
#    --docker-registry-server-url https:/$registryName.azurecr.io `
#    --docker-registry-server-user $registryName `
#    --docker-registry-server-password $password `

#az webapp container up -n AppName --registry-rg ContainerRegistryResourceGroup --registry-name ContainerRegistryName
#https://docs.microsoft.com/fi-fi/cli/azure/ext/webapp/webapp/container?view=azure-cli-latest

# Enable Application Insights logging.
Write-Output "Updating `"$appName`" logging settings..."
az webapp log config `
    --resource-group $resourceGroupName `
    --name $appName `
    --application-logging true `
    --detailed-error-messages true `
    --level verbose

# See more settings at https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps?tabs=net#automate-monitoring.

az webapp config appsettings set `
    --resource-group $resourceGroupName `
    --name $appName `
    --settings `
        "WEBSITES_PORT=8888" `
        "ApplicationInsightsAgent_EXTENSION_VERSION=~2" `
        "XDT_MicrosoftApplicationInsights_Mode=Basic" `
        "ANCM_ADDITIONAL_ERROR_PAGE_LINK=https://$appName.scm.azurewebsites.net/detectors?type=tools&name=eventviewer" `
        "APPINSIGHTS_INSTRUMENTATIONKEY=$applicationInsightsObject.instrumentationKey" `
        "APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=$applicationInsightsObject.instrumentationKey"

# Setting if SQL Server traces are collected. By default this off.
# az webapp config appsettings set `
#    --resource-group $resourceGroupName `
#    --name $appName `
#    --settings "InstrumentationEngine_EXTENSION_VERSION=~1" "XDT_MicrosoftApplicationInsights_BaseExtensions=~1"

# Sets collection level. Options are "recommended", "basic" and "disabled".
 

Write-Output "Updating `"$appName`" logging settings done."

  
# By default Azure ACR allows connections from any network. This changes
# the default to deny. Later rules open only allowed hosts to connect.
# These require the Premium registry.
# az acr update `
#  --name $registryName `
#  --default-action Allow

# az acr network-rule add `
# --name $registryName `
# --subnet $frontEndSubVnetName

#az container create `
#  --resource-group $resourceGroupName `
#  --name $appName `
#  --image mcr.microsoft.com/azuredocs/aci-helloworld `
#  --dns-name-label $appName `
#  --ports 80 `
#  --vnet $VnetName `
#  --subnet $SubVnetName

az container create `
  --resource-group $resourceGroupName `
  --name $containerName1 `
  --image $backendDeploymentImage `
  --vnet $vnetName `
  --subnet $backEndSubVnetName `
  --registry-username $registryName `
  --registry-password $password `
  --assign-identity $containerIdentityResourceID `
  --environment-variables `
    APPINSIGHTS_INSTRUMENTATIONKEY="$applicationInsightsObject.instrumentationKey" `
    APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=$applicationInsightsObject.instrumentationKey"

az container create `
  --resource-group $resourceGroupName `
  --name $containerName2 `
  --image $backendDeploymentImage `
  --vnet $vnetName `
  --subnet $backEndsubVnetName `
  --registry-username $registryName `
  --registry-password $password `
  --assign-identity $containerIdentityResourceID `
  --environment-variables `
    APPINSIGHTS_INSTRUMENTATIONKEY="$applicationInsightsObject.instrumentationKey" `
    APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=$applicationInsightsObject.instrumentationKey"

az container show `
    --resource-group $resourceGroupName `
    --name $containerName1 `
    --query "{FQDN:ipAddress.fqdn,ProvisioningState:provisioningState}" `
    --out table

az container logs `
    --resource-group $resourceGroupName `
    --name $containerName1

az container list `
    --resource-group $resourceGroupName `
    --output table


# Clean-up.
# az group delete --name $resourceGroupName
$apiBrokenDataNode = @()
Disable-AzContextAutosave -Scope Process

# Connect to Azure with user-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity -AccountId $AccountId).context

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
$apiBrokenCount = 0
$resourceName = ''
$resources = Get-AzResource -ResourceType Microsoft.Web/connections
$resources | ForEach-Object {     
    $logicAppUrl = $_.ResourceId + '?api-version=2018-07-01-preview'
    
    # Get Logic App Content
    #$resourceJsonResult = az rest --method get --uri $logicAppUrl
    $var = "https://management.azure.com" + $logicAppUrl
    $accsessToken = Get-AzAccessToken `
		-TenantId $connection.TenantID

    $auth = "Bearer " + $accsessToken.Token
    $resourceJson = Invoke-RestMethod -Uri $var -Headers @{ Authorization = $auth }

    $resourceName = $_.Name
    $resourceGroupName = $_.ResourceGroupName

    # Check Logic App Connectors
    $apiConnectionStatus = $resourceJson.properties.overallStatus
    if($apiConnectionStatus -eq 'Error')
    {
        $apiBrokenCount++;
        $apiBrokenDataNode += [pscustomobject]@{
                'ResourceGroupName' = $_.ResourceGroupName;
                'ResourceName' = $_.Name;
                'Status' = $resourceJson.properties.statuses.status;
                'APIName' = $resourceJson.properties.api.name;
                'APIDisplayName' = $resourceJson.properties.api.displayName;
                'ResourceType'= $resourceJson.type;
                'ResourceLocation'= $resourceJson.location;
                'ResourceId'= $resourceJson.id;
                'ErrorCode'= $resourceJson.properties.statuses.error.code
                'ErrorMessage'= $resourceJson.properties.statuses.error.message
            }
        
    }
    $json = $apiBrokenDataNode | ConvertTo-Json
       
}
if($null -ne $json){
        Invoke-RestMethod -Method 'Post' -Uri "Logic App HTTP Trigger URL" -Body $json
}

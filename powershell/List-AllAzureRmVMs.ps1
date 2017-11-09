  Import-Module AzureRm

$VMList = @()

$TenantId = Read-Host -Prompt 'Input your tenant ID'

if ($TenantId) {
    Add-AzureRmAccount -TenantId $TenantId | Out-Null
} else {
    Write-Host "No tenant ID provided, using the default..."
    Add-AzureRmAccount | Out-Null
}

$Subscriptions = Get-AzureRmSubscription -TenantId $TenantId

ForEach ($Subscription in $Subscriptions) {
    $SubscriptionId = $Subscription.SubscriptionId

    Select-AzureRmSubscription -Subscription $SubscriptionId | Out-Null

    $AzureRmVMs=Get-AzureRmVM
    $AzureRmNICs = Get-AzureRmNetworkInterface | where VirtualMachine -NE $null
    $AzureRmPubs = Get-AzureRmPublicIpAddress | where-object -Property IpAddress -NE "Not Assigned"

    if (!$AzureRmVMs) {
        Write-Host "The following subscription ID does not have any AzureRmVMs:  $SubscriptionId ($($Subscription.Name))"
        continue
    }

    Write-Output "`n####################"
    Write-Output "Private IP addresses"
    Write-Output "####################`n"

    ForEach ($NIC in $AzureRmNICs) {
        # Private IPs
        $VM = $AzureRmVMs | where-object -Property Id -EQ $NIC.VirtualMachine.id
        $PrivateIP =  $NIC.IpConfigurations | select-object -ExpandProperty PrivateIpAddress
        Write-Output "$($VM.Name) : $PrivateIP"
    }

    Write-Output "`n####################"
    Write-Output "Public IP addresses"
    Write-Output "####################`n"

    ForEach ($System in $AzureRmPubs) {
        $PublicIP = $System.IpAddress
        Write-Output "$($System.Name) : $PublicIP"
    }
}

Remove-AzureRmAccount

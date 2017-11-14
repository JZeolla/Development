# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2017-11-09
# File Type:       PowerShell Script
# Version:         1.0
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a PowerShell script to pull the public and private IPs for AzureRm VMs in a given Azure tenant.
#
# Notes
# - Anything that has a placeholder value is tagged with TODO.
# - This can be useful to audit an environment, or to do immediately prior to doing a vulnerability scan of AzureRM VMs (to get an updated IP list).
# - If attempting to do something similar with the Azure Cloud Shell (bash), consider:
#    ```
#    az account list | jq -r '.[] | .id' | while read subs; do echo "${subs}"; az account set --subscription "${subs}"; az vm list-ip-addresses | jq '.[] | .virtualMachine.network.publicIpAddresses | .[] | .ipAddress'; done
#    ```
#
# =========================

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

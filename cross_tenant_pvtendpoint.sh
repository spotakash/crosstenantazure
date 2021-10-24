# Gather Information for Performing task in Source Tenant
# Private Endpoint Creation
MyResourceGroup=source-tenant-rg
MyVnetName=source-tenant-vnet
MySubnet=Endpoint
loc=southeastasia
subresourceblob=blob
# Assuming you have existing [Private DNS Zone also created for workload](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration)
blobpvtdnszonename=privatelink.blob.core.windows.net
blobpvtdnszonerid=/subscriptions/1111111111/resourceGroups/source-tenant-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net
dnszonegroup=default
# Source Tenant blob 
sourceaccounblobri=/subscriptions/1111111111/resourceGroups/source-tenant-rg/providers/Microsoft.Storage/storageAccounts/sourcetenant-sa
sourceaccounblbconnection=sourcetenantsaconct
sourcetenantblobpe=sourcetenantblobpe
sourcetenantbloburl=https://sourcetenant-sa.blob.core.windows.net/
# Destination Tenant blob
destinationaccountblobri=/subscriptions/2222222222/resourceGroups/destination-tenant-rg/providers/Microsoft.Storage/storageAccounts/destinationtenant-sa
destinationaccountconnection=destinationtenantsaconct
desttenantblobpe=destinationtenantblobpe
differnttenanturl=https://destinationtenant-sa.blob.core.windows.net/
# Source tenant blob Private Endpoint Creation
az network private-endpoint create -g $MyResourceGroup -n $sourcetenantblobpe --vnet-name $MyVnetName --subnet $MySubnet \
--private-connection-resource-id $sourceaccounblobri --group-id $subresourceblob --connection-name $sourceaccounblbconnection -l $loc
# Destination tenant blob Private Endpoint Creation. 
# Note: "--manual-request true" is required for cross tenant request. 
az network private-endpoint create -g $MyResourceGroup -n $desttenantblobpe --vnet-name $MyVnetName --subnet $MySubnet --manual-request true \
--private-connection-resource-id $destinationaccountblobri --group-id $subresourceblob --connection-name $destinationaccountconnection -l $loc

# Note Private Endpoint is auto-approve within source tenant
# In Destination Teant Administrator need to approve Private Endpoint Request under Workload Networking section
# Next steps to be performed only after Private Endpoint in Source Tenant started showing 'Approved'

# Central Private DNS Zone mapping for source tenant Private Endpoint
az network private-endpoint dns-zone-group create --endpoint-name $sourcetenantblobpe --name $dnszonegroup --private-dns-zone $blobpvtdnszonerid \
--resource-group $MyResourceGroup --zone-name $blobpvtdnszonename
# After Approve Private Endpoint in destination
# Central Private DNS Zone mapping for destination tenant Private Endpoint
az network private-endpoint dns-zone-group create --endpoint-name $desttenantblobpe --name $dnszonegroup --private-dns-zone $blobpvtdnszonerid \
--resource-group $MyResourceGroup --zone-name $blobpvtdnszonename

# Retrieving Vnet and Subnet ID
VNET_ID=$(az network vnet show --resource-group $MyResourceGroup --name $MyVnetName --query id -o tsv)

# Virtual Network Link to Private DNS Zone. Use Private DNS Zone Resource ID if it is residing in different resource group
az network private-dns link vnet create --name stroagevnetlink -g $MyResourceGroup \
--virtual-network $VNET_ID --zone-name $blobpvtdnszonename --registration-enabled true

## Results Should look below for Private IP Resolution to Storage FQDN

## Both source Tenant PE and destination Tenant PE sitting under source Private DNS Zone Resolving to Private IP
## SSH VM and 
admin@cross-tenant-vm:~$ nslookup sourcetenant-sa.blob.core.windows.net
Server:         127.0.0.53
Address:        127.0.0.53#53
Non-authoritative answer:
sourcetenant-sa.blob.core.windows.net      canonical name = sourcetenant-sa.privatelink.blob.core.windows.net.
Name:   sourcetenant-sa.privatelink.blob.core.windows.net
Address: 10.0.1.4
admin@cross-tenant-vm:~$ nslookup destinationtenant-sa.blob.core.windows.net
Server:         127.0.0.53
Address:        127.0.0.53#53
Non-authoritative answer:
destinationtenant-sa.blob.core.windows.net canonical name = destinationtenant-sa.privatelink.blob.core.windows.net.
Name:   destinationtenant-sa.privatelink.blob.core.windows.net
Address: 10.0.1.5
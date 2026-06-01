#In order to run the script, you must have an Azure Admin account that has been given permissions for Powershell Ms Graph API.
#More details on the origin of this script can be found here: https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-assign-app-role-managed-identity-powershell?tabs=microsoftgraph#complete-script

[CmdletBinding()]
param (
    # Your tenant ID (in the Azure portal, under Azure Active Directory > Overview).
    [Parameter(Mandatory = $true)]
    [String]
    $tenantID,

    # The managed identity's object ID.
    [Parameter(Mandatory = $true)]
    [String]
    $managedIdentityObjectId,

    # The name of the server app sevice principal that exposes the app role.
    [Parameter(Mandatory = $true)]
    [String]
    $serverApplicationName,

    # The name of the app role that the managed identity should be assigned to. For example, MyApi.Read.All
    [Parameter(Mandatory = $true)]
    [String]
    $appRoleName
)

if (Get-Module -ListAvailable -Name Microsoft.Graph) {
    Write-Host "Microsoft.Graph module exists, skipping import."
} 
else {
    Install-Module Microsoft.Graph -Scope AllUsers
    Import-Module Microsoft.Graph
}


Connect-MgGraph -TenantId $tenantId -Scopes 'Application.Read.All','Application.ReadWrite.All','AppRoleAssignment.ReadWrite.All','Directory.AccessAsUser.All','Directory.Read.All','Directory.ReadWrite.All'

# Look up the details about the server app's service principal and app role.
$serverServicePrincipal = (Get-MgServicePrincipal -Filter "DisplayName eq '$serverApplicationName'")
$serverServicePrincipalObjectId = $serverServicePrincipal.Id
$appRoleId = ($serverServicePrincipal.AppRoles | Where-Object {$_.Value -eq $appRoleName }).Id

# Assign the managed identity access to the app role.
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $managedIdentityObjectId `
    -PrincipalId $managedIdentityObjectId `
    -ResourceId $serverServicePrincipalObjectId `
    -AppRoleId $appRoleId

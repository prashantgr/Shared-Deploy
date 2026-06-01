param (
    [Parameter(Mandatory)][string]$groupName,
    [Parameter(Mandatory)][string]$instanceName,
    [Parameter(Mandatory)][string]$apimPath,
    [Parameter(Mandatory)][string]$apimApiName,
    [Parameter(Mandatory)][string]$policyString,
    [Parameter(Mandatory)][string]$swaggerPath
 )

$ApiMgmtContext = New-AzApiManagementContext -ResourceGroupName $groupName -ServiceName $instanceName
Write-Output "Successfully found ApiManagementContext from Azure."

$policyString = $policyString.Trim()
$hasMatchingDoubleQuotes = $policyString.Length -ge 2 -and $policyString.StartsWith('"') -and $policyString.EndsWith('"')
$hasMatchingSingleQuotes = $policyString.Length -ge 2 -and $policyString.StartsWith("'") -and $policyString.EndsWith("'")

if ($hasMatchingDoubleQuotes -or $hasMatchingSingleQuotes) {
    $policyString = $policyString.Substring(1, $policyString.Length - 2)
}

$supportedSwaggerFileNames = @('*.swagger.json', 'swagger.json', '*.openapi.json', 'openapi.json')

Write-Output "Finding Swagger Files in [$swaggerPath]."

if (-not (Test-Path -LiteralPath $swaggerPath -PathType Container)) {
    Write-Error "Swagger path [$swaggerPath] does not exist or is not a directory. Stopping..." -ErrorAction Stop
}

[array]$swaggerFiles = Get-ChildItem -LiteralPath $swaggerPath -Recurse |
    Where-Object {
        -not $_.PSIsContainer -and (
            $_.Name -like '*.swagger.json' -or
            $_.Name -like 'swagger.json' -or
            $_.Name -like '*.openapi.json' -or
            $_.Name -like 'openapi.json'
        )
    } |
    Sort-Object FullName

if($swaggerFiles.Count -eq 0){
    [array]$jsonFiles = Get-ChildItem -LiteralPath $swaggerPath -Filter *.json -Recurse |
        Where-Object { -not $_.PSIsContainer } |
        Select-Object -First 20

    if ($jsonFiles.Count -gt 0) {
        Write-Output "Found JSON files, but none matched supported OpenAPI names [$($supportedSwaggerFileNames -join ', ')]:"
        $jsonFiles | ForEach-Object { Write-Output $_.FullName }
    }
    else {
        Write-Output "No JSON files found under [$swaggerPath]."
    }

    Write-Error "No swagger files found. Stopping..." -ErrorAction Stop
}
else {
    Write-Output "Found Swagger Files."
    Write-Output $swaggerFiles
}

# Ensure the API version set exists for this API (version set ID matches the base API name)
$versionSetId = $apimApiName
$existingVersionSet = Get-AzApiManagementApiVersionSet -Context $ApiMgmtContext -ApiVersionSetId $versionSetId -ErrorAction SilentlyContinue

if ($null -eq $existingVersionSet) {
    Write-Output "Creating version set: $versionSetId"
    New-AzApiManagementApiVersionSet -Context $ApiMgmtContext `
        -ApiVersionSetId $versionSetId `
        -Name $apimApiName `
        -Scheme "Query" `
        -QueryName "api-version"
    Write-Output "Version set created: $versionSetId"
} else {
    Write-Output "Using existing version set: $versionSetId"
}

foreach($swaggerFile in $swaggerFiles) {
    Write-Output "Importing file to APIM: $swaggerFile"

    $swagerFileContent = Get-Content -Raw -Path $swaggerFile | ConvertFrom-Json

    $version = $swagerFileContent.info.version
    $apiMgmtApiName  = "$apimApiName-$version"

    # Parse numeric version (e.g., "V1" -> "1", "V0" -> "0") for the APIM apiVersion field
    $apiVersion = $version -replace '^[Vv]', ''

    $import = Import-AzApiManagementApi `
        -Context $ApiMgmtContext `
        -ApiId $apiMgmtApiName `
        -SpecificationFormat 'OpenApi' `
        -SpecificationPath $swaggerFile `
        -Path $apimPath `
        -ApiVersionSetId $versionSetId `
        -ApiVersion $apiVersion
       
    if(!$import){
        Write-Error "Import failed. Stopping..." -ErrorAction Stop
      }

    Write-Output "Successfully imported swagger.json to [$apimApiName] $apimPath"

    Write-Output "Setting policy"
    Write-Output $policyString

    Set-AzApiManagementPolicy -Context $ApiMgmtContext -ApiId $apiMgmtApiName -Policy $policyString

    Write-Output "Successfully set new policy for backend service."
}

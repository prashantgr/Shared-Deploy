param (
    [Parameter(Mandatory)][string]$path,
    [Parameter(Mandatory)][string]$tokens,
    [Parameter(Mandatory=$false)][string]$publishPath
)

function Main() {
    Write-Output "--- POWERSHELL SCRIPT: tokenizer.ps1 ---"

    $parsedTokens = Split-Text $tokens ':'

    $files = Get-Childitem -path $path -recurse | Where-Object {! $_.PSIsContainer}
    foreach ($file in $files)
    {
        $fileFullName = $file.FullName
        $content = (Get-Content -path $fileFullName -Raw)
        $fileTokenized = ($content | Select-String "%%.*%%").Matches.Success

        if (-not $fileTokenized) {
            continue;
        }

        Write-Output "Searching and replacing token values in [$fileFullName]"

        foreach ($token in $parsedTokens){
            $parsedTokenValue = Split-Text $token '='
            $searchValue = "%%" + $parsedTokenValue[0] + "%%"
            $value = $parsedTokenValue[1]

            $tokenFound = ($content | Select-String $searchValue).Matches.Success
            if ($tokenFound) {
                Write-Output "Replacing [$searchValue] to [$value]"
            }
            else {
                continue;
            }

            $content = $content -replace $searchValue, $value
        }

        if($publishPath)
        {
            Write-Output "--------- Put File in publish path ----------"
            Write-Output "Path: $publishPath"

            $fileName = Split-Path $fileFullName -leaf
            
            Write-Output "filename: $fileName"

            $fileFullName = $publishPath + [IO.Path]::DirectorySeparatorChar + $fileName

            Write-Output "new location: $fileFullName"
        }

        Set-Content -Path $fileFullName -Value $content
    }

    Write-Output "------------------------------"
}

function Split-Text {
    param(
        [Parameter(Mandatory=$True)] [string] $Text,
        [Parameter(Mandatory=$True)] [string] $Separator,
        [string] $EscapeChar = '\'
    )

    $Text -split
        ('(?<=(?<!{0})(?:{0}{0})*){1}' -f [regex]::Escape($EscapeChar), [regex]::Escape($Separator)) `
            -replace ('{0}(.)' -f [regex]::Escape($EscapeChar)), '$1'
}

Main

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

$PathAssets = $env:BuildAssetsFolder
$PathDownloads = $env:BuildAssetsFolder

$StyleInfo = $PSStyle.Foreground.Blue
$StyleAction = $PSStyle.Foreground.Green
$StyleStatus = $PSStyle.Foreground.Magenta
$StyleCommand = $PSStyle.Foreground.Yellow
$StyleQuiet = $PSStyle.Foreground.BrightBlack
$StyleAlert = $PSStyle.Foreground.Red


$global:MessageHeader = "ahk2exe-action"
function Set-MessageHeader {
    param (
        [string]$header
    )

    $oldHeader, $global:MessageHeader = $MessageHeader, $header
    return $oldHeader
}

function Show-Message {
    param (
        [string]$message,
        [string]$message_style = $PSStyle.Foreground.White,
        [string]$header_style = $StyleInfo
    )

    Write-Host "$header_style$global:MessageHeader::$($PSStyle.Reset) " -NoNewLine
    Write-Host "$message_style$message$($PSStyle.Reset)"
}

function Get-GitHubReleaseInformation {
    param (
        [string]$Repository,
        [string]$ReleaseTag = 'latest'
    )

    $repositoryOwner, $repositoryName = ($Repository -split "/")[0, 1]
    if ([string]::IsNullOrEmpty($repositoryOwner)) { Throw "Invalid repository path, missing repository owner."}
    if ([string]::IsNullOrEmpty($repositoryName)) { Throw "Invalid repository path, missing repository name."}

    $displayPath = "$repositoryOwner/$repositoryName/$ReleaseTag"
    $previousHeader = Set-MessageHeader "Query-$displayPath"

    if ($ReleaseTag -like 'latest') {
        $apiUrl = "https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/latest"
    } else {
        $apiUrl = "https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/tags/$ReleaseTag"
    }

    Show-Message "Getting release information..." $StyleAction
    $headers = @{ "User-Agent" = "PowerShell-ahk2exe-action" }
    if (![string]::IsNullOrEmpty($env:GitHubToken)) { $headers["Authorization"] = "token $env:GitHubToken" }

    $release = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

    [void](Set-MessageHeader $previousHeader)
    return $release
}

function Get-GitHubReleaseAssets {
    param (
        [string]$Repository,
        [string]$ReleaseTag = 'latest',
        [string]$FileTypeFilter
    )

    $repositoryOwner, $repositoryName = ($Repository -split "/")[0, 1]
    if ([string]::IsNullOrEmpty($repositoryOwner)) { Throw "Invalid repository path, missing repository owner."}
    if ([string]::IsNullOrEmpty($repositoryName)) { Throw "Invalid repository path, missing repository name."}

    $displayPath = "$repositoryOwner/$repositoryName/$ReleaseTag"
    $previousHeader = Set-MessageHeader "Download-$displayPath"

    $downloadFolderName = $displayPath.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
    $downloadFolder = Join-Path $PathDownloads $downloadFolderName
    if (Test-Path -Path $downloadFolder) {
        if ((Get-ChildItem -Path "$downloadFolder" | Measure-Object).Count -gt 0) {
            Show-Message "$displayPath is already present, skipping re-download..." $StyleQuiet

            [void](Set-MessageHeader $previousHeader)
            return $downloadFolder
        }
    }


    $release = Get-GitHubReleaseInformation -Repository $Repository -ReleaseTag $ReleaseTag
    
    $assets = $release.assets
    if ($assets.Count -eq 0) { Throw "No assets found for release '$displayPath'" }

    Show-Message "Filtering assets for '$FileTypeFilter' files..." $StyleAction
    $filteredAssets = $assets | Where-Object { $_.name -like "$FileTypeFilter" }
    if ($filteredAssets.Count -eq 0) { Throw "No assets matching the file type '$FileTypeFilter' found." }
    Show-Message "Found files: $filteredAssets" $StyleCommand

    Show-Message "Downloading assets..." $StyleAction
    foreach ($asset in $filteredAssets) {
        $downloadUrl = $asset.browser_download_url
        $fileName = $asset.name
        $downloadDestination = Join-Path $downloadFolder $fileName

        $previousHeaderAsset = Set-MessageHeader "Asset-$fileName"
        Show-Message "Downloading..." $StyleAction
        Show-Message "Source: $downloadUrl" $StyleCommand
        Show-Message "Destination: $downloadDestination" $StyleCommand
        [void](New-Item -ItemType Directory -Path $downloadFolder -Force)
        [void](New-Object System.Net.WebClient).DownloadFile($downloadUrl, $downloadDestination)
        Show-Message "Download completed" $StyleStatus
        [void](Set-MessageHeader $previousHeaderAsset)
    }
    Show-Message "Downloading assets completed" $StyleStatus

    [void](Set-MessageHeader $previousHeader)
    return $downloadFolder
}

function Get-GitHubReleaseFile {
    param(
        [string]$Repository,
        [string]$ReleaseTag = 'latest',
        [string]$FileName
    )

    $repositoryOwner, $repositoryName = ($Repository -split "/")[0, 1]
    if ([string]::IsNullOrEmpty($repositoryOwner)) { Throw "Invalid repository path, missing repository owner."}
    if ([string]::IsNullOrEmpty($repositoryName)) { Throw "Invalid repository path, missing repository name."}

    $displayPath = "$repositoryOwner/$repositoryName/$ReleaseTag/$FileName"
    $previousHeader = Set-MessageHeader "Download-$displayPath"

    $downloadFolderName = $displayPath.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
    $downloadFolder = Join-Path $PathDownloads $downloadFolderName
    $downloadDestination = Join-Path $downloadFolder $FileName
    if (Test-Path -Path $downloadFolder) {
        if ((Get-ChildItem -Path "$downloadFolder" | Measure-Object).Count -gt 0) {
            Show-Message "$displayPath is already present, skipping re-download..." $StyleQuiet

            [void](Set-MessageHeader $previousHeader)
            return $downloadDestination
        }
    }

    $release = Get-GitHubReleaseInformation -Repository $Repository -ReleaseTag $ReleaseTag
    $tag = $release.tag_name

    $downloadUrl = " https://raw.githubusercontent.com/$repositoryOwner/$repositoryName/refs/tags/$tag/$FileName"

    $previousHeaderAsset = Set-MessageHeader "File-$FileName"
    Show-Message "Downloading..." $StyleAction
    Show-Message "Source: $downloadUrl" $StyleCommand
    Show-Message "Destination: $downloadDestination" $StyleCommand
    [void](New-Item -ItemType Directory -Path $downloadFolder -Force)
    [void](New-Object System.Net.WebClient).DownloadFile($downloadUrl, $downloadDestination)
    Show-Message "Download completed" $StyleStatus

    return $downloadDestination
}

function Invoke-UnzipAllInPlace {
    param (
        [string]$FolderPath
    )

    foreach ($zip in Get-ChildItem -Path $FolderPath -Filter *.zip -Recurse) {
        Show-Message "Extracting $zip..." $StyleAction
        Show-Message "Source: $zip" $StyleCommand
        Show-Message "Destination: $FolderPath"  $StyleCommand
        [void](New-Item -ItemType Directory -Path $PathAssets -Force)
        Expand-Archive -Force $zip -DestinationPath $FolderPath
    }
}

function Install-AutoHotkey {
    $previousHeader = Set-MessageHeader "Install-Autohotkey"

    Show-Message "Installing..." $StyleAction
    $downloadFolder = Get-GitHubReleaseAssets -Repository "$env:AutoHotkeyRepo" -ReleaseTag "$env:AutoHotkeyTag" -FileTypeFilter "*.zip"

    switch ($env:Target) {
        'x64' {
            $exeName = 'AutoHotkey64.exe'
            $searchFilter = 'AutoHotkey(U)?64\.exe'
        }
        'x86' {
            $exeName = 'AutoHotkey32.exe'
            $searchFilter = 'AutoHotkey(U)?32\.exe'
        }
        Default { Throw "Unsupported Architecture: '$target'. Valid Options: x64, x86" }
    }

    $installPath = (Get-ChildItem -Path $downloadFolder -Recurse | Where-Object { $_.Name -match "^$searchFilter$" } | Select-Object -First 1)
    if ([System.IO.File]::Exists($installPath)) {
        Show-Message "Autohotkey is already installed, skipping re-installation..." $StyleQuiet

        [void](Set-MessageHeader $previousHeader)
        return $installPath
    }

    Invoke-UnzipAllInPlace -FolderPath $downloadFolder

    Show-Message "Verifying installation..." $StyleAction
    $installPath = (Get-ChildItem -Path $downloadFolder -Recurse | Where-Object { $_.Name -match "^$searchFilter$" } | Select-Object -First 1)
    if (![System.IO.File]::Exists($installPath)) { Throw "Missing AutoHotkey Executable '$exeName'." }
    Show-Message "Installation path: $installPath" $StyleCommand
    Show-Message "Installation completed" $StyleStatus

    [void](Set-MessageHeader $previousHeader)
    return $installPath
}

function Install-Ahk2Exe {
    $previousHeader = Set-MessageHeader "Install-Ahk2Exe"

    Show-Message "Installing..." $StyleAction
    $downloadFolder = Get-GitHubReleaseAssets -Repository "$env:Ahk2ExeRepo" -ReleaseTag "$env:Ahk2ExeTag" -FileTypeFilter "*.zip"

    $exeName = 'Ahk2Exe.exe'

    $installPath = (Get-ChildItem -Path $downloadFolder -Recurse -Filter $exeName | Select-Object -First 1)
    if ([System.IO.File]::Exists($installPath)) {
        Show-Message "Ahk2Exe is already installed, skipping re-installation..." $StyleQuiet

        [void](Set-MessageHeader $previousHeader)
        return $installPath
    }

    Invoke-UnzipAllInPlace -FolderPath $downloadFolder

    Show-Message "Verifying installation..." $StyleAction
    $installPath = (Get-ChildItem -Path $downloadFolder -Recurse -Filter $exeName | Select-Object -First 1)
    if (![System.IO.File]::Exists($installPath)) { Throw "Missing Ahk2Exe Executable '$exeName'." }
    Show-Message "Installation path: $installPath" $StyleCommand
    Show-Message "Installation completed" $StyleStatus

    [void](Set-MessageHeader $previousHeader)
    return $installPath
}

function Install-BinMod {
    param (
        [string]$Ahk2ExePath
    )
    $previousHeader = Set-MessageHeader "Install-BinMod"

    Show-Message "Installing..." $StyleAction
    $downloadFile = Get-GitHubReleaseFile -Repository "$env:Ahk2ExeRepo" -ReleaseTag "$env:Ahk2ExeTag" -FileName "BinMod.ahk"

    $exeName = 'BinMod.exe'
    $ahk2exeFolder = Split-Path -Path $Ahk2ExePath -Parent
    $installPath = Join-Path $ahk2exeFolder $exeName
    if ([System.IO.File]::Exists($installPath)) {
        Show-Message "BinMod is already installed, skipping re-installation..." $StyleQuiet

        [void](Set-MessageHeader $previousHeader)
        return
    }

    Invoke-Ahk2Exe -Path "$ahk2exePath" -Base "$ahk2exePath" -In "$downloadFile" -Out "$installPath" -Icon "" -Compression "none" -ResourceId ""

    Show-Message "Verifying installation..." $StyleAction
    if (![System.IO.File]::Exists($installPath)) { Throw "Missing BinMod Executable '$exeName'." }
    Show-Message "Installation path: $installPath" $StyleCommand
    Show-Message "Installation completed" $StyleStatus

    [void](Set-MessageHeader $previousHeader)
    return $installPath
}

function Install-UPX {
    param (
        [string]$Ahk2ExePath
    )

    $previousHeader = Set-MessageHeader "Install-UPX"

    Show-Message "Installing..." $StyleAction
    $downloadFolder = Get-GitHubReleaseAssets -Repository "$env:UPXRepo" -ReleaseTag "$env:UPXTag" -FileTypeFilter "*win64.zip"

    $exeName = 'upx.exe'
    $ahk2exeFolder = Split-Path -Path $Ahk2ExePath -Parent

    $installPath = Join-Path $ahk2exeFolder $exeName
    if ([System.IO.File]::Exists($installPath)) {
        Show-Message "UPX is already installed, skipping re-installation..." $StyleQuiet

        [void](Set-MessageHeader $previousHeader)
        return
    }

    Invoke-UnzipAllInPlace -FolderPath $downloadFolder

    $upxPath = (Get-ChildItem -Path $downloadFolder -Recurse -Filter $exeName | Select-Object -First 1)
    if ([string]::IsNullOrEmpty($upxPath)) { Throw "Missing UPX Executable '$upxPath'." }

    Show-Message "Copying UPX executable into Ahk2Exe directory..." $StyleAction
    Show-Message "Source: $upxPath" $StyleCommand
    Show-Message "Destination: $installPath" $StyleCommand
    Move-Item -Path $upxPath -Destination $installPath -Force

    Show-Message "Verifying installation..." $StyleAction
    if (![System.IO.File]::Exists($installPath)) { throw "Failed to install UPX. File was not present in Ahk2Exe folder after installation step completed." }
    Show-Message "Installation path: $installPath" $StyleCommand
    Show-Message "Installation completed" $StyleStatus

    [void](Set-MessageHeader $previousHeader)
    return $installPath
}

function Invoke-Ahk2Exe {
    param (
        [string]$Path,
        [string]$In,
        [string]$Out,
        [string]$Icon,
        [string]$Base,
        [string]$Compression = 'upx',
        [string]$ResourceId
    )

    $previousHeader = Set-MessageHeader "Compile-Ahk2Exe"

    Show-Message "Compiling $In to $Out..." $StyleAction

    $ahk2exe_args = "/silent verbose /in `"$In`""
    $ahk2exe_args += " /base `"$Base`""

    Switch ($compression) {
        'none' { $ahk2exe_args += " /compress 0" }
        'upx'  { $ahk2exe_args += " /compress 2" }
        Default { Throw "Unsupported Compression Type: '$compression'. Valid Options: none, upx"}
    }

    if (![string]::IsNullOrEmpty($Out)) {
        [void](New-Item -Path $Out -ItemType File -Force)
        $ahk2exe_args += " /out `"$Out`""
    }
    $ahk2exe_args += if (![string]::IsNullOrEmpty($Icon)) { " /icon `"$Icon`"" }
    $ahk2exe_args += if (![string]::IsNullOrEmpty($ResourceId)) { " /resourceid `"$ResourceId`"" }

    $command = "Start-Process -NoNewWindow -PassThru -FilePath `"$Path`" -ArgumentList '$ahk2exe_args'"

    Show-Message "`"$command`"" $StyleCommand
    $process = Invoke-Expression "$command"
    $process | Wait-Process -Timeout 300
    if ($process.ExitCode -ne 0) {
        Throw "Exception occurred during build."
    } else {
        Show-Message "Compilation completed" $StyleStatus
    }

    [void](Set-MessageHeader $previousHeader)
}

function Invoke-Action {
    Show-Message "Starting..." $StyleAction

    if ([string]::IsNullOrEmpty($env:GitHubToken)) {
        Show-Message "GitHubToken environment variable is not set. API calls may be rate limited." $StyleAlert
    }

    $ahkPath = Install-AutoHotkey
    $ahk2exePath = Install-Ahk2Exe

    [void](Install-BinMod -Ahk2ExePath $ahk2exePath)

    if ("$env:Compression" -eq "upx") {
        [void](Install-UPX -Ahk2ExePath $ahk2exePath)
    }

    Invoke-Ahk2Exe -Path "$ahk2exePath" -Base "$ahkPath" -In "$env:In" -Out "$env:Out" -Icon "$env:Icon" -Compression "$env:Compression" -ResourceId "$env:ResourceId"
    Show-Message "Finished" $StyleStatus
}

Invoke-Action

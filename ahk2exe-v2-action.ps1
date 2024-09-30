Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

$PathAssets = $env:BuildAssetsFolder
$PathDownloads = $env:BuildAssetsFolder

$StyleInfo = $PSStyle.Foreground.Blue
$StyleAction = $PSStyle.Foreground.Green
$StyleStatus = $PSStyle.Foreground.Magenta
$StyleCommand = $PSStyle.Foreground.Yellow
$StyleQuiet = $PSStyle.Foreground.BrightBlack

function Show-Message {
    param (
        [string]$header,
        [string]$message,
        [string]$header_style = $PSStyle.Foreground.Blue,
        [string]$message_style = $PSStyle.Foreground.White
    )
    Write-Host "$header_style::$header::$($PSStyle.Reset) " -NoNewLine
    Write-Host "$message_style$message$($PSStyle.Reset)"
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
    $downloadFolderName = $displayPath.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
    $downloadFolder = Join-Path $PathDownloads $downloadFolderName
    if (Test-Path -Path $downloadFolder) { 
        if ((Get-ChildItem -Path "$downloadFolder" | Measure-Object).Count -gt 0) {
            Show-Message "Download-$displayPath" "$displayPath is already present, skipping re-download..." $StyleInfo $StyleQuiet
            return $downloadFolder
        }
    }

    if ($ReleaseTag -like 'latest') {
        $apiUrl = "https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/latest"
    } else {
        $apiUrl = "https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/tags/$ReleaseTag"
    }

    Show-Message "Download-$displayPath" "Getting release information..." $StyleInfo $StyleAction
    $release = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "User-Agent" = "PowerShell" }

    $assets = $release.assets
    if ($assets.Count -eq 0) { Throw "No assets found for release '$displayPath'" }

    Show-Message "Download-$displayPath" "Filtering assets for '$FileTypeFilter' files..." $StyleInfo $StyleAction
    $filteredAssets = $assets | Where-Object { $_.name -like "$FileTypeFilter" }
    if ($filteredAssets.Count -eq 0) { Throw "No assets matching the file type '$FileTypeFilter' found." }
    Show-Message "Download-$displayPath" "Found files: $filteredAssets" $StyleInfo $StyleCommand

    Show-Message "Download-$displayPath" "Downloading assets..." $StyleInfo $StyleAction
    foreach ($asset in $filteredAssets) {
        $downloadUrl = $asset.browser_download_url
        $fileName = $asset.name
        $downloadDestination = Join-Path $downloadFolder $fileName

        Show-Message "Asset-$fileName" "Downloading..." $StyleInfo $StyleAction
        Show-Message "Asset-$fileName" "Source: $downloadUrl" $StyleInfo $StyleCommand
        Show-Message "Asset-$fileName" "Destination: $downloadDestination" $StyleInfo $StyleCommand
        [void](New-Item -ItemType Directory -Path $downloadFolder -Force)
        [void](New-Object System.Net.WebClient).DownloadFile($downloadUrl, $downloadDestination)
        Show-Message "Asset-$fileName" "Download completed" $StyleInfo $StyleStatus
    }
    Show-Message "Download-$displayPath" "Downloading assets completed" $StyleInfo $StyleStatus
    return $downloadFolder
}

function Invoke-UnzipAllInPlace {
    param (
        [string]$TaskName,
        [string]$FolderPath
    )

    foreach ($zip in Get-ChildItem -Path $FolderPath -Filter *.zip -Recurse) {
        Show-Message "$TaskName" "Extracting $zip..." $StyleInfo $StyleAction
        Show-Message "$TaskName" "Source: $zip" $StyleInfo $StyleCommand
        Show-Message "$TaskName" "Destination: $FolderPath" $StyleInfo $StyleCommand
        [void](New-Item -ItemType Directory -Path $PathAssets -Force)
        Expand-Archive -Force $zip -DestinationPath $FolderPath
    }
}

function Install-AutoHotkey {
    Show-Message "Install-Autohotkey" "Installing..." $StyleInfo $StyleAction
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
        Show-Message "Install-Autohotkey" "Autohotkey is already installed, skipping re-installation..." $StyleInfo $StyleQuiet
        return $installPath
    }

    Invoke-UnzipAllInPlace -TaskName "Install-Autohotkey" -FolderPath $downloadFolder

    $installPath = (Get-ChildItem -Path $downloadFolder -Recurse -Filter $exeName | Select-Object -First 1)
    if (![System.IO.File]::Exists($installPath)) { Throw "Missing AutoHotkey Executable '$exeName'." }
    Show-Message "Install-Autohotkey" "Installation path: $installPath" $StyleInfo $StyleCommand
    Show-Message "Install-Autohotkey" "Installation completed" $StyleInfo $StyleStatus
    return $installPath
}

function Install-Ahk2Exe {
    Show-Message "Install-Ahk2Exe" "Installing..." $StyleInfo $StyleAction
    $downloadFolder = Get-GitHubReleaseAssets -Repository "$env:Ahk2ExeRepo" -ReleaseTag "$env:Ahk2ExeTag" -FileTypeFilter "*.zip"

    $exeName = 'Ahk2Exe.exe'

    $installPath = (Get-ChildItem -Path $downloadFolder -Recurse -Filter $exeName | Select-Object -First 1)
    if ([System.IO.File]::Exists($installPath)) { 
        Show-Message "Install-Ahk2Exe" "Ahk2Exe is already installed, skipping re-installation..." $StyleInfo $StyleQuiet
        return $installPath
    }

    Invoke-UnzipAllInPlace -TaskName "Install-Ahk2Exe" -FolderPath $downloadFolder

    $installPath = (Get-ChildItem -Path $downloadFolder -Recurse -Filter $exeName | Select-Object -First 1)
    if (![System.IO.File]::Exists($installPath)) { Throw "Missing Ahk2Exe Executable '$exeName'." }
    Show-Message "Install-Ahk2Exe" "Installation path: $installPath" $StyleInfo $StyleCommand
    Show-Message "Install-Ahk2Exe" "Installation completed" $StyleInfo $StyleStatus
    return $installPath
}

function Install-UPX {
    param (
        [string]$Ahk2ExePath
    )

    Show-Message "Install-UPX" "Installing..." $StyleInfo $StyleAction
    $downloadFolder = Get-GitHubReleaseAssets -Repository "$env:UPXRepo" -ReleaseTag "$env:UPXTag" -FileTypeFilter "*win64.zip"

    $exeName = 'upx.exe'
    $ahk2exeFolder = Split-Path -Path $Ahk2ExePath -Parent 

    $installPath = Join-Path $ahk2exeFolder $exeName
    if ([System.IO.File]::Exists($installPath)) {
        Show-Message "Install-UPX" "UPX is already installed, skipping re-installation..." $StyleInfo $StyleQuiet
        return
    }

    Invoke-UnzipAllInPlace -TaskName "Install-UPX" -FolderPath $downloadFolder

    $upxPath = (Get-ChildItem -Path $downloadFolder -Recurse -Filter $exeName | Select-Object -First 1)
    if ([string]::IsNullOrEmpty($upxPath)) { Throw "Missing UPX Executable '$upxPath'." }

    Show-Message "Install-UPX" "Copying UPX executable into Ahk2Exe directory..." $StyleInfo $StyleAction
    Show-Message "Install-UPX" "Source: $upxPath" $StyleInfo $StyleCommand
    Show-Message "Install-UPX" "Destination: $installPath" $StyleInfo $StyleCommand
    Move-Item -Path $upxPath -Destination $installPath -Force

    if (![System.IO.File]::Exists($installPath)) { throw "Failed to install UPX. File was not present in Ahk2Exe folder after installation step completed." }
    Show-Message "Install-UPX" "Installation path: $installPath" $StyleInfo $StyleCommand
    Show-Message "Install-UPX" "Installation completed" $StyleInfo $StyleStatus
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
    Show-Message "Build $Out" "Converting $In to $Out..." $StyleInfo $StyleAction

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

    Show-Message "Build $Out" "`"$command`"" $StyleInfo $StyleCommand
    $process = Invoke-Expression "$command"
    $process | Wait-Process -Timeout 300
    if ($process.ExitCode -ne 0) {
        Throw "Exception occurred during build."
    } else {
        Show-Message "Build-$Out" "Build completed" $StyleInfo $StyleStatus
    }
}

function Invoke-Action {
	Show-Message "Action-Started" "" $StyleStatus
    
    $ahkPath = Install-AutoHotkey
    $ahk2exePath = Install-Ahk2Exe

	if ("$env:Compression" -eq "upx") {
	    Install-UPX -Ahk2ExePath $ahk2exePath
	}
	
	Invoke-Ahk2Exe -Path "$ahk2exePath" -Base "$ahkPath" -In "$env:In" -Out "$env:Out" -Icon "$env:Icon" -Compression "$env:Compression" -ResourceId "$env:ResourceId"
	Show-Message "Action-Finished" "" $StyleStatus
}
	
Invoke-Action
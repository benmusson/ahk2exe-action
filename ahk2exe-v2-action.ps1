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

function Invoke-DownloadArtifacts {
    param (
        [string]$name, 
        [string]$url
    )
    $path_zip = Join-Path $PathDownloads
 "$name.zip"
    $path_final = Join-Path $PathAssets $name

    if (Test-Path -Path $path_final) { 
        if ((Get-ChildItem -Path "$path_final" | Measure-Object).Count -gt 0) {
            Show-Message "Download $name" "$name is already present, skipping re-download..." $StyleInfo $StyleQuiet
            return
        }
    }

    Show-Message "Download $name" "Downloading..." $StyleInfo $StyleAction
    Show-Message "Download $name" "Source: $url" $StyleInfo $StyleCommand
    Show-Message "Download $name" "Destination: $path_zip" $StyleInfo $StyleCommand
    [void](New-Item -ItemType Directory -Path $PathDownloads -Force)
    [void](New-Object System.Net.WebClient).DownloadFile($url, $path_zip)
    Show-Message "Download $name" "Download completed" $StyleInfo $StyleStatus

    Show-Message "Download $name" "Extracting..." $StyleInfo $StyleAction
    Show-Message "Download $name" "Source: $path_zip" $StyleInfo $StyleCommand
    Show-Message "Download $name" "Destination: $path_final" $StyleInfo $StyleCommand
    [void](New-Item -ItemType Directory -Path $PathAssets -Force)
    Expand-Archive -Force $path_zip -DestinationPath $path_final
    Show-Message "Download $name" "Extraction completed" $StyleInfo $StyleStatus
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
            Show-Message "Get-Assets $displayPath" "$displayPath is already present, skipping re-download..." $StyleInfo $StyleQuiet
            return $downloadFolder
        }
    }

    if ($ReleaseTag -like 'latest') {
        $apiUrl = "https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/latest"
    } else {
        $apiUrl = "https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/tags/$ReleaseTag"
    }

    Show-Message "Get-Assets $displayPath" "Getting release information..." $StyleInfo $StyleAction
    $release = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "User-Agent" = "PowerShell" }
    # $latestTag = $release.tag_name
    # Show-Message "Get-Assets $displayPath" "Latest Tag: $latestTag" $StyleInfo $StyleCommand

    $assets = $release.assets
    if ($assets.Count -eq 0) { Throw "No assets found for release '$displayPath'" }

    Show-Message "Get-Assets $displayPath" "Filtering assets for '$FileTypeFilter' files..." $StyleInfo $StyleAction
    $filteredAssets = $assets | Where-Object { $_.name -like "$FileTypeFilter" }
    if ($filteredAssets.Count -eq 0) { Throw "No assets matching the file type '$FileTypeFilter' found." }
    Show-Message "Get-Assets $displayPath" "Found files: $filteredAssets" $StyleInfo $StyleCommand

    Show-Message "Get-Assets $displayPath" "Downloading assets..." $StyleInfo $StyleAction
    foreach ($asset in $filteredAssets) {
        $downloadUrl = $asset.browser_download_url
        $fileName = $asset.name
        $downloadDestination = Join-Path $downloadFolder $fileName

        Show-Message "Get-Assets $displayPath - $fileName" "Downloading..." $StyleInfo $StyleAction
        Show-Message "Get-Assets $displayPath - $fileName" "Source: $downloadUrl" $StyleInfo $StyleCommand
        Show-Message "Get-Assets $displayPath - $fileName" "Destination: $downloadDestination" $StyleInfo $StyleCommand
        [void](New-Item -ItemType Directory -Path $downloadFolder -Force)
        [void](New-Object System.Net.WebClient).DownloadFile($downloadUrl, $downloadDestination)
        Show-Message "Get-Assets $displayPath - $fileName" "Download completed" $StyleInfo $StyleStatus
    }
    Show-Message "Get-Assets $displayPath" "Downloading assets completed" $StyleInfo $StyleStatus
    return $downloadFolder
}

function Install-UPX {
    $destination = Join-Path "$PathAssets" "Ahk2Exe\upx.exe"
    if ([System.IO.File]::Exists($destination)) {
        Show-Message "Install UPX" "UPX is already installed, skipping installation..." $StyleInfo $StyleQuiet
        return
    }

    Show-Message "Install UPX" "Searching for UPX executable..." $StyleInfo $StyleAction
    foreach ($exe in Get-ChildItem -Path (Join-Path $PathAssets "UPX") -Filter *.exe -Recurse)  {
        Show-Message "Install UPX" "Found!" $StyleInfo $StyleCommand

        Show-Message "Install UPX" "Copying UPX executable into Ahk2Exe directory..." $StyleInfo $StyleAction
        Show-Message "Install UPX" "Source: $exe" $StyleInfo $StyleCommand
        Show-Message "Install UPX" "Destination: $destination" $StyleInfo $StyleCommand
        Move-Item -Path $exe.FullName -Destination $destination -Force
        break
    }

    if ([System.IO.File]::Exists($destination)) {
        Show-Message "Install UPX" "Installation successful" $StyleInfo $StyleStatus
    } else {
        throw "Failed to install UPX. File was not present in Ahk2Exe folder after installation step completed."
    }
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
    $ahk2exe_args += if (![string]::IsNullOrEmpty($ResourcId)) { " /resourceid `"$ResourceId`"" }

    $command = "Start-Process -NoNewWindow -PassThru -FilePath `"$Path`" -ArgumentList '$ahk2exe_args'"

    Show-Message "Build $Out" "`"$command`"" $StyleInfo $StyleCommand
    $process = Invoke-Expression "$command"
    $process | Wait-Process -Timeout 300
    if ($process.ExitCode -ne 0) {
        Throw "Exception occurred during build."
    } else {
        Show-Message "Build $Out" "Build completed" $StyleInfo $StyleStatus
    }
}

function Install-AutoHotkey {
    Show-Message "Install Autohotkey" "Installing..." $StyleInfo $StyleAction
    $downloadFolder = Get-GitHubReleaseAssets -Repository "$env:AutoHotkeyRepo" -ReleaseTag "$env:AutoHotkeyTag" -FileTypeFilter "*.zip"

    foreach ($zip in Get-ChildItem -Path $downloadFolder -Filter *.zip -Recurse) {
        Show-Message "Install Autohotkey" "Extracting..." $StyleInfo $StyleAction
        Show-Message "Install Autohotkey" "Source: $zip" $StyleInfo $StyleCommand
        Show-Message "Install Autohotkey" "Destination: $downloadFolder" $StyleInfo $StyleCommand
        [void](New-Item -ItemType Directory -Path $PathAssets -Force)
        Expand-Archive -Force $zip -DestinationPath $downloadFolder
        Show-Message "Install Autohotkey" "Extraction completed" $StyleInfo $StyleStatus
    }

    switch ($env:Target) {
        'x64' { $exeName = 'AutoHotkey64.exe' }
        'x86' { $exeName = 'AutoHotkey32.exe' }
        Default { Throw "Unsupported Architecture: '$target'. Valid Options: x64, x86" }
    }

    $exePath = Join-Path $downloadFolder $exeName
    if (![System.IO.File]::Exists($exePath)) { Throw "Missing AutoHotkey Executable '$exeName'." }
    Show-Message "Install Autohotkey" "Installation path: $exePath" $StyleInfo $StyleCommand
    Show-Message "Install Autohotkey" "Installation completed" $StyleInfo $StyleStatus
    return $exePath
}

function Install-Ahk2Exe {
    Show-Message "Install Ahk2Exe" "Installing..." $StyleInfo $StyleAction
    $downloadFolder = Get-GitHubReleaseAssets -Repository "$env:Ahk2ExeRepo" -ReleaseTag "$env:Ahk2ExeTag" -FileTypeFilter "*.zip"

    foreach ($zip in Get-ChildItem -Path $downloadFolder -Filter *.zip -Recurse) {
        Show-Message "Install Ahk2Exe" "Extracting..." $StyleInfo $StyleAction
        Show-Message "Install Ahk2Exe" "Source: $zip" $StyleInfo $StyleCommand
        Show-Message "Install Ahk2Exe" "Destination: $downloadFolder" $StyleInfo $StyleCommand
        [void](New-Item -ItemType Directory -Path $PathAssets -Force)
        Expand-Archive -Force $zip -DestinationPath $downloadFolder
        Show-Message "Install Ahk2Exe" "Extraction completed" $StyleInfo $StyleStatus
    }

    $exeName = 'Ahk2Exe.exe'

    $exePath = Join-Path $downloadFolder $exeName
    if (![System.IO.File]::Exists($exePath)) { Throw "Missing Ahk2Exe Executable '$exeName'." }
    Show-Message "Install Ahk2Exe" "Installation path: $exePath" $StyleInfo $StyleCommand
    Show-Message "Install Ahk2Exe" "Installation completed" $StyleInfo $StyleStatus
    return $exePath
}

function Invoke-Action {
	Show-Message "Action Started" "" $StyleStatus
    
    $ahkPath = Install-AutoHotkey
    $ahk2exePath = Install-Ahk2Exe
	
	# if ("$env:Compression" -eq "upx") {
	#     Invoke-DownloadArtifacts 'UPX' "$env:Url_UPX"
	#     Install-UPX
	# }
	
	Invoke-Ahk2Exe -Path "$ahk2exePath" -Base "$ahkPath" -In "$env:In" -Out "$env:Out" -Icon "$env:Icon" -Compression "$env:Compression" -ResourceId "$env:ResourceId"
	Show-Message "Action Finished" "" $StyleStatus
}
	
Invoke-Action
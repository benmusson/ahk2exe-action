Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

$path_assets = Join-Path $env:Build_Assets_Folder 'assets'
$path_downloads = Join-Path $env:Build_Assets_Folder 'downloads'

$style_info = $PSStyle.Foreground.Blue
$style_action = $PSStyle.Foreground.Green
$style_status = $PSStyle.Foreground.Magenta
$style_command = $PSStyle.Foreground.Yellow
$style_quiet = $PSStyle.Foreground.BrightBlack

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
    $path_zip = Join-Path $path_downloads "$name.zip"
    $path_final = Join-Path $path_assets $name

    if (Test-Path -Path $path_final) { 
        if ((Get-ChildItem -Path "$path_final" | Measure-Object).Count -gt 0) {
            Show-Message "Download $name" "$name is already present, skipping re-download..." $style_info $style_quiet
            return
        }
    }
    Show-Message "Download $name" "Downloading..." $style_info $style_action
    Show-Message "Download $name" "Source: $url" $style_info $style_command
    Show-Message "Download $name" "Destination: $path_zip" $style_info $style_command
    
    [void](New-Item -ItemType Directory -Path $path_downloads -Force)
    [void](New-Object System.Net.WebClient).DownloadFile($url, $path_zip)

    [void](New-Item -ItemType Directory -Path $path_assets -Force)
    Expand-Archive -Force $path_zip -DestinationPath $path_final

    Show-Message "Download $name" "Download completed" $style_info $style_status
}

function Install-UPX {
    $destination = Join-Path "$path_assets" "Ahk2Exe\upx.exe"
    if ([System.IO.File]::Exists($destination)) {
        Show-Message "Install UPX" "UPX is already installed, skipping installation..." $style_info $style_quiet
        return
    }

    Show-Message "Install UPX" "Searching for UPX executable..." $style_info $style_action
    foreach ($exe in Get-ChildItem -Path (Join-Path $path_assets "UPX") -Filter *.exe -Recurse)  {
        Show-Message "Install UPX" "Found, copying to $destination" $style_info $style_command
        Move-Item -Path $exe.FullName -Destination $destination -Force
        break
    }

    if ([System.IO.File]::Exists($destination)) {
        Show-Message "Install UPX" "Installation successful" $style_info $style_status
    } else {
        throw "Failed to install UPX. File was not present in Ahk2Exe folder after installation step completed."
    }
}

function Invoke-Ahk2Exe {
    param (
        [string]$in,
        [string]$out,
        [string]$icon,
        [string]$target = 'x64',
        [string]$compression = 'upx',
        [string]$resourceid
    )
    Show-Message "Build $out" "Converting $in to $out..." $style_info $style_action

    $ahk2exe_path = Join-Path $path_assets 'Ahk2Exe/Ahk2Exe.exe'
    $ahk2exe_args = "/silent verbose /in `"$in`""

    Switch ($target) {
        'x64' { $base = Join-Path $path_assets 'AutoHotkey/AutoHotkey64.exe' }
        'x86' { $base = Join-Path $path_assets 'AutoHotkey/AutoHotkey32.exe' }
        Default { Throw "Unsupported Architecture: '$target'. Valid Options: x64, x86" }
    }
    $ahk2exe_args += " /base `"$base`""

    Switch ($compression) {
        'none' { $ahk2exe_args += " /compress 0" }
        'upx'  { $ahk2exe_args += " /compress 2" } 
        Default { Throw "Unsupported Compression Type: '$compression'. Valid Options: none, upx"}
    }
    
    if (![string]::IsNullOrEmpty($out)) { 
        [void](New-Item -Path $out -ItemType File -Force)
        $ahk2exe_args += " /out `"$out`"" 
    }
    $ahk2exe_args += if (![string]::IsNullOrEmpty($icon)) { " /icon `"$icon`"" }
    $ahk2exe_args += if (![string]::IsNullOrEmpty($resourceid)) { " /resourceid `"$resourceid`"" }

    $command = "Start-Process -NoNewWindow -PassThru -FilePath `"$ahk2exe_path`" -ArgumentList '$ahk2exe_args'"

    Show-Message "Build $out" "`"$command`"" $style_info $style_command
    $process = Invoke-Expression "$command"
    $process | Wait-Process -Timeout 30
    if ($process.ExitCode -ne 0) {
        Throw "Exception occurred during build."
    } else {
        Show-Message "Build $out" "Build completed" $style_info $style_status
    }
}

Show-Message "Build Started" "" $style_status

Invoke-DownloadArtifacts 'AutoHotkey' "$env:Url_Ahk"
Invoke-DownloadArtifacts 'Ahk2Exe' "$env:Url_Ahk2Exe"

if ("$env:Compression" -eq "upx") {
    Invoke-DownloadArtifacts 'UPX' "$env:Url_UPX"
    Install-UPX
}

Invoke-Ahk2Exe -In "$env:In" -Out "$env:Out" -Icon "$env:Icon" -Target "$env:Target" -Compression "$env:Compression" -ResourceId "$env:ResourceId"

Show-Message "Build Finished" "" $style_status
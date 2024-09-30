$ErrorActionPreference = "Stop"

$path_assets = Join-Path $env:Build_Assets_Folder 'assets'
$path_downloads = Join-Path $env:Build_Assets_Folder 'downloads'

function Show-Message {
    param (
        [string]$header,
        [string]$message,
        [string]$header_color = "Green",
        [string]$message_color = "White"
    )
    Write-Host "::$header:: " -ForegroundColor $header_color -NoNewLine
    Write-Host "$message" -ForegroundColor $message_color
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
            Show-Message "Download $name" "$name is already present, skipping re-download..." "Blue" "DarkGray"
            return
        }
    }
    Show-Message "Download $name" "Downloading..." "Blue" "DarkGreen"
    Show-Message "Download $name" "Source: $url" "Blue" "DarkYellow"
    Show-Message "Download $name" "Destination: $path_zip" "Blue" "DarkYellow"
    
    [void](New-Item -ItemType Directory -Path $path_downloads -Force)
    [void](New-Object System.Net.WebClient).DownloadFile($url, $path_zip)

    [void](New-Item -ItemType Directory -Path $path_assets -Force)
    Expand-Archive -Force $path_zip -DestinationPath $path_final

    Show-Message "Download $name" "Download completed" "Blue" "Magenta"
}

function Install-UPX {
    $destination = Join-Path "$path_assets" "Ahk2Exe\upx.exe"
    if ([System.IO.File]::Exists($destination)) {
        Show-Message "Install UPX" "UPX is already installed, skipping installation..." "Blue" "DarkGray"
        return
    }

    Show-Message "Install UPX" "Searching for UPX executable..." "Blue" "DarkGreen"
    foreach ($exe in Get-ChildItem -Path (Join-Path $path_assets "UPX") -Filter *.exe -Recurse)  {
        Show-Message "Install UPX" "Found, copying to $destination" "Blue" "Yellow"
        Move-Item -Path $exe.FullName -Destination $destination -Force
        break
    }

    if ([System.IO.File]::Exists($destination)) {
        Show-Message "Install UPX" "Installation Successful" "Blue" "Magenta"
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
    Show-Message "Build $out" "Converting $ahk_input to $out..." "Blue" "DarkGreen"

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

    $ahk2exe_args += if (![string]::IsNullOrEmpty($out)) { " /out `"$out`"" }
    $ahk2exe_args += if (![string]::IsNullOrEmpty($icon)) { " /icon `"$icon`"" }
    $ahk2exe_args += if (![string]::IsNullOrEmpty($resourceid)) { " /resourceid  `"$resourceid`"" }

    $command = "Start-Process -NoNewWindow -PassThru -FilePath `"$ahk2exe_path`" -ArgumentList '$ahk2exe_args'"

    Show-Message "Build $out" "`"$command`"" "Blue" "DarkYellow"
    $process = Invoke-Expression "$command"
    $process | Wait-Process -Timeout 30
    if ($process.ExitCode -ne 0) {
        Throw "Exception occurred during build."
    } else {
        Show-Message "Build $out" "Build completed" "Blue" "Magenta"
    }
    
}

Show-Message "Build Started" "" "Magenta"

Invoke-DownloadArtifacts 'AutoHotkey' "$env:Url_Ahk"
Invoke-DownloadArtifacts 'Ahk2Exe' "$env:Url_Ahk2Exe"

if ("$compression" -eq "upx") {
    Invoke-DownloadArtifacts 'UPX' "$Url_UPX"
    Install-UPX
}

Invoke-Ahk2Exe -In "$env:In" -Out "$env:Out" -Icon "$env:Icon" -Target "$env:Target" -Compression "$env:Compression" -ResourceId "$env:ResourceId"

Show-Message "Build Finished" "" "Magenta"
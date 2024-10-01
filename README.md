# Ahk2Exe Action
This action allows compiling [AutoHotkey] scripts with [Ahk2Exe].

![Build and Test](https://github.com/benmusson/ahk2exe-action/actions/workflows/test.yml/badge.svg)

| **Feature** | **Description** |
| - | - |
| **Support for AutoHotkey v1.1 and v2.0**          | 🎉 Works with both AutoHotkey v1.1 and v2.0, so you can use whichever version you prefer!                         |
| **UPX Compression Support**                       | 📦 Option to use UPX compression for smaller, more lightweight binaries.                                          |
| **Cache Support**                                 | ⚡ Built-in caching to speed things up by avoiding unnecessary downloads on repeated tasks.                       |
| **Direct Downloads from AutoHotkey GitHub Repos** | ⬇️ Grab binaries directly from the official AutoHotkey repos, with the option to pick the release tag you need.   |
| **No External GitHub Actions Needed**             | 🚀 Fully self-contained! No need for external GitHub Actions – everything works out of the box.                   |


## Usage

### Pre-requisites

> [!IMPORTANT]  
> This action only works on `windows` GitHub actions runners.

### Complete Example
```yaml
name: Compile

on: push

jobs:
  build:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4

    - name: Build with latest AutoHotkey release
      uses: benmusson/ahk2exe-action@v1
      with:
        in: .\path\to\script.ahk
        out: .\build\MyCompiledScript.exe
        icon: .\images\favicon.ico
        target: x64
        compression: upx
        ahk-tag: latest
```

### Inputs

| Name | Description | Default | Required |
|-|-|-|-|
|`in`| The path and name of the script to compile. | | ✔️
|`out`| The path\name of the output .exe to be created. | The directory\base_name of the input file plus extension of .exe, or any relevant compiler directive in the script. |
|`icon`| The icon file to be used. | Any SetMainIcon compiler directive in the script. |
|`target`| Target architecture. Valid options: x86, x64. | `x64` |
|`resourceid`| Assigns a non-standard resource ID to be used for the main script for compilations which use an .exe base file (see Embedded Scripts). Numeric resource IDs should consist of a hash sign (#) followed by a decimal number. | #1, or any ResourceID compiler directive in the script. |
|`compression`| Specifies which compression method to use. Valid options: none, upx. | `upx` |
|`ahk-repo`| GitHub repository source for AutoHotkey. | `AutoHotkey/AutoHotkey` |
|`ahk-tag`| Tagged GitHub release for AutoHotkey. View releases for official repo [here](https://github.com/AutoHotkey/AutoHotkey/releases). | `latest` |
|`ahk2exe-repo`| GitHub repository source for Ahk2Exe. | `AutoHotkey/Ahk2Exe` |
|`ahk2exe-tag`| Tagged GitHub release for Ahk2Exe. View releases for official repo [here](https://github.com/AutoHotkey/Ahk2Exe/releases). | `latest` |
|`upx-repo`| GitHub repository source for UPX. | `UPX/UPX` |
|`upx-tag`| Tagged GitHub release for UPX. View releases for official repo [here](https://github.com/UPX/UPX/releases).| `latest` |
|`build-assets-folder`| The path used to store build assets downloaded during the action. | `.\.ahk2exe-v2-action` |

### Example Workflows

#### Basic Usage
```yaml
name: Compile

on: push

jobs:
  build:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4

      # Compiled file will be '.\path\to\script.exe'
    - name: Build with latest AutoHotkey release
      uses: benmusson/ahk2exe-action@v1
      with:
        in: .\path\to\script.ahk
```

#### Specify AutoHotkey Version
```yaml
name: Compile

on: push

jobs:
  build:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4

    - name: Build with AutoHotkey v1.1.37.02
      uses: benmusson/ahk2exe-action@v1
      with:
        in: .\path\to\script.ahk
        ahk-tag: v1.1.37.02
```


#### Specify Output, Use Icon
```yaml
name: Compile

on: push

jobs:
  build:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4

    - name: Build (With Icon)
      uses: benmusson/ahk2exe-action@v1
      with:
        in: .\path\to\script.ahk
        out: .\build\MyCompiledScript.exe
        icon: .\images\favicon.ico
```

#### Build for x86 and x64
```yaml
name: Compile (x86/x64)

on: push

jobs:
  build:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4

    - name: Build (x86)
      uses: benmusson/ahk2exe-action@v1
      with:
        in: .\path\to\script.ahk
        out: .\build\MyCompiledScript_x86.exe
        icon: .\images\favicon.ico
        target: x86
        ahk-tag: v2.0.18

    - name: Build (x64)
      uses: benmusson/ahk2exe-action@v1
      with:
        in: .\path\to\script.ahk
        out: .\build\MyCompiledScript_x64.exe
        icon: .\images\favicon.ico
        target: x64
        ahk-tag: v2.0.18
```

## Contributing
Have an issue or see room for improvement? Issues and pull requests are welcome!

## License
The scripts and documentation in this project are released under the [GPLv3 License](https://github.com/benmusson/ahk2exe-action/blob/main/LICENSE).

[action-ahk2exe]: https://github.com/benmusson/action-ahk2exe
[AutoHotkey]: https://github.com/AutoHotkey/AutoHotkey
[Ahk2Exe]: https://github.com/AutoHotkey/Ahk2Exe
[GPLv3 License]: (https://github.com/benmusson/ahk2exe-action/blob/main/LICENSE)
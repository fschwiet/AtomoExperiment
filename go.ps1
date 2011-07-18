if (Get-Module psake) {
    Remove-Module psake
}

Import-Module .\packages\psake.4.0.1.0\tools\psake.psm1

invoke-psake .\default.ps1
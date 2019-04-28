# Scripts
A mix of scripts I've made, or at least put together

Create-FireWallRule.ps1 - Create Firewall rules, even in WinPE
![alt text](https://raw.githubusercontent.com/MattiasC85/Scripts/master/CreateFWRule.png)

test-port.ps1  - Test connection to hostname on specific port, in WinPE

UserSid-Coverter.ps1 - Converts SID/Username back and forwards.

Get-CredentialGuardStatus.ps1 - CredentialGuard configuration and service status.

Get-InstalledUpdates.ps1 - Installed updates by searching history.

Get-RegistryKeyLastWriteTime.ps1 - Get LastWriteTime of registry key

Keycheck - Tool that checks the embedded product key in bios. Works on Win7x86, Winpe (with .net 4) and ofc win10x64.
Used to determine if the key is for core(Home) or Pro. Great when deploying both EDU and ENT windows versions.
Must have a wrapper if running in a TS. Will give an exit code of 600 if pro and 601 if home.

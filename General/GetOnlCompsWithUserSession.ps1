<#
.Synopsis
   Gets all the online computers that matches the username and Domain variables.
.DESCRIPTION
   Work in progress
.EXAMPLE
   GetOnlCompsWithUserSession.ps1 -SiteServer cm1 -SiteName cm1 -UserName ad
.EXAMPLE
   GetOnlCompsWithUserSession.ps1 -SiteServer cm1 -SiteName cm1 -UserName %lkd% -Domain RemoteDomain
#>

Param (
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   [string] $SiteServer,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   [string] $SiteName,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   [string] $UserName,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$False)]
   $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name # NETBIOSName of remote domain or leave blank for current
   )


if ($UserName.Contains('%') -eq $false)
{
write-host "Observe that UserName is accepting Wildcards in the form of '%'" -ForegroundColor DarkYellow
}
$BuildDomainName=$null
if ($Domain.Contains(".") -eq $true)
{
    $SplitDomain=$Domain.ToString().Split(".")

    Foreach ($part in $SplitDomain)
    {
        $BuildDomainName=($BuildDomainName+"dc=$part,")
    }

    $BuildDomainName=($BuildDomainName.SubString(0,$BuildDomainName.Length-1))

$Domain=(Get-ADDomain $BuildDomainName).NetBIOSName
}


#write-host $Domain
$namespace = "ROOT\SMS\site_$SiteName"
$classname = "SMS_CombinedDeviceResources"

$UserName=$UserName.ToLower().Replace(($Domain.ToLower()+"\"),"")
#Write-Host "cur:" $UserName
Get-WmiObject -Query "select Name,ResourceID,CNIsOnline,CurrentLogonUser from SMS_CombinedDeviceResources where CurrentLogonUser like '$Domain\\$UserName' and CNIsOnline=1" -ComputerName $SiteServer -Namespace $namespace | select Name, CurrentLogonUser, ResourceID, CNIsOnline

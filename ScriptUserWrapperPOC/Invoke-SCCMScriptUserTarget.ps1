<#
.Synopsis
   Gets all the online computers where the name of the console session matches the "usernames"-param.
   And triggers a (SCCM) run script action of the choosen computers
.DESCRIPTION
   Work in progress
.INPUTS
    -SiteServer
     The SCCM-site server.

    -SiteCode
     The SCCM-site code.
    
    -UserNames
     A string array of usernames to search for. Supports short domain names and % as a wildcard

    -ScriptToDownloadAndRun
     UNC-, http- or file -path to the script to download and execute.
     \\Server\file.ps1, http://Server/file.ps1, Z:\folder\file.ps1

    -ScriptWrapperName
     The name of the script in the SCCM console.
         
    -RunInUserContext
     0 or 1. 1 = Runs the script in the context and privilege of the targeted user.
    
    -DownloadLoc
     Directory where the downloaded script is stored.
    
    -SkipVerificationPrompt
     Skips the prompt to choose targets and runs the script on all targets matching -Usernames.
     Except on servers ofc =)  

.EXAMPLE
   Invoke-SCCMScriptUserTarget.ps1 -SiteServer Siteserver1 -SiteName am1 -UserNames ("%mcel","domain\user01") -ScriptToDownloadAndRun "\\server\WrapperShare$\Msgbox\msgbox3.ps1" -ScriptWrapperName "UserWrapper"
#>
Param (
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   [string] $SiteServer,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   [string] $SiteName,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   [string[]] $UserNames,
   [Parameter(Mandatory=$True)]
   [string]$ScriptToDownloadAndRun,
   [Parameter(Mandatory=$True)]
   [string]$ScriptWrapperName="WrapperLastOne",
   [Parameter(Mandatory=$False)]
   [int]$RunInUserContext=1,
   [Parameter(Mandatory=$False)]
   [string]$DownloadLoc="%windir%\UserScriptStore",
   [Parameter(Mandatory=$False)]
   [Switch]$SkipVerificationPrompt,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$False)]
   $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name # NETBIOSName of remote domain or leave blank for current
   )


Function Main
{

if (($UserNames -join ",").Contains("%") -eq $false)
{
    write-host "Observe that UserName is accepting Wildcards in the form of '%'" -ForegroundColor DarkYellow
}

$BuildDomainName=$null
if ($Domain.Contains(".") -eq $true)
{
    $DomainBefore=$Domain
    $SplitDomain=$Domain.ToString().Split(".")

    Foreach ($part in $SplitDomain)
    {
        $BuildDomainName=($BuildDomainName+"dc=$part,")
    }

    $BuildDomainName=($BuildDomainName.SubString(0,$BuildDomainName.Length-1))
    #write-host $BuildDomainName

    $Domain=(Get-ADDomain $BuildDomainName).NetBIOSName

}

$namespace = "ROOT\SMS\site_$SiteName"
$classname = "SMS_CombinedDeviceResources"
#$Domain=$Domain.ToUpper()
#$UserNames=$UserNames.ToLower().Replace(($Domain.ToLower()+'\'),"")

write-host "UserNames:"$UserNames


                                                                #Builds the Targets-object
$Targets=Foreach ($User in $UserNames)
{
    $User=$User.replace("\","\\")
    $BuildTargets=Get-WmiObject -Query "select Name,ResourceID,CNIsOnline,CurrentLogonUser from SMS_CombinedDeviceResources where CurrentLogonUser like '$User' and CNIsOnline=1" -ComputerName $SiteServer -Namespace $namespace | select Name, CurrentLogonUser, ResourceID, CNIsOnline
    $BuildTargets
}


write-host "Targets found:" ($Targets.Count)
write-host "Checking for duplicate ResourceID's"
                                                                #Removes duplicate target objects (That Eg. '-UserNames ("%01","%er01")' would return)
$Targets=($Targets | Sort-Object -Property ResourceID -Unique)
write-host "Targets after cleanup:" ($Targets.Count)

If (!$Targets)
{
    Write-host "No targets found."
    break
}
                                                                #Adds index property on each target object.
$index=0
Foreach ($Target in $Targets)
{
    $Target | Add-Member -MemberType NoteProperty -Name "Index" -Value $index -Force
    #$Target | Format-Table
    $index++
}


$TargetList=$null

                                                                #Lets you view and choose targets before execution.
if (!$SkipVerificationPrompt)
{
    $Targets
    while ($TargetList -in ("",$null))
    {
        [ValidatePattern('^(\d+(,\d+)*|all)$')]$TargetList=Read-host "Type the indexes of the targets that you want to run the script on with ',' as the separator or 'all' to include all targets."
        if ($TargetList -eq "all")
        {
            $TargetList=($Targets.Index -join ",")

        }
        
    }
$Targets=$Targets | Where-Object -Property Index -in ($TargetList.split(","))
}
write-host ""
Write-Host "Will execute the script on the following computers:" -ForegroundColor Yellow
$Targets.Name
write-host "The script will execute if the console user is in this list:" -ForegroundColor Yellow
$Targets.CurrentLogonUser

$TargetUsers=($Targets.CurrentLogonUser -join ",")

                                                                #The params to send to the wrapper script.
[Array]$Parameter = @(
@{Name="DownloadLoc";Value=$DownloadLoc},
@{Name="RunInUserContext";Value=$RunInUserContext},
@{Name="Users";Value=$TargetUsers},
@{Name="ScriptToDownloadAndRun";Value=$ScriptToDownloadAndRun},
@{Name="ScriptHash";Value=((Get-FileHash $ScriptToDownloadAndRun).Hash)}
)

$Execute=Invoke-SCCMRunScript -SiteServer $SiteServer -Namespace $namespace -ScriptName $ScriptWrapperName -TargetResourceIDs @($Targets.ResourceID) -InputParameters @($Parameter)
write-host "Done, returnvalue is:" $Execute.ReturnValue
}


function Invoke-SCCMRunScript {

<#
Robert Johnsson's Invoke-SCCMRunScript
https://twitter.com/johnsson_r
https://gist.github.com/Robert-LTH/7423e418aab033d114d7c8a2df99246b#>

        param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteServer,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,
        [Array]$InputParameters = @(),
        [string]$TargetCollectionID = "",
        [Array]$TargetResourceIDs = @()
    )
    # if something goes wrong, we want to stop!
    $ErrorActionPreference = "Stop"

    # We can not run on all members of a collection AND selected resources
    if (-not ([string]::IsNullOrEmpty($TargetCollectionID)) -and $TargetResourceIDs -gt 0) {
        throw "Use either TargetCollectionID or TargetResourceIDs, not both!"
    }
    if (([string]::IsNullOrEmpty($TargetCollectionID)) -and $TargetResourceIDs -lt 1) {
        throw "We need some resources (devices) to run the script!"
    }


    # Get the script
    $Script = [wmi](Get-WmiObject -class SMS_Scripts -Namespace $Namespace -ComputerName $SiteServer -Filter "ScriptName = '$ScriptName'").__PATH

    if (-not $Script) {
        throw "Could not find script with name '$ScriptName'"
    }
    # Parse the parameter definition
    $Parameters = [xml]([string]::new([Convert]::FromBase64String($Script.ParamsDefinition)))

    $Parameters.ScriptParameters.ChildNodes | % {
        # In the case of a missing required parameter, bail!
        if ($_.IsRequired -and $InputParameters.Count -lt 1) {
            throw "Script 'ScriptName' has required parameters but no parameters was passed."
        }

        if ($_.Name -notin $InputParameters.Name) {
            write-host $InputParameters.Name
            throw "Parameter '$($_.Name)' has not been passed in InputParamters!"
        }
    }

    # GUID used for parametergroup
    $ParameterGroupGUID = $(New-Guid)

    if ($InputParameters.Count -le 0) {
        # If no ScriptParameters: <ScriptParameters></ScriptParameters> and an empty hash
        $ParametersXML = "<ScriptParameters></ScriptParameters>"
        $ParametersHash = ""
    }
    else {
        foreach ($Parameter in $InputParameters) {
            $InnerParametersXML = "$InnerParametersXML<ScriptParameter ParameterGroupGuid=`"$ParameterGroupGUID`" ParameterGroupName=`"PG_$ParameterGroupGUID`" ParameterName=`"$($Parameter.Name)`" ParameterType=`"$($Parameter.Type)`" ParameterValue=`"$($Parameter.Value)`"/>"
        }
        $ParametersXML = "<ScriptParameters>$InnerParametersXML</ScriptParameters>"

        $SHA256 = [System.Security.Cryptography.SHA256Cng]::new()
        $Bytes = ($SHA256.ComputeHash(([System.Text.Encoding]::Unicode).GetBytes($ParametersXML)))
        $ParametersHash = ($Bytes | ForEach-Object ToString X2) -join ''
    }

    $RunScriptXMLDefinition = "<ScriptContent ScriptGuid='{0}'><ScriptVersion>{1}</ScriptVersion><ScriptType>{2}</ScriptType><ScriptHash ScriptHashAlg='SHA256'>{3}</ScriptHash>{4}<ParameterGroupHash ParameterHashAlg='SHA256'>{5}</ParameterGroupHash></ScriptContent>"
    $RunScriptXML = $RunScriptXMLDefinition -f $Script.ScriptGuid,$Script.ScriptVersion,$Script.ScriptType,$Script.ScriptHash,$ParametersXML,$ParametersHash
    
    # Get information about the class instead of fetching an instance
    # WMI holds the secret of what parameters that needs to be passed and the actual order in which they have to be passed
    $MC = [WmiClass]"\\$SiteServer\$($Namespace):SMS_ClientOperation"
    
    # Get the parameters of the WmiMethod
    $MethodName = 'InitiateClientOperationEx'
    $InParams = $MC.psbase.GetMethodParameters($MethodName)
    
    # Information about the script is passed as the parameter 'Param' as a BASE64 encoded string
    $InParams.Param = ([Convert]::ToBase64String(([System.Text.Encoding]::UTF8).GetBytes($RunScriptXML)))
    
    # Hardcoded to 0 in certain DLLs
    $InParams.RandomizationWindow = "0"
    
    # If we are using a collection, set it. TargetCollectionID can be empty string: ""
    $InParams.TargetCollectionID = $TargetCollectionID
    
    # If we have a list of resources to run the script on, set it. TargetResourceIDs can be an empty array: @()
    # Criteria for a "valid" resource is IsClient=$true and IsBlocked=$false and IsObsolete=$false and ClientType=1
    $InParams.TargetResourceIDs = $TargetResourceIDs
    
    # Run Script is type 135
    $InParams.Type = "135"
    
    # Everything should be ready for processing, invoke the method!
    $R = $MC.InvokeMethod($MethodName, $InParams, $null)
    
    # The result contains the client operation id of the execution
    $R
}


Main
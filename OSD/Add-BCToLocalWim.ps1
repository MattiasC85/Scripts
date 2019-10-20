<#

Add-BCToLocalWim.ps1
- Adds branch cache support to WinPE without having to change the central boot images.
Can be executed in a Task Sequence.


$WimRootDir 
- The Root of where to look for a folder with the name of the boot image's buildnumber.
These folders should contain an "install.wim" from a Win 10-ISO with the specific buildnumber.
Can be a mapped drive or an UNC-Path.

Eg. -WimRootDir \\dp1\Win10Wims
Boot image is 1809 (Has the buildnumber 17763)

The script then tries to find \\dp1\Win10Wims\17763\Install.wim


Version 0.1 - 20191020 - Initial POC

Mattias Cedervall

For details: https://someguy100.wixsite.com/sccm802dot1x/blog/add-branchcache-support-to-winpe-without-modifying-any-central-boot-image

#>

Param(
    [Parameter(Mandatory=$True)]
    [String] $WimRootDir,
    [Parameter(ParameterSetName="SKU")]
    [String] $SKU="Ent"
)


#Controls the index used when mounting Install.wim
 
switch ($SKU)
{
 "Ent" {$index=3}
 "Edu" {$index=1}
}


function PSobjectFromOutput ([String[]]$strArray, [int]$StartLine)
{
    $PSCustomObject=New-object PSobject
    foreach ($line in $strArray[$StartLine..$strArray.Count].Trim())
    { 
        if ($line -match ":")
        {
            $split=$line.split(":")
            $PSCustomObject | Add-Member -NotePropertyName $split[0].Trim() -NotePropertyValue $split[1].Trim() 
        }
    }
return $PSCustomObject
}


################ MAIN #####################

$tsenv=New-Object -ComObject Microsoft.Sms.TSEnvironment
$LogDir=$tsenv.Value("_SMSTSLogPath")
Start-Transcript -Path $LogDir\Add-BCToLocalWim.log -Append

            #If running in FullOS we need to know where OSDDownloadContent.exe is located

$TSM=Get-Process -Name TSManager
$BinDir=($TSM.Path).ToLower().Replace($TSM.Description.ToLower(),"")


            #Makes references to these folders easier and available if the TS-Editor

$DataDir=$tsenv.Value("_SMSTSMDataPath")
$TSImageID=$tsenv.Value("_SMSTSBootImageID")
$WinPEGenDir=$TSEnv.Value("WinPEGen01")


            #Code stolen *cough* I mean borrowed from @NickolajA (SCConfigMgr)'s Invoke-CMApplyDriverPackage.ps1
            #https://github.com/SCConfigMgr/ConfigMgr/blob/master/Operating%20System%20Deployment/Drivers/Invoke-CMApplyDriverPackage.ps1
    
            #It's more comfortable to edit the boot-image before it is staged for the first time and the BCD is written. 

$tsenv.Value("OSDDownloadDownloadPackages")=$TSImageID
$tsenv.Value("OSDDownloadDestinationPath")=$DataDir
$tsenv.Value("OSDDownloadDestinationLocationType")="TSCache"
$TSEnv.Value("OSDDownloadDestinationVariable") ="ImageDir"


            #Forces the download of the bootimage bound to the TS.

$Proc=Start-process ($($BinDir)+"OSDDownloadContent.exe") -Wait -PassThru -NoNewWindow


            #Gets the directory of the downloaded Wim.

$ImageDir=$TSEnv.Value("ImageDir01")

$TSEnv.Value("OSDDownloadDownloadPackages") = [System.String]::Empty
$TSEnv.Value("OSDDownloadDestinationPath")=[System.String]::Empty
$TSEnv.Value("OSDDownloadDestinationLocationType") = [System.String]::Empty
$TSEnv.Value("OSDDownloadDestinationVariable") =[System.String]::Empty


            #Gets the FullPath of the wim-file located in 'ImageDir01'

$ImageLocalPath=(Get-Item -Path "$imageDir\*" -Filter *.wim).FullName


            #There's a better way of getting this info, see the function PSobjectFromOutput. Just havn't had time to implement it yet.

$ImageInfo=Dism.exe /Get-WimInfo /WimFile:"$ImageLocalPath" /index:1
$Arch="x86"

            
            #I've made this in order to support multiple WinPE-versions without changing this script all too much.
            #Gets the Architecture of the bootimage so we know what version of WinPEGen to run.

            #It also gets the buildnumber of the bootimage and tries to match it to a folder of the same name located in the $WimRootDir.
            #When you switch ADK, all you need to do is to create a folder below $WimRootDir with the new buildnumber and to copy a Win10-install.wim file of the same version to that folder.

$FullVersion=($ImageInfo | Select-String "Version ").ToString().Split(":")[1].Trim()
$BuildNumber=([Version]$FullVersion).Build

if ($ImageInfo.Contains("Architecture : x64"))
{
	$Arch="x64"
}


            #WinPEGen mounts images in the "tmp"-folder. 
            #X:\Temp hasn't got too much available space and I do trust SCCM to have choosen a HDD with far more.

$NewTmpFolder=$DataDir.Substring(0,3)+"TempMount"
if ([System.IO.Directory]::Exists($NewTmpFolder) -eq $False)
{
	$TmpFolder=New-Item -Type Directory -Path $NewTmpFolder
}

Write-host "Boot Image info"
write-host "Build: $BuildNumber"
Write-host "Architecture: $Arch"
Write-host "Starting WinPEGen"


            #A Good place to force an error if a Win10-source for the current build isn't found.

if ([System.IO.Directory]::Exists("$WimRootDir\$BuildNumber"))
{
	Write-host "Detected Win10 Wim-path:$WimRootDir\$BuildNumber"
}


            #Write outputs to the console.

write-host "CommandLine: $WinPEGenDir\$Arch\WinPEGen.exe" $WimRootDir\$BuildNumber\install.wim $index $ImageLocalPath 1


            #Save the hash in order to check if the wim was changed.

$PreEditHash=(Get-FileHash "$ImageLocalPath").Hash


            #Changes the tmp variable, launches WinPEGen and restores tmp once we're done.

$OldTmpEnv=[System.Environment]::GetEnvironmentVariable("tmp")
$NewTmpEnv=[System.Environment]::SetEnvironmentVariable("tmp",$NewTmpFolder)


            #Don't know how Bob is, but he's next in line. ^^

& "$WinPEGenDir\$Arch\WinPEGen.exe" "$WimRootDir\$BuildNumber\install.wim" $index "$ImageLocalPath" 1
[System.Environment]::SetEnvironmentVariable("tmp", $OldTmpEnv)
Start-Sleep -s 2

            #Check if the bootimage has been changed.

$NewHash=(Get-FileHash "$ImageLocalPath").Hash

if ($PreEditHash -ne $NewHash)
{
    $TSEnv.Value("BCGood2Go") = "True"
}
Stop-Transcript

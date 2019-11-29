<#

Version: 0.3

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

Version 0.3 - 20191129 - added verification of paths, added ProgressUI error dialog and output from WinPEGen
Version 0.2 - 20191025 - Added if's, some additional logging and made a psobject out of the dism output.
Version 0.1 - 20191020 - Initial POC

Mattias Cedervall

#>

Param(
    [Parameter(Mandatory=$True)]
    [String] $WimRootDir,
    [Parameter(ParameterSetName="SKU")]
    [String] $SKU="Ent",
    [Parameter(Mandatory=$False)]
    [Switch] $PEGenOutToLog
)

#Controls the index used when mounting Install.wim
 
switch ($SKU)
{
 "Ent" {$index=3}
 "Edu" {$index=1}
}



function AbortWithExitCode ($ExtCode,$Msg)
{   
    $tsProgressUI=New-Object -ComObject Microsoft.Sms.TSProgressUI
    $tsProgressUI.ShowErrorDialog($TSEnv["_SMSTSOrgName"],$TSEnv["_SMSTSPackageName"],$TSEnv["_SMSTSPackageName"],$Msg,[string]$ExtCode,180,0,$TSEnv["_SMSTSCurrentActionName"])
    #$TSEnv.Value("TSDisableProgressUI")="True"
    Stop-Transcript
    Exit $ExtCode
}

function PSobjectFromOutput ([String[]]$strArray, [int]$StartLine, [String]$Pattern)
{
    $PSCustomObject=New-object PSobject
    foreach ($line in $strArray[$StartLine..$strArray.Count].Trim())
    { 
        if ($line -like $Pattern)
        {
            $split=$line.Split(":",2)
            $PSCustomObject | Add-Member -NotePropertyName $split[0].Trim() -NotePropertyValue $split[1].Trim()
        }
    }
return $PSCustomObject
}

function VerifyPath ($Path,$Name)
{	
	if ($Path -in ($null,""))
	{
	  AbortWithExitCode 1 "$Name - Path is null`/empty"
	  return
	}
	$Result=Test-path "$Path"
	if ($Result -eq $False)
	{
		AbortWithExitCode 5 "$Name - $Path was not found"
	}
	else
	{
		write-host "$Name - path was found"
	}
}
################ MAIN #####################

$tsenv=New-Object -ComObject Microsoft.Sms.TSEnvironment
$LogDir=$tsenv.Value("_SMSTSLogPath")
Start-Transcript -Path $LogDir\Add-BCToLocalWim.log -Append -Force

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

$Proc=start-Process ($($BinDir)+"OSDDownloadContent.exe") -Wait -PassThru -NoNewWindow
write-host "Download Exit Code:" $Proc.ExitCode.ToString()

if ($Proc.ExitCode -ne 0)
{
    write-host "Download Failed"
    AbortWithExitCode $Proc.ExitCode "Error while downloading boot image."
}

            #Gets the directory of the downloaded Wim.

$ImageDir=$TSEnv.Value("ImageDir01")

$TSEnv.Value("OSDDownloadDownloadPackages") = [System.String]::Empty
$TSEnv.Value("OSDDownloadDestinationPath")=[System.String]::Empty
$TSEnv.Value("OSDDownloadDestinationLocationType") = [System.String]::Empty
$TSEnv.Value("OSDDownloadDestinationVariable") =[System.String]::Empty


            #Gets the FullPath of the wim-file located in 'ImageDir01'

$ImageLocalPath=(Get-Item -Path "$imageDir\*" -Filter *.wim).FullName

VerifyPath "$ImageLocalPath" "Boot Wimfile"

$ImageInfo=Dism.exe /Get-WimInfo /WimFile:"$ImageLocalPath" /index:1

$ImageInfo2=PSobjectFromOutput $ImageInfo 3 "* : *"

$Arch=$ImageInfo2.Architecture
$FullVersion=$ImageInfo2.Version
#$Arch="x86"

            
            #I've made this in order to support multiple WinPE-versions without changing this script all too much.
            #Gets the Architecture of the bootimage so we know what version of WinPEGen to run.

            #It also gets the buildnumber of the bootimage and tries to match it to a folder of the same name located in the $WimRootDir.
            #When you switch ADK, all you need to do is to create a folder below $WimRootDir with the new buildnumber and to copy a Win10-install.wim file of the same version to that folder.


#$FullVersion=($ImageInfo | Select-String "Version ").ToString().Split(":")[1].Trim()
$BuildNumber=([Version]$FullVersion).Build

<#
if ($ImageInfo.Contains("Architecture : x64"))
{
	$Arch="x64"
}
#>

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


            #A Good place to force an error if a Win10-source for the current build isn't found.



$Win10Wim="$WimRootDir\$BuildNumber\install.wim"
write-host "Win10 Wim Path: $Win10Wim"
VerifyPath "$Win10Wim" "Win10 Wimfile"

VerifyPath "$WinPEGenDir\$Arch\WinPEGen.exe" "WinPEGen Path"


            #Extra check
$RunPEGen=$false
if (([System.IO.File]::Exists("$WimRootDir\$BuildNumber\install.wim")) -and ([System.IO.File]::Exists($ImageLocalPath)))
{
	Write-host "Detected Win10 Wim-path:$WimRootDir\$BuildNumber\install.wim"
    	$RunPEGen=$true
}


if ($RunPEGen -eq $true)
{
    write-host "Starting WinPEGen"
                #Write output to the console.

                #Save the hash in order to check if the wim was changed.

    $PreEditHash=(Get-FileHash "$ImageLocalPath").Hash


                #Changes the tmp variable, launches WinPEGen and restores tmp once we're done.

    $OldTmpEnv=[System.Environment]::GetEnvironmentVariable("tmp")
    $NewTmpEnv=[System.Environment]::SetEnvironmentVariable("tmp",$NewTmpFolder)


                #Don't know who Bob is, but he's next in line. ^^
    #$index=7
    
    write-host "CommandLine: $WinPEGenDir\$Arch\WinPEGen.exe" $WimRootDir\$BuildNumber\install.wim $index $ImageLocalPath 1
    $PEGenOut=& "$WinPEGenDir\$Arch\WinPEGen.exe" "$WimRootDir\$BuildNumber\install.wim" $index "$ImageLocalPath" 1
    $lastexit=$LASTEXITCODE
    Write-host "LASTEXITCODE after WinPEGen:" $lastexit
                        
                 #write the output of WinPEGen to the log.

    if ($PEGenOutToLog)
    {
        Write-output $PEGenOut
    }
    
    [System.Environment]::SetEnvironmentVariable("tmp", $OldTmpEnv)
    Start-Sleep -s 2

                #Restore the tmp variable before exiting
    if ($lastexit -ne 0)
    {
	    write-host $PEGenOut[($PEGenOut.Count-3)..($PEGenOut.Count-1)]
        AbortWithExitCode $lastexit "WinPEGen message: $($PEGenOut[($PEGenOut.Count-3)..($PEGenOut.Count-1)])"
    }

                #Check if the bootimage has been changed.

    $NewHash=(Get-FileHash "$ImageLocalPath").Hash

    if ($PreEditHash -ne $NewHash)
    {
        $TSEnv.Value("BCGood2Go") = "True"
    }
    else
    {
        AbortWithExitCode 10 "The Boot image was unchanged.`r`n Start the script with '-PEGenOutToLog' and check $LogDir\Add-BCToLocalWim.log for more details."
    }
}
else
{
$text="Couldn't find the files needed for WinPEGen."
Write-host $text
AbortWithExitCode 666 $text

}
Stop-Transcript

Param (
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   $PathOfSymlink,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   $Target,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$False)]
   [bool] $TargetIsTSVariable=$False
)


Function DrvLetterToGuidPath($Path)
{
$Drive=-join $Path[0]
$VolGuid=(Get-WmiObject win32_Volume | where {$_.DriveLetter -eq ($Drive+":")} | Select-Object -Property deviceID).DeviceID
$GuidPath=($Path.Replace((-join ($Path[0..2])),$VolGuid))
return $GuidPath
}

Start-Transcript

If ($TargetIsTSVariable -eq $true)
{
    try
    {
        $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    }
    catch
    {
        Write-host "TSEnv was not found"
        Stop-Transcript
        exit
    }
    write-host "Target is TSVariable"
    $Target=($tsenv[$Target])
    write-host "TSVariable=$Target"
    

}

try
{
    $attribs=[System.IO.File]::GetAttributes($Target)
    if (($attribs -and ($attribs -eq "Directory" )) -eq $false)
    {
            write-host "Only directories is supported at the moment."
            $TargetIsFolder=$False
            exit
    }
    if ([System.IO.Directory]::Exists($PathOfSymlink) -eq $false)
    {
        $GuidTarget=DrvLetterToGuidPath($Target)
        Write-host "Will create symlink:" $PathOfSymlink "pointing to:" $Target
        $b=(cmd /c mklink /D $PathOfSymlink $GuidTarget)
        write-host $b
    }
    else
    {
    Write-host "Place of symlink ($PathOfSymlink) already exist. Aborting..."
    }
    
    
}
catch
{
write-host "Could not locate $target"
Stop-Transcript
exit
}


#$GuidTarget=DrvLetterToGuidPath($Target)
#If ($TargetIsFolder)
#    {
#        Write-host "Place of symlink ($PathOfSymlink) already exist. Aborting..."
#    }

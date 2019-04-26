$Logfile="X:\Windows\temp\EarlyTSLog.log"
If ([System.IO.File]::Exists($LogFile))
{
exit
}
Start-Transcript -Path $Logfile
$ScriptDir=[System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)

$TSEnvExists=$false
while ($TSEnvExists -eq $false)
{
    Try
    {
        Start-Sleep -Seconds 1
        $tsenv=New-Object -ComObject Microsoft.sms.TSEnvironment

        try
        {
                $TS=New-object -ComObject Microsoft.sms.TSEnvironment
                if (($TS.GetVariables().Count) -gt 0)
                {
                    foreach($TSVar in $TS.GetVariables())
                    {
                    write-host $TSVar"="($TS["$TSVar"])
                    }
                    $TSEnvExists=$true
                }

        }
        catch
        {
            write-host "Waiting for TSEnv to be available..."
            Start-Sleep -Seconds 2
        }
    }
    catch
    {
        $tsenv=$null
    }
$tsenv=$null
Start-Sleep -Seconds 1
}
write-host "TSEnv is now available"


try
{
    $tsenv=New-Object -ComObject Microsoft.sms.TSEnvironment
}
catch
{
    write-host "Error before setting TSVariable"
}

If (($tsenv["ScriptHasRun"]) -eq "True")
{
    write-host "Script has already run."
}
else{
#DoStuff #If triggering another script let it set the 'ScriptHasRun' variable

    write-host "Script will be executed."
    $tsenv["ScriptHasRun"]="True"
}
$tsenv=$null

Stop-Transcript
exit
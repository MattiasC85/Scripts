<# Remove comment in order to use with configmgr's "run script"

[CmdletBinding()]
param(
        [Parameter(Mandatory=$False)]
        [int]$ShutCountdown=90,
        [Parameter(Mandatory=$False)]
        [int]$ForceShutdown=1
)

#>


Function Update-AndRestart
{

<#
.DESCRIPTION
  Finalizes a pending FU (installed through WU/WUFB) and restarts the computer
.PARAMETER ShutdownInSecs
    Seconds before the shutdown is initiated.
.PARAMETER SkipShutdownOptionsCheck
    Bypasses the check of testing if the current shutdownoptions includes "update and reboot" or "update and shut down".
.PARAMETER Force
    If set to true forces the shutdown even if a user is logged on.
.NOTES
  Version:        0.3Alpha
  Author:         Mattias Cedervall
  Creation Date:  2021-04-05
  Purpose/Change: Initial script development
.EXAMPLE
  Update-AndRestart -ComputerName MyComputer -ShutdownInSecs 600 -SkipShutdownOptionsCheck
#>

[CmdletBinding()]
param(
        [Parameter(Mandatory=$False)]
        [int]$ShutdownInSecs=90,
        [Parameter(Mandatory=$False)]
        [switch]$SkipShutdownOptionsCheck,
        [Parameter(Mandatory=$False)]
        [string]$ComputerName=$Env:COMPUTERNAME,
        [Parameter(Mandatory=$False)]      
        [bool]$Force=$true,
        [Parameter(Mandatory=$False)]
        [bool]$VerboseOutput=$false,
        [Parameter(Mandatory=$False)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
)

    Function Get-CurrentShutdownOptions
    {
        #Anything but 0 indicates that the computer needs to restart to finish an update.(Not only feature updates)

        $CurrentFlyoutOptions=(Get-ItemPropertyValue -LiteralPath hklm:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator -Name ShutdownFlyoutOptions)
        return $CurrentFlyoutOptions
    }

    Function Get-FeatureUpdateProgress
    {

        $VolatileExist=Get-Item HKLM:\SYSTEM\Setup\MoSetup\Volatile\ -ErrorAction SilentlyContinue
        if ($VolatileExist -ne $null)
        {
            $SetupPhase=($VolatileExist.GetValue("SetupPhase"))
            $Progress=($VolatileExist.GetValue("SetupProgress"))
            if ($Progress -eq $null)
            {
                return -1
            }
            else
            {
                return $Progress
            }
        }
    }

    Function Get-FUUpdateResult
    {
        $SetupRes=(Get-ItemPropertyValue hklm:\SYSTEM\Setup\MoSetup\Volatile -Name "SetupHostResult" -ErrorAction SilentlyContinue)
        $retValue=$SetupRes

        if ($SetupRes -eq $null)
        {
            $retValue=(Get-ItemProperty hklm:\SYSTEM\Setup\MoSetup\Volatile -Name "BoxResult" -ErrorAction SilentlyContinue)
        }
        return $retValue
    }


    Function Initiate-Shutdown
    {
    param(

        [Parameter(Mandatory=$False)]
        [ValidateSet("Restart","Shutdown")]
        [String]$ShutdownOption="Restart",
        [Parameter(Mandatory=$False)]
        [Bool]$Force=$false,
        [Parameter(Mandatory=$False)]
        [int]$Countdown=30,
        [Parameter(Mandatory=$False)]
        [bool]$VerboseOutput=$false
    )

    $signature1 = @"
[DllImport("advapi32.dll", SetLastError = true)]
public static extern UInt32 InitiateShutdown(string lpMachineName, string lpMessage, UInt32 dwGraceperiod, UInt32 dwShutdownFlags, UInt32 dwReason);
"@
  
$signature2 = @"
[DllImport("ntdll.dll", SetLastError = true)]
public static extern IntPtr RtlAdjustPrivilege(int Privilege, bool bEnablePrivilege, bool IsThreadPrivilege, out bool PreviousValue);
"@

$advapi32 = Add-Type -MemberDefinition $signature1 -name "AdvApi32" -Namespace "Win32" -PassThru
$ntdll = Add-Type -MemberDefinition $signature2 -name "NtDll" -Namespace "Win32" -PassThru
    
    try{
        $x = $null
        $ModifyTokenRetCode=$ntdll::RtlAdjustPrivilege(19,$true,$false,[ref]$x)
    }
    catch
    {
        Write-Verbose "Error adjusting token"
        #return
    }

    Write-Output "Remote current verbose value: $VerbosePreference"
    Write-Output "ShouldEnableVerboseOutput: $VerboseOutput"
    
    if ($VerboseOutput -eq $true)
    {
        $VerbosePreference='Continue'
    }
    Write-Verbose "Countdown: $Countdown"


    if ($Countdown -ge 60)
    {
        $TimeString="$([Math]::Truncate($Countdown/60)) minute(s)."
        if (($Countdown % 60) -gt 0)
        {
            $TimeString=$TimeString.Replace("minute(s).","minute(s) and $($Countdown % 60) seconds.")
        }
	
    }
    else
    {
	    $TimeString="$Countdown seconds."
    }

    Enum ShutdownFlags
    {
         <#

        SHUTDOWN_FORCE_OTHERS
        0x00000001 (0x1)
        All sessions are forcefully logged off. If this flag is not set and users other than the current user are logged on to the computer specified by the lpMachineName parameter, this function fails with a return value of ERROR_SHUTDOWN_USERS_LOGGED_ON.

        SHUTDOWN_FORCE_SELF
        0x00000002 (0x2)
        Specifies that the originating session is logged off forcefully. If this flag is not set, the originating session is shut down interactively, so a shutdown is not guaranteed even if the function returns successfully.

        SHUTDOWN_GRACE_OVERRIDE
        0x00000020 (0x20)
        Overrides the grace period so that the computer is shut down immediately.
        
        SHUTDOWN_HYBRID
        0x00000200 (0x200)
        Beginning with InitiateShutdown running on Windows 8, you must include the SHUTDOWN_HYBRID flag with one or more of the flags in this table to specify options for the shutdown.
        Beginning with Windows 8, InitiateShutdown always initiate a full system shutdown if the SHUTDOWN_HYBRID flag is absent.
        
        SHUTDOWN_INSTALL_UPDATES
        0x00000040 (0x40)
        The computer installs any updates before starting the shutdown.
        
        SHUTDOWN_NOREBOOT
        0x00000010 (0x10)
        The computer is shut down but is not powered down or rebooted.
        
        SHUTDOWN_POWEROFF
        0x00000008 (0x8)
        The computer is shut down and powered down.
        
        SHUTDOWN_RESTART
        0x00000004 (0x4)
        The computer is shut down and rebooted.
        
        SHUTDOWN_RESTARTAPPS
        0x00000080 (0x80)
        The system is rebooted using the ExitWindowsEx function with the EWX_RESTARTAPPS flag. This restarts any applications that have been registered for restart using the RegisterApplicationRestart function.
        
        0x47=SHUTDOWN_INSTALL_UPDATES, SHUTDOWN_FORCE_OTHERS, SHUTDOWN_FORCE_SELF, SHUTDOWN_RESTART
        
        #>

        SHUTDOWN_FORCE_OTHERS = 0x00000001
        SHUTDOWN_FORCE_SELF = 0x00000002
        SHUTDOWN_GRACE_OVERRIDE = 0x00000020
        SHUTDOWN_HYBRID = 0x00000200
        SHUTDOWN_INSTALL_UPDATES = 0x00000040
        SHUTDOWN_NOREBOOT = 0x00000010
        SHUTDOWN_POWEROFF = 0x00000008
        SHUTDOWN_RESTART = 0x00000004
        SHUTDOWN_RESTARTAPPS = 0x00000080

    }

    #https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--1000-1299-

    if ($ShutdownOption -eq "Restart")
    {
        Write-Verbose "Restart"
        $flags=[ShutdownFlags]::SHUTDOWN_FORCE_SELF + [ShutdownFlags]::SHUTDOWN_INSTALL_UPDATES + [ShutdownFlags]::SHUTDOWN_RESTART
    }
    elseif ($ShutdownOption -eq "Shutdown")
    {
        Write-Verbose "PowerOff"
        $flags=[ShutdownFlags]::SHUTDOWN_FORCE_SELF + [ShutdownFlags]::SHUTDOWN_INSTALL_UPDATES + [ShutdownFlags]::SHUTDOWN_POWEROFF
    }

    if ($Force -eq $true)
    {
        Write-Verbose "Forcing shutdown"
        $flags=$flags + [ShutdownFlags]::SHUTDOWN_FORCE_OTHERS
    }

    Write-Verbose "Final flags: $flags"
    try
    {
        Write-Verbose "TimeString: $TimeString"
        Write-Verbose "CountDown: $Countdown"
        #$flags=[int]([ShutdownFlags]::SHUTDOWN_RESTART + [ShutdownFlags]::SHUTDOWN_FORCE_OTHERS + [ShutdownFlags]::SHUTDOWN_FORCE_SELF)
        #Write-Host "$($flags)"
        #Write-host "Push enter to initiate update and shutdown/restart on $(hostname)"
        #Read-Host
        
        $ShutDownTryRetCode=$advapi32::InitiateShutdown($null,"Installing updates and restarting in $TimeString",$Countdown,[Uint32]$flags,[Uint32]'0x80020011')
        if ($ShutDownTryRetCode -eq 1115)
        {
	        Write-Output "Shutdown is already in progress"
        }
        else
        {
            Write-Output "ShutdownRetCode: $ShutDownTryRetCode"
        }
        
    }
    catch
    {
        Write-Output "Error restarting $ComputerName, $_"
        return
    }
}


    Function Set-InstallAtShutdownRegValue
    {
        try
        {
            $regkey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator",$true)
            $regkey.DeleteSubKey("InstallAtShutDown")
            $NewKey=$regkey.CreateSubKey("InstallAtShutdown")
            #$NewKey.SetValue('',"1")
            $NewKey.SetValue('',1, [Microsoft.Win32.RegistryValueKind]::DWord)
            $regkey.close()
        return 0
        
        }
        catch
        {
            Write-Verbose $_
	        return -1
        }
    }
    
    Function ConvertTo-ScriptBlockWithParams
    {
        param(
        [Parameter(Mandatory=$True)]
        [String]$FunctionName,
        [Parameter(Mandatory=$True)]
        [Hashtable]$Parameters

        )
    
        try
        {
            $MyFunction=(get-item Function:$FunctionName)
            $params=$Parameters
            $ScriptBlock=[ScriptBlock]::Create(".{$($MyFunction.ScriptBlock)} $(&{$args} @params)")
        }

        catch{
        Write-Output "Error getting function $FunctionName"
        }
        return $ScriptBlock
    
    }


    Function Check-PendingRebootFU
    {
        write-host "in Check-PendingRebootFU"
        try
        {
            $Shut=Get-CurrentShutdownOptions
            if ($Shut -ne 0)
            {
                Write-Output "Shutdownoptions: $Shut"   
                $Prog=Get-FeatureUpdateProgress
                Write-Output "Progress: $Prog"
                if ($Prog -eq 100)
                {   
                    Write-Output "Update 100% done"
                    $ret=Get-FUUpdateResult
                    Write-Output "Last FU error:  $ret"
                    if ($ret -eq 0)
                    {
                        return 0
                    }
                
                }
            }
        }
        catch
        {
            Write-Output "Error in Check-PendingRebootFU"
            return -1
        }
         return -1
    }

################################ MAIN ################################

    if ($VerboseOutput -eq $true)
    {
        $VerbosePreference='Continue'
    }

    if ($ComputerName -ne $Env:ComputerName)
    {
        try{
            Write-Verbose "Verbose current: $VerbosePreference"
            $ShutdownOptFunc=(get-item Function:Get-CurrentShutdownOptions)
            $ShutOpt=(Invoke-Command -ScriptBlock $($ShutdownOptFunc.ScriptBlock) -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop)
        }
        catch
        {
            ###Either the Computer is Offline or credentials doesn't work.

            Write-Verbose "Error getting `$ShutOpt"
            throw $_
            return
        }

        if ($ShutOpt -notin ($null,0))
        {
            Write-Output "ShutdownOptions:  $($ShutOpt.ToString())"

        }
        

        if ($ShutOpt -notin ($null,0) -or $SkipShutdownOptionsCheck -eq $true)
        {
            Write-Verbose "ShutdownOptionCheck was bypassed: $SkipShutdownOptionsCheck"
            $ProgressFunc= (get-item Function:Get-FeatureUpdateProgress)
            $UpdResFunc=(get-item Function:Get-FUUpdateResult)

            #$ShutOpt=Invoke-Command -ScriptBlock $($ShutdownOptFunc.ScriptBlock) -ComputerName $ComputerName
            $FUProgress=Invoke-Command -ScriptBlock $($ProgressFunc.ScriptBlock) -ComputerName $ComputerName -Credential $Credential
            $FUResult=Invoke-Command -ScriptBlock $($UpdResFunc.ScriptBlock) -ComputerName $ComputerName -Credential $Credential

            Write-Output "Feature Update progress: " $FUProgress
            Write-Output "Feature Update result: " $FUResult

            if ($FUProgress -eq 100 -and $FUResult -eq 0)
            {
                Write-Verbose "Progress is 100% and result is 0. Continuing"
                $InstRegFunc=(get-item Function:Set-InstallAtShutdownRegValue)
                $SetInstallRegValueResult=Invoke-Command -ScriptBlock $($InstRegFunc.ScriptBlock) -ComputerName $ComputerName -Credential $Credential
                Write-Output "Set InstallAtShutdownRegValue result: $SetInstallRegValueResult"
            
            }
            else
            {
                Write-Output "FUInstallProgress: $FUProgress percent done"
                Write-Output "FU not 100% done or failed to install, won't restart the computer."
                return
            }
            $ForceShutdownIsOne=[bool]$($Force -eq 1)
            $TestBoolAsString="`$$ForceShutdownIsOne"

            $InitShutdownParams=@{
            "Countdown"=$ShutdownInSecs
            "VerboseOutput"='$true'
            "Force"=$TestBoolAsString         ##Forces restart even if a user is logged on
            }


            $InitShutdownSB=(ConvertTo-ScriptBlockWithParams -FunctionName "Initiate-Shutdown" -Parameters  $InitShutdownParams)
            Invoke-Command -ScriptBlock $InitShutdownSB -ComputerName $ComputerName -Credential $Credential

        }
        else
        {
            Write-Output "Current ShutdownOptions is 0 and `$SkipShutdownOptionsCheck was not true. Exiting...."
        }

    }
    else
    {
        Write-Verbose "Running local"
        $FUProgress=Get-FeatureUpdateProgress
        $ShutOpt=Get-CurrentShutdownOptions
        $FUResult=Get-FUUpdateResult
        Write-Verbose "Progress local: $FUProgress"
        Write-Verbose "Current shutdown options: $ShutOpt"
        Write-Verbose "Last update result: $FUResult"

        if ($ShutOpt -notin ($null,0) -or $SkipShutdownOptionsCheck -eq $true)
        {
            if ($FUProgress -eq 100 -and $FUResult -eq 0)
            {
                Write-Verbose "Progress is 100% and result is 0. Continuing"
                $SetInstallRegValueResult=Set-InstallAtShutdownRegValue
                Initiate-Shutdown -Force $ForceShutdown -Countdown $ShutCountdown -VerboseOutput $VerboseOutput
            }
        }
        else
        {
                Write-Output "FUInstallProgress: $FUProgress percent done"
                Write-Output "FU not 100% done or failed to install, won't restart the computer."
                return
        }
    }



    <# Example of other type of params

        $FunctionParams = @{
        "Restart"='$true'
        "Countdown"=$ShutdownInSecs
        "MyTestString"='"Edited string"'    #Please notice the '" "' surrounding the string when a space is present 
        "BoolTest"='$true'
        }
    #>
}

<# Remove comment in order to use with configmgr's "run script"

Update-AndRestart -ShutdownInSecs $ShutCountdown -Force $ForceShutdown -VerboseOutput $true

#>
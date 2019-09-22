$a=Start-Transcript
Add-Type -AssemblyName Microsoft.VisualBasic
$User=[System.Security.Principal.WindowsIdentity]::GetCurrent()
write-host $MyInvocation.MyCommand.Definition
$MsgText=$MyInvocation.MyCommand.Name + ([System.Environment]::NewLine) + "Running SCCM script as User:" + $user.Name

try{
    if ([System.Environment]::UserInteractive){
        $result = [Microsoft.VisualBasic.Interaction]::MsgBox($MsgText,'OKOnly,SystemModal,Information', 'Running as User')
        $result
    }
    else{ 
        Write-Output $MsgText
    }

}
catch
{
write-host "Error when trying to show the msgbox"
}
finally{
Stop-Transcript
}
($a.Path) | Out-File C:\trans.log
Function Test-URI
{
    param (
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]$URIPath,
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]$ExpectedContentType
)

    $UriOut=$null
    $Result=[System.Uri]::TryCreate($URIPath, [System.UriKind]::Absolute,[ref] $UriOut)

    if ($Result -eq $true)
    {
        $WebRes=Invoke-WebRequest -Uri $UriOut -ErrorAction SilentlyContinue
        if ($WebRes.BaseResponse.StatusCode -eq "OK" -and $WebRes.BaseResponse.ResponseUri -eq $URIPath -and $WebRes.BaseResponse.ContentType -match $ContentType)
        {
            return $true
        }
    }

    return $false
}

Function ChangeBgColor($Color){

#Will only use Invoke to make changes

if ($([System.Drawing.Color]::$Color))
{
    Write-Host "---------------"
    write-host "Color is valid"
    $ColorName=([System.Drawing.Color]::$Color).Name
    Write-Host "Changing BGColor to $ColorName"
    #Write-Host $ColorName
}
else{
write-host "Invalid Color."
break
}

$hash.Window.Dispatcher.invoke(
    [action]{$Border=$hash.window.FindName("Bord1");$Border.BackGround=$ColorName
    },
    "Normal"
)
}


Function ChangeSpinnerColor
{

#Using Invoke if it's required.

    param (
    [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]$Dyncolor
)

    DynamicParam {
        Add-Type -AssemblyName System.Drawing, PresentationCore
        $RingColor = 'RingColor'
        $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
        $PSParamAttribute.Mandatory = $True
        $AttCol.Add($PSParamAttribute) 
        $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttCol.Add($ValidateSetAttribute)
        $PSBoundParameters.RingColor= "White"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($RingColor, [string], $AttCol)
        $RuntimeParamDict.Add($RingColor, $RuntimeParameter)
        
        return $RuntimeParamDict
    }

Process
{

write-host "Updating Spinner"
$a=$hash.window.Dispatcher.CheckAccess()
write-host "Spinner needs invoke:" $($a -eq $false)
    if ($a -eq $True)
    {
        write-host "Have access to spinner"
        $Spinner=$hash.window.FindName("Ring");$Spinner.Foreground="$($PSBoundParameters.RingColor)"
    }
    else{
    write-host "Using invoke to update spinner"
    $hash.Window.Dispatcher.invoke(
        [action]{$Spinner=$hash.window.FindName("Ring");$Spinner.Foreground="$($PSBoundParameters.RingColor)"
        },
        "Normal"
    )
    }
    Write-Host "-----------"
}

}

Function SetBackgroundToPic(){

    #Using Invoke if it's required.

    param (
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]$ImagePath
)


if ($ImagePath.ToLower().StartsWith("http") -eq $false)
{
    if (Test-Path $ImagePath)
    {
        Write-host "Local image Found:" $ImagePath
    
    }
    else
    {
        write-host "Path is unreachable"
        break
    }
}
else
{
    Write-host "Http image:" $ImagePath
    if ($(Test-URI -URIPath $ImagePath -ExpectedContentType "image*") -eq $true)
    {
        Write-host "URI of image is reachable"
    }
    else
    {
        write-host "URI of image is unreachable"
        break
    }
}

$acc=$hash.window.Dispatcher.CheckAccess()
    If ($acc -eq $false)
    {
        Write-host "Using invoke to update background: $($acc -eq $false)"
        $hash.Window.Dispatcher.invoke(
        [action]{
        $ImageBrush=[System.Windows.Media.ImageBrush]::new()
        $ImageBrush.Opacity=1
        $ImageBrush.Stretch=[System.Windows.Media.Stretch]::UniformToFill
        $ImageBrush.ImageSource=[System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]::new($ImagePath, [System.UriKind]::Absolute))
        $t=$hash.window.FindName("Bord1");$t.BackGround=$ImageBrush
        },
        "Normal"

    )
    }
    else
    {

        Write-host "Using invoke to update background: $($acc -eq $false)"
        
        $ImageBrush=[System.Windows.Media.ImageBrush]::new()
        $ImageBrush.Opacity=1
        $ImageBrush.Stretch=[System.Windows.Media.Stretch]::UniformToFill
        $ImageBrush.ImageSource=[System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]::new($ImagePath, [System.UriKind]::Absolute))
        $t=$hash.window.FindName("Bord1");$t.BackGround=$ImageBrush
    }
    Write-Host "-----------"
}

Function ChangeTextBlock()
{
    #(On purpose) Only works when called from a thread that already is using $hash.Window.Dispatcher.Invoke

    Param (
	[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]$BlockName,
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]$Text
    )
 DynamicParam {
        Add-Type -AssemblyName System.Drawing, PresentationCore
        
        $DynColor = 'DynColor'
        $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
        $PSParamAttribute.Mandatory = $True
        $AttCol.Add($PSParamAttribute) 
        $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttCol.Add($ValidateSetAttribute)
        $PSBoundParameters.DynColor= "White"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($DynColor, [string], $AttCol)
        $RuntimeParamDict.Add($DynColor, $RuntimeParameter)
        
        return $RuntimeParamDict
    }

Process
{
Write-Host "Updating Textblock '$($PSBoundParameters.BlockName)'"
$ColorName=([System.Drawing.Color]::$DynColor).Name
$a=$hash.window.Dispatcher.CheckAccess()
write-host "TextBlock Needs invoke:" $($a -eq $false)
$TextBlock=$hash.window.FindName("$BlockName"); $TextBlock.Text=$Text; $TextBlock.Foreground="$($PSBoundParameters.DynColor)"
Write-Host "-----------"

<#
$hash.Window.Dispatcher.invoke(
    [action]{$TextBlock=$hash.window.FindName("$BlockName"); $TextBlock.Text=$Text; $TextBlock.Foreground="$($PSBoundParameters.DynColor)"
    },
    "Normal"
)
#>
}
}

Function Set-FinalScreen{

    try 
    {
        ChangeSpinnerColor -RingColor Yellow      #Invoke is handled within the function
        $d=$hash.Window.Dispatcher.Invoke(
        {
            ChangeTextBlock -BlockName "TextBlock1" -Text "Thank you for watching" -DynColor Yellow
        }
        ),
        "Normal"
       
        SetBackgroundToPic -ImagePath 'https://www.groovypost.com/wp-content/uploads/2019/01/computer_update_windows_PC_admin_Featured.jpg'
        Start-Sleep -Seconds 6
        #$d=$hash.Window.Dispatcher.Invoke(
        $hash.Window.Dispatcher.Invoke(
        {
            SetBackgroundToPic -ImagePath $PSScriptRoot\bliss.jpg
            
            ChangeTextBlock -BlockName "TextBlock1" -Text "Thank you for watching" -DynColor Black
        
            ChangeSpinnerColor -RingColor Black      #Invoke is handled within the function

        }
        ),
        "Normal"
    }
    catch
    {
        write-host $_
    }

}

function Start-SplashScreen{
    $Powershell.Runspace = $script:runspace
    $script:handle = $script:Powershell.BeginInvoke()
    Start-Sleep -Seconds 1
}

function Close-SplashScreen (){
    $hash.window.Dispatcher.Invoke("Normal",[action]{ $hash.window.close() })
    $Powershell.EndInvoke($handle) | Out-Null
    $runspace.Close() | Out-Null
}

Function New-Splash
{
    Param (
	[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [int]$Width,
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [int]$Height
    )

Add-Type -AssemblyName PresentationFramework, System.Drawing, System.Windows.Forms, WindowsFormsIntegration

$Load=("$PSScriptRoot\assembly\MahApps.Metro.dll")
[System.Reflection.Assembly]::LoadFrom($Load) |Out-Null

$script:hash = [hashtable]::Synchronized(@{})
$script:runspace = [runspacefactory]::CreateRunspace()
$Runspace.ApartmentState = "STA"
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()
$Runspace.SessionStateProxy.SetVariable("hash",$hash)
$Runspace.SessionStateProxy.SetVariable("Width",$Width)
$Runspace.SessionStateProxy.SetVariable("Height",$Height)

$script:Powershell = [PowerShell]::Create()

$Script={

$WindowHeight= $Height*1.20
$WindowWidth=$Width*1.20

[XML]$Xaml = @"
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Splash" Height="$WindowHeight" Width="$WindowWidth" Background="Transparent">
    <Grid Name="Main" Margin="10" Background="Transparent" >
		<Border Name="Bord1" Background="DodgerBlue" BorderBrush="Silver" BorderThickness="0" CornerRadius="20,20,20,20">
		    <Border.Effect>
                <DropShadowEffect x:Name="DSE" Color="Black" Direction="270" BlurRadius="30" ShadowDepth="2" Opacity="0.6" />
            </Border.Effect>
        </Border>
	</Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $Xaml
$hash.window = [Windows.Markup.XamlReader]::Load($reader)
$hash.window.AllowsTransparency=$true
$hash.window.WindowStyle = [System.Windows.WindowStyle]::None
$hash.window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$hash.window.Topmost = $True
$hash.window.WindowStartupLocation= [System.Windows.WindowStartupLocation]::CenterScreen

$Grid=$hash.window.FindName("Main")
$Grid.Height=$Height
$Grid.Width=$Width


# Add a progress ring
$ProgressRing = [MahApps.Metro.Controls.ProgressRing]::new()
$ProgressRing.Name="Ring"
$ProgressRing.Foreground="DimGray"
$ProgressRing.Opacity = 1
$ProgressRing.IsActive = $true
$ProgressRing.Margin = "0,0,0,10"
$ProgressRing.Height=90
$ProgressRing.Width=90

$ProgressRing.VerticalAlignment=[System.Windows.VerticalAlignment]::Center
$Grid.AddChild($ProgressRing)
$ProgressRing.RegisterName("Ring",$ProgressRing)
$ProgressRing.SetValue([System.Windows.Controls.Grid]::RowProperty,1)
$hash.window.Add_Closing({[System.Windows.Forms.Application]::Exit()})

$TextBlock = New-Object System.Windows.Controls.TextBlock
$TextBlock.Name="TextBlock1"
$TextBlock.TextAlignment=[System.Windows.TextAlignment]::Center
$TextBlock.Foreground="DimGray"
$TextBlock.Margin = "0,0,0,20"
$TextBlock.FontSize=22
$TextBlock.Text = "Run Code after 'ShowDialog'"
$TextBlock.HorizontalAlignment=[System.Windows.HorizontalAlignment]::Center
$TextBlock.VerticalAlignment=[System.Windows.VerticalAlignment]::Bottom
$Grid.AddChild($TextBlock)
$TextBlock.RegisterName("TextBlock1",$TextBlock)

$Grid.RegisterName("Grid1",$Grid)
$hash.window.ShowDialog()
$hash.window.Activate()
}

$Powershell.AddScript($Script) | Out-Null
write-host $Height
write-host "Loading complete"

}

################## POC MAIN ##################

New-Splash -Width 600 -Height 240
Start-SplashScreen
$arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name
$arrSet=$arrSet | Where-Object {$_ -like "A*" -or $_ -like "B*"}


foreach ($color in $arrSet)
{
    ChangeBgColor -Color $color
    $random=Get-Random -Minimum 450 -Maximum 700
    Start-Sleep -Milliseconds $random
}


Write-Host "---------------"


Set-FinalScreen
Start-Sleep -Seconds 10
Close-SplashScreen
write-host "Closed and done"



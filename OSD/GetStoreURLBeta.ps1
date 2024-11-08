﻿function Download-Files
{
    Param (
    [Parameter(Mandatory=$true)]
    [string]$ID,
    [Parameter(Mandatory=$true)]
    [psobject[]]$MSStoreObj,
    [Parameter(Mandatory=$False)]
    [string]$DownloadPath =[System.Environment]::GetEnvironmentVariable("Temp")
    )

    $TargetDir = "$DownloadPath\$ID"

    If ((Test-Path $TargetDir) -eq $false){
        $Folder = New-Item -Path $TargetDir -ItemType Directory -Force 
    }

    foreach ($Url in ($MSStoreObj.URLS))
    {
        if ($MSStoreObj.Type -eq "Store") {
            $ContentInfo=Invoke-WebRequest -Uri $Url -Method Head -ErrorAction SilentlyContinue
        
            if ($ContentInfo -ne $null) {
                $FileName = $($ContentInfo.Headers["Content-Disposition"] -split "fileName=")[-1]
                #Write-Host "FileName: $FileName"
            }
        }
        else {
            $FileName = $($MSStoreObj.FileName)
            $FileName = $($Url -split "/")[-1]
        }

        Write-Host "Downloading $FileName to $TargetDir..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-RestMethod -Method Get -Uri $Url -OutFile "$TargetDir\$FileName"
    }
}

function Get-OnlyLatestVersionsBeta
{
    Param (
        [Parameter(Mandatory=$True)]
        $ProductObject,
        [Parameter(Mandatory=$True)]
        $URLsObject
    )

    $PkgName = $($ProductObject.PackageName -split "_")[0]

    [array]$AffectedURLs = $URLsObject | Where {$_.FileName.StartsWith($PkgName)}
    [array]$AffectedURLs | % {Add-Member -InputObject $_ -MemberType NoteProperty -Name FileType -Value "$($_.FileName.Split(".")[-1])"}
    [array]$AffectedURLs | % {Add-Member -InputObject $_ -MemberType NoteProperty -Name Ver -Value $($_.FileName -Split "_")[1]}
    [array]$AffectedURLs | % {Add-Member -InputObject $_ -MemberType AliasProperty -Name Version -Value Ver -SecondValue version}

    $Grouped = $AffectedURLs | Group-Object -Property FileType
    #Write-Host "Group count: $($Grouped.Count)"

    $ToRemove = foreach ($group in ($Grouped | Where {$_.Count -gt 1}))
    {
        #Write-Host "GroupName: $($group.Name)"

        $ArchGroup = $group.Group | Group-Object -Property Architecture
        
        foreach ($Archgroup in ($ArchGroup | Where {$_.Count -gt 1})) {
            $count = $($Archgroup.count)
            $top = $Archgroup.Group | Sort-Object -Property Version | Select-Object -First $($count -1)
            #Write-Host "Top: $($top.FileName)"
            $top
        }
        
    }

    Write-Host "Number of excluded versions: $($ToRemove.Count)"
    Write-Verbose "Excluded Files:"
    
    Foreach ($Removed in $ToRemove)
    {
        Write-Verbose "Excluded file: $($Removed.FileName)"
    }

    return $URLsObject | Where {$($_.FileName) -notin ($ToRemove.FileName)}
}

function Add-ArchitectureBeta
{
    Param (
        [Parameter(Mandatory=$True)]
        $URLsObject
    )

    $URLsObject | Where {$_.FileName -match "_x64_"} | Add-Member -MemberType NoteProperty -Name Architecture -Value x64
    $URLsObject | Where {$_.FileName -match "_x86_"} | Add-Member -MemberType NoteProperty -Name Architecture -Value x86
    $URLsObject | Where {$_.FileName -match "_arm_"} | Add-Member -MemberType NoteProperty -Name Architecture -Value arm
    $URLsObject | Where {$_.FileName -match "_arm64_"} | Add-Member -MemberType NoteProperty -Name Architecture -Value arm64
    $URLsObject | Where {$_.FileName -match "_neutral_"} | Add-Member -MemberType NoteProperty -Name Architecture -Value neutral
}

function Get-CookieXML
{
    $CookieXML= @'
    <Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.w3.org/2003/05/soap-envelope">
  <Header>
    <Action d3p1:mustUnderstand="1" xmlns:d3p1="http://www.w3.org/2003/05/soap-envelope" xmlns="http://www.w3.org/2005/08/addressing">http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/GetCookie</Action>
    <MessageID xmlns="http://www.w3.org/2005/08/addressing">urn:uuid:b9b43757-2247-4d7b-ae8f-a71ba8a22386</MessageID>
    <To d3p1:mustUnderstand="1" xmlns:d3p1="http://www.w3.org/2003/05/soap-envelope" xmlns="http://www.w3.org/2005/08/addressing">https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx</To>
    <Security d3p1:mustUnderstand="1" xmlns:d3p1="http://www.w3.org/2003/05/soap-envelope" xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <Timestamp xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
        <Created>2017-12-02T00:16:15.210Z</Created>
        <Expires>2017-12-29T06:25:43.943Z</Expires>
      </Timestamp>
      <WindowsUpdateTicketsToken d4p1:id="ClientMSA" xmlns:d4p1="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" xmlns="http://schemas.microsoft.com/msus/2014/10/WindowsUpdateAuthorization">
        <TicketType Name="MSA" Version="1.0" Policy="MBI_SSL">
          <User />
        </TicketType>
      </WindowsUpdateTicketsToken>
    </Security>
  </Header>
  <Body>
    <GetCookie xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
      <oldCookie>
      </oldCookie>
      <lastChange>2015-10-21T17:01:07.1472913Z</lastChange>
      <currentTime>2017-12-02T00:16:15.217Z</currentTime>
      <protocolVersion>1.40</protocolVersion>
    </GetCookie>
  </Body>
</Envelope>
'@

return $CookieXML
}

function Get-WUIDReqXML
{
    $WUIDXML= @'
    <s:Envelope
	xmlns:a="http://www.w3.org/2005/08/addressing"
	xmlns:s="http://www.w3.org/2003/05/soap-envelope">
	<s:Header>
		<a:Action s:mustUnderstand="1">http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/SyncUpdates</a:Action>
		<a:MessageID>urn:uuid:175df68c-4b91-41ee-b70b-f2208c65438e</a:MessageID>
		<a:To s:mustUnderstand="1">https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx</a:To>
		<o:Security s:mustUnderstand="1"
			xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
			<Timestamp
				xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
				<Created>2017-08-05T02:03:05.038Z</Created>
				<Expires>2017-08-05T02:08:05.038Z</Expires>
			</Timestamp>
			<wuws:WindowsUpdateTicketsToken wsu:id="ClientMSA"
				xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
				xmlns:wuws="http://schemas.microsoft.com/msus/2014/10/WindowsUpdateAuthorization">
				<TicketType Name="MSA" Version="1.0" Policy="MBI_SSL">
					{2}
				</TicketType>
			</wuws:WindowsUpdateTicketsToken>
		</o:Security>
	</s:Header>
	<s:Body>
		<SyncUpdates
			xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
			<cookie>
				<Expiration>2045-03-11T02:02:48Z</Expiration>
				<EncryptedData>{0}</EncryptedData>
			</cookie>
			<parameters>
				<ExpressQuery>false</ExpressQuery>
				<InstalledNonLeafUpdateIDs>
					<int>1</int>
					<int>2</int>
					<int>3</int>
					<int>11</int>
					<int>19</int>
					<int>544</int>
					<int>549</int>
					<int>2359974</int>
					<int>2359977</int>
					<int>5169044</int>
					<int>8788830</int>
					<int>23110993</int>
					<int>23110994</int>
					<int>54341900</int>
					<int>54343656</int>
					<int>59830006</int>
					<int>59830007</int>
					<int>59830008</int>
					<int>60484010</int>
					<int>62450018</int>
					<int>62450019</int>
					<int>62450020</int>
					<int>66027979</int>
					<int>66053150</int>
					<int>97657898</int>
					<int>98822896</int>
					<int>98959022</int>
					<int>98959023</int>
					<int>98959024</int>
					<int>98959025</int>
					<int>98959026</int>
					<int>104433538</int>
					<int>104900364</int>
					<int>105489019</int>
					<int>117765322</int>
					<int>129905029</int>
					<int>130040031</int>
					<int>132387090</int>
					<int>132393049</int>
					<int>133399034</int>
					<int>138537048</int>
					<int>140377312</int>
					<int>143747671</int>
					<int>158941041</int>
					<int>158941042</int>
					<int>158941043</int>
					<int>158941044</int>
					<int>159123858</int>
					<int>159130928</int>
					<int>164836897</int>
					<int>164847386</int>
					<int>164848327</int>
					<int>164852241</int>
					<int>164852246</int>
					<int>164852252</int>
					<int>164852253</int>
				</InstalledNonLeafUpdateIDs>
				<OtherCachedUpdateIDs>
					<int>10</int>
					<int>17</int>
					<int>2359977</int>
					<int>5143990</int>
					<int>5169043</int>
					<int>5169047</int>
					<int>8806526</int>
					<int>9125350</int>
					<int>9154769</int>
					<int>10809856</int>
					<int>23110995</int>
					<int>23110996</int>
					<int>23110999</int>
					<int>23111000</int>
					<int>23111001</int>
					<int>23111002</int>
					<int>23111003</int>
					<int>23111004</int>
					<int>24513870</int>
					<int>28880263</int>
					<int>30077688</int>
					<int>30486944</int>
					<int>30526991</int>
					<int>30528442</int>
					<int>30530496</int>
					<int>30530501</int>
					<int>30530504</int>
					<int>30530962</int>
					<int>30535326</int>
					<int>30536242</int>
					<int>30539913</int>
					<int>30545142</int>
					<int>30545145</int>
					<int>30545488</int>
					<int>30546212</int>
					<int>30547779</int>
					<int>30548797</int>
					<int>30548860</int>
					<int>30549262</int>
					<int>30551160</int>
					<int>30551161</int>
					<int>30551164</int>
					<int>30553016</int>
					<int>30553744</int>
					<int>30554014</int>
					<int>30559008</int>
					<int>30559011</int>
					<int>30560006</int>
					<int>30560011</int>
					<int>30561006</int>
					<int>30563261</int>
					<int>30565215</int>
					<int>30578059</int>
					<int>30664998</int>
					<int>30677904</int>
					<int>30681618</int>
					<int>30682195</int>
					<int>30685055</int>
					<int>30702579</int>
					<int>30708772</int>
					<int>30709591</int>
					<int>30711304</int>
					<int>30715418</int>
					<int>30720106</int>
					<int>30720273</int>
					<int>30732075</int>
					<int>30866952</int>
					<int>30866964</int>
					<int>30870749</int>
					<int>30877852</int>
					<int>30878437</int>
					<int>30890151</int>
					<int>30892149</int>
					<int>30990917</int>
					<int>31049444</int>
					<int>31190936</int>
					<int>31196961</int>
					<int>31197811</int>
					<int>31198836</int>
					<int>31202713</int>
					<int>31203522</int>
					<int>31205442</int>
					<int>31205557</int>
					<int>31207585</int>
					<int>31208440</int>
					<int>31208451</int>
					<int>31209591</int>
					<int>31210536</int>
					<int>31211625</int>
					<int>31212713</int>
					<int>31213588</int>
					<int>31218518</int>
					<int>31219420</int>
					<int>31220279</int>
					<int>31220302</int>
					<int>31222086</int>
					<int>31227080</int>
					<int>31229030</int>
					<int>31238236</int>
					<int>31254198</int>
					<int>31258008</int>
					<int>36436779</int>
					<int>36437850</int>
					<int>36464012</int>
					<int>41916569</int>
					<int>47249982</int>
					<int>47283134</int>
					<int>58577027</int>
					<int>58578040</int>
					<int>58578041</int>
					<int>58628920</int>
					<int>59107045</int>
					<int>59125697</int>
					<int>59142249</int>
					<int>60466586</int>
					<int>60478936</int>
					<int>66450441</int>
					<int>66467021</int>
					<int>66479051</int>
					<int>75202978</int>
					<int>77436021</int>
					<int>77449129</int>
					<int>85159569</int>
					<int>90199702</int>
					<int>90212090</int>
					<int>96911147</int>
					<int>97110308</int>
					<int>98528428</int>
					<int>98665206</int>
					<int>98837995</int>
					<int>98842922</int>
					<int>98842977</int>
					<int>98846632</int>
					<int>98866485</int>
					<int>98874250</int>
					<int>98879075</int>
					<int>98904649</int>
					<int>98918872</int>
					<int>98945691</int>
					<int>98959458</int>
					<int>98984707</int>
					<int>100220125</int>
					<int>100238731</int>
					<int>100662329</int>
					<int>100795834</int>
					<int>100862457</int>
					<int>103124811</int>
					<int>103348671</int>
					<int>104369981</int>
					<int>104372472</int>
					<int>104385324</int>
					<int>104465831</int>
					<int>104465834</int>
					<int>104467697</int>
					<int>104473368</int>
					<int>104482267</int>
					<int>104505005</int>
					<int>104523840</int>
					<int>104550085</int>
					<int>104558084</int>
					<int>104659441</int>
					<int>104659675</int>
					<int>104664678</int>
					<int>104668274</int>
					<int>104671092</int>
					<int>104673242</int>
					<int>104674239</int>
					<int>104679268</int>
					<int>104686047</int>
					<int>104698649</int>
					<int>104751469</int>
					<int>104752478</int>
					<int>104755145</int>
					<int>104761158</int>
					<int>104762266</int>
					<int>104786484</int>
					<int>104853747</int>
					<int>104873258</int>
					<int>104983051</int>
					<int>105063056</int>
					<int>105116588</int>
					<int>105178523</int>
					<int>105318602</int>
					<int>105362613</int>
					<int>105364552</int>
					<int>105368563</int>
					<int>105369591</int>
					<int>105370746</int>
					<int>105373503</int>
					<int>105373615</int>
					<int>105376634</int>
					<int>105377546</int>
					<int>105378752</int>
					<int>105379574</int>
					<int>105381626</int>
					<int>105382587</int>
					<int>105425313</int>
					<int>105495146</int>
					<int>105862607</int>
					<int>105939029</int>
					<int>105995585</int>
					<int>106017178</int>
					<int>106129726</int>
					<int>106768485</int>
					<int>107825194</int>
					<int>111906429</int>
					<int>115121473</int>
					<int>115578654</int>
					<int>116630363</int>
					<int>117835105</int>
					<int>117850671</int>
					<int>118638500</int>
					<int>118662027</int>
					<int>118872681</int>
					<int>118873829</int>
					<int>118879289</int>
					<int>118889092</int>
					<int>119501720</int>
					<int>119551648</int>
					<int>119569538</int>
					<int>119640702</int>
					<int>119667998</int>
					<int>119674103</int>
					<int>119697201</int>
					<int>119706266</int>
					<int>119744627</int>
					<int>119773746</int>
					<int>120072697</int>
					<int>120144309</int>
					<int>120214154</int>
					<int>120357027</int>
					<int>120392612</int>
					<int>120399120</int>
					<int>120553945</int>
					<int>120783545</int>
					<int>120797092</int>
					<int>120881676</int>
					<int>120889689</int>
					<int>120999554</int>
					<int>121168608</int>
					<int>121268830</int>
					<int>121341838</int>
					<int>121729951</int>
					<int>121803677</int>
					<int>122165810</int>
					<int>125408034</int>
					<int>127293130</int>
					<int>127566683</int>
					<int>127762067</int>
					<int>127861893</int>
					<int>128571722</int>
					<int>128647535</int>
					<int>128698922</int>
					<int>128701748</int>
					<int>128771507</int>
					<int>129037212</int>
					<int>129079800</int>
					<int>129175415</int>
					<int>129317272</int>
					<int>129319665</int>
					<int>129365668</int>
					<int>129378095</int>
					<int>129424803</int>
					<int>129590730</int>
					<int>129603714</int>
					<int>129625954</int>
					<int>129692391</int>
					<int>129714980</int>
					<int>129721097</int>
					<int>129886397</int>
					<int>129968371</int>
					<int>129972243</int>
					<int>130009862</int>
					<int>130033651</int>
					<int>130040030</int>
					<int>130040032</int>
					<int>130040033</int>
					<int>130091954</int>
					<int>130100640</int>
					<int>130131267</int>
					<int>130131921</int>
					<int>130144837</int>
					<int>130171030</int>
					<int>130172071</int>
					<int>130197218</int>
					<int>130212435</int>
					<int>130291076</int>
					<int>130402427</int>
					<int>130405166</int>
					<int>130676169</int>
					<int>130698471</int>
					<int>130713390</int>
					<int>130785217</int>
					<int>131396908</int>
					<int>131455115</int>
					<int>131682095</int>
					<int>131689473</int>
					<int>131701956</int>
					<int>132142800</int>
					<int>132525441</int>
					<int>132765492</int>
					<int>132801275</int>
					<int>133399034</int>
					<int>134522926</int>
					<int>134524022</int>
					<int>134528994</int>
					<int>134532942</int>
					<int>134536993</int>
					<int>134538001</int>
					<int>134547533</int>
					<int>134549216</int>
					<int>134549317</int>
					<int>134550159</int>
					<int>134550214</int>
					<int>134550232</int>
					<int>134551154</int>
					<int>134551207</int>
					<int>134551390</int>
					<int>134553171</int>
					<int>134553237</int>
					<int>134554199</int>
					<int>134554227</int>
					<int>134555229</int>
					<int>134555240</int>
					<int>134556118</int>
					<int>134557078</int>
					<int>134560099</int>
					<int>134560287</int>
					<int>134562084</int>
					<int>134562180</int>
					<int>134563287</int>
					<int>134565083</int>
					<int>134566130</int>
					<int>134568111</int>
					<int>134624737</int>
					<int>134666461</int>
					<int>134672998</int>
					<int>134684008</int>
					<int>134916523</int>
					<int>135100527</int>
					<int>135219410</int>
					<int>135222083</int>
					<int>135306997</int>
					<int>135463054</int>
					<int>135779456</int>
					<int>135812968</int>
					<int>136097030</int>
					<int>136131333</int>
					<int>136146907</int>
					<int>136157556</int>
					<int>136320962</int>
					<int>136450641</int>
					<int>136466000</int>
					<int>136745792</int>
					<int>136761546</int>
					<int>136840245</int>
					<int>138160034</int>
					<int>138181244</int>
					<int>138210071</int>
					<int>138210107</int>
					<int>138232200</int>
					<int>138237088</int>
					<int>138277547</int>
					<int>138287133</int>
					<int>138306991</int>
					<int>138324625</int>
					<int>138341916</int>
					<int>138372035</int>
					<int>138372036</int>
					<int>138375118</int>
					<int>138378071</int>
					<int>138380128</int>
					<int>138380194</int>
					<int>138534411</int>
					<int>138618294</int>
					<int>138931764</int>
					<int>139536037</int>
					<int>139536038</int>
					<int>139536039</int>
					<int>139536040</int>
					<int>140367832</int>
					<int>140406050</int>
					<int>140421668</int>
					<int>140422973</int>
					<int>140423713</int>
					<int>140436348</int>
					<int>140483470</int>
					<int>140615715</int>
					<int>140802803</int>
					<int>140896470</int>
					<int>141189437</int>
					<int>141192744</int>
					<int>141382548</int>
					<int>141461680</int>
					<int>141624996</int>
					<int>141627135</int>
					<int>141659139</int>
					<int>141872038</int>
					<int>141993721</int>
					<int>142006413</int>
					<int>142045136</int>
					<int>142095667</int>
					<int>142227273</int>
					<int>142250480</int>
					<int>142518788</int>
					<int>142544931</int>
					<int>142546314</int>
					<int>142555433</int>
					<int>142653044</int>
					<int>143191852</int>
					<int>143258496</int>
					<int>143299722</int>
					<int>143331253</int>
					<int>143432462</int>
					<int>143632431</int>
					<int>143695326</int>
					<int>144219522</int>
					<int>144590916</int>
					<int>145410436</int>
					<int>146720405</int>
					<int>150810438</int>
					<int>151258773</int>
					<int>151315554</int>
					<int>151400090</int>
					<int>151429441</int>
					<int>151439617</int>
					<int>151453617</int>
					<int>151466296</int>
					<int>151511132</int>
					<int>151636561</int>
					<int>151823192</int>
					<int>151827116</int>
					<int>151850642</int>
					<int>152016572</int>
					<int>153111675</int>
					<int>153114652</int>
					<int>153123147</int>
					<int>153267108</int>
					<int>153389799</int>
					<int>153395366</int>
					<int>153718608</int>
					<int>154171028</int>
					<int>154315227</int>
					<int>154559688</int>
					<int>154978771</int>
					<int>154979742</int>
					<int>154985773</int>
					<int>154989370</int>
					<int>155044852</int>
					<int>155065458</int>
					<int>155578573</int>
					<int>156403304</int>
					<int>159085959</int>
					<int>159776047</int>
					<int>159816630</int>
					<int>160733048</int>
					<int>160733049</int>
					<int>160733050</int>
					<int>160733051</int>
					<int>160733056</int>
					<int>164824922</int>
					<int>164824924</int>
					<int>164824926</int>
					<int>164824930</int>
					<int>164831646</int>
					<int>164831647</int>
					<int>164831648</int>
					<int>164831650</int>
					<int>164835050</int>
					<int>164835051</int>
					<int>164835052</int>
					<int>164835056</int>
					<int>164835057</int>
					<int>164835059</int>
					<int>164836898</int>
					<int>164836899</int>
					<int>164836900</int>
					<int>164845333</int>
					<int>164845334</int>
					<int>164845336</int>
					<int>164845337</int>
					<int>164845341</int>
					<int>164845342</int>
					<int>164845345</int>
					<int>164845346</int>
					<int>164845349</int>
					<int>164845350</int>
					<int>164845353</int>
					<int>164845355</int>
					<int>164845358</int>
					<int>164845361</int>
					<int>164845364</int>
					<int>164847387</int>
					<int>164847388</int>
					<int>164847389</int>
					<int>164847390</int>
					<int>164848328</int>
					<int>164848329</int>
					<int>164848330</int>
					<int>164849448</int>
					<int>164849449</int>
					<int>164849451</int>
					<int>164849452</int>
					<int>164849454</int>
					<int>164849455</int>
					<int>164849457</int>
					<int>164849461</int>
					<int>164850219</int>
					<int>164850220</int>
					<int>164850222</int>
					<int>164850223</int>
					<int>164850224</int>
					<int>164850226</int>
					<int>164850227</int>
					<int>164850228</int>
					<int>164850229</int>
					<int>164850231</int>
					<int>164850236</int>
					<int>164850237</int>
					<int>164850240</int>
					<int>164850242</int>
					<int>164850243</int>
					<int>164852242</int>
					<int>164852243</int>
					<int>164852244</int>
					<int>164852247</int>
					<int>164852248</int>
					<int>164852249</int>
					<int>164852250</int>
					<int>164852251</int>
					<int>164852254</int>
					<int>164852256</int>
					<int>164852257</int>
					<int>164852258</int>
					<int>164852259</int>
					<int>164852260</int>
					<int>164852261</int>
					<int>164852262</int>
					<int>164853061</int>
					<int>164853063</int>
					<int>164853071</int>
					<int>164853072</int>
					<int>164853075</int>
					<int>168118980</int>
					<int>168118981</int>
					<int>168118983</int>
					<int>168118984</int>
					<int>168180375</int>
					<int>168180376</int>
					<int>168180378</int>
					<int>168180379</int>
					<int>168270830</int>
					<int>168270831</int>
					<int>168270833</int>
					<int>168270834</int>
					<int>168270835</int>
				</OtherCachedUpdateIDs>
				<SkipSoftwareSync>false</SkipSoftwareSync>
				<NeedTwoGroupOutOfScopeUpdates>true</NeedTwoGroupOutOfScopeUpdates>
				<FilterAppCategoryIds>
					<CategoryIdentifier>
						<Id>{1}</Id>
					</CategoryIdentifier>
				</FilterAppCategoryIds>
				<TreatAppCategoryIdsAsInstalled>true</TreatAppCategoryIdsAsInstalled>
				<AlsoPerformRegularSync>false</AlsoPerformRegularSync>
				<ComputerSpec/>
				<ExtendedUpdateInfoParameters>
					<XmlUpdateFragmentTypes>
						<XmlUpdateFragmentType>Extended</XmlUpdateFragmentType>
					</XmlUpdateFragmentTypes>
					<Locales>
						<string>en-US</string>
						<string>en</string>
					</Locales>
				</ExtendedUpdateInfoParameters>
				<ClientPreferredLanguages>
					<string>en-US</string>
				</ClientPreferredLanguages>
				<ProductsParameters>
					<SyncCurrentVersionOnly>false</SyncCurrentVersionOnly>
					<DeviceAttributes>BranchReadinessLevel=CB;CurrentBranch=rs_prerelease;OEMModel=Virtual Machine;FlightRing=WIS;AttrDataVer=21;SystemManufacturer=Microsoft Corporation;InstallLanguage=en-US;OSUILocale=en-US;InstallationType=Client;FlightingBranchName=external;FirmwareVersion=Hyper-V UEFI Release v2.5;SystemProductName=Virtual Machine;OSSkuId=48;FlightContent=Branch;App=WU;OEMName_Uncleaned=Microsoft Corporation;AppVer=10.0.16184.1001;OSArchitecture=AMD64;SystemSKU=None;UpdateManagementGroup=2;IsFlightingEnabled=1;IsDeviceRetailDemo=0;TelemetryLevel=3;OSVersion=10.0.16184.1001;DeviceFamily=Windows.Desktop;</DeviceAttributes>
					<CallerAttributes>Interactive=1;IsSeeker=0;</CallerAttributes>
					<Products/>
				</ProductsParameters>
			</parameters>
		</SyncUpdates>
	</s:Body>
</s:Envelope>
'@

return $WUIDXML
}

function Get-FE3FileXML
{
    $FE3XML= @'
    <s:Envelope
	xmlns:a="http://www.w3.org/2005/08/addressing"
	xmlns:s="http://www.w3.org/2003/05/soap-envelope">
    <s:Header>
        <a:Action s:mustUnderstand="1">http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/GetExtendedUpdateInfo2</a:Action>
        <a:MessageID>urn:uuid:2cc99c2e-3b3e-4fb1-9e31-0cd30e6f43a0</a:MessageID>
        <a:To s:mustUnderstand="1">https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx/secured</a:To>
        <o:Security s:mustUnderstand="1"
			xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
            <Timestamp
				xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
                <Created>2017-08-01T00:29:01.868Z</Created>
                <Expires>2017-08-01T00:34:01.868Z</Expires>
            </Timestamp>
            <wuws:WindowsUpdateTicketsToken wsu:id="ClientMSA"
				xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
				xmlns:wuws="http://schemas.microsoft.com/msus/2014/10/WindowsUpdateAuthorization">
                <TicketType Name="MSA" Version="1.0" Policy="MBI_SSL">
                    {2}
                </TicketType>
            </wuws:WindowsUpdateTicketsToken>
        </o:Security>
    </s:Header>
    <s:Body>
        <GetExtendedUpdateInfo2
			xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
            <updateIDs>
                <UpdateIdentity>
                    <UpdateID>{0}</UpdateID>
                    <RevisionNumber>{1}</RevisionNumber>
                </UpdateIdentity>
            </updateIDs>
            <infoTypes>
                <XmlUpdateFragmentType>FileUrl</XmlUpdateFragmentType>
                <XmlUpdateFragmentType>FileDecryption</XmlUpdateFragmentType>
            </infoTypes>
            <deviceAttributes>BranchReadinessLevel=CB;CurrentBranch=rs_prerelease;OEMModel=Virtual Machine;FlightRing=WIS;AttrDataVer=21;SystemManufacturer=Microsoft Corporation;InstallLanguage=en-US;OSUILocale=en-US;InstallationType=Client;FlightingBranchName=external;FirmwareVersion=Hyper-V UEFI Release v2.5;SystemProductName=Virtual Machine;OSSkuId=48;FlightContent=Branch;App=WU;OEMName_Uncleaned=Microsoft Corporation;AppVer=10.0.16184.1001;OSArchitecture=AMD64;SystemSKU=None;UpdateManagementGroup=2;IsFlightingEnabled=1;IsDeviceRetailDemo=0;TelemetryLevel=3;OSVersion=10.0.16184.1001;DeviceFamily=Windows.Desktop;</deviceAttributes>
        </GetExtendedUpdateInfo2>
    </s:Body>
</s:Envelope>
'@

return $FE3XML
}

function Get-StoreURLS
{

<#

.SYNOPSIS
   Returns direct download links for MSStore apps.

.DESCRIPTION
   Returns direct download links for MSStore apps and this time without any 3rd-party involved.

.PARAMETER ProductNumber
The Product number. Can be found in the URL, eg "https://apps.microsoft.com/detail/9wzdncrfhvn5" where "9wzdncrfhvn5" is the product number.

.PARAMETER Architecture
The target architecture of which links that should be included. x86, x64, arm or arm64.

.PARAMETER DoDownload
Will download all the files found to the folder %temp%\$ProductNumber

.EXAMPLE
PS> Get-StoreURLS -ProductNumber 9wzdncrfhvn5

.EXAMPLE
PS> $URLS = Get-StoreURLS -ProductNumber xp8bt8dw290mpq -Architecture x64

.EXAMPLE
PS> $URLS = Get-StoreURLS -ProductNumber 9wzdncrfhvn5 -Architecture x64 -DoDownload
              
#>

    Param (
       [Parameter(Mandatory=$True)]
       [string] $ProductNumber,
       [Parameter(Mandatory=$False)]
       [ValidateSet("x86","x64","arm","arm64")]
       [string] $Architecture,
       [Parameter(Mandatory=$False)]
       [switch] $DoDownload,
       [Parameter(Mandatory=$False)]
       [switch] $BetaOnlyLatestVersions,
       [Parameter(Mandatory=$False)]
       [switch] $BetaIncludeEncFiles = $false
    )

    #$ProductNumber="9NBLGGH6FW5V"

    #$ProductNumber="xp8bt8dw290mpq"
    #$Architecture="x86"

    $release_type = "Retail"
    #$ProductNumber="xp8bt8dw290mpq"

    $URI="https://storeedgefd.dsx.mp.microsoft.com/v9.0/products/$($ProductNumber)?market=US&locale=en-us&deviceFamily=Windows.Desktop"

    try {
        $ProdInfo = Invoke-RestMethod -Method Get -Uri $URI -ErrorAction Continue
    }
    catch {
        return "Error getting product data. $($($_.ErrorDetails.Message | ConvertFrom-Json).message)"
    }

    if ($ProdInfo.Payload.DisplayPrice -ne "free") {
        Write-Error "Not a free store app, aborting."
        return
    }
    #return $ProdInfo

    $Data=$ProdInfo.Payload.Skus[0].FulfillmentData

    if ($Data -eq $null) {
        #Write-Host "Detected exe installer or failed to find FulfillmentData"
        $URLNonAppx = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/packageManifests/$ProductNumber"
        $resp = Invoke-RestMethod -Uri $URLNonAppx
        $Installers = $resp.data.Versions

        $TmpID = $($Installers.DefaultLocale.PackageName)
        $URLS = $Installers.Installers.InstallerUrl | select -Unique

        $tempArrURLS= @()

        $ToReturn = foreach ($installer in $Installers.Installers) {

            #$FileName = $TmpID.Replace(" ","") + $($installer.Architecture) + ".exe"
            #$installer | Add-Member -MemberType NoteProperty -Name "FileName" -Value $FileName

            $arr = @()
            $arr = $arr + $installer.InstallerUrl
            [System.Collections.ArrayList]$arrList=$arr

            $obj = New-Object PSObject -Property @{
                    ID = $TmpID + " $($installer.Architecture)"
                    #FileName = $FileName
                    URLS = $arrList
                    Architecture = $($installer.Architecture)
                    ProductNumber = $($ProductNumber)
                    Type = "Exe"
            }

            if (($tempArrURLS -Contains $($installer.InstallerUrl)) -eq $False) {
                $obj
                $tempArrURLS = $tempArrURLS + $installer.InstallerUrl
            }

        }

        if ($Architecture) {
            $ToReturn = $ToReturn | where {$_.Architecture -eq $Architecture}
        }

        $ToReturn | Add-Member -MemberType ScriptMethod -Name "Download" -Value {param([string] $ID=$($this.ProductNumber), [object]$StoreObj = $([array]$this), [string]$DownloadFolder = [System.Environment]::GetEnvironmentVariable("Temp")) Download-Files -ID $ID -MSStoreObj $StoreObj -DownloadPath $DownloadFolder}

        if ($DoDownload.IsPresent) {
            if ($ToReturn -ne $null) {
                Download-Files -ID $ProductNumber -MSStoreObj $ToReturn
                Write-Host "Done!" -ForegroundColor Green
                (Start "$([System.Environment]::GetEnvironmentVariable("Temp"))\$ProductNumber\")
                return $ToReturn
            }
            else {
                Write-Warning "No Urls found!"
                return
            }
        }
        else {
            return $ToReturn
        }
    }

    $ProductInfoObj = New-Object PSObject -Property @{
                    ProductName = $ProdInfo.PayLoad.Title
                    PackageName = $ProdInfo.Payload.PackageFamilyNames[0]
                    ProductID = $ProdInfo.PayLoad.ProductId
                    Publisher = $ProdInfo.PayLoad.PublisherName
                    PublisherURL = $ProdInfo.PayLoad.AppWebsiteUrl
                    License = $ProdInfo.PayLoad.AdditionalLicenseTerms
                  }

    #return $ProductInfoObj
    Write-Host "Product found:"
    
    Foreach ($Prop in $ProductInfoObj.psobject.Properties) {
        Write-Host "  $($Prop.Name): $($Prop.Value)"
    }

    Write-Host ""
    #Write-Host "$($ProductInfoObj | fl * | Out-String)"


    $DataObj=$Data | Convertfrom-Json

    $Cookie = Get-CookieXML

    $CookieURL="https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx"

    $CookieHeader = @{
        'Content-Type' = 'application/soap+xml; charset=utf-8'
    }

    $cookieResp=Invoke-RestMethod -Method Post -Body $Cookie -Uri $CookieURL -Headers $CookieHeader

    #Write-Host "After cookieResp"

    $cookieValue=$cookieResp.GetElementsByTagName("EncryptedData")[0].firstChild.Data

    $WUIDReq = Get-WUIDReqXML

    $FinalWU=$WUIDReq.Replace("{0}",$cookieValue).replace("{1}",$($DataObj.WuCategoryId.ToString())).Replace("{2}",$release_type)

    $WUURL="https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx"

    #Write-Host "Before WUResp"

    $WUResp=Invoke-RestMethod -Method Post -Body $FinalWU -Headers $CookieHeader -Uri $WUURL
    #Write-Host "After WUResp"

    if ($WUResp -ne $null) {
        #Write-Host "Not null"
        #Write-Host "$($WUResp | fl *)"
    }
    else {
        Write-Error "Error getting WU-response!"
        return
    }

    [xml]$doc2=$WUResp.InnerXml.ToString().replace("&lt;","<").replace("&gt;",">")

    $Files=$doc2.GetElementsByTagName("Files")
    $secfrag=$doc2.GetElementsByTagName("SecuredFragment")

    [array]$objs=foreach ($node in $Files) {
        $id=$node.parentNode.parentNode.getElementsByTagName("ID")[0].FirstChild.Value
        $Filename=$node.FirstChild.Attributes['InstallerSpecificIdentifier'].Value+"_"+$node.firstChild.attributes['FileName'].Value
        New-Object PSObject -Property @{
                ID = $ID
                FileName = $Filename
        }
    }

    foreach ($node2 in $secfrag) {
        $ID=$node2.parentNode.parentNode.parentNode.getElementsByTagName("ID")[0].FirstChild.Value
        $updID=$node2.parentNode.parentNode.firstChild
        $UpdateID=$updID.UpdateID
        $Revision=$updID.RevisionNumber
        #$Revision
        $AddTo=$objs.Where({$_.ID -eq $ID})[0]
        $AddTo | Add-Member -MemberType NoteProperty -Name UpdateID -Value $UpdateID
        $AddTo | Add-Member -MemberType NoteProperty -Name Revision -Value $Revision
    }

    $FE3Req = Get-FE3FileXML
    $FE3URL="https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx/secured"

    Foreach ($obj in $objs) {
        $FinalFE3=$FE3Req.Replace("{0}",$obj.UpdateID).replace("{1}",$obj.Revision).Replace("{2}",$release_type)
        $FE3Resp=Invoke-RestMethod -Uri $FE3URL -Method Post -Body $FinalFE3 -Headers $CookieHeader

        $URLS=$FE3Resp.getElementsByTagName("FileLocation")
        $URLS = $URLS | Sort-Object -Property Url
        #write-host "$($URLS | fl * | Out-String)"
        $i=0
        $arr = @()

        foreach ($URL in $URLS) {
            $arr = $arr + $($URL.Url)
            #$obj | Add-Member -MemberType NoteProperty -Name $("URL$i") -Value $($URL.Url)
            $i++
        }

        [System.Collections.ArrayList]$arrList=$arr
        $obj | Add-Member -MemberType NoteProperty -Name URLS -Value $arrList
        $obj | Add-Member -MemberType NoteProperty -Name ProductNumber -Value $ProductNumber
        $obj | Add-Member -MemberType NoteProperty -Name Type -Value "Store"
    }

    if ($objs -eq $null)
    {
        Write-Error "No URLs found for store app!"
        return
    }

    if ($BetaIncludeEncFiles.IsPresent -eq $False)
    {
        Write-Host "Excluding any encrypted files!"
        $EncFiles = $objs | Where {$($_.FileName.Split(".")[-1]).startsWith("e")}
        $objs = $objs | Where {$_ -notin $EncFiles}
        
        if ($EncFiles.Count -gt 0 ) {
            Write-Host "Removed $($EncFiles.Count) encrypted files from the list."
        }
    }
    
    [array]$ToReturn = $objs | Where {$_.FileName -match "_$Architecture`_" -or $_.Filename -match "_neutral"}

    $ToReturn | Add-Member -MemberType ScriptMethod -Name "Download" -Value {param([string] $ID=$($this.ProductNumber), [object]$StoreObj = $([array]$this), [string]$DownloadFolder = [System.Environment]::GetEnvironmentVariable("Temp")) Download-Files -ID $ID -MSStoreObj $StoreObj -DownloadPath $DownloadFolder}
    
    Add-ArchitectureBeta -URLsObject $ToReturn

    if ($BetaOnlyLatestVersions.IsPresent)
    {
        Write-Host "Trying to exclude older versions..."
        $ToReturn = Get-OnlyLatestVersionsBeta -ProductObject $ProductInfoObj -URLsObject $ToReturn
    }

    if ($DoDownload.IsPresent) {
        if ($ToReturn -ne $null) {
            Download-Files -ID $ProductNumber -MSStoreObj $ToReturn
            Write-Host "Done!" -ForegroundColor Green
            (Start "$([System.Environment]::GetEnvironmentVariable("Temp"))\$ProductNumber\")
            return $ToReturn
        }
        else {
            Write-Warning "No Urls found!"
            return
        }
    }
    else {
        return $ToReturn
    }
}

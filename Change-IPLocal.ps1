$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Windows.Forms
If(-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent() ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Start-Process powershell.exe "-executionpolicy bypass","-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    exit
}
    
#Selection de la carte réseau active
$netAdapter = (Get-NetAdapter).Where{$_.Status -eq "Up"}
$initialConfiguration = Get-NetIPConfiguration -InterfaceAlias $($netAdapter.Name)

do
{
Write-Host @"
[1] - Attribution d'une Addresse IP Local aléatoire
[2] - Export de la configuration r�seau initiale
[3] - Mise en place DHCP + IPv6 (~reinitialisation)
[Q] - Quitter
"@
$result = Read-Host "Votre Choix : "
if($result -eq "1")
{
    $actualConfiguration = Get-NetIPConfiguration -InterfaceAlias $($netAdapter.Name)
    #Désactivation de l'IPV6
    Disable-NetAdapterBinding -InterfaceAlias $($netAdapter.Name) -ComponentID ms_tcpip6
    #Récupération de l'IP IPv4
    $IPv4 = Get-NetIPAddress -InterfaceAlias $($netAdapter.Name) -AddressFamily IPv4
    $ip = $IPv4.IPAddress
    #Gestion IPv4 classe C seulement car j'ai la flemme désolé
    $lastDigit = Get-Random -minimum 10 -Maximum 240
    $ipArray = $ip.Split('.')
    $newIP = [string]::Format("{0}.{1}.{2}.{3}",$ipArray[0],$ipArray[1],$ipArray[2],$lastDigit)

    #Désactivation DHCP 
    Set-NetIPInterface -InterfaceAlias $($netAdapter.Name) -Dhcp Disable
    #Attribution de l'IP
    New-NetIPAddress -InterfaceAlias $($netAdapter.Name) -IPAddress $newIP -PrefixLength 24 -DefaultGateway $($actualConfiguration.IPv4DefaultGateway.NextHop)
    #Configuration DNS
    Set-DnsClientServerAddress -InterfaceAlias $($netAdapter.Name) -ServerAddresses $($actualConfiguration.DNSServer.ServerAddresses)
}
if($result -eq "2")
{
    $object = New-Object PSObject -Property @{
        NetProfileName = $initialConfiguration.NetProfile.Name.ToString()
        IPv4Address = $initialConfiguration.IPv4Address.IPAddress
        IPv4DefaultGateway = $initialConfiguration.IPv4DefaultGateway.NextHop
        DNSServer = $initialConfiguration.DNSServer.ServerAddresses
    }
    $dlg=New-Object System.Windows.Forms.SaveFileDialog
    if($dlg.ShowDialog() -eq 'Ok')
    {
        ConvertTo-Json $object | Out-File $dlg.FileName
    }
    
}
if($result -eq "3")
{
    Set-NetIPInterface -InterfaceAlias $($netAdapter.Name) -Dhcp Enable
    Enable-NetAdapterBinding -InterfaceAlias $($netAdapter.Name) -ComponentID ms_tcpip6
}

}
while($result -ne "Q")




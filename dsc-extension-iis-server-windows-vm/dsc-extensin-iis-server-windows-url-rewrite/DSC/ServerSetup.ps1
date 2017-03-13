Configuration Main
{

Import-DscResource -ModuleName xWebAdministration, PSDesiredStateConfiguration

Node Localhost
  {
    WindowsFeature IIS
    {
      Name   = 'Web-Server'
      Ensure = 'Present'
    }
    WindowsFeature WebServerRole
    {
      Name   = "Web-Server"
      Ensure = "Present"
    }
    WindowsFeature WebManagementConsole
    {
      Name   = "Web-Mgmt-Console"
      Ensure = "Present"
    }
    WindowsFeature WebManagementService
    {
      Name   = "Web-Mgmt-Service"
      Ensure = "Present"
    }
    xWebsite DefaultSite
    {
      Ensure          = 'Present'
      Name            = 'Default Web Site'
      State           = 'Started'
      PhysicalPath    = 'C:\inetpub\wwwroot'
      DependsOn       = '[WindowsFeature]IIS'
    }
    Package UrlRewrite
    {
      #Install URL Rewrite module for IIS
      DependsOn = "[WindowsFeature]WebServerRole"
      Ensure = "Present"
      Name = "IIS URL Rewrite Module 2"
      Path = "https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi"
      Arguments = "/quiet"
      ProductId = "08F0318A-D113-4CF0-993E-50F191D397AD"
    }
    Script ReWriteRules
    {
      #Adds rewrite allowedServerVariables to applicationHost.config
      DependsOn = "[Package]UrlRewrite"
      SetScript = {
        $current = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | Select-Object -ExpandProperty collection | ?{$_.ElementTagName -eq "add"} | Select-Object -ExpandProperty name
        $expected = @("HTTPS", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "REMOTE_ADDR")
        $missing = $expected | Where-Object {$current -notcontains $_}
        try
        {
          Start-WebCommitDelay 
          $missing | ForEach-Object { Add-WebConfiguration /system.webServer/rewrite/allowedServerVariables -atIndex 0 -value @{name="$_"} -Verbose }
          Stop-WebCommitDelay -Commit $true 
        } 
        catch [System.Exception]
        { 
          $_ | Out-String
        }
      }
      TestScript = {
        $current = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | Select-Object -ExpandProperty collection | Select-Object -ExpandProperty name
        $expected = @("HTTPS", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "REMOTE_ADDR")
        $result = -not @($expected| Where-Object {$current -notcontains $_}| Select-Object -first 1).Count
        return $result
      }
      GetScript = {
        $allowedServerVariables = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | Select-Object -ExpandProperty collection
        return $allowedServerVariables
      }
    }
    Script AddRewriteRules
    {
      DependsOn = "[Package]UrlRewrite"
      GetScript = {
        $results = @{}
        return $results
      }
      SetScript = {
        function Add-RewriteRule{
            param (
                [string]$domain,
                [string]$hostName,
                [string]$port
            )

            $ruleName = "$hostName-inbound"
            $publicHost = "$hostName.$domain"
            $privateHost = "http://localhost:$port/{R:1}"

            $path = "MACHINE/WEBROOT/APPHOST/Default Web Site"

            Add-WebConfigurationProperty -pspath $path -filter "system.webServer/rewrite/rules" -name "." -value @{name=$ruleName;stopProcessing='True'}
            Set-WebConfigurationProperty -pspath $path -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/match" -name "url" -value "(.*)"

            Add-WebConfigurationProperty -pspath $path -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/conditions" -name "." -value @{input='{HTTP_POST}';pattern=$publicHost}
            Set-WebConfigurationProperty -pspath $path -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/action" -name "type" -value "Rewrite"
            Set-WebConfigurationProperty -pspath $path -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/action" -name "url" -value $privateHost
        }

        Add-RewriteRule -domain "example.com" -hostName = "build" -port 8080
        Add-RewriteRule -domain "example.com" -hostName = "deploy" -port 8181
        
      }
      TestScript = {
        return $false
      }
    }
  }
}
Configuration Main
{

Param ( [string] $nodeName )

Import-DscResource -ModuleName xWebAdministration, PSDesiredStateConfiguration

Node $nodeName
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
    Script AddRewriteRules
    {
      DependsOn = "[Package]UrlRewrite"
      GetScript = {
        $results = @{}
        return $results
      }
      SetScript = {
        $configPath = "MACHINE/WEBROOT/APPHOST/Default Web Site"
        $domainName = "example.com"

        function Add-RewriteRule{
            param (
                [string]$domain,
                [string]$hostName,
                [string]$port,
                [string]$configPath
            )

            $ruleName = "$hostName-inbound"
            $publicHost = "$hostName.$domain"
            $privateHost = "http://localhost:$port/{R:1}"

            Add-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules" -name "." -value @{name=$ruleName;stopProcessing='True'}
            Set-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/match" -name "url" -value "(.*)"

            Add-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/conditions" -name "." -value @{input='{HTTP_POST}';pattern=$publicHost}
            Set-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/action" -name "type" -value "Rewrite"
            Set-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='$hostName-inbound']/action" -name "url" -value $privateHost
        }

        # Http to Https Rule
        Add-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules" -name "." -value @{name='Redirect to HTTPS';stopProcessing='True'}
        Set-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='Redirect to HTTPS']/match" -name "url" -value "(.*)"
        Add-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='Redirect to HTTPS']/conditions" -name "." -value @{input='{HTTPS}';pattern='^OFF$'}
        Set-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='Redirect to HTTPS']/action" -name "type" -value "Redirect"
        Set-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='Redirect to HTTPS']/action" -name "url" -value "https://{HTTP_HOST}/{REQUEST_URI}"
        Set-WebConfigurationProperty -pspath $configPath -filter "system.webServer/rewrite/rules/rule[@name='Redirect to HTTPS']/action" -name "redirectType" -value "Found"
        
        # Set the individual rules
        Add-RewriteRule -domain $domainName -hostName "build" -port 8080 -configPath $configPath
        Add-RewriteRule -domain $domainName -hostName "deploy" -port 8181 -configPath $configPath
      }
      TestScript = {
        return $false
      }
    }
  }
}

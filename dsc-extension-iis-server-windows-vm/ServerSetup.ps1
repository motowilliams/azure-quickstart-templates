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
    Script DownloadWebDeploy
    {
        TestScript = {
            Test-Path "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        }
        SetScript ={
            $source = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
            $dest = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
            Invoke-WebRequest $source -OutFile $dest
        }
        GetScript = {@{Result = "DownloadWebDeploy"}}
        DependsOn = "[WindowsFeature]WebServerRole"
    }
    Package InstallWebDeploy
    {
        Ensure = "Present"
        Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        Name = "Microsoft Web Deploy 3.6"
        ProductId = "{ED4CC1E5-043E-4157-8452-B5E533FE2BA1}"
        Arguments = "ADDLOCAL=ALL"
        DependsOn = "[Script]DownloadWebDeploy"
    }
    Service StartWebDeploy
    {
        Name = "WMSVC"
        StartupType = "Automatic"
        State = "Running"
        DependsOn = "[Package]InstallWebDeploy"
    }
  }
}
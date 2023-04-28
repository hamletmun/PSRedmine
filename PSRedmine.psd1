@{
Author = 'Mun, Seung Soo'
HelpInfoUri = 'https://github.com/hamletmun/PSRedmine'
ModuleVersion = '0.0.1'
RequiredModules = 'Microsoft.PowerShell.Utility'
RootModule = 'PSRedmine.psm1'
FunctionsToExport = @('Connect-Redmine','Disconnect-Redmine','Send-HTTPRequest',
 'Search-RedmineResource','New-RedmineResource','Get-RedmineResource','Edit-RedmineResource','Remove-RedmineResource')
}

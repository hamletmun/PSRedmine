# PSRedmine

## Installation
1. Copy the entire module folder into the Modules directory
   * All users: `C:\Program Files\WindowsPowerShell\Modules\`
   * Per user: `$HOME\Documents\WindowsPowerShell\Modules\`
2. You can just restart your PowerShell session or manually import the module
    ```PowerShell
    Import-Module PSRedmine
    ```

## Basic Usage
Connect, CRUD, Disconnect
```PowerShell
Connect-Redmine demo.redmine.org

New-RedmineResource project -name testing -identifier test99
New-RedmineResource version -project_id test99 -name testversion
New-RedmineResource issue -project_id test99 -subject testissue

Search-RedmineResource project -name testing
Search-RedmineResource version -name testver -project_id test99 

Get-RedmineResource project test99
Get-RedmineResource project 475
Get-RedmineResource version 408
Get-RedmineResource issue 29552

Edit-RedmineResource project -project_id test99 -description 'change description'
Edit-RedmineResource version -version_id 408 -description 'add desc' -due_date 2018-09-29
Edit-RedmineResource issue -issue_id 29552 -version_id 406

Remove-RedmineResource issue 29552
Remove-RedmineResource version 408
Remove-RedmineResource project test99 # Administrator only

Get-RedmineUsers # Administrator only

Disconnect-Redmine
```

## Reference
* [Redmine API](http://www.redmine.org/projects/redmine/wiki/Rest_api) wiki page

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

New-Redmine project -name testing -identifier test99
New-Redmine version -project_id test99 -name testversion
New-Redmine issue -project_id test99 -subject testissue

Get-Redmine project test99
Get-Redmine project 475
Get-Redmine version 408
Get-Redmine issue 29552

Edit-Redmine project -project_id test99 -description 'change description'
Edit-Redmine version -version_id 408 -description 'add desc' -due_date 2018-09-29
Edit-Redmine issue -issue_id 29552 -version_id 406

Remove-Redmine issue 29552
Remove-Redmine version 408
Remove-Redmine project test99 # Administrator only

Get-RedmineUsers # Administrator only

Disconnect-Redmine
```

## Reference
* [Redmine API](http://www.redmine.org/projects/redmine/wiki/Rest_api) wiki page

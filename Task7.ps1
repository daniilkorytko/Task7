
$dscStorageAccountRG = "Task10"
$dscStorageAccountRG1 = "Task10.1"
$dscStorageAccount = "mystorageaccounttask4"
$dscStorageAccount1 = "mystorageaccounttask7"
$MyLOcation = "westeurope"
$dscName = 'dscTask7.ps1.zip'


$TemplateParametersUriTask7 = 'https://raw.githubusercontent.com/daniilkorytko/Task7/master/Task7.1Parametr.json'
$ParametersFilePathTask7 = "$env:TEMP\Task7Parametr.json" 

$webContent1 = Invoke-WebRequest -Uri $TemplateParametersUriTask7
$webContent1.Content | Out-File $ParametersFilePathTask7


$TemplateParametersUriTask7restore = 'https://raw.githubusercontent.com/daniilkorytko/Task7/master/Task7RestoreParametr.json'
$ParametersFilePathTask7restore = "$env:TEMP\Task7Parametrrestore.json" 

$webContent2 = Invoke-WebRequest -Uri $TemplateParametersUriTask7restore
$webContent2.Content | Out-File $ParametersFilePathTask7restore


$TemplateParametersUriTask7DSC = 'https://raw.githubusercontent.com/daniilkorytko/Task7/master/dscTask7.ps1'
$ParametersFilePathTask7DSC = "$env:TEMP\dscTask7.ps1" 

$webContent3 = Invoke-WebRequest -Uri $TemplateParametersUriTask7DSC
$webContent3.Content | Out-File $ParametersFilePathTask7DSC




#new resource group
New-AzureRmResourceGroup -Name $dscStorageAccountRG -Location $MyLOcation
New-AzureRmResourceGroup -Name $dscStorageAccountRG1 -Location $MyLOcation

#new storage account
New-AzureRmStorageAccount -ResourceGroupName $dscStorageAccountRG -AccountName $dscStorageAccount -Location $MyLOcation -SkuName Standard_GRS 
New-AzureRmStorageAccount -ResourceGroupName $dscStorageAccountRG -AccountName $dscStorageAccount1 -Location $MyLOcation -SkuName Standard_GRS 



#create blob in storage accoun
Publish-AzureRmVMDscConfiguration -ConfigurationPath $ParametersFilePathTask7DSC `
-ResourceGroupName $dscStorageAccountRG -StorageAccountName $dscStorageAccount -Force

$key = ((Get-AzureRMStorageAccountKey -ResourceGroupName $dscStorageAccountRG -Name $dscStorageAccount) | where {$_.KeyName -Like 'key1'}).Value
$ctx = New-AzureStorageContext -StorageAccountName $dscStorageAccount -StorageAccountKey $key
$sasToken = New-AzureStorageBlobSASToken -Container "windows-powershell-dsc" -Blob $dscName -Permission rwl `
-ExpiryTime ([DateTime]::Now.AddHours(24.0)) -FullUri -Context $ctx

$Secure_String_sasToken= ConvertTo-SecureString $sasToken -AsPlainText -Force
$Secure_String_Pwd = ConvertTo-SecureString "Administrator1" -AsPlainText -Force


$ran=get-random
$vault = 'vaultName'+$ran



New-AzureRmResourceGroupDeployment -ResourceGroupName $dscStorageAccountRG `
   -TemplateUri https://raw.githubusercontent.com/daniilkorytko/Task7/master/Task7.1.json `
   -TemplateParameterFile $ParametersFilePathTask7 `
   -AdminPassword $Secure_String_Pwd -vaultName $vault -DSC $Secure_String_sasToken -Verbose

$vaultName = get-AzureRmRecoveryServicesVault -ResourceGroupName $dscStorageAccountRG | where{$_.Name -like $vault}

Set-AzureRmRecoveryServicesVaultContext -Vault $vaultName

$Container = Get-AzureRmRecoveryServicesBackupContainer -ContainerType "AzureVM" -Status "Registered" -FriendlyName 'MyVmTask4' 

$BackupItem = Get-AzureRmRecoveryServicesBackupItem -Container $Container -WorkloadType "AzureVM"

$Backup = Backup-AzureRmRecoveryServicesBackupItem -Item $BackupItem


Write-Host "Waiting for backup complete"
do {
    $job = Get-AzureRmRecoveryservicesBackupJob –Status "InProgress"
    start-sleep -seconds 30
    Write-Host -NoNewline ">"
} while ($job) 


$rp = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $backupitem 
$restore = Restore-AzureRmRecoveryServicesBackupItem -RecoveryPoint $rp[0] -StorageAccountName $dscStorageAccount1 -StorageAccountResourceGroupName $dscStorageAccountRG


Write-Host "Waiting for restore complete"
do {
    $job = Get-AzureRmRecoveryservicesBackupJob –Status "InProgress"
    start-sleep -seconds 30
    Write-Host -NoNewline ">"
} while ($job) 

$restore





$storageAccount = get-AzureRmStorageAccount -ResourceGroupName $dscStorageAccountRG | where{$_.StorageAccountName -eq $dscStorageAccount1}

$ctx = $storageAccount.Context

$container = Get-AzureRmStorageContainer -ResourceGroupName $dscStorageAccountRG  -StorageAccountName $storageAccount.StorageAccountName 


$vm_Name = (Get-AzureStorageBlob -Container ($container.Name) -Context $ctx).ICloudBlob.Uri.AbsoluteUri

foreach ($item in $vm_Name) {
    if (($item -like '*vhd') -and ($item -like '*osdisk*')) {
        $osDisk = $item 
    }elseif (($item -like '*vhd') -and ($item -like '*datadisk*')) {
        $dataDisk = $item     
    }
}

New-AzureRmResourceGroupDeployment -ResourceGroupName $dscStorageAccountRG1 `
   -TemplateUri https://raw.githubusercontent.com/daniilkorytko/Task7/master/Task7Restore.json `
   -TemplateParameterFile $ParametersFilePathTask7restore `
   -idosDisk $osDisk -iddataDisks $dataDisk -Verbose

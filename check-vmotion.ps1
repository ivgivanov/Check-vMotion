Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue

$vCenter = Read-Host -prompt "Enter vCenter Server instance"

Connect-VIServer -server $vCenter

$CSVObjects = @()
$Results = @()
$err = @()
$destpath = [Environment]::GetFolderPath("Desktop")
$ClusterName = Read-Host -prompt "Enter cluster name"
$hosts = Get-VMHost -Location $ClusterName | Where {$_.ConnectionState -eq "Connected"} | Sort Name

while($confirmNetTest -ne "y") {
	$confirmNetTest = Read-Host -prompt "Do you want to perform vMotion network test? This will migrate specified VM across the hosts ensuring the network connectivity (y/n)"
	If ($confirmNetTest -eq "n") {break}
	}

If ($confirmNetTest -eq "y") {
		$TestVMName = Read-Host -prompt "Enter test VM name"
		while ($TestVM -eq $null) {
		$TestVM = Get-VM -Name $TestVMName -ErrorAction SilentlyContinue
			If ($TestVM -eq $null) {$TestVMName = Read-Host "No such VM. Please provide VM name"}
		}
}

$IsTestVMAffected = 0

$viewSI = Get-View 'ServiceInstance'
$viewVmProvChecker = Get-View $viewSI.Content.VmProvisioningChecker

for($i=0; $i -le $hosts.GetUpperBound(0); $i++){

	$vms = Get-VM -Location $hosts[$i]

	$o = $i+1
	If ($i -eq $hosts.GetUpperBound(0)) { $o = 0}

	Write-Host "Testing VM vMotion compatibility between" $hosts[$i] "and" $hosts[$o]

	foreach($vm in $vms){

		$Results = $viewVmProvChecker.QueryVMotionCompatibilityEx($vm.Id, $hosts[$o].Id)
			foreach ($Record in $Results) {
				If ($Record.Error -ne $null) {
				   foreach ($Error in $Record.Error) {
					$CSVObject = new-object PSObject
					$CSVObject | add-member -membertype NoteProperty -name "VM" -value $Record.VM
					If ($Record.VM -eq $TestVM.Id) {$IsTestVMAffected = 1} 
					$CSVObject | add-member -membertype NoteProperty -name "VMHost" -value $Record.Host
					$CSVObject | add-member -membertype NoteProperty -name "Error" -value $Error.LocalizedMessage
					$CSVObjects += $CSVObject
				   }					
				}
			}

	}

}

If ($confirmNetTest -eq "y") {
	If ($IsTestVMAffected -eq 0) {
	Write-Host "Testing vMotion network connectivity by migrating" $TestVM "across the hosts in" $ClusterName
	$InitialVMHost = $TestVM.VMHost
		for ($i=0; $i -le $hosts.GetUpperBound(0); $i++) {
				If ($i -eq $hosts.GetUpperBound(0)) {
				$DestHost = $hosts[0]
				} else { $DestHost = $hosts[$i+1] }
			
			Move-VM -VM $TestVM -Destination $DestHost -ErrorVariable +err 2>> $destpath\vMotionNetTest.txt | out-null
		}	
		If ($err.count -eq 0) {Write-Output "Network test completed successfully" >> $destpath\vMotionNetTest.txt}
		If ($InitialVMHost -ne $hosts[0]) { Move-VM -VM $TestVM -Destination $InitialVMHost }
	} else { Write-Output "The specified test VM cannot be migrated. Please check vMotionTest.csv file for details" >> $destpath\vMotionNetTest.txt }
}

Disconnect-VIServer -Confirm:$False

If ($CSVObjects.count -eq 0) {
	$CSVObjectNoErr = new-object PSObject
	$CSVObjectNoErr | add-member -membertype NoteProperty -name "Result" -value "No errors found"
	$CSVObjectNoErr | Export-Csv -Path $destpath\vMotionTest.csv -NoTypeInformation
	}
else { $CSVObjects | Export-Csv -Path $destpath\vMotionTest.csv -NoTypeInformation }
Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue

$vCenter = Read-Host -prompt "Enter vCenter Server instance"

Connect-VIServer -server $vCenter

$CSVObjects = @()
$Results = @()
$destpath = [Environment]::GetFolderPath("Desktop")
$ClusterName = Read-Host -prompt "Enter cluster name"
$hosts = Get-VMHost -Location $ClusterName | Where {$_.ConnectionState -eq "Connected"} | Sort Name
$viewSI = Get-View 'ServiceInstance'
$viewVmProvChecker = Get-View $viewSI.Content.VmProvisioningChecker

for($i=0; $i -le $hosts.GetUpperBound(0); $i++){

	$vms = Get-VM -Location $hosts[$i]

	$o = $i+1
	If ($i -eq $hosts.GetUpperBound(0)) { $o = 0}

	Write-Host "Testing vMotion compatibility between" $hosts[$i] "and" $hosts[$o]

	foreach($vm in $vms){

		$Results = $viewVmProvChecker.QueryVMotionCompatibilityEx($vm.Id, $hosts[$o].Id)
			foreach ($Record in $Results) {
				If ($Record.Error -ne $null) {
				   foreach ($Error in $Record.Error) {
					$CSVObject = new-object PSObject
					$CSVObject | add-member -membertype NoteProperty -name "VM" -value $Record.VM
					$CSVObject | add-member -membertype NoteProperty -name "VMHost" -value $Record.Host
					$CSVObject | add-member -membertype NoteProperty -name "Error" -value $Error.LocalizedMessage
					$CSVObjects += $CSVObject
				   }					
				}
			}

	}

}

Disconnect-VIServer -Confirm:$False

If ($CSVObjects.count -eq 0) {
	$CSVObjectNoErr = new-object PSObject
	$CSVObjectNoErr | add-member -membertype NoteProperty -name "Result" -value "No errors found"
	$CSVObjectNoErr | Export-Csv -Path $destpath\vMotionTest.csv -NoTypeInformation
	}
else { $CSVObjects | Export-Csv -Path $destpath\vMotionTest.csv -NoTypeInformation }
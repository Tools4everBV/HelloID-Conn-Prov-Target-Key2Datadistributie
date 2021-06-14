$config = $configuration | ConvertFrom-Json;
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json;
$mRef = $managerAccountReference | ConvertFrom-Json;
$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];


$DataSource = $config.dataSource
$Username = $config.username
$Password = $config.password

$OracleConnectionString = "User Id=$Username;Password=$Password;Data Source=$DataSource"

if(-Not($dryRun -eq $True)) {
    try{
		$null =[Reflection.Assembly]::LoadWithPartialName("System.Data.OracleClient")

		#check correlation before create
        $OracleConnection = New-Object System.Data.OracleClient.OracleConnection($OracleConnectionString)
        $OracleConnection.Open()
        Write-Verbose -Verbose "Successfully connected Oracle to database '$DataSource'" 
		
		$OracleQueryUpdate = "DELETE FROM DDS_GEBRUIKER_APPLICATIE WHERE GEBRUIKERNR = '$aRef' AND APPLICATIENR = 1";
	
		Write-Verbose -Verbose $OracleQueryUpdate
		
        $OracleCmd = $OracleConnection.CreateCommand()
		$OracleCmd.CommandText = $OracleQueryUpdate
		$OracleCmd.ExecuteNonQuery() | Out-Null

        $OracleQueryUpdate = "DELETE FROM DDS_GEBRUIKER_PROFIEL WHERE GEBRUIKERNR = '$aRef' AND (PROFIELNR = 1 OR PROFIELNR = 2 OR PROFIELNR = 7)";
	
		Write-Verbose -Verbose $OracleQueryUpdate
		
        $OracleCmd = $OracleConnection.CreateCommand()
		$OracleCmd.CommandText = $OracleQueryUpdate
		$OracleCmd.ExecuteNonQuery() | Out-Null
			
		Write-Verbose -Verbose "Successfully performed Oracle update query."

		$success = $True;
		$auditMessage = " succesfully";   
    } catch {
        Write-Error $_
    }finally{
        if($OracleConnection.State -eq "Open"){
            $OracleConnection.close()
        }
        Write-Verbose -Verbose "Successfully disconnected from Oracle database '$DataSource'"
    }
}

$success = $True;
$auditLogs.Add([PSCustomObject]@{
    # Action = "CreateAccount"; Optionally specify a different action for this audit log
    Message = "Created account with username $($account.userName)";
    IsError = $False;
});

# Send results
$result = [PSCustomObject]@{
	Success= $success;
	AuditLogs = $auditLogs;
    Account = $account;
};
Write-Output $result | ConvertTo-Json -Depth 10;

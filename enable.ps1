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
		
        $OracleCmd = $OracleConnection.CreateCommand()

		$OracleQuery = "
                      MERGE INTO DDS_GEBRUIKER_APPLICATIE t1
						  USING
						  	(SELECT DISTINCT
									'$aRef' AS GEBRUIKERNR,
									1 AS APPLICATIENR
							 FROM DDS_GEBRUIKER_APPLICATIE) t2
						  ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.APPLICATIENR = t2.APPLICATIENR)
					  WHEN NOT MATCHED THEN
					  	INSERT VALUES (t2.GEBRUIKERNR, t2.APPLICATIENR)";
	
		Write-Verbose -Verbose $OracleQuery
		       
		$OracleCmd.CommandText = $OracleQuery
		$OracleCmd.ExecuteNonQuery() | Out-Null

       $OracleQuery2 = "
                      MERGE INTO DDS_GEBRUIKER_PROFIEL t1
						  USING
						  	(SELECT DISTINCT
									'$aRef' AS GEBRUIKERNR,
									1 AS PROFIELNR
							 FROM DDS_GEBRUIKER_PROFIEL) t2
						  ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.PROFIELNR = t2.PROFIELNR)
					  WHEN NOT MATCHED THEN
					  	INSERT VALUES (t2.GEBRUIKERNR, t2.PROFIELNR)";
	
		Write-Verbose -Verbose $OracleQuery2
		       
		$OracleCmd.CommandText = $OracleQuery2
		$OracleCmd.ExecuteNonQuery() | Out-Null

        $OracleQuery3 = "
                      MERGE INTO DDS_GEBRUIKER_PROFIEL t1
						  USING
						  	(SELECT DISTINCT
									'$aRef' AS GEBRUIKERNR,
									2 AS PROFIELNR
							 FROM DDS_GEBRUIKER_PROFIEL) t2
						  ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.PROFIELNR = t2.PROFIELNR)
					  WHEN NOT MATCHED THEN
					  	INSERT VALUES (t2.GEBRUIKERNR, t2.PROFIELNR)";
	
		Write-Verbose -Verbose $OracleQuery3
		       
		$OracleCmd.CommandText = $OracleQuery3
		$OracleCmd.ExecuteNonQuery() | Out-Null

        $OracleQuery4 = "
                      MERGE INTO DDS_GEBRUIKER_PROFIEL t1
						  USING
						  	(SELECT DISTINCT
									'$aRef' AS GEBRUIKERNR,
									7 AS PROFIELNR
							 FROM DDS_GEBRUIKER_PROFIEL) t2
						  ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.PROFIELNR = t2.PROFIELNR)
					  WHEN NOT MATCHED THEN
					  	INSERT VALUES (t2.GEBRUIKERNR, t2.PROFIELNR)";
	
		Write-Verbose -Verbose $OracleQuery4
		       
		$OracleCmd.CommandText = $OracleQuery4
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

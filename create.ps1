$config = $configuration | ConvertFrom-Json;
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

$oracleUsername = $p.Accounts.OracleKey2DD.USERNAME

$DataSource = $config.dataSource
$Username = $config.username
$Password = $config.password

$OracleConnectionString = "User Id=$Username;Password=$Password;Data Source=$DataSource"

$displayname = ""

$prefix = ""
if(-Not([string]::IsNullOrEmpty($p.Name.FamilyNamePrefix)))
{
    $prefix = $p.Name.FamilyNamePrefix + " "
    $prefixEnd = " " + $p.Name.FamilyNamePrefix
}

$partnerprefix = ""
if(-Not([string]::IsNullOrEmpty($p.Name.FamilyNamePartnerPrefix)))
{
    $partnerprefix = $p.Name.FamilyNamePartnerPrefix + " "
    $partnerprefixEnd = " " + $p.Name.FamilyNamePartnerPrefix
}

switch($p.Name.Convention)
{
    "B" {$displayname += $p.Name.FamilyName + ", " + $p.Name.NickName + $prefixEnd}
    "P" {$displayname += $p.Name.FamilyNamePartner + ", " + $p.Name.NickName + $partnerprefixEnd}
    "BP" {$displayname += $p.Name.FamilyName + " - " + $partnerprefix + $p.Name.FamilyNamePartner + ", " + $p.Name.NickName + $prefixEnd}
    "PB" {$displayname += $p.Name.FamilyNamePartner + " - " + $prefix + $p.Name.FamilyName + ", " + $p.Name.NickName + $partnerprefixEnd}
    default {$displayname += $p.Name.FamilyName + ", " + $p.Name.NickName + $prefixEnd}
}

# Change mapping here
$account = [PSCustomObject]@{
    GEBRUIKERNR						= "";
    GEBRUIKERNAAM					= $displayname;
    ORACLE_USER						= $oracleUsername;
    LOGO						    = "";
    RSS							    = "";
};

if(-Not($dryRun -eq $True)) {
    try{
		$null =[Reflection.Assembly]::LoadWithPartialName("System.Data.OracleClient")

		$OracleConnection = New-Object System.Data.OracleClient.OracleConnection($OracleConnectionString)
        $OracleConnection.Open()
        Write-Verbose -Verbose "Successfully connected Oracle to database '$DataSource'" 

        #Controleer of oracle user al een GEBRUIKERSNR heeft
        $OracleCmd = $OracleConnection.CreateCommand()
        $OracleQuery = "SELECT GEBRUIKERNR FROM DDS_GEBRUIKER WHERE ORACLE_USER = '$($account.ORACLE_USER)'"
        $OracleCmd.CommandText = $OracleQuery

        $OracleAdapter = New-Object System.Data.OracleClient.OracleDataAdapter($cmd)
        $OracleAdapter.SelectCommand = $OracleCmd;

        $DataSet = New-Object system.Data.DataSet
        $null = $OracleAdapter.fill($DataSet)

        $result = $DataSet.Tables[0] | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors;
            
        Write-Verbose -Verbose "Successfully performed Oracle '$OracleQuery'. Returned [$($DataSet.Tables[0].Columns.Count)] columns and [$($DataSet.Tables[0].Rows.Count)] rows"
                
        $rowcount = $($DataSet.Tables[0].Rows.Count)
            
        if($rowcount -ne 0){    
            $account.GEBRUIKERNR = $account.GEBRUIKERNR
        }
        else
        {
            $OracleQuery = "SELECT DDS_GEBRUIKER_SEQ.NEXTVAL FROM dual"
            $OracleCmd.CommandText = $OracleQuery

            $OracleAdapter.SelectCommand = $OracleCmd;

            $DataSet = New-Object system.Data.DataSet
            $null = $OracleAdapter.fill($DataSet)

            $result = $DataSet.Tables[0] | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors;
            $account.GEBRUIKERNR = $result.NEXTVAL
        }
                    
        $OracleQuery1 = "		
            MERGE INTO DDS_GEBRUIKER t1
                USING
                (SELECT DISTINCT
                        '$($account.GEBRUIKERNR)' AS GEBRUIKERNR,
                        '$($account.ORACLE_USER)' AS ORACLE_USER,
                        '$($account.GEBRUIKERNAAM)' AS GEBRUIKERNAAM,
                        '' AS LOGO,
                        '' AS RSS
                    FROM DDS_GEBRUIKER) t2
                ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.ORACLE_USER = t2.ORACLE_USER)
            WHEN NOT MATCHED THEN
            INSERT VALUES (t2.GEBRUIKERNR, t2.ORACLE_USER, t2.GEBRUIKERNAAM, t2.LOGO, t2.RSS)"

        Write-Verbose -Verbose $OracleQuery1
        
        $OracleCmd.CommandText = $OracleQuery1
        $OracleCmd.ExecuteNonQuery() | Out-Null
        
        $OracleQuery2 = "		
            MERGE INTO DDS_GEBRUIKER_APPLICATIE t1
                USING
                (SELECT DISTINCT
                        '$($account.GEBRUIKERNR)' AS GEBRUIKERNR,
                        1 AS APPLICATIENR
                    FROM DDS_GEBRUIKER_APPLICATIE) t2
                ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.APPLICATIENR = t2.APPLICATIENR)
            WHEN NOT MATCHED THEN
            INSERT VALUES (t2.GEBRUIKERNR, t2.APPLICATIENR)"

        Write-Verbose -Verbose $OracleQuery2
        
        $OracleCmd.CommandText = $OracleQuery2
        $OracleCmd.ExecuteNonQuery() | Out-Null
        
        $OracleQuery3 = "		
            MERGE INTO DDS_GEBRUIKER_PROFIEL t1
                USING
                (SELECT DISTINCT
                        '$($account.GEBRUIKERNR)' AS GEBRUIKERNR,
                        1 AS PROFIELNR
                    FROM DDS_GEBRUIKER_PROFIEL) t2
                ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.PROFIELNR = t2.PROFIELNR)
            WHEN NOT MATCHED THEN
            INSERT VALUES (t2.GEBRUIKERNR, t2.PROFIELNR)"

        Write-Verbose -Verbose $OracleQuery3
        
        $OracleCmd.CommandText = $OracleQuery3
        $OracleCmd.ExecuteNonQuery() | Out-Null
        
        $OracleQuery4 = "		
            MERGE INTO DDS_GEBRUIKER_PROFIEL t1
                USING
                (SELECT DISTINCT
                        '$($account.GEBRUIKERNR)' AS GEBRUIKERNR,
                        2 AS PROFIELNR
                    FROM DDS_GEBRUIKER_PROFIEL) t2
                ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.PROFIELNR = t2.PROFIELNR)
            WHEN NOT MATCHED THEN
            INSERT VALUES (t2.GEBRUIKERNR, t2.PROFIELNR)"

        Write-Verbose -Verbose $OracleQuery4
        
        $OracleCmd.CommandText = $OracleQuery4
        $OracleCmd.ExecuteNonQuery() | Out-Null
        
        $OracleQuery5 = "		
            MERGE INTO DDS_GEBRUIKER_PROFIEL t1
                USING
                (SELECT DISTINCT
                        '$($account.GEBRUIKERNR)' AS GEBRUIKERNR,
                        7 AS PROFIELNR
                    FROM DDS_GEBRUIKER_PROFIEL) t2
                ON (t1.GEBRUIKERNR = t2.GEBRUIKERNR AND t1.PROFIELNR = t2.PROFIELNR)
            WHEN NOT MATCHED THEN
            INSERT VALUES (t2.GEBRUIKERNR, t2.PROFIELNR)"

        Write-Verbose -Verbose $OracleQuery5
        
        $OracleCmd.CommandText = $OracleQuery5
        $OracleCmd.ExecuteNonQuery() | Out-Null

        Write-Verbose -Verbose "Successfully performed Oracle creation queries."

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
	AccountReference= $account.GEBRUIKERNR;
	AuditLogs = $auditLogs;
    Account = $account;

    # Optionally return data for use in other systems
    ExportData = [PSCustomObject]@{
        GEBRUIKERNR = $account.GEBRUIKERNR;
        ORACLE_USER = $account.ORACLE_USER;
    };
    
};
Write-Output $result | ConvertTo-Json -Depth 10;

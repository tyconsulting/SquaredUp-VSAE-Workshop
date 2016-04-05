#=================================================================
# AUTHOR:           Tao Yang
# Script Name:      GetDBEngineLongRunningQueries.ps1
# DATE:             28/09/2015
# Version:          1.0
# COMMENT:          - Script to get the long running queries on a SQL DB Engine
#==============================================================
Param ([string]$ConnectionString, [String]$TCPPort, [int]$TopN, [int]$SQLQueryTimeoutSeconds)

$SQLQuery = @"
SELECT TOP $TopN creation_time 
        ,last_execution_time
        ,total_physical_reads
        ,total_logical_reads 
        ,total_logical_writes
        , execution_count
        , total_worker_time
        , total_elapsed_time
        , total_elapsed_time / execution_count avg_elapsed_time
        ,SUBSTRING(st.text, (qs.statement_start_offset/2) + 1,
         ((CASE statement_end_offset
          WHEN -1 THEN DATALENGTH(st.text)
          ELSE qs.statement_end_offset END
            - qs.statement_start_offset)/2) + 1) AS statement_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY total_elapsed_time / execution_count DESC;
"@
#Connect to the DB engine
If ($TCPPort -ne $NULL -AND $TCPPort -ne 0)
{
    $conString = "Server`=$ConnectionString,$TCPPort;Integrated Security=true;Initial Catalog=master"
} else {
    $conString = "Server`=$ConnectionString;Integrated Security=true;Initial Catalog=master"
}

Write-Output "Connection String: '$conString'"
#Write-Output $SQLQuery
$SQLCon = New-Object System.Data.SqlClient.SqlConnection
$SQLCon.ConnectionString = $conString
$SQLCon.Open()

#execute SQL queries
$sqlCmd = $SQLCon.CreateCommand()
$sqlCmd.CommandTimeout=$SQLQueryTimeoutSeconds
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter

#Alert Staging table
$sqlCmd.CommandText = $SQLQuery
$SqlAdapter.SelectCommand = $sqlCmd
$DataSet = New-Object System.Data.DataSet
$SqlAdapter.Fill($DataSet) | Out-Null

#Close SQL Connection
$SQLCon.Close()

#Process result
$arrSQLResult = New-Object System.Collections.ArrayList

Foreach ($set in $DataSet.Tables[0])
{
    $objDS = New-object psobject
    Foreach ($objProperty in (Get-member -InputObject $set -MemberType Property))
    {
        $PropertyName = $objProperty.Name
        Add-Member -InputObject $objDS -MemberType NoteProperty -Name $PropertyName -Value $set.$PropertyName
    }
    [void]$arrSQLResult.Add($objDS)
}
Write-Output "Top $TopN Long Running Queries in the DB Engine:"
Write-Output "------------------------------------"
Foreach ($item in $arrSQLResult)
{
    Write-Output $item
    Write-Output "------------------------------------"
    Write-Output ""
}

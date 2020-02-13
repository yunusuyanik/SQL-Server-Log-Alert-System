
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_DailyChecker') IS NULL EXEC ('CREATE PROCEDURE dbo.usp_DailyChecker AS RETURN 0;');
GO
ALTER PROC [dbo].usp_DailyChecker 
AS
/* 
Version 1.1
Date : 02.01.2020
Written by : 
Yunus UYANIK and Buğrahan Bol(%1).
Silikon Akademi

www.silikonakademi.com
www.yunusuyanik.com
*/

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..##temp_DailyChecker') IS NOT NULL
	DROP TABLE ##temp_DailyChecker;
CREATE TABLE ##temp_DailyChecker 
(Id int identity(1,1),
Priority int,
CheckGroup VARCHAR(250),
CheckSubGroup VARCHAR(1000),
DatabaseName VARCHAR(250),
Details VARCHAR(max),
Details2 VARCHAR(max),
Comment VARCHAR(max))

DECLARE @sqlrestarttime VARCHAR(100) = (SELECT CONVERT(VARCHAR(100),create_date,120) FROM sys.databases where database_id=2)

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
VALUES (-1,'Daily Checker',NULL,NULL,CONVERT(VARCHAR(100),GETDATE(),120)+' tarihinde çalıştırılmıştır.','Son SQL Restart tarihi : '+@sqlrestarttime)

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
SELECT  
	0,
	'ComputerName : '+CONVERT(VARCHAR(100),SERVERPROPERTY('MachineName')),
	'InstanceName : '+CONVERT(VARCHAR(100),SERVERPROPERTY('ServerName')),  
	'Edition : '+CONVERT(VARCHAR(100),SERVERPROPERTY('Edition')),
	'ProductVersion : '+CONVERT(VARCHAR(100),SERVERPROPERTY('ProductVersion')),  
	'ProductLevel: '+CONVERT(VARCHAR(100),SERVERPROPERTY('ProductLevel'));  

/***************************************************************
****************** Backup Operations
***************************************************************/

Print 'Backup operation processing...'

IF OBJECT_ID('tempdb..#tmp_BackupDetails') IS NOT NULL
	DROP TABLE #tmp_BackupDetails;
SELECT  
	d.database_id,
    [database_name] = d.name, 
    [last_backup_date] = (MAX(backup_finish_date)),
    backup_size_mb=CAST(COALESCE(MAX(bs.backup_size),0)/1024.00/1024.00 AS NUMERIC(18,2)),
    avg_backup_duration_sec= AVG(CAST(DATEDIFF(s, bs.backup_start_date, bs.backup_finish_date) AS int)),
    bs.type
	INTO #tmp_BackupDetails
FROM sys.databases d WITH (NOLOCK) 
LEFT JOIN msdb.dbo.backupset bs WITH (NOLOCK) 
        ON bs.database_name = d.name 
            AND bs.is_copy_only = 0
    WHERE d.name NOT IN ('tempdb','distribution') AND bs.type IN ('D','L') AND d.state=0
GROUP BY d.database_id,d.Name, bs.type

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
SELECT 
	Priority = 1, 
	CheckGroup = 'Backup',
	CheckSubGroup = CASE WHEN type='D' THEN 'Full Backup Operations' WHEN type='L' THEN 'Log Backup Operations' WHEN type IS NULL THEN 'Warning Backup Operations' END ,
	DatabaseName = [database_name] ,
	Details=
		CASE 
			WHEN last_backup_date IS NOT NULL AND type='D' THEN 
			'Son Backup tarihi : '+CONVERT(VARCHAR(100),last_backup_date,120) 
			WHEN last_backup_date IS NULL THEN '! veritabanına ait backup yoktur.'
			WHEN last_backup_date < GETDATE()-3 AND type='D' THEN '! Son 3 gündür FULL backup yoktur.'
			WHEN last_backup_date IS NOT NULL AND type='L' THEN 
			'Son Log Backup tarihi : '+CONVERT(VARCHAR(100),last_backup_date,120)+'. '+CAST(backup_size_mb AS VARCHAR(20))
			WHEN last_backup_date IS NULL AND type='L' THEN '! veritabanına ait LOG backup yoktur.'
			WHEN last_backup_date < GETDATE()-1 AND type='L' THEN '! Son 1 gündür LOG backup yoktur.'
		END,
	Details2 = CAST(backup_size_mb AS VARCHAR(20))+' MB backup '+CAST(avg_backup_duration_sec AS VARCHAR(20))+' saniye sürmüştür.'
FROM #tmp_BackupDetails 
ORDER BY database_id

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details)
SELECT 1 Priority, 'Backup' CheckGroup,'FULL Recovery Model & Log Backup Operations' CheckSubGroup,name DatabaseName,
'! Recovery Model FULL olmasına rağmen LOG backup yoktur. ' Details
FROM sys.databases WITH (NOLOCK) WHERE database_id NOT IN (SELECT database_id FROM #tmp_BackupDetails WHERE type='L')
AND recovery_model=1

/***************************************************************
****************** Disk Operations
***************************************************************/

Print 'Disk operation processing...'

;WITH cte_DiskInfo
AS (
	SELECT 
		tab.volume_mount_point,
		tab.total_bytes_gb,
		tab.available_bytes_gb,
		tab.free_size_percent,
		ReadLatency = CASE WHEN num_of_reads = 0 THEN 0 ELSE (io_stall_read_ms/num_of_reads) END,
		WriteLatency = CASE WHEN num_of_writes = 0 THEN 0 ELSE (io_stall_write_ms/num_of_writes) END,
		Latency = CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE (io_stall/(num_of_reads + num_of_writes)) END
	FROM (
			SELECT 
				SUM(num_of_reads) AS num_of_reads,
				SUM(io_stall_read_ms) AS io_stall_read_ms, 
				SUM(num_of_writes) AS num_of_writes,
				SUM(io_stall_write_ms) AS io_stall_write_ms, 
				SUM(num_of_bytes_read) AS num_of_bytes_read,
				SUM(num_of_bytes_written) AS num_of_bytes_written, 
				SUM(io_stall) AS io_stall, 
				MAX(vs.volume_mount_point) as volume_mount_point,
				MAX(vs.total_bytes)/1024/1024/1024 as total_bytes_gb,
				MAX(vs.available_bytes)/1024/1024/1024 as available_bytes_gb,
				CAST(MAX(vs.available_bytes) * 100.0 / MAX(vs.total_bytes) AS DECIMAL(5, 2)) as free_size_percent
			FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
				INNER JOIN sys.master_files AS mf WITH (NOLOCK)
				ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
				CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.[file_id]) AS vs 
				GROUP BY vs.volume_mount_point
		) AS tab
)
INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,Details,Details2)
SELECT 
	DISTINCT 
	Priority = 2, 
	CheckGroup = 'Disk Size & Latency Info',
	CheckSubGroup = 'Disk Letter : '+volume_mount_point,
	Details = 'Size (GB) : '+CONVERT(VARCHAR(100),total_bytes_gb)+' ,Free Size (GB) : '+CONVERT(VARCHAR(100),available_bytes_gb)+
	' (%'+CONVERT(VARCHAR(10),free_size_percent)+')',
	Details2 = 'ReadLatency : '+CONVERT(VARCHAR(100),ReadLatency)+' - WriteLatency : '+CONVERT(VARCHAR(100),WriteLatency)+' - Latency : '+CONVERT(VARCHAR(100),Latency)
FROM cte_DiskInfo


/***************************************************************
****************** VLF Count
***************************************************************/

Print 'VLF check operation processing...'

IF OBJECT_ID('tempdb..#VLFInfo') IS NOT NULL
	DROP TABLE #VLFInfo;
IF OBJECT_ID('tempdb..#VLFCountResults') IS NOT NULL
	DROP TABLE #VLFCountResults;
CREATE TABLE #VLFInfo (RecoveryUnitID int, FileID  int,
					   FileSize bigint, StartOffset bigint,
					   FSeqNo      bigint, [Status]    bigint,
					   Parity      bigint, CreateLSN   numeric(38));
	 
CREATE TABLE #VLFCountResults(DatabaseName sysname, VLFCount int);
	 
EXEC sp_MSforeachdb N'Use [?]; 

				INSERT INTO #VLFInfo 
				EXEC sp_executesql N''DBCC LOGINFO([?])''; 
	 
				INSERT INTO #VLFCountResults 
				SELECT DB_NAME(), COUNT(*) 
				FROM #VLFInfo; 

				TRUNCATE TABLE #VLFInfo;'
	 

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
SELECT 
	Priority = 3, 
	CheckGroup = 'VLF Count',
	CheckSubGroup = 'VLF Count Bigger Than 50',
	DatabaseName,
	Details = 'VLF Count : '+ CONVERT(VARCHAR(100),VLFCount),
	Details2 = NULL
FROM #VLFCountResults WHERE VLFCount >= 50
ORDER BY DatabaseName




/***************************************************************
****************** Data Corruption
***************************************************************/

Print 'Data Corruption Check processing...'

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
SELECT 
	Priority = 4, 
	CheckGroup = 'Data Corruption',
	CheckSubGroup = 'Suspect Pages',
	DatabaseName = DB_NAME([database_id]),
	Details = 'Page : '+CONVERT(VARCHAR(100),[database_id])+':'+CONVERT(VARCHAR(100),[file_id])+':'+CONVERT(VARCHAR(100),[page_id]),
	Details2 = '' +
	CASE WHEN event_type = 1 THEN 'An 823 error that causes a suspect page (such as a disk error) or an 824 error other than a bad checksum or a torn page (such as a bad page ID).'
	WHEN event_type = 2 THEN 'Bad checksum.'
	WHEN event_type = 3 THEN 'Torn page.'
	WHEN event_type = 4 THEN 'Restored (page was restored after it was marked bad).'
	WHEN event_type = 5 THEN 'Repaired (DBCC repaired the page).'
	WHEN event_type = 7 THEN 'Deallocated by DBCC.' END +
	' Error Count : '+CONVERT(VARCHAR(100),[error_count])+ ' Last Update Date : '+CONVERT(VARCHAR(100),[last_update_date])
	--Script eklenecek dbcc checkdb
FROM msdb.dbo.suspect_pages WITH (NOLOCK)
ORDER BY database_id

/***************************************************************
****************** Memory information
***************************************************************/

Print 'Memory information check processing...'

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
SELECT 
	Priority = 5, 
	CheckGroup = 'Memory',
	CheckSubGroup = 'SQL Server Memory',
	DatabaseName = NULL,
	Details = 'SQL Server Memory Usage (MB) : '+CONVERT(VARCHAR(100),(physical_memory_in_use_kb/1024))+' ,Memory Utilizastion (%) : '+CONVERT(VARCHAR(100),memory_utilization_percentage),
	Details2 = 'Lock Pages (MB) : '+CONVERT(VARCHAR(100),(locked_page_allocations_kb/1024))
FROM sys.dm_os_process_memory WITH (NOLOCK) 
UNION ALL

SELECT 
	Priority = 5, 
	CheckGroup = 'Memory',
	CheckSubGroup = 'OS Memory and Pressure',
	DatabaseName = NULL,
	Details = 'Physical Memory (MB) : '+CONVERT(VARCHAR(100),(total_physical_memory_kb/1024)),
	Details2 = 'system_memory_state_desc : '+system_memory_state_desc
FROM sys.dm_os_sys_memory WITH (NOLOCK) 


/***************************************************************
****************** Worker Info
***************************************************************/

IF OBJECT_ID('tempdb..#temp_Scheduler') IS NOT NULL
	DROP TABLE #temp_Scheduler;
SELECT 
	AVG(current_tasks_count) current_tasks_count, 
	AVG(work_queue_count) work_queue_count,
	AVG(runnable_tasks_count) runnable_tasks_count,
	AVG(pending_disk_io_count) pending_disk_io_count
INTO #temp_Scheduler
FROM sys.dm_os_schedulers WITH (NOLOCK)
WHERE scheduler_id < 255

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
SELECT 
	Priority = 6, 
	CheckGroup = 'Worker Info',
	CheckSubGroup = 'CPU or Disk Pressure',
	DatabaseName = NULL,
	Details = '! runnable_tasks_count : '+CONVERT(VARCHAR(100),[runnable_tasks_count])+', pending_disk_io_count :'+CONVERT(VARCHAR(100),[pending_disk_io_count]),
	Details2 = 'current_tasks_count : '+CONVERT(VARCHAR(100),[current_tasks_count])+', work_queue_count :'+CONVERT(VARCHAR(100),[work_queue_count])
FROM #temp_Scheduler
WHERE (runnable_tasks_count>3 OR pending_disk_io_count>3);



/***************************************************************
****************** CPU Info
***************************************************************/

IF OBJECT_ID('tempdb..#temp_CPUInfo') IS NOT NULL
	DROP TABLE #temp_CPUInfo;
DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info WITH (NOLOCK)) 

;WITH cte_CPUInfo
AS (
SELECT TOP(256) SQLProcessUtilization AS [SQLServerProcessCPUUtilization], 
               100 - SystemIdle - SQLProcessUtilization AS [OtherProcessCPUUtilization]
FROM (SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, 
			record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
			AS [SystemIdle], 
			record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') 
			AS [SQLProcessUtilization], [timestamp] 
	  FROM (SELECT [timestamp], CONVERT(xml, record) AS [record] 
			FROM sys.dm_os_ring_buffers WITH (NOLOCK)
			WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
			AND record LIKE N'%<SystemHealth>%') AS x) AS y )

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2)
SELECT 
	Priority = 6, 
	CheckGroup = 'CPU',
	CheckSubGroup = 'AVG CPU Values (Last 256 Min)',
	DatabaseName = NULL,
	Details = 'SQL Server Process CPU Utilization : '+CONVERT(VARCHAR(100),AVG([SQLServerProcessCPUUtilization])),
	Details2 = ' Other Process CPU Utilization : '+CONVERT(VARCHAR(100),AVG([OtherProcessCPUUtilization]))
FROM cte_CPUInfo



/***************************************************************
****************** Performans Counters Info
***************************************************************/

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2,Comment)
SELECT 
	Priority = 7, 
	CheckGroup = 'Counters',
	CheckSubGroup = 'Page life expectancy',
	DatabaseName = NULL,
	Details = 'Value : '+CONVERT(VARCHAR(100),[cntr_value]),
	Details2 = NULL,
	Comment = 'If value less than 300, probably you have to optimize your queries which start with using TOP IO or more memory.'
FROM sys.dm_os_performance_counters WITH (NOLOCK)
WHERE [object_name] = 'SQLServer:Buffer Manager' 
AND counter_name = N'Page life expectancy' 
OPTION (RECOMPILE)


--Memory Grants Pending




/***************************************************************
****************** Always On
***************************************************************/

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2,Comment)
SELECT 
	Priority = 10,
	CheckGroup = 'Always On',
	CheckSubGroup = CASE WHEN last_commit_time<DATEADD(MINUTE,-30,GETDATE()) THEN 'Warning - There is delay 30 min' ELSE 'Info' END,
	DatabaseName = DB_NAME(database_id),
	Details = 
	'Last Commit : '+CONVERT(VARCHAR(100),last_commit_time,120)
	+' - Queue Size : '+CONVERT(VARCHAR(100),redo_queue_size),
	Details2 = 
	'Estimated Time : '+ CONVERT(VARCHAR(20),DATEADD(mi,(redo_queue_size/redo_rate/60.0),GETDATE()),120)
	+' - Behind Time : '+CAST(CAST(((DATEDIFF(s,last_commit_time,GetDate()))/3600) as varchar) + ' hour(s), ' + CAST((DATEDIFF(s,last_commit_time,GetDate())%3600)/60 as varchar) + ' min, ' + CAST((DATEDIFF(s,last_commit_time,GetDate())%60) as varchar) + ' sec' as VARCHAR(30))
	,
	Comment = CASE WHEN last_commit_time<DATEADD(MINUTE,-30,GETDATE()) THEN 'If your Queue Size more than 1000, probably you have a transfer issue.' ELSE NULL END
FROM master.sys.dm_hadr_database_replica_states
WHERE last_redone_time is not null and redo_rate>0



/***************************************************************
****************** Deadlock
***************************************************************/

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2,Comment)
SELECT 
	Priority = 11, 
	CheckGroup = 'Lock Info',
	CheckSubGroup = 'Deadlock',
	DatabaseName = NULL,
	Details = 'Number of Deadlocks : '+CONVERT(VARCHAR(100),cntr_value),
	Details2 = NULL,
	Comment = ''
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Number of Deadlocks/sec' AND instance_name = '_Total'

/*
DROP TABLE IF EXISTS #IOWarningResults
CREATE TABLE #IOWarningResults(LogDate datetime, ProcessInfo sysname, LogText varchar(MAX));

	INSERT INTO #IOWarningResults 
	EXEC xp_readerrorlog 0, 1;

SELECT LogDate, ProcessInfo, LogText
FROM #IOWarningResults
WHERE LogText LIKE 'taking longer than 15 seconds'
ORDER BY LogDate DESC;

DROP TABLE #IOWarningResults;




EXEC [usp_DailyChecker]

INSERT INTO ##temp_DailyChecker (Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2,Comment)
SELECT 
	Priority = 3, 
	CheckGroup = '',
	CheckSubGroup = '',
	DatabaseName = '',
	Details = '',
	Details2 = '',
	Comment = ''
FROM 







-- Look for I/O requests taking longer than 15 seconds in the six most recent SQL Server Error Logs (Query 30) (IO Warnings)




-- Missing Indexes for all databases by Index Advantage  (Query 33) (Missing Indexes All Databases)
SELECT CONVERT(decimal(18,2), migs.user_seeks * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01)) AS [index_advantage],
FORMAT(migs.last_user_seek, 'yyyy-MM-dd HH:mm:ss') AS [last_user_seek], 
mid.[statement] AS [Database.Schema.Table],
COUNT(1) OVER(PARTITION BY mid.[statement]) AS [missing_indexes_for_table],
COUNT(1) OVER(PARTITION BY mid.[statement], equality_columns) AS [similar_missing_indexes_for_table],
mid.equality_columns, mid.inequality_columns, mid.included_columns, migs.user_seeks, 
CONVERT(decimal(18,2), migs.avg_total_user_cost) AS [avg_total_user_cost], migs.avg_user_impact 
FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK)
ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK)
ON mig.index_handle = mid.index_handle
ORDER BY index_advantage DESC OPTION (RECOMPILE);




-- Get CPU utilization by database (Query 35) (CPU Usage by Database)
WITH DB_CPU_Stats
AS
(SELECT pa.DatabaseID, DB_Name(pa.DatabaseID) AS [Database Name], SUM(qs.total_worker_time/1000) AS [CPU_Time_Ms]
 FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
 CROSS APPLY (SELECT CONVERT(int, value) AS [DatabaseID] 
              FROM sys.dm_exec_plan_attributes(qs.plan_handle)
              WHERE attribute = N'dbid') AS pa
 GROUP BY DatabaseID)
SELECT ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [CPU Rank],
       [Database Name], [CPU_Time_Ms] AS [CPU Time (ms)], 
       CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPU Percent]
FROM DB_CPU_Stats
WHERE DatabaseID <> 32767 -- ResourceDB
ORDER BY [CPU Rank] OPTION (RECOMPILE);


-- Get I/O utilization by database (Query 36) (IO Usage By Database)
WITH Aggregate_IO_Statistics
AS (SELECT DB_NAME(database_id) AS [Database Name],
    CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) AS [ioTotalMB],
    CAST(SUM(num_of_bytes_read ) / 1048576 AS DECIMAL(12, 2)) AS [ioReadMB],
    CAST(SUM(num_of_bytes_written) / 1048576 AS DECIMAL(12, 2)) AS [ioWriteMB]
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
    GROUP BY database_id)
SELECT ROW_NUMBER() OVER (ORDER BY ioTotalMB DESC) AS [I/O Rank],
        [Database Name], ioTotalMB AS [Total I/O (MB)],
        CAST(ioTotalMB / SUM(ioTotalMB) OVER () * 100.0 AS DECIMAL(5, 2)) AS [Total I/O %],
        ioReadMB AS [Read I/O (MB)], 
		CAST(ioReadMB / SUM(ioReadMB) OVER () * 100.0 AS DECIMAL(5, 2)) AS [Read I/O %],
        ioWriteMB AS [Write I/O (MB)], 
		CAST(ioWriteMB / SUM(ioWriteMB) OVER () * 100.0 AS DECIMAL(5, 2)) AS [Write I/O %]
FROM Aggregate_IO_Statistics
ORDER BY [I/O Rank] OPTION (RECOMPILE);


WITH AggregateBufferPoolUsage
AS
(SELECT DB_NAME(database_id) AS [Database Name],
CAST(COUNT(*) * 8/1024.0 AS DECIMAL (10,2))  AS [CachedSize]
FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
WHERE database_id <> 32767 -- ResourceDB
GROUP BY DB_NAME(database_id))
SELECT ROW_NUMBER() OVER(ORDER BY CachedSize DESC) AS [Buffer Pool Rank], [Database Name], CachedSize AS [Cached Size (MB)],
       CAST(CachedSize / SUM(CachedSize) OVER() * 100.0 AS DECIMAL(5,2)) AS [Buffer Pool Percent]
FROM AggregateBufferPoolUsage
ORDER BY [Buffer Pool Rank] OPTION (RECOMPILE);

usp_DailyChecker
wait type eklenecek

*/
SELECT Priority,CheckGroup,CheckSubGroup,DatabaseName,Details,Details2,Comment FROM ##temp_DailyChecker
ORDER BY Priority,CheckGroup,CheckSubGroup

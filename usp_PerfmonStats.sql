USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_PerfmonStats]    Script Date: 7/19/2019 3:21:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_PerfmonStats') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_PerfmonStats AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_PerfmonStats]
		@OutputDatabaseName NVARCHAR(256) = NULL ,
		@OutputSchemaName NVARCHAR(256) = NULL ,
		@OutputTableName NVARCHAR(256) = NULL,
		@CleanupTime VARCHAR(3) = NULL
	AS
		
	/*  If table not exists it created. */
	PRINT 'If table not exists it created.'

	DECLARE @StringToExecute VARCHAR(MAX)
	SET @StringToExecute = 'USE '
        + @OutputDatabaseName
        + '; IF EXISTS(SELECT * FROM '
        + @OutputDatabaseName
        + '.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = '''
        + @OutputSchemaName
        + ''') AND NOT EXISTS (SELECT * FROM '
        + @OutputDatabaseName
        + '.INFORMATION_SCHEMA.TABLES WHERE QUOTENAME(TABLE_SCHEMA) = '''
        + @OutputSchemaName + ''' AND QUOTENAME(TABLE_NAME) = '''
        + @OutputTableName + ''') CREATE TABLE '
        + @OutputSchemaName + '.'
        + @OutputTableName
        + ' ([ID] [int] IDENTITY(1,1) NOT NULL,
			[check_date] [datetime] NULL,
			[object_name] [nvarchar](255) NOT NULL,
			[counter_name] [nvarchar](128) NOT NULL,
			[instance_name] [nvarchar](128) NULL,
			[cntr_value] [bigint] NULL,
			[cntr_type] [int] NULL,
			[value_per_second] [bigint] NULL,
            PRIMARY KEY CLUSTERED (ID ASC))'

	EXEC(@StringToExecute);

	IF @CleanupTime IS NOT NULL
		BEGIN
			SET @StringToExecute = '
			DELETE FROM '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+' 
			WHERE check_date<GETDATE()-'+@CleanupTime+'';
			EXEC(@StringToExecute);

			/*  If @CleanupTime is not null. So, i clear it. */
			PRINT 'If @CleanupTime is not null. So, i clear it.'

		END


	/* CPU usage insert temp table.  */
	PRINT 'CPU usage insert temp table'

	DECLARE @ts_now BIGINT = ( SELECT cpu_ticks / (cpu_ticks / ms_ticks) FROM sys.dm_os_sys_info);
	DECLARE @checkdate datetime = GETDATE()
	IF OBJECT_ID('tempdb..#Log_CPU_Utilization') is not null DROP TABLE #Log_CPU_Utilization

		SELECT TOP (1)
			check_date = @checkdate
			,SQLProcessUtilization 
			,SystemIdle
			,100 - SystemIdle - SQLProcessUtilization AS [OtherProcessCPUUtilization]
			,DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time] INTO #Log_CPU_Utilization
		FROM (SELECT
				record.value('(./Record/@id)[1]', 'int') AS record_id
				,record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')
				AS [SystemIdle]
				,record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]',
				'int')
				AS [SQLProcessUtilization]
				,[timestamp]
			FROM (SELECT [timestamp], CONVERT(XML, record) AS [record] FROM sys.dm_os_ring_buffers 
				WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' AND record LIKE '%<SystemHealth>%') AS x) AS y
			ORDER BY record_id DESC

	/* Perfmon Stats insert temp table.  */
	PRINT 'Perfmon Stats insert temp table'

	IF OBJECT_ID('tempdb..#Log_Performance_Counters') IS NOT NULL DROP TABLE #Log_Performance_Counters

		SELECT
			check_date = @checkdate,*
		INTO #Log_Performance_Counters
		FROM sys.dm_os_performance_counters
			WHERE instance_name IN ('', '_Total') AND cntr_type != 272696576
			AND counter_name IN
			('Total Server Memory (KB)',
			'Target Server Memory (KB)',
			'Memory Grants Pending',
			'Page life expectancy',
			'Buffer cache hit ratio',
			'Average Wait Time (ms)',
			'Active Temp Tables',
			'User Connections',
			'Lock Wait Time (ms)',
			'Average Wait Time (ms)',
			'Free Memory (KB)')


	/* Perfmon Stats (Per Sec) insert temp table.  */
	PRINT 'Perfmon Stats (Per Sec) insert temp table'
	IF OBJECT_ID('tempdb..#Log_Performance_Counters_PerSec') IS NOT NULL DROP TABLE #Log_Performance_Counters_PerSec

		SELECT
			check_date = @checkdate,*
		INTO #Log_Performance_Counters_PerSec
		FROM sys.dm_os_performance_counters
		WHERE instance_name IN ('', '_Total') AND cntr_type = 272696576
		AND counter_name IN
		(
		'Page reads/sec',
		'Page writes/sec',
		'Lock Requests/sec',
		'Lock Timeouts/sec',
		'Lock Waits/sec',
		'Number of Deadlocks/sec',
		'Transactions/sec',
		'Batch Requests/sec',
		'SQL Compilations/sec',
		'SQL Re-Compilations/sec',
		'Errors/sec')

	WAITFOR DELAY '00:00:01'

	IF OBJECT_ID('tempdb..#Log_Performance_Counters_PerSec2') IS NOT NULL DROP TABLE #Log_Performance_Counters_PerSec2

		SELECT
			check_date = @checkdate,*
		INTO #Log_Performance_Counters_PerSec2
		FROM sys.dm_os_performance_counters
		WHERE instance_name IN ('', '_Total') AND cntr_type = 272696576
		AND counter_name IN
		(
		'Page reads/sec',
		'Page writes/sec',
		'Lock Requests/sec',
		'Lock Timeouts/sec',
		'Lock Waits/sec',
		'Number of Deadlocks/sec',
		'Transactions/sec',
		'Batch Requests/sec',
		'SQL Compilations/sec',
		'SQL Re-Compilations/sec',
		'Errors/sec')

	IF @OutputDatabaseName IS NOT NULL AND @OutputSchemaName IS NOT NULL AND @OutputTableName IS NOT NULL
	BEGIN
		SET @StringToExecute = '
		INSERT INTO '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+' 
		([check_date],[object_name],[counter_name],[cntr_value])
		SELECT [check_date] , [object_name] = ''System'', [counter_name] = ''SQL CPU'', [cntr_value] = SQLProcessUtilization FROM #Log_CPU_Utilization 
		UNION ALL
		SELECT [check_date] ,[object_name] = ''System'', [counter_name] = ''Other CPU'', [cntr_value] = OtherProcessCPUUtilization FROM #Log_CPU_Utilization

		INSERT INTO '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+' 
		([check_date],[object_name],[counter_name],[instance_name],[cntr_value],[cntr_type])
		SELECT [check_date] ,[object_name],[counter_name],[instance_name],[cntr_value],[cntr_type]
		FROM #Log_Performance_Counters

		INSERT INTO '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+' 
		([check_date],[object_name],[counter_name],[instance_name],[cntr_value],[cntr_type],[value_per_second])
		SELECT PCR.[check_date],PCR.[object_name],PCR.[counter_name],PCR.[instance_name],PCR.[cntr_value],PCR.[cntr_type],
		[value_per_second] = PCR2.cntr_value-PCR.cntr_value
		FROM  #Log_Performance_Counters_PerSec PCR
		JOIN #Log_Performance_Counters_PerSec2 PCR2 ON PCR.counter_name=PCR2.counter_name';
		EXEC(@StringToExecute)

		/*  If you want move data to table, I will import on the live table. */
		PRINT 'If you want move data to table, I will import on the live table.'

	END

	IF @OutputDatabaseName IS NULL AND @OutputSchemaName IS NULL AND @OutputTableName IS NULL
	BEGIN
		
		SELECT [check_date] , [object_name] = 'System', [counter_name] = 'SQL CPU',[instance_name]=NULL, [cntr_value] = SQLProcessUtilization,[cntr_type]=NULL ,[value_per_second]=NULL
		FROM #Log_CPU_Utilization 
			UNION ALL
		SELECT	[check_date] ,
				[object_name] = 'System', 
				[counter_name] = 'Other CPU',
				[instance_name]=NULL, 
				[cntr_value] = OtherProcessCPUUtilization,
				[cntr_type]=NULL,
				[value_per_second]=NULL
		FROM #Log_CPU_Utilization
			UNION ALL
		SELECT	[check_date] ,
				[object_name],
				[counter_name],
				[instance_name],
				[cntr_value],
				[cntr_type],
				[value_per_second]=NULL
		FROM #Log_Performance_Counters
			UNION ALL 
		SELECT	PCR.[check_date],
				PCR.[object_name],
				PCR.[counter_name],
				PCR.[instance_name],
				PCR.[cntr_value],
				PCR.[cntr_type],
				[value_per_second] = PCR2.cntr_value-PCR.cntr_value
		FROM  #Log_Performance_Counters_PerSec PCR
			JOIN #Log_Performance_Counters_PerSec2 PCR2 ON PCR.counter_name=PCR2.counter_name

		/*  If you want just see, I can show your data on the your results screen. */
		PRINT 'If you want just see, I can show your data on the your results screen.'

	END

		


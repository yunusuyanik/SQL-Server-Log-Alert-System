USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_DriveStats]    Script Date: 7/19/2019 2:57:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_DriveStats') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_DriveStats AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_DriveStats]
			@OutputDatabaseName NVARCHAR(256) = NULL ,
			@OutputSchemaName NVARCHAR(256) = NULL ,
			@OutputTableName NVARCHAR(256) = NULL,
			@CleanupTime VARCHAR(3) = NULL
		AS
		
	/*  If table not exists it created. */
	PRINT 'If table not exists it created.'

	DECLARE @checkdate datetime = GETDATE()
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
			[server_name] [varchar] (255) NULL,
			[instance_name] [varchar] (255) NULL,
			[volume_letter] [varchar](10) NULL,
			[volume_label] [varchar](255) NULL,
			[volume_capacity_gb] int NULL,
			[volume_free_space_gb] int NULL,
			[percentage_free_space] DECIMAL(18,2) NULL,
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


	/*  I will import data on temp table. */
	PRINT 'I will import data on temp table.'

	IF OBJECT_ID('tempdb.dbo.#temp_drive_stats') IS NOT NULL
			DROP TABLE #temp_drive_stats

	SELECT DISTINCT
		check_date = @checkdate
		,cast(SERVERPROPERTY('MachineName') as varchar(100)) AS server_name
		,cast( ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') as varchar(100)) AS instance_name
		,vs.volume_mount_point AS volume_letter
		,vs.logical_volume_name AS volume_label
		,vs.total_bytes/1024/1024/1024 AS volume_capacity_gb
		,vs.available_bytes/1024/1024/1024 AS volume_free_space_gb
		,CAST(vs.available_bytes * 100.0 / vs.total_bytes AS DECIMAL(5, 2)) AS percentage_free_space
	INTO #temp_drive_stats
	FROM sys.master_files AS mf
		 CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs

	

	IF @OutputDatabaseName IS NOT NULL AND @OutputSchemaName IS NOT NULL AND @OutputTableName IS NOT NULL
	BEGIN
		SET @StringToExecute = '
		INSERT INTO '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+'  
		([check_date],[server_name],[instance_name],[volume_letter],[volume_label],[volume_capacity_gb],[volume_free_space_gb],[percentage_free_space])
		SELECT * FROM #temp_drive_stats';
		EXEC(@StringToExecute);

		/*  If you want move data to table, I will import on the live table. */
		PRINT 'If you want move data to table, I will import on the live table.'

	END

	IF @OutputDatabaseName IS NULL AND @OutputSchemaName IS NULL AND @OutputTableName IS NULL
	BEGIN
		SELECT * FROM #temp_drive_stats

		/*  If you want just see, I can show your data on the your results screen. */
		PRINT 'If you want just see, I can show your data on the your results screen.'

	END


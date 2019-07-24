USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_DriveStats]    Script Date: 7/19/2019 2:57:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_ErrorLog') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_ErrorLog AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_ErrorLog]
			@OutputDatabaseName NVARCHAR(256) = NULL ,
			@OutputSchemaName NVARCHAR(256) = NULL ,
			@OutputTableName NVARCHAR(256) = NULL,
			@CleanupTime VARCHAR(3) = NULL,
			@LastTime INT = 1
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
			[log_date] [datetime] NULL,
			[process_info] [varchar] (255) NULL,
			[error_code] [varchar] (255) NULL,
			[error_message] [varchar] (max) NULL,
            PRIMARY KEY CLUSTERED (ID ASC))
			IF NOT EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('''+@OutputTableName+''') AND NAME =''IX_SA_DBA_check_date'') 
				CREATE INDEX IX_SA_DBA_check_date ON '+@OutputTableName+' ([check_date]) WITH (FILLFACTOR=90);';
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

		DECLARE @StartTime DATETIME
		IF @OutputDatabaseName IS NOT NULL AND @OutputSchemaName IS NOT NULL AND @OutputTableName IS NOT NULL
		BEGIN 
			SELECT @StartTime=ISNULL((MAX(check_date)),GETDATE()-30) FROM Log_SQLErrors
		END 
		ELSE BEGIN SET @StartTime=GETDATE()-@LastTime END

		/*  I will drop temp tables. */
		PRINT 'I will drop temp tables.'

		IF OBJECT_ID('tempdb.dbo.#temp_error_log') IS NOT NULL DROP TABLE #temp_error_log
		IF OBJECT_ID('tempdb.dbo.#temp_error_log') IS NOT NULL DROP TABLE #temp_error_log
		IF OBJECT_ID('tempdb.dbo.#temp_error_log') IS NOT NULL DROP TABLE #temp_error_log

		CREATE TABLE #temp_error_log (LogDate DATETIME, ProcessInfo VARCHAR(64), [Text] VARCHAR(MAX));
		
		/*  I will import data on temp table. */
		PRINT 'I will import data on temp table.'

		INSERT INTO #temp_error_log 
		EXEC xp_readerrorlog 0,1,null,null,@StartTime,null,'desc' 

		SELECT check_date =@checkdate,el1.LogDate log_date,el1.ProcessInfo process_info,el1.Text error_code,el2.Text error_message
		INTO #temp_error_log_result
		FROM #temp_error_log el1
		LEFT JOIN #temp_error_log el2 ON el1.LogDate=el2.LogDate
		WHERE el1.Text LIKE 'Error%' and el2.Text NOT LIKE 'Error%'
		AND SUBSTRING(el1.Text,CHARINDEX('Severity:',el1.Text)+10,CHARINDEX('State:',el1.Text)-CHARINDEX('Severity:',el1.Text)-12)>=16
		
	IF @OutputDatabaseName IS NOT NULL AND @OutputSchemaName IS NOT NULL AND @OutputTableName IS NOT NULL
	BEGIN
		SET @StringToExecute = '
		INSERT INTO '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+'  
		([check_date],[log_date],[process_info],[error_code],[error_message])
		SELECT * FROM #temp_error_log_result';
		EXEC(@StringToExecute);

		/*  If you want move data to table, I will import on the live table. */
		PRINT 'If you want move data to table, I will import on the live table.'

	END

	IF @OutputDatabaseName IS NULL AND @OutputSchemaName IS NULL AND @OutputTableName IS NULL
	BEGIN
		SELECT * FROM #temp_error_log_result

		/*  If you want just see, I can show your data on the your results screen. */
		PRINT 'If you want just see, I can show your data on the your results screen.'

	END

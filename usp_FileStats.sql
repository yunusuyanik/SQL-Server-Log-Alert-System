USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_FileStats]    Script Date: 7/19/2019 3:20:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_FileStats') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_FileStats AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_FileStats]
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
			[database_id] [int] NULL,
			[file_id] [int] NULL,
			[database_name] [varchar](500) NULL,
			[file_name] [varchar](1000) NULL,
			[type_desc] [varchar](10) NULL,
			[size_on_disk_mb] DECIMAL(18,2) NULL,
			[free_size_mb] DECIMAL(18,2) NULL,
			[io_stall_read_ms] bigint NULL,
			[num_of_reads] bigint NULL,
			[num_of_bytes_read] bigint NULL,
			[io_stall_write_ms] bigint NULL,
			[num_of_writes] bigint NULL,
			[num_of_bytes_written] bigint NULL,
			[growth] [int] NULL,
			[is_percent_growth] bit NULL,
			[physical_file_name] [varchar](5000) NULL,
            PRIMARY KEY CLUSTERED (ID ASC))
	    
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

		IF OBJECT_ID('tempdb.dbo.#temp_file_stats') IS NOT NULL
			DROP TABLE #temp_file_stats
		IF OBJECT_ID('tempdb.dbo.#temp_free_size') IS NOT NULL
			DROP TABLE #temp_free_size


	/*  I will import data on temp table. */
	PRINT 'I will import data on temp table.'
	SELECT
		check_date = @checkdate,
		b.[database_id],
		b.[file_id],
		[database_name] = DB_NAME(b.[database_id]),
		[file_name] = b.[name],
		[type_desc],
		[size_on_disk_mb] = CAST(([size_on_disk_bytes]*1.0/1024/1024) AS DECIMAL(9, 2)),
		[io_stall_read_ms],
		[num_of_reads],
		[num_of_bytes_read],
		[io_stall_write_ms],
		[num_of_writes],
		[num_of_bytes_written],
		[growth],
		[is_percent_growth],
		[physical_file_name] = b.[physical_name]
	INTO #temp_file_stats
	FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS a
	INNER JOIN sys.master_files AS b
	ON a.file_id = b.file_id
	AND a.database_id = b.database_id
		WHERE a.num_of_reads > 0
			AND a.num_of_writes > 0
	ORDER BY a.database_id;

	CREATE TABLE #temp_free_size (db_id int,file_id int ,free_size_mb DECIMAL(18,2))
	EXEC sp_MSforeachdb '
		USE [?]
		INSERT INTO #temp_free_size (db_id,file_id,free_size_mb)
		SELECT
		DB_ID(),
		file_id,
		SUM(CAST((size/128.0-FILEPROPERTY(name, ''SpaceUsed'')/128.0) AS DECIMAL(18,2))) as free_size_mb
		FROM sys.database_files
		group by file_id'

	IF @OutputDatabaseName IS NOT NULL AND @OutputSchemaName IS NOT NULL AND @OutputTableName IS NOT NULL
	BEGIN
		SET @StringToExecute = '
		INSERT INTO '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+'  
		([check_date],[database_id],[file_id],[database_name],[file_name],[type_desc],[size_on_disk_mb],[io_stall_read_ms],[num_of_reads],[num_of_bytes_read],[io_stall_write_ms],[num_of_writes],[num_of_bytes_written],[growth],[is_percent_growth],[physical_file_name],[free_size_mb])
		SELECT tfs.*,tfss.free_size_mb FROM #temp_file_stats tfs
			JOIN #temp_free_size tfss ON tfs.database_id=tfss.db_id AND tfs.file_id=tfss.file_id';
		EXEC(@StringToExecute);

		/*  If you want move data to table, I will import on the live table. */
		PRINT 'If you want move data to table, I will import on the live table.'

	END
	

	IF @OutputDatabaseName IS NULL AND @OutputSchemaName IS NULL AND @OutputTableName IS NULL
	BEGIN
		SELECT tfs.*,tfss.free_size_mb FROM #temp_file_stats tfs
		JOIN #temp_free_size tfss ON tfs.database_id=tfss.db_id AND tfs.file_id=tfss.file_id

		/*  If you want just see, I can show your data on the your results screen. */
		PRINT 'If you want just see, I can show your data on the your results screen.'

	END

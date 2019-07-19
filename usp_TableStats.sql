USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_TableStats]    Script Date: 7/19/2019 3:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_TableStats') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_TableStats AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_TableStats]
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
			[database_name] [varchar](255) NULL,
            [schema_name] [varchar](255) NULL,
            [table_name] [varchar](255) NULL,
            [table_rows] [bigint] NULL,
            [compression_type] [varchar](100) NULL,
            [table_type] [varchar](100) NULL,
            [page_count] [int] NULL,
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

	/*  I will import data on temp table. */
	PRINT 'I will import data on temp table.'

	IF OBJECT_ID('tempdb.dbo.#temp_table_stats') IS NOT NULL DROP TABLE #temp_table_stats

	CREATE TABLE #temp_table_stats ([database_name] [varchar](255) NULL,[schema_name] [varchar](255) NULL,[table_name] [varchar](255) NULL,[table_rows] [bigint] NULL,[compression_type] [varchar](20) NULL,[table_type] [varchar](20) NULL,[page_count] [int] NULL)
	
	EXEC sp_MSforeachdb 'IF ''[?]''  NOT IN (''tempdb'',''model'',''msdb'')
	BEGIN
		INSERT INTO #temp_table_stats 
		SELECT
		''[?]'' as database_name,
		s.name as schema_name,
		t.name as table_name,
		part.tableRows table_rows,
		part.data_Compression compression_type,
		'''' table_type,
		0 page_count
		FROM [?].sys.tables t
		INNER JOIN [?].sys.schemas s on t.schema_id=s.schema_id
		INNER JOIN [?].sys.indexes i on i.object_id=t.object_id and i.index_id<2
		CROSS APPLY (
						select object_id,sum(rows) as tableRows,max(data_Compression_desc) as data_Compression
						from  [?].sys.partitions p
						where  p.object_id=t.object_id and p.index_id<2
						group by object_id
						having sum(rows)>10000
		) AS PART
		--CROSS APPLY [?].sys.dm_db_index_physical_stats(db_id(''[?]''),t.object_id,i.index_id,null,''Limited'') inxphy
	END'

	IF @OutputDatabaseName IS NOT NULL AND @OutputSchemaName IS NOT NULL AND @OutputTableName IS NOT NULL
	BEGIN
		SET @StringToExecute = '
		INSERT INTO '+@OutputDatabaseName+'.'+@OutputSchemaName+'.'+@OutputTableName+'  
		(check_date,[database_name],[schema_name],[table_name],[table_rows],[compression_type],[table_type],[page_count])
		SELECT check_date = GETDATE(),[database_name],[schema_name],[table_name],[table_rows],[compression_type],[table_type],[page_count] FROM #temp_table_stats';
		EXEC(@StringToExecute);
		
		/*  If you want move data to table, I will import on the live table. */
		PRINT 'If you want move data to table, I will import on the live table.'

	END

	IF @OutputDatabaseName IS NULL AND @OutputSchemaName IS NULL AND @OutputTableName IS NULL
	BEGIN
		SELECT * FROM #temp_table_stats

		/*  If you want just see, I can show your data on the your results screen. */
		PRINT 'If you want just see, I can show your data on the your results screen.'

	END


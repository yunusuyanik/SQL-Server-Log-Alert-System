
;WITH backups AS (
    SELECT  
	[server_name] = @@Servername,
    [database_name] = d.name, 
    [day_since_last_backup] = DATEDIFF(DAY, MAX(Backup_finish_date), GETDATE()),
	[min_since_last_backup] = DATEDIFF(MI, MAX(Backup_finish_date), GETDATE()),
    [last_backup_date] = (MAX(backup_finish_date)),
    backup_size_gb=CAST(COALESCE(MAX(bs.backup_size),0)/1024.00/1024.00/1024.00 AS NUMERIC(18,2)),
    backup_size_mb=CAST(COALESCE(MAX(bs.backup_size),0)/1024.00/1024.00 AS NUMERIC(18,2)),
    media_set_id = MAX(bs.media_set_id),
    avg_backup_duration_sec= AVG(CAST(DATEDIFF(s, bs.backup_start_date, bs.backup_finish_date) AS int)),
    max_backup_duration_sec= MAX(CAST(DATEDIFF(s, bs.backup_start_date, bs.backup_finish_date) AS int)),
    bs.type
    FROM sys.databases d 
    LEFT JOIN msdb.dbo.backupset bs 
		ON bs.database_name = d.name 
                AND bs.is_copy_only = 0
	WHERE d.name!='tempdb'
    GROUP BY d.Name, bs.type
)
    SELECT server_name,database_name,
	CASE WHEN agdb.database_id IS NOT NULL THEN 1
             ELSE 0
        END [is_availability_group]
      , CASE WHEN sys.fn_hadr_backup_is_preferred_replica(b.database_name) = 1
             THEN 1
             ELSE 0
        END [is_rreferred_replica],
	type,last_backup_date,backup_size_mb,day_since_last_backup,[min_since_last_backup],avg_backup_duration_sec,max_backup_duration_sec,physical_device_name,logical_device_name,device_type,physical_block_size
	
    FROM backups b
    LEFT JOIN msdb.dbo.backupmediafamily F
		ON b.media_set_id = F.media_set_id
	 LEFT OUTER JOIN sys.dm_hadr_database_replica_states agdb 
		ON DB_NAME(agdb.database_id) = b.[database_name] AND agdb.is_local = 1
    ORDER BY b.server_name, b.database_name, type


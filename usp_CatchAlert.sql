USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_CatchAlert]    Script Date: 7/19/2019 3:33:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


IF OBJECT_ID('dbo.usp_CatchAlert') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_CatchAlert AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_CatchAlert]
AS
DECLARE @last_check_date datetime 
DECLARE @value int


	/* ----------------------------------
	 I am gonna check fail jobs. */
	PRINT 'I am gonna check fail jobs'

		SELECT @last_check_date=last_check_date,@value=value FROM ConfigThreshold WHERE alert_group='Job Failed'

			INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,error_message)

			SELECT 
				check_date,@@SERVERNAME server_name,
				'Job Failed' alert_group,
				job_name alert_name,
				'<br> <b>StepName :</b> '+step_name+'<br> <b>Error Message :</b> <br>'+error_message error_message from Log_JobInfo 
			WHERE 
				check_date>=@last_check_date
				AND Status='Failed'
				AND job_name NOT IN ('YONTEMCREDITCUBE Process','YONTEMCUBE Process')

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='Job Failed' 


	/* ----------------------------------
	 I am gonna check sql error log. */
	PRINT 'I am gonna check fail jobs'

		SELECT @last_check_date=last_check_date,@value=value FROM ConfigThreshold WHERE alert_group='SQL Error Log'

			INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,error_message)

			SELECT 
				check_date,@@SERVERNAME server_name,
				'SQL Error Log' alert_group,
				process_info alert_name,
				'<br> <b>Error Message :</b> <br>'+error_message error_message from Log_SQLErrors
			WHERE 
				check_date>=@last_check_date

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='SQL Error Log' 


	/* ----------------------------------
	 I am gonna check disk size. */
	PRINT 'I am gonna check disk size.'

		SELECT @last_check_date=DATEADD(MI,-10,last_check_date),@value=value FROM ConfigThreshold WHERE alert_group='Disk Size'

			INSERT INTO ErrorLog (check_date,server_name,instance_name,alert_group,alert_name,priority,error_message)
			SELECT 
				check_date,server_name,instance_name,
				'Disk Size' alert_group,
				'Free Space Under Than %'+CONVERT(VARCHAR(10),@value) alert_name,
				1 priority,
				volume_letter+' ('+volume_label+') <br> 
				<b>Capacity (GB): </b>'+CONVERT(VARCHAR(100),volume_capacity_gb)+'
				<br><b>Free Space (GB) : </b>'+CONVERT(VARCHAR(100),volume_free_space_gb)+'
				<br><b>Free Space (Percentage) : </b>'+CONVERT(VARCHAR(100),percentage_free_space) error_message
			FROM Log_DriveStats 
			WHERE 
				percentage_free_space<@value
				AND check_date>=@last_check_date

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='Disk Size'


	/* ----------------------------------
	 I am gonna check ldf file size. */
	PRINT 'I am gonna check ldf file size.'

		SELECT @last_check_date=DATEADD(MI,-10,last_check_date),@value=value FROM ConfigThreshold WHERE alert_group='Log File Size'

			SELECT TOP 1 WITH TIES 
				check_date,
				database_name,
				type_desc,
				SUM(size_on_disk_mb) as data_file_size,
				LAG(SUM(size_on_disk_mb),1,0) OVER(ORDER BY check_date,database_name,type_desc) log_file_size
			INTO #temp_size
			FROM Log_FileStats 
			WHERE 
				check_date>=@last_check_date
			GROUP BY check_date,database_name,type_desc
			ORDER BY check_date DESC

			INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,priority,error_message)
			SELECT 
				check_date,
				@@SERVERNAME server_name,
				'Log File Size' alert_group,
				'Log File Size Bigger Than 4/3 Data File Size' alert_name,
				1 priority,
				'<br> <b> DatabaseName : </b> '+database_name+
				'<br> <b> Data File Size (MB) : </b> '+CONVERT(VARCHAR(100),data_file_size)+
				'<br> <b> Log File Size (MB) </b> : '+CONVERT(VARCHAR(100),log_file_size) error_message FROM #temp_size
			WHERE type_desc='ROWS' and log_file_size>=(data_file_size/4)*3 AND log_file_size>50000

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='Log File Size'


	/* ----------------------------------
	 I am gonna check cpu usage. */
	PRINT 'I am gonna check cpu usage.'

		SELECT @last_check_date=last_check_date,@value=value FROM ConfigThreshold WHERE alert_group='CPU'

			INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,priority,error_message)

			SELECT 
				check_date,@@SERVERNAME server_name,
				'CPU' alert_group,
				'CPU Utilization More Than %'+CONVERT(VARCHAR(10),@value) alert_name,
				1 priority ,
				'<br><b>'+counter_name+' :</b> '+CONVERT(VARCHAR(100),cntr_value) error_message
			FROM Log_PerfmonStats 
			WHERE 
				cntr_value>@value
				AND check_date>=@last_check_date
				AND counter_name IN ('SQL CPU','Other CPU')

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='CPU' 


	/* ----------------------------------
	 I am gonna check database which is_percent_growth=0 */
	PRINT 'I am gonna check database which is_percent_growth=0'

		SELECT @last_check_date=last_check_date,@value=value FROM ConfigThreshold WHERE alert_group='is_percent_growth'

			INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,priority,error_message)
			SELECT 
				check_date,@@SERVERNAME server_name,
				'is_percent_growth' alert_group,
				'There is file(s) set with percent growth' alert_name,
				10 priority ,
				'<br> <b>DatabaseName : </b>'+ database_name+'<br> <b>FileName : </b>'+file_name error_message
			FROM Log_FileStats 
			WHERE 
				is_percent_growth=1
				AND check_date>=@last_check_date

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='is_percent_growth' 

	/* ----------------------------------
	 I am gonna check tempdb size. */
	PRINT 'I am gonna check tempdb size.'


		SELECT @last_check_date=DATEADD(MI,-10,last_check_date),@value=value FROM ConfigThreshold WHERE alert_group='TempDB Size MB'

			INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,priority,error_message)
			SELECT 
				TOP 1
				MAX(check_date),@@SERVERNAME server_name,
				'TempDB Size MB' alert_group,
				'TempDB Size More Than '+CONVERT(VARCHAR(10),@value)+' MB' alert_name,
				10 priority ,
				'<br><b>size_on_disk_mb : </b>'+ CONVERT(VARCHAR(50),(SUM(size_on_disk_mb)))+'
				<br><b>free_size_mb : </b>'+ CONVERT(VARCHAR(50),(SUM(free_size_mb))) error_message
			FROM Log_FileStats 
			WHERE
				check_date>=@last_check_date AND database_name='tempdb'
			GROUP BY database_name,check_date
			HAVING SUM(size_on_disk_mb)>@value
			ORDER BY check_date DESC

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='TempDB Size MB' 


	/* ----------------------------------
	 I am gonna check latency of AlwaysOn, If you have it. */
	PRINT 'I am gonna check latency of AlwaysOn, If you have it.'

		IF (SELECT SERVERPROPERTY('IsHadrEnabled'))=1

		BEGIN
		SELECT @last_check_date=last_check_date,@value=value FROM ConfigThreshold WHERE alert_group='AlwaysOn Latency'


			DECLARE @table VARCHAR(MAX)
				SELECT 
					[current_time] = CONVERT(VARCHAR(20),GETDATE(),120),
					[database_name] = DB_NAME(database_id),
					[redo_rate],
					[last_commit_time],
					[time_behind_primary] = CAST(CAST(((DATEDIFF(s,last_commit_time,GetDate()))/3600) as varchar) + ' hour(s), ' + CAST((DATEDIFF(s,last_commit_time,GetDate())%3600)/60 as varchar) + ' min, ' + CAST((DATEDIFF(s,last_commit_time,GetDate())%60) as varchar) + ' sec' as VARCHAR(30)),
					[redo_queue_size],
					[estimated_completion_time] = CONVERT(VARCHAR(20),DATEADD(mi,(redo_queue_size/redo_rate/60.0),GETDATE()),120),
					[estimated_recovery_time_minutes] = CAST((redo_queue_size/redo_rate/60.0) as decimal(10,2))
				INTO #temp_alwayson_delay
				FROM master.sys.dm_hadr_database_replica_states
				WHERE last_redone_time is not null and redo_rate>0
				AND last_commit_time<DATEADD(MINUTE,-@value,GETDATE())

				SET @table =
						N'<p><b>Alert</b> : There is a delay in alwayson data transfer that bigger than 60 min.</p>'+
						N'<table border=1>' +
						N'<tr>
						<th>[database_name]</th>
						<th>[redo_rate]</th>
						<th>[last_commit_time]</th>
						<th>[time_behind_primary]</th>
						<th>[redo_queue_size]</th>
						<th>[estimated_completion_time]</th>
						<th>[current_time]</th>
						</tr>' +
						CAST((SELECT
								td = [database_name]
								,''
								,td = [redo_rate]
								,''
								,td = [last_commit_time]
								,''
								,td = [time_behind_primary]
								,''
								,td = [redo_queue_size]
								,''
								,td = [estimated_completion_time]
								,''
								,td = [current_time]
								,''
							FROM #temp_alwayson_delay
							FOR XML PATH ('tr'), TYPE)
						AS NVARCHAR(MAX)) +
						N'</table>';	

			INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,priority,error_message)
			SELECT TOP 1
				@last_check_date check_date,@@SERVERNAME server_name,
				'AlwaysOn Latency' alert_group,
				'AlwaysOn Latency More Than '+CONVERT(VARCHAR(10),@value)+' min' alert_name,
				1 priority ,
				@table error_message
			FROM #temp_alwayson_delay 

		UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='AlwaysOn Latency' 
		END


	/* ----------------------------------
	 I am gonna send mail about all errors */
	PRINT 'I am gonna send mail about all errors'

		DECLARE @To varchar(100)
		DECLARE @ProfileName varchar(50)
		DECLARE @IsActive int
		DECLARE @MailSubject varchar(100)
		DECLARE @FireCount int = 0
		DECLARE @xml NVARCHAR(MAX)
		DECLARE @body NVARCHAR(MAX)
		DECLARE @id INT
		DECLARE @alert_group VARCHAR(255)

		SELECT TOP 1 @MailSubject=QUOTENAME(customer_name)+' - '+QUOTENAME(server_name)+' - '+c.alert_group,
		@body='
		<b>Log Date : </b>'+CONVERT(VARCHAR(21),check_date,120)+'
		<br><b>Name </b>'+alert_name+'
		<br><I>Detail : </I>'+error_message+'
		',@To=c.[To],@ProfileName=c.profilename,@IsActive=c.is_active,
		@id=e.ID,
		@alert_group=e.alert_group
		FROM ErrorLog e
		JOIN ConfigThreshold c ON e.alert_group=c.alert_group WHERE e.email_send=0 AND check_date>DATEADD(MI,9,last_mail_send)
		ORDER BY e.check_date DESC
		IF @IsActive=1 
			BEGIN
					EXEC msdb.dbo.sp_send_dbmail
					@profile_name = @ProfileName, @body = @body, @body_format = 'HTML', @recipients = @To, @subject = @MailSubject;
					UPDATE ErrorLog SET email_send=1 WHERE ID=@id
					UPDATE ConfigThreshold SET last_mail_send=GETDATE() WHERE alert_group=@alert_group
			END








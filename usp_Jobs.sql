USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_Jobs]    Script Date: 7/19/2019 3:21:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_Jobs') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Jobs AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_Jobs]
		AS

	IF OBJECT_ID('tempdb.dbo.#temp_job') IS NOT NULL
		DROP TABLE #temp_job
		
			SELECT 
				[check_date] = GETDATE(),
				[job_name] = j.Name, 
				[description] = '"' + NULLIF(j.Description, 'No description available.') + '"',
				[job_owner] = SUSER_SNAME(j.owner_sid),
				[number_of_steps] = (SELECT COUNT(step_id) FROM msdb.dbo.sysjobsteps WHERE job_id = j.job_id),
				[is_enabled] = CASE j.Enabled
					WHEN 1 THEN 'Yes'
					WHEN 0 THEN 'No'
				END,
				[frequency] = CASE s.freq_type
					WHEN 1 THEN 'Once'
					WHEN 4 THEN 'Daily'
					WHEN 8 THEN 'Weekly'
					WHEN 16 THEN 'Monthly'
					WHEN 32 THEN 'Monthly relative'
					WHEN 64 THEN 'When SQLServer Agent starts'
				END, 
				CASE(s.freq_subday_interval)
					WHEN 0 THEN 'Once'
					ELSE cast('Every ' 
							+ right(s.freq_subday_interval,2) 
							+ ' '
							+     CASE(s.freq_subday_type)
										WHEN 1 THEN 'Once'
										WHEN 4 THEN 'Minutes'
										WHEN 8 THEN 'Hours'
									END as char(16))
				END as [subday_frequency],
				[next_start date] = CONVERT(DATETIME, RTRIM(NULLIF(js.next_run_date, 0)) + ' '
					+ STUFF(STUFF(REPLACE(STR(RTRIM(js.next_run_time),6,0),
					' ','0'),3,0,':'),6,0,':')),
				[last_run duration] = STUFF(STUFF(REPLACE(STR(lastrun.run_duration,7,0),
					' ','0'),4,0,':'),7,0,':'),
				[last_start date] = CONVERT(DATETIME, RTRIM(lastrun.run_date) + ' '
					+ STUFF(STUFF(REPLACE(STR(RTRIM(lastrun.run_time),6,0),
					' ','0'),3,0,':'),6,0,':')),
				[last_run message] = lastrun.message
				,[status] = CASE
				WHEN lastrun.run_status = 0 THEN 'Failed'
				WHEN lastrun.run_status = 1 THEN 'Succeded'
				WHEN lastrun.run_status = 2 THEN 'Retry'
				WHEN lastrun.run_status = 3 THEN 'Canceled'
				END
			INTO #temp_job
			FROM msdb.dbo.sysjobs j
			LEFT OUTER JOIN msdb.dbo.sysjobschedules js
				ON j.job_id = js.job_id
			LEFT OUTER JOIN msdb.dbo.sysschedules s
				ON js.schedule_id = s.schedule_id 
			LEFT  JOIN (SELECT job_id, max(run_duration) AS run_duration
					FROM msdb.dbo.sysjobhistory
					GROUP BY job_id) maxdur
			ON j.job_id = maxdur.job_id
			-- INNER JOIN -- Swap Join Types if you don't want to include jobs that have never run
			LEFT JOIN
				(SELECT j1.job_id, j1.run_duration, j1.run_date, j1.run_time, j1.message,j1.run_status
				FROM msdb.dbo.sysjobhistory j1
				WHERE instance_id = (SELECT MAX(instance_id) FROM msdb.dbo.sysjobhistory j2 WHERE j2.job_id = j1.job_id)) lastrun
				ON j.job_id = lastrun.job_id



		SELECT * FROM #temp_job

		/*  If you want just see, I can show your data on the your results screen. */
		PRINT 'If you want just see, I can show your data on the your results screen.'

GO


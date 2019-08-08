USE [msdb]
GO

/****** Object:  Trigger [dbo].[tr_JobHistory]    Script Date: 8.08.2019 11:44:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[tr_JobHistory]
ON [msdb].[dbo].[sysjobhistory]
AFTER INSERT
AS

INSERT INTO DBA_DB.dbo.Log_JobHistory
(check_date,job_name,description,job_owner,number_of_steps,is_enabled,frequency,subday_frequency,next_start_date,last_run_duration,last_start_date,last_run_message,status)
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
FROM msdb.dbo.sysjobs j
LEFT OUTER JOIN msdb.dbo.sysjobschedules js
    ON j.job_id = js.job_id
LEFT OUTER JOIN msdb.dbo.sysschedules s
    ON js.schedule_id = s.schedule_id 
INNER JOIN (SELECT job_id, max(run_duration) AS run_duration
        FROM inserted
        GROUP BY job_id) maxdur
ON j.job_id = maxdur.job_id
-- INNER JOIN -- Swap Join Types if you don't want to include jobs that have never run
INNER JOIN
    (SELECT j1.job_id, j1.run_duration, j1.run_date, j1.run_time, j1.message,j1.run_status
    FROM inserted j1
    WHERE instance_id = (SELECT MAX(instance_id) FROM inserted j2 WHERE j2.job_id = j1.job_id) AND step_id!=0) lastrun
    ON j.job_id = lastrun.job_id



GO

ALTER TABLE [dbo].[sysjobhistory] ENABLE TRIGGER [tr_JobHistory]
GO


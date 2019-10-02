USE [DBA_DB]
GO

ALTER TABLE [dbo].[ConfigThreshold] ADD CONSTRAINT [PK_ConfigThreshold] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=90)
ALTER TABLE [dbo].[ErrorLog] ADD CONSTRAINT [PK_ErrorLog] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=90)
ALTER TABLE [dbo].[Log_DriveStats] ADD CONSTRAINT [PK_Log_DriveStats] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=90)
ALTER TABLE [dbo].[Log_FileStats] ADD CONSTRAINT [PK_Log_FileStats] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=90)
ALTER TABLE [dbo].[Log_JobHistory] ADD CONSTRAINT [PK_Log_JobHistory] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=90)
ALTER TABLE [dbo].[Log_PerfmonStats] ADD CONSTRAINT [PK_Log_PerfmonStats] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=90)
ALTER TABLE [dbo].[Log_WaitStats] ADD CONSTRAINT [PK_Log_WaitStats] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=90)


CREATE INDEX [IX_alert_group_last_mail_send] 
ON [dbo].[ConfigThreshold] ([alert_group],[last_mail_send])
INCLUDE ([customer_name],[is_active],[profilename],[To]) WITH (FILLFACTOR=90)

CREATE INDEX [IX_email_send_check_date_alert_group] 
ON [dbo].[ErrorLog]([email_send],[check_date],[alert_group])
INCLUDE ([server_name],[alert_name],[error_message]) WITH (FILLFACTOR=90)

CREATE INDEX [IX_check_date] 
ON [dbo].[Log_DriveStats] ([check_date],[percentage_free_space]) WITH (FILLFACTOR=90)

CREATE INDEX [IX_check_date_database_name_includes] 
ON [dbo].[Log_FileStats] ([check_date],[database_name])
INCLUDE ([type_desc],[size_on_disk_mb],[free_size_mb]) WITH (FILLFACTOR=90)

CREATE INDEX [IX_check_date_status_job_name_includes] 
ON [dbo].[Log_JobHistory] ([check_date],[status],[job_name])
INCLUDE ([step_name],[job_owner],[frequency],[subday_frequency],[next_start_date],[last_run_duration],[last_start_date],[last_run_message]) WITH (FILLFACTOR=90)

CREATE INDEX [IX_check_date_cntr_value_counter_name] 
ON [dbo].[Log_PerfmonStats]([check_date],[cntr_value],[counter_name]) WITH (FILLFACTOR=90)

CREATE INDEX [IX_check_date] 
ON [dbo].[Log_WaitStats] ([check_date]) WITH (FILLFACTOR=90)


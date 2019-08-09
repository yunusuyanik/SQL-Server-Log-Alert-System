USE [DBA_DB]
GO

/****** Object:  Table [dbo].[Log_JobHistory]    Script Date: 9.08.2019 10:52:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Log_JobHistory](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[check_date] [datetime] NULL,
	[job_name] [varchar](1000) NOT NULL,
	[step_name] [varchar](1000) NULL,
	[description] [varchar](8000) NULL,
	[job_owner] [varchar](128) NULL,
	[number_of_steps] [int] NULL,
	[is_enabled] [varchar](3) NULL,
	[frequency] [varchar](27) NULL,
	[subday_frequency] [varchar](16) NULL,
	[next_start_date] [datetime] NULL,
	[last_run_duration] [varchar](100) NULL,
	[last_start_date] [datetime] NULL,
	[last_run_message] [varchar](8000) NULL,
	[status] [varchar](8) NULL
) ON [PRIMARY]
GO


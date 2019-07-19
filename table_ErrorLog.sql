USE [DBA_DB]
GO

/****** Object:  Table [dbo].[ErrorLog]    Script Date: 7/19/2019 3:33:17 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[ErrorLog](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[check_date] [datetime] NULL,
	[server_name] [varchar](255) NULL,
	[instance_name] [varchar](255) NULL,
	[alert_group] [varchar](255) NULL,
	[alert_name] [varchar](255) NULL,
	[value] [decimal](18, 2) NULL,
	[status] [varchar](255) NULL,
	[error_message] [varchar](max) NULL,
	[error_number] [int] NULL,
	[priority] [int] NULL,
	[email_send] [bit] NULL,
 CONSTRAINT [PK_ErrorLog] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

ALTER TABLE [dbo].[ErrorLog] ADD  CONSTRAINT [DF__ErrorLog__email___3587F3E0]  DEFAULT ((0)) FOR [email_send]
GO



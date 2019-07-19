USE [DBA_DB]
GO

/****** Object:  Table [dbo].[ConfigThreshold]    Script Date: 7/19/2019 3:33:50 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[ConfigThreshold](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[customer_name] [varchar](255) NULL,
	[alert_group] [varchar](50) NULL,
	[is_active] [bit] NULL,
	[description] [varchar](500) NULL,
	[To] [varchar](50) NULL,
	[CC] [varchar](50) NULL,
	[BCC] [varchar](50) NULL,
	[profilename] [varchar](50) NULL,
	[value] [bigint] NULL,
	[last_check_date] [datetime] NULL,
	[last_mail_send] [datetime] NULL
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO



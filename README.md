# SQL Server Log Alert System
Log and Alert system for SQL Server

There are nine stored procedure, two tables and five jobs.

### usp_CatchAlert

<p>This stored procedure seeking for log tables. When it saw something wrong, it catch and send mail immediately.</p>

It check these things, for now;

1 - Job Failed

2 - Disk Free Size

3 - CPU

4 - TempDB Size

5 - Log File Size

6 - AlwaysOn Latency

7 - is_percent_growth=0


### usp_DriveStats
 
<p>This stored procedure</p>

### usp_FileStats
<p>This stored procedure</p>

### usp_Jobs
<p>This stored procedure</p>

### usp_PerfmonStats
<p>This stored procedure</p>

### usp_TableStats
<p>This stored procedure</p>

### usp_TableStats
<p>This stored procedure</p>

### usp_WaitStats
<p>This stored procedure</p>

### usp_Report
<p>This stored procedure</p>

### usp_WhoIsActive_Log
<p>This stored procedure : https://www.brentozar.com/archive/2016/07/logging-activity-using-sp_whoisactive-take-2/</p>

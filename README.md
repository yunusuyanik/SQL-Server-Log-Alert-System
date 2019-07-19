# SQL Server Log Alert System
Log and Alert system for SQL Server

There are nine stored procedure, two tables and five jobs.

<b>usp_CatchAlert</b>

<p>This stored procedure seeking for log tables. When it saw something wrong, it catch and send mail immediately.</p>

It check these things, for now;

1 - Job Failed

2 - Disk Free Size

3 - CPU

4 - TempDB Size

5 - Log File Size

6 - AlwaysOn Latency

7 - is_percent_growth=0


<b>usp_DriveStats</b>
<p>This stored procedure</p>

<b>usp_FileStats</b>
<p>This stored procedure</p>

<b>usp_Jobs</b>
<p>This stored procedure</p>

<b>usp_PerfmonStats</b>
<p>This stored procedure</p>

<b>usp_TableStats</b>
<p>This stored procedure</p>

<b>usp_TableStats</b>
<p>This stored procedure</p>

<b>usp_WaitStats</b>
<p>This stored procedure</p>

<b>usp_Report</b>
<p>This stored procedure</p>

<b>usp_WhoIsActive_Log</b>
<p>This stored procedure : https://www.brentozar.com/archive/2016/07/logging-activity-using-sp_whoisactive-take-2/</p>

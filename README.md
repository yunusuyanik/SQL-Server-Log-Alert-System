# SQL Server Log Alert System
Log and Alert system for SQL Server

There are ten stored procedure, two tables and five jobs.

### usp_CatchAlert

<p>This stored procedure seeking for log tables. When it saw something wrong, it catch and send mail immediately.</p>

It check these things, for now;

* Job Failed

* Disk Free Size

* CPU

* TempDB Size

* Log File Size

* AlwaysOn Latency

* is_percent_growth=0

* Severity>=16 errors.


### usp_DriveStats
 
<p>
ID,
check_date,
server_name,
instance_name,
volume_letter,
volume_label,
volume_capacity_gb,
volume_free_space_gb,
percentage_free_space</p>

### usp_FileStats
<p>
ID
check_date
database_id
file_id
database_name
file_name
type_desc
size_on_disk_mb
free_size_mb
io_stall_read_ms
num_of_reads
num_of_bytes_read
io_stall_write_ms
num_of_writes
num_of_bytes_written
growth
is_percent_growth
physical_file_name
</p>

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

### usp_ErrorLog
<p>This stored procedure</p>

### usp_WhoIsActive_Log
<p>This stored procedure : https://www.brentozar.com/archive/2016/07/logging-activity-using-sp_whoisactive-take-2/</p>

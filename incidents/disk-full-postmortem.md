Title: Disk Full Incident on sre-lab — Application Writes Failed 

  

Date: July 4 2026 

Duration: ~10 minutes (from disk hitting 100% to recovery) 

Severity: P1 — Critical (complete disk full, all writes failing) 

  

Summary: 

The sre-lab server disk reached 100% capacity causing all application  

writes to fail with "No space left on device" errors. The incident was  

caused by two large files filling 17GB of available disk space.  

Recovery was achieved by identifying and deleting the large files,  

restoring disk to 12% usage. 

  

Timeline: 

[14:32] Disk filled to 88% after largefile (15GB) written to disk 

[14:33] Second write attempt pushed disk to 100% 

[14:34] All writes failing — "No space left on device" 

[14:35] Incident detected, investigation began 

[14:36] Large files identified using du and find commands 

[14:37]Files verified safe to delete using ls -lah and lsof 

[14:38] Files deleted, disk recovered to 12% 

[14:39] Incident resolved 

  

Root Cause: 

Two large dummy files (largefile 15GB, testfile 2.3GB) were written  

to /home/ubuntu filling the 20GB disk to 100%. No disk monitoring  

alerts were in place to catch the gradual fill before it became critical. 

Log rotation was not configured allowing unbounded file growth. 

  

Impact: 

- All application writes failed during the incident 

- Any running application would have stopped logging 

- Database writes would have failed risking data corruption 

- Deployments would have failed 

- Duration of user impact: approximately 10 minutes 

  

What went wrong: 

1. No disk usage alert configured at 80% threshold 

2. No log rotation configured to prevent unbounded file growth 

3. No process to regularly audit large files on the server 

  

Action items to prevent recurrence: 

1. Configure disk alert at 80% threshold — Owner: SRE team — Due: immediately 

2. Configure logrotate for all application logs — Owner: SRE team — Due: this week 

3. Add disk usage check to monitoring script — Owner: Bethel— Due: today 

4. Document runbook for disk full incidents — Owner: Bethel— Due: this week 

Title: CPU spike above threshold  

  

Date: July 9 2026 

Duration: ~20 minutes (from CPU hitting 94.1% to recovery) 

Severity: P2 → High CPU on one core, performance degraded but not down 

  

Summary: 

The sre-lab-2 CPU reached 94.1 % capacity and consuming continuously, which will result to other process being slow. The incident was caused by a deliberate process added which was  running in the background, consuming 94.1% of one CPU core continuously with no resource limits configured. Recovery was achieved by identifying and killing the process, and CPU was restore to 0% usage. 

  

Timeline: 

[14:00] spike in CPU usage was identified after a process was added 

[14:02] incident detected and investigation commenced immediately 

[14:03] the process causing this spike was identified using uptime  commands 

[14:07] process was verified and ls -l /proc/1641/exe command was ran to confirm what process it was 

[14:08] process was killed using kill -15, CPU recovered to 0% 

[14:09] Incident resolved 

  

Root Cause: 

A CPU-intensive process (cat /dev/urandom | gzip -9) was deliberately  

run in the background, consuming 94.1% of one CPU core continuously 

with no resource limits configured. 

  

Impact: 

- performance degradtion 

- Duration of user impact: approximately 8 minutes 

  

What went wrong: 

1. No CPU usage alert configured at 75% threshold 

3. No resource limits configured on background processes allowing single process to consume entire CPU core 

  

Action items to prevent recurrence: 

1. Configure CPU alert at 75% threshold — Owner: SRE team — Due: immediately 

3. Add CPU usage check to monitoring script — Owner: Bethel— Due: today 

4. Document runbook for Cpu  recovery full incidents — Owner: Bethel— Due: this week. 

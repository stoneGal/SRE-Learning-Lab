Title: VM clock not in sync with the time on Servers on sre-lab-2 — Incorrect server time. 

  

Date: July 5 2026 

Duration: ~50minutes (from the time of checking the current sync status to recovery) 

Severity: P3 — Medium severity(log timestamp, incident timelines are inaccurate, failed verification due to SSL certificate) 

  

Summary: 

The server time was incorrect, resulting to wrong log timestamps and the incident timelines were inaccurate, inability to correlate logs across servers and TLS certificates may fail validation  

Timeline: 

[21:26] chronyd logs show first clock drift detected 

[21:37] Engineer noticed time sync issues while practicing 

[21:38] Ran chronyc tracking — confirmed not synchronised 

[21:39] Ran chronyc sources — found available sources 

[21:40] Ran sudo chronyc makestep — forced immediate sync 

[21:40] Confirmed recovery — Leap status: Normal 

  

Root Cause: 

The VM was suspended when the Mac slept. When it resumed, the clock had drifted 128 seconds and chrony could not find sync sources immediately after resume.  

 

Impact: 

-SSL certificate errors 

- Authentication failure 

- Log correlation breaks 

 

  

What went wrong: 

A monitoring check on chronyd service status was not configured 

An alert if clock drift exceeds 1 second was not configured 

A dashboard showing time sync status across all servers was not in place 

 

Action items to prevent recurrence: 

1. sets up a chronyd monitoring alert — Owner: SRE team — Due: immediately 

An alert if clock drift exceeds 1 second - Owner: Bethel — Due: immediately 

A dashboard showing time sync status across all servers: — Owner: SRE team — Due: 12th july 2026 

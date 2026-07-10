
Title :  Resource Exhaustion (RAM > Threshold)  

Date: 10th July 2026 

Duration: ~10 minutes (from initial memory anomaly to recovery) 

Severity : P2 → High memory utilization, swap activated, performance degraded no critical services affected 

 

Summary: 

A delibrate python process filled up and Memory usage steadily climbed from an idle baseline of   1.6Gi  and due to this Linux cleared some spaces in cache. Swap  triggered and a 0.1% of swap was also used, during this time there was no critical application disrupted till it was resolved. 

 
Timelines 

[10:58] Memory fill started, baseline 1.6Gi available 

[11:00] Available dropped to 311Mi — warning threshold breached (below 389Mi) 

[11:01] Available dropped to 135Mi — critical threshold breached (below 195Mi) 

[11:01] Swap activated at 1.0Mi used 

[11:01] Python script released memory, RAM recovered to 1.6Gi available 

[11:01] Incident resolved 

 

Root Cause: 

A Memory intensive python process  was deliberately  

run in the background with no resource limits configured.  

  

Impact: 

- performance degration due to Swap  

- There was no user impact  


What went wrong: 

1. No resource limits configured on background processes allowing single process to consume larger part of the memory 

  

Action items to prevent recurrence: 

Configure memory alert at 20% available threshold Owner: Bethel — Due: immediately 

Add memory check to monitoring script with swap monitoring Owner: Bethel — Due: today 

Configure resource limits on all application processes Owner: SRE team — Due: this week 

Document runbook for memory pressure incidents Owner: Bethel — Due: this week 

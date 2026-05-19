# Google Cloud NSI demo - Consumer

This module deploys a simple NSI consumer with two VM instances. Both instances are deployed into the same network and subnet, but the traffic between them will be inspected by the NSI.

Read through the main.tf code for the exact links between 
Firewall Rule > Firewall Policy > Security Profile > Intercept Endpoint Group

## Testing

Once deployed 

1. connect to consumer vm1 and try to reach vm2 from it. This connection will be intercepted by the ingress policy applied to vm2
1. from vm1 try to connect to any web service (eg. `curl https://google.com`) to trigger intercept for outbound connections to ports 80 and 443
1. observe intercepted traffic on producer FortiGates in the same zone
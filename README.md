## Purpose

Proof of concept for infrastructure required to launch a highly-scalable single-page blog in AWS. Also includes local development.


### Development

Development can be done locally by running

```
make development
```

This will start a Docker container on your local machine and bind the `html/` directory to the correct location inside an `nginx` container. The site will be accessible on `http://localhost`.

All code related to the site is located under `html/`


### Deploying to Production

The provided Terraform scripts will perform an end-to-end setup of the required infrastructure in AWS. Components include:

* VPC + Subnets + Security Groups
* Launch configurations and autoscaling groups
* ALB + Target Group associations for the Autoscaling group


You can deploy this code by typing `make deploy`


### Notes

* Currently the configuration in `Makefile` and `terraform/templates/*.tpl` use `daviddyball/ablog:latest` as the expected Docker image file name. Change as necessary.
* You may want to add SSH port access to the `web` security group in `terraform/site.tf` should you wish to do any remote debugging of launch configurations.
* The production autoscaling-group configuration uses "EC2" monitoring as default. This would be better implemented with "ELB" as the monitoring type, but you should test the deployment process before switching out to this, just to be sure that it works as expected and you don't spin up 1M ec2 instances while you try to debug any possible backend failures on the ALB.
* There aren't many moving parts to this infrastructure, so it is a good candidate for AWS serverless hosting via Lambda functions and API gateway. Worth a thought.
* Autoscaling of this infrastructure can be achieved using hooks to the ASG from the load-balancer. You can use request-based rules (requests/sec) or load-based rules (autoscaling group avg. CPU) to decide when to scale in more EC2 capacity.

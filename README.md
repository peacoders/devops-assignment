# devops_assignment
This repo contains all the necessary information/instructions for the DevOps assignment of Impactechs recruitment process. 

## TL;DR
The assigment has three parts: 
- Terraforming - Hack your way into a modular terraform project
- Architecture design - We want to design a new Netflix; well just in paper ;)
- Lets deploy something in Kubernetes - Containerize, deploy and monitor a sample Go application

### Terraforming
Dont worry about syntax, we just want to take refactor our Terraform scripts in a best practices project. Some requirements:
- Our DevOps team may work in parallel on the same infrastructure
- We want to avoid duplication - speed is important
- We want to deploy to 3 environments: Dev, Stage, Production
- Versions change, but it shouldn't break our scripts

#### What to deliver?
- A refactored project! Easily maintainable, modular and extendable
- A very brief explanation how you tackled the requirements. Code snippets are fine as well

### Architecture
Netflix is awesome! We want to design our own streaming platform and some requirements are: 
- Users should authenticate and authorized to access their accounts
- Users can save, rate and recommend to a friend any stream
- We would like to send recommendations to the users as well; lets dont waste time searching for what they might like
- Our billing should be instant, and accounting should have live feed on the data
- Our Dev would like to A/B test their new cool clent-side frontend design
- Our Ops team needs to monitor and be alerted for any issues

#### What to deliver?
An architecture diagram depicting the services and any infrastructure pieces the new Netflix will need. Here is the catch;
Also write us some notes on the problems you see in your design.

### Deploy something
We have included a dummy Golang (1.12) microservice which exposes 3 endpoints on port 8080: 
- /demo/random-error -> Randomly something goes wrong
- /demo/hello -> Hello world!
- /metrics -> We need to monitor some metrics

```go
go get -d -v -t
go test --cover -v ./... --run UnitTest
go build -v -o go-demo
```

This app should be containerized and should be shipped in a brand new K8s cluster. So we would like to: 
- Deploy a Prometheus server to monitor our app
- Deploy our app which should be accessible externally
- Our app should be highly available and scale based on resources automatically

#### What to deliver? 
- A Dockerfile 
- All the K8s deployment manifests that are needed to configure our monitoring and deploy our app into a 
cluster. You can use simple k8s manifests, Helm or kustomize. Totally up to you.
- Some notes on what else we might need for Ops or Dev 



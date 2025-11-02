# IAI Project

## IAC
AWS infrastructure, Creating separate subnets, public and private.

### Public Subnet
Has my NAT and ALB for both website access and the ability to access the internet.

### Private Subnet
Has my EKS nodes, where I deploy my website.

### Image
<img src="infra.png">

## Website

### Frontend
Written in javascript and html, the frontend is a simple api caller to the backend, written with python and flask.

### Backend
Written in Python with Flask, the backend has a JSON file consists of 50 users, with an api endpoint to search for a specific user.
The backend also has a logging mechanism, prints to stdout for future elk interaction.

## EKS
My EKS has an ingress to access the ALB, which aims directly to my frontend's service, that way users can access the website. The backend is only accessable through the frontend.

Deployment is done using helm.

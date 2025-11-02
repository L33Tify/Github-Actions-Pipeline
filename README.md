# IAI Project - User Management Web Application

A cloud-native user management application demonstrating modern DevOps practices with Infrastructure as Code, containerized applications, and Kubernetes deployment on AWS EKS.

## Project Overview

This project is a complete end-to-end demonstration that includes:
- **Infrastructure as Code** (Terraform) for AWS resource provisioning
- **Containerized microservices** (Frontend + Backend)
- **Kubernetes deployment** using Helm charts on AWS EKS
- **Automated deployment scripts** for streamlined operations

## Technologies & Components

### Cloud Infrastructure
- **AWS EKS** - Managed Kubernetes cluster
- **AWS ALB** - Application Load Balancer
- **AWS ECR** - Container registry for Docker images
- **AWS IAM** - Identity and access management
- **VPC with public/private subnets** 

### Infrastructure as Code
- **Terraform** - Infrastructure provisioning
- **Modules** - Reusable EKS cluster and node group components

### Application Stack
- **Backend**: Python + Flask
  - REST API for user search functionality
  - JSON database with 50 sample users
  - Structured logging
- **Frontend**: HTML + JavaScript

### Kubernetes & Deployment
- **Helm** - Package manager for Kubernetes applications
- **AWS Load Balancer Controller** - Manages ALB integration
- **Ingress** - Routes external traffic to frontend service
- **ConfigMaps & Secrets** - Configuration management

### Development Tools
- **Docker** - Containerization
- **Shell scripts** - Deployment automation
- **Git** - Version control

## Deployment Script Explanation

The `scripts/helm-aws-install.sh` script automates the aws ingress installation:

1. **Cluster Verification**: Confirms kubectl context points to the correct EKS cluster
2. **Infrastructure Discovery**: Retrieves VPC ID and IAM role ARN from AWS
3. **Load Balancer Controller**: Installs/upgrades AWS Load Balancer Controller via Helm
4. **Application Deployment**: Deploys the user-management-app Helm chart - makes sure the cluster has the app already running before running the workflow.
5. **Health Verification**: Waits for pods, ingress, and load balancer readiness
6. **Connectivity Test**: Validates the application is accessible via HTTP

## Infrastructure Architecture

### Network Design
- **Public Subnet**: Contains NAT Gateway and Application Load Balancer
- **Private Subnet**: Hosts EKS worker nodes (secure, no direct internet access)

### Security Model
- **Backend services**: Only accessible through frontend (internal communication)
- **Frontend service**: Exposed via ALB ingress for public access
- **EKS nodes**: Located in private subnets for enhanced security

### Architecture Diagram
<img src="infra.png" alt="Infrastructure Architecture">

## Application Features

### Backend API Endpoints
- `GET /users` - List all users
- `GET /users/search?name={query}` - Search users by name
- Health check and logging functionality

### Frontend Features
- Clean, responsive web interface
- Real-time user search functionality
- Error handling and loading states

## Install
set up aws-cli
```bash
cd iac
terraform init
terraform plan
terraform apply

cd scripts
./helm-aws-install
```

## Cleanup

To destroy all resources:

```bash
# Delete Kubernetes resources
helm uninstall user-management-app
helm uninstall aws-load-balancer-controller -n kube-system

# Destroy infrastructure
cd iac
terraform destroy
```

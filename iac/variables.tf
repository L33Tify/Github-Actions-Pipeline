variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name to be used for resource naming"
  type        = string
  default     = "user-management"
}

variable "aws_account_id" {
  description = "The AWS account ID"
  type        = string
  default     = "737210140690"
}

variable "github_deployer_user" {
  description = "The IAM username of the github-deployer user"
  type        = string
  default     = "github-deployer"
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "us-east-2a"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.11.0/24"
}

# EKS Variables
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "Instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

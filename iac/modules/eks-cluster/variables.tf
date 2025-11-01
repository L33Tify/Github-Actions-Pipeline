variable "project" {}
variable "vpc_id" {}
variable "subnet_ids" {
  type = list(string)
}
variable "cluster_version" {
  default = "1.33"
}
variable "aws_account_id" {
  description = "The AWS account ID"
  type        = string
  default     = "737210140690"
}

variable "github_deployer_user_arn" {
  description = "The ARN of the github-deployer IAM user"
  type        = string
  default     = ""
}

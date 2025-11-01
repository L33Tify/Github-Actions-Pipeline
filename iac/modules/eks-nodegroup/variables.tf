variable "project" {}
variable "cluster_name" {}
variable "subnet_ids" {
  type = list(string)
}
variable "instance_type" {
  default = "m7i-flex.large"
}

variable "desired_size" {
  default = 2
}
variable "min_size" {
  default = 2
}
variable "max_size" {
  default = 4
}

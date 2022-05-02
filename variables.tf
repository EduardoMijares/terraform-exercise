variable "aws_region" {
  description = "Default AWS Region"
  default     = "us-east-1"
}
variable "vpc_cidr1" {
  description = "VPC1 CIDR by default"
  default     = "10.0.0.0/16"
}
variable "vpc_cidr2" {
  description = "VPC2 CIDR by default"
  default     = "172.16.0.0/16"
}

#


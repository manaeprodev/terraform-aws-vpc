variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr_bloc" {
  type  = string
  description = "Le block CIDR du VPC"
  default = "172.18.0.0/19"
}

variable "vpc_name" {
  type = string
  description = "Name of the VPC"
  default = "insset-ccm"

}

variable "azs" {
  type = map(string)
  default = {
    "a" = 0,
    "b" = 1
  }
}


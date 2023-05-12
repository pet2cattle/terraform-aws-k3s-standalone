# tags

variable "tags" {
  type = map(string)
  default = {
    infra = "k3s"
    environment = "dev"
  }
}

# app

variable "k3s_cluster_name" {
  type = string
}

variable "k3s_token" {
  type = string
}

# instances

variable "ami_id" {
  type = string
  default = ""
}

# master ASG 

variable "k3s_master_instances" {
  type    = any
  default = {}
}

# IAM

variable "access_keys" {
  type    = any
  default = {}
}

# app buckets

variable "buckets" {
  type    = any
  default = {}
}

# IAM

variable "iam" {
  type    = any
  default = {}
}
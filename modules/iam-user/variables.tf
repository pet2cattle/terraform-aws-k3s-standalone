variable "k3s_cluster_name" {
  type = string
}

variable "iam_path" {
  type = string
  default = "/k3s/"
}

variable "users" {
  type = any
  default = {}
}

# TAGS

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}
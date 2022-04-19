variable "server_counts" {
  type    = map(number)
  default = {
    "gitlab"  = 1  # Key name is used for resource prefix
  }
}

variable "runner_counts" {
  type    = map(number)
  default = {
    "runner"  = 2  # Key name is used for resource prefix
  }
}

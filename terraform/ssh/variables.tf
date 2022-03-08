variable "ssh-server_counts" {
  type    = map(number)
  default = {
    "ssh-server"  = 1  # Key name is used for resource prefix
  }
}

variable "ssh-client_counts" {
  type    = map(number)
  default = {
    "ssh-client"  = 2  # Key name is used for resource prefix
  }
}

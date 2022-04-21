variable "runner_counts" {
  type    = map(number)
  default = {
    "runner"  = 2  # Key name is used for resource prefix
  }
}

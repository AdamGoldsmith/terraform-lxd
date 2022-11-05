variable "instance_counts" {
  type    = map(number)
  default = {
    "gitlab-runner" = 4  # Key name is used for resource prefix
  }
}

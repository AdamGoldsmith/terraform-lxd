variable "gitlab_counts" {
  type    = map(number)
  default = {
    "gitlab"  = 1  # Key name is used for resource prefix
  }
}

locals {
  gitlab_runner_names = {
    for name, count in var.runner_counts : name => [
      for i in range(1, count+1) : format("%s-%02d", name, i)
    ]
  }
}

# Get CloudInit user data info
data "template_file" "user_data" {
  template = file("${path.module}/../config/cloud_init.yml")
}

# Create container profile
resource "lxd_profile" "config" {
  name = "runner_config"

  config = {
    "limits.cpu"          = 2
    "limits.memory"       = "2048MB"
    "user.vendor-data"    = data.template_file.user_data.rendered
  }
}

# Create LXD GitLab Runner containers
resource "lxd_container" "gitlab_runner" {
  for_each   = toset(local.gitlab_runner_names.runner)
  name       = each.key
  # Using a cloud-based image will allow cloud-init configuration (ubuntu images just work)
  image      = "ubuntu:20.04"
  ephemeral  = false
  profiles   = ["default", lxd_profile.config.name]
}

locals {
  container_names = {
    for name, count in var.vm_counts : name => [
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
  name = "config"

  config = {
    "limits.cpu" = 2
    "user.vendor-data" = data.template_file.user_data.rendered
  }
}

# Create LXD containers
resource "lxd_container" "vault" {
  for_each  = toset(local.container_names.vault)
  name      = each.key
  image     = "ubuntu:20.04"
  # Using a cloud-based image will allow cloud-init configuration
  // image     = "images:centos/7/cloud"
  // image     = "images:almalinux/8/cloud"
  // I couldn't get cloud-init working when using type of virtual-machine
  // type      = "virtual-machine"
  ephemeral = false
  profiles  = ["default", lxd_profile.config.name]
}

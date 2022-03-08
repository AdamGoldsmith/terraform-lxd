locals {
  ssh_server_names = {
    for name, count in var.ssh-server_counts : name => [
      for i in range(1, count+1) : format("%s-%02d", name, i)
    ]
  }
}

locals {
  ssh_client_names = {
    for name, count in var.ssh-client_counts : name => [
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
  name = "ssh_config"

  config = {
    "limits.cpu" = 2
    "user.vendor-data" = data.template_file.user_data.rendered
  }
}

# Create LXD SSH Server containers
resource "lxd_container" "ssh_server" {
  for_each  = toset(local.ssh_server_names.ssh-server)
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

# Create LXD SSH Client containers
resource "lxd_container" "ssh_client" {
  for_each  = toset(local.ssh_client_names.ssh-client)
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

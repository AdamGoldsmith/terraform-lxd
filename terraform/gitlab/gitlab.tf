locals {
  gitlab_names = {
    for name, count in var.server_counts : name => [
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
  name = "gitlab_config"

  config = {
    "limits.cpu"          = 4
    "limits.memory"       = "4096MB"
    "user.vendor-data"    = data.template_file.user_data.rendered
  }
}

# Create storage pool
resource "lxd_storage_pool" "gitlab" {
  name = "gitlab"
  driver = "dir"
  config = {
    source = "/var/lib/lxd/storage-pools/gitlab"
  }
}

# Create storage volume
resource "lxd_volume" "gitlab1" {
  name = "gitlab1"
  pool = "${lxd_storage_pool.gitlab.name}"
}

# Create LXD GitLab Server containers
resource "lxd_container" "gitlab" {
  for_each   = toset(local.gitlab_names.gitlab)
  name       = each.key
  # Using a cloud-based image will allow cloud-init configuration (ubuntu images just work)
  // image      = "images:centos/7/cloud"
  // image      = "images:almalinux/8/cloud"
  // image      = "ubuntu:18.04"
  image      = "ubuntu:20.04"
  // I couldn't get cloud-init working when using type of virtual-machine
  // type       = "virtual-machine"
  ephemeral  = false
  profiles   = ["default", lxd_profile.config.name]

  config = {
    "security.privileged" = 1
    "raw.lxc"             = "lxc.apparmor.profile = unconfined"
  }

  device {
    name = "volume1"
    type = "disk"
    properties = {
      path   = "/opt/gitlab"
      source = "${lxd_volume.gitlab1.name}"
      pool   = "${lxd_storage_pool.gitlab.name}"
    }
  }
}

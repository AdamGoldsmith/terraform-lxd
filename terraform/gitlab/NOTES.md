# Notes

When creating the container for gitlab there are some special requirements. In the lxd_container resoource creation section of the file `terraform/gitlab/gitlab.tf`, notice the following options:

```
  config = {
    "security.privileged" = 1
    "raw.lxc"             = "lxc.apparmor.profile = unconfined"
  }
```

These are required to allow the GitLab installation to change the host systems kernel settings. The `security.privileged` config setting can be disabled after installing GitLab

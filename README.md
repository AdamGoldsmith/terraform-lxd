# Deploy Vault instances on LXD using Ansible + Terraform

## Prerequisites

* lxd >4.0
* lxc
* Ansible
  * community.crypto.openssh_keypair plugin (install with `ansible-galaxy collection install community.crypto`)
  * community.general.lxd (install with `ansible-galaxy collection install community.general`)
* Terraform

## Running the code (TL;DR)

TODO: Tidy up

1. Clone repo
1. `cd ansible`
1. `ansible-playbook playbooks/localhost/localhost.yml`
1. `cd ../terraform/gitlab/server`
1. `terraform init`
1. `terraform apply --auto-approve`
1. `cd ../runner`
1. `terraform init`
1. `terraform apply --auto-approve`
1. `cd ../../vault`
1. `terraform init`
1. `terraform apply --auto-approve`
1. `cd ../../ansible`
1. Test ansible connectivity: `ansible lxd -m ping`
1. Connect directly: `ssh -i ssh_keys/id_ansible ansible@x.x.x.x` (grab IP from `lxc list` output)
1. `ansible-playbook playbooks/site.yml`

# Known issues

1. Raft storage cluster nodes do not connect on CentOS-based images so using Ubuntu images instead.

# TODO:

1. Add ssh server terraform deployment method and docs
1. Remove roles from repo and clone them when needed instead
1. Add GitLab backup/restore functionality/roles
1. Tidy up variables & remove unused ones
1. Consider shifing the CloudInit config directory into each project dir to keep it grouped
1. Update README :-)

# References

This blog helped me select the correct LXD configuration & LXC container settings:
https://blog.canutethegreat.com/portable-devops-platform-gitlab-in-an-lxd-container-db2850224caf

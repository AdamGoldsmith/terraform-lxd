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
1. `ansible-playbook playbooks/site.yml`
1. `cd ../terraform/vault`
1. `terraform init`
1. `terraform apply`
1. `cd ../../ansible`
1. `ansible vault -m ping`
1. Connect directly: `ssh -i ssh_keys/id_ansible ansible@x.x.x.x` (grab IP from `lxc list` output)

# Known issues

1. Raft storage cluster nodes do not connect on Centos based images

# TODO:

1. Tidy up variables & remove unused ones
1. Consider shifing the CloudInit config directory into each project dir to keep it grouped
1. Update README :-)

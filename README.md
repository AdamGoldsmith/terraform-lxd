# Deploy GitLab, Vault & Traefik instances on LXD using Ansible + Terraform

## Network Connectivity Overiew

```mermaid
flowchart BT
  dns(DNS) --> |"172.32.0.10"| user([User])
  style user color:#cc0,stroke:#cc0,fill:#fff
  user --> |"gitlab.example.com"| dns
  user([User]) --> |"http(s)://gitlab.example.com"| router{192.168.0.1<br/>Router<br/>172.32.0.10}
  subgraph INTERNAL
    style INTERNAL color:#fff,stroke:#0af,stroke-width:3px,fill:#fff
    router --> |":80 -> 192.168.0.2:8080" | lxd_host[LXD Host]
    router --> |":443 -> 192.168.0.2:4443"| lxd_host[LXD Host]
    style router fill:#0af
    lxd_host --> |":8080 -> :80" | lxc_traefik[Traefik Proxy]
    lxd_host --> |":4443 -> :443"| lxc_traefik[Traefik Proxy]
    style lxd_host fill:#0af
    style lxc_traefik fill:#0d0
    subgraph LXD
      direction BT
      style LXD color:#0d0,stroke:#0d0,stroke-width:3px,fill:#fff,stroke-dasharray: 10 5
      lxc_gr1[gitlab-runner-01]
      style lxc_gr1 fill:#0d0
      lxc_gr2[gitlab-runner-02]
      style lxc_gr2 fill:#0d0
      lxc_traefik --> |":8080 -> gitlab-server-01.lxd:80" | lxc_gs[gitlab-server-01]
      lxc_traefik --> |":4443 -> gitlab-server-01.lxd:443"| lxc_gs[gitlab-server-01]
      style lxc_gs fill:#0d0
      lxc_vs1[vault-server-01]
      style lxc_vs1 fill:#0d0
      lxc_vs2[vault-server-02]
      style lxc_vs2 fill:#0d0
    end
  end
  subgraph KEY
    style KEY stroke:#000,stroke-width:3px,fill:#eee
    direction LR
    physical["Physical Hardware"]
    virtual["Virtual LXC Container"]
    style physical fill:#0af
    style virtual fill:#0d0
  end
```

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
1. `ansible-playbook playbooks/site.yml --tags localhost`
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
1. Test elevated privilege ansible connectivity: `ansible lxd -b -m ping`
1. Connect directly: `ssh -i ssh_keys/id_ansible ansible@x.x.x.x` (grab IP from `lxc list` output)
1. `ansible-playbook playbooks/site.yml --skip-tags runner_register`
1. Navigate to GitLab "runners" page (under "admin") and copy the runner registration token
1. `ansible-playbook playbooks/site.yml --tags runner_register -e "runner_registration_token=vMZms9z6uKBKcxxKTDAC"`

# Known issues

1. Raft storage cluster nodes do not connect on CentOS-based images so using Ubuntu images instead.

# TODO:

1. Add ssh server terraform deployment method and docs
1. Remove roles from repo and clone them when needed instead
1. When using gitlab container registry -> set up 5050 rule from LXD host to traefik (initially I went direct to gitlab instance), then update `volume` config for runners
1. Ansiblise the CA, key, crt & csr creation steps for traefik mTLS (see [these notes](ansible/playbooks/traefik/config_notes.md) for details)
1. Fix GitLab mail
1. Add GitLab backup/restore functionality/roles
1. Consider making runner registration idempotent - currently keeps registering runners
1. Tidy up variables & remove unused ones
1. Convert module names to FQCNs
1. Consider shifting the CloudInit config directory into each project dir to keep it grouped
1. Create unit file for traefik service
1. Consider using Vault as CA for self-signed traefik certs
1. Update README :-)

# My goal

Create a Gitlab instance that uses Vault for secret management

# My journey

This repo has evolved over a long time from initially standing up a 3-node cluster of vault servers using virtualbox. Not before long, I realised vbox was slow and not very scallable. So I then started devloping on GCP using Terraform - that was fun and made life easier (actually it made it more complicated at first having to learn new concepts and tools but nonetheless the right way to do things). After a year my free subscription ran out which left me a bit lost, so I turned back to self-hosting. I bought a powerful Mini PC from Asus and set about creating my home lab. Wanting to continue using Terraform and being able to scale my infrastructure, I chose LXC/LXD as my platform. There are terraform and Ansible plugins that allow me to spin up instances and connect dynamically if a bit of prep work has been done. My journey has definitely branched out from my initial goal which has been great for learning new technology and tools. One of the best ones is the reverse proxy `traefik` which has forced me to learn/bolster knowledge of concepts that I only half-understood eg TLS/mTLS.

Here, I attempt to show the current status of the project in bullet points:

* Host Server
  * Asus PN51 running Ubuntu Desktop 22.04
* Hypervisor
  * LXD
* Ansible
  * **Preparation**: Create SSH key pairs locally & creat the cloud init config for the LXC containers
  * **Provision**: Configure target hosts with services (traefik, vault, gitlab)
* Terraform
  * Manage LXC container deployments
    Service | Instances
    --------|----------
    Traefik | 1
    Gitlab Server | 1
    Gitlab Runners | 4
    Vault Servers | 3
    Web Servers | 5
* Traefik
  * Reverse proxy for redirecting sub-domain traffic to LXC containers
  * Uses a mixture of TLS configurations
    * TLS passthrough for Gitlab instance as it already uses letsencrypt
    * Other services have TLS termination at traefik server (automatically retrieving certs from LetsEncrypt - brilliant!)
    * Originally used HTTP for upstream backend LCX connections
    * Configured HTTPS using self-signed certificates for upstream traffic
    * Intend to use mTLS so backend upstream services can trust the traefik server
    * Consider using Vault as the CA for certs
* Vault
  * 3 node cluster
  * Only accessible internally (considering opening this up...)
* Gitlab
  * 1 server instance
  * 4 runners using docker-in-docker for pipelines
* Web servers
  * Only playing with these at the moment
  * Load balanced behind traefik instance
  * Testing TLS/mTLS configurations

# Renewing SSL certificates

1. Login to gitlab server
    ```bash
    gitlab-ctl renew-le-certs
    ```
1. Put new certs on gitlab runners, from code repo (update gitlab_server_address accordingly)
   ```bash
   ansible-playbook playbooks/runner/runner.yml -e "gitlab_server_address=gitlab.example.com" --tags runner_certs
   ```

# GitLab Pipeline Notes

`gitlab-ci.yml`
```
# This pipeline will build from Dockerfile, test the newly-built image, then, if successful, push
# the image to GitLab Container Registry with a specified tag (defaults to latest if not specified)
variables:
  TAG_VERSION:
    value: "latest"
    description: "Version to tag image after successful testing"
  TAG_LATEST: ${CI_REGISTRY_IMAGE}/${CI_COMMIT_REF_NAME}/my-nginx:${TAG_VERSION}
  TAG_COMMIT: ${CI_REGISTRY_IMAGE}/${CI_COMMIT_REF_NAME}/my-nginx:${CI_COMMIT_SHORT_SHA}

stages:
  - build
  - test
  - push

docker_build:
  stage: build
  script:
    - echo -n ${CI_REGISTRY_PASSWORD} | docker login -u ${CI_REGISTRY_USER} --password-stdin ${CI_REGISTRY}
    - docker build -t ${TAG_COMMIT} ./docker
    - docker push ${TAG_COMMIT}

docker_test:
  stage: test
  image: ${TAG_COMMIT}
  services:
    - name: ${TAG_COMMIT}
      alias: my-nginx
  script:
    - curl http://my-nginx:80

docker_push:
  stage: push
  script:
    - echo -n ${CI_REGISTRY_PASSWORD} | docker login -u ${CI_REGISTRY_USER} --password-stdin ${CI_REGISTRY}
    - docker pull ${TAG_COMMIT}
    - echo "Tagging ${TAG_COMMIT} with \"${TAG_VERSION}\""
    - docker tag ${TAG_COMMIT} ${TAG_LATEST}
    - docker push ${TAG_LATEST}
```

# References

This blog helped me select the correct LXD configuration & LXC container settings:
https://blog.canutethegreat.com/portable-devops-platform-gitlab-in-an-lxd-container-db2850224caf

This may be useful for running packer on LXC images in a pipeline using a docker-based runner
https://github.com/micw/docker-lxc-demo/blob/master/Dockerfile

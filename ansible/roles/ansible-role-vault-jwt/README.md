# ansible-role-vault-jwt

Configure Hashicorp's Vault JWT authentication method by
* Enabling JWT authentication method
* Configuring JWT authentication method
* Configuring GitLab access policy
* Configuring GitLab role

Currently tested on these Operating Systems
* Oracle Linux/RHEL/CentOS
* Debian/Stretch64

## References

Role creation was based on this [GitLab documentation](https://docs.gitlab.com/ee/ci/secrets/) for using external secrets in CI

## Requirements

* Ansible 2.5 or higher

## Role Variables

`defaults/main.yml`
```yaml
vault_tls_disable: "false"                                                      # Choose whether to disable TLS for vault connections (not advised)
vault_protocol: "{{ vault_tls_disable | bool | ternary('http', 'https') }}"     # HTTP/HTTPS connection to Vault service - default HTTPS
vault_addr: "{{ ansible_fqdn }}"                                                # Vault listener address
vault_port: 8200                                                                # Vault listener port
vault_keysfile: "~/.hashicorp_vault_keys.json"                                  # Local file storing master key shards
vault_admintokenfile: "~/.hashicorp_admin_token.json"                           # Local file storing admin token
jwks_domain: "gitlab.example.com"                                               # Name of GitLab domain
```

## Dependencies

None

## Example Playbook

```yaml
---

- name: Enable HashiCorp Vault JWT (JSON Web Token)
  hosts: vault
  become: no
  gather_facts: yes
  run_once: yes
  tags:
    - vault
    - vault_jwt

  tasks:

    - name: Run vault server jwt role
      include_role:
        name: ansible-role-vault-jwt
```

## License

MIT License

## Author Information

Adam Goldsmith

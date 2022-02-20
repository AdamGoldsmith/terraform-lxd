variable "vm_counts" {
  type    = map(number)
  default = {
    "vault"  = 3  # Key name is used for resource prefix
  }
}

// resource "random_pet" "server_name" {
//   for_each = toset(var.vault_instances)
// }

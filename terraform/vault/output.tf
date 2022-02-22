# Output container names
// output "pet_names" {
//   value = [
//     for pet in random_pet.server_name:
//       pet.id
//   ]
// }

output "container_info" {
  description = "Container info"
  value = [
    for container in lxd_container.vault: {
      (container.name) = {
        image     = container.image
        ip        = container.ip_address
      }
    }
  ]
}
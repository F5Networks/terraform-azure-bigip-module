output "mgmtPublicIP" {
  value = module.bigip.*.mgmtPublicIP
}

output "mgmtPublicDNS" {
  value = module.bigip.*.mgmtPublicDNS
}
output "bigip_username" {
  value = module.bigip.*.f5_username
}

output "bigip_password" {
  value = module.bigip.*.bigip_password
}

output "mgmtPort" {
  value = module.bigip.*.mgmtPort
}

output "mgmtPublicURL" {
  description = "mgmtPublicURL"
  value       = [for i in range(var.instance_count) : format("https://%s:%s", module.bigip[i].mgmtPublicDNS, module.bigip[i].mgmtPort)]
}

output "resourcegroup_name" {
  description = "Resource Group in which objects are created"
  value       = azurerm_resource_group.rg.name
}

output "public_addresses" {
  value = module.bigip.*.public_addresses
}

output "private_addresses" {
  value = module.bigip.*.private_addresses
}

output "bigip_instance_ids" {
  value = module.bigip.*.bigip_instance_ids
}

output "external_public_primary_private_ip" {
  description = "List of external_public_primary_private_ip"
  value       = flatten([for i in range(length(module.bigip.*.private_addresses)) : module.bigip.*.private_addresses[i]["public_private"]["private_ip"]])
}

output "bigip_nic_ids" {
  value = module.bigip.*.bigip_nic_ids
}

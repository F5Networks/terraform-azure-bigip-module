output "mgmtPublicIP" {
  value = module.bigip.*.mgmtPublicIP[0]
}

output "mgmtPublicDNS" {
  value = module.bigip.*.mgmtPublicDNS[0]
}
output "bigip_username" {
  value = module.bigip.*.f5_username[0]
}

output "bigip_password" {
  value = module.bigip.*.bigip_password[0]
}

output "mgmtPort" {
  value = module.bigip.*.mgmtPort[0]
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


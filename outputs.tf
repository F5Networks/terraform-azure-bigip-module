output "mgmtPublicIP" {
  description = "The actual ip address allocated for the resource."
  value       = length(local.mgmt_public_subnet_id) > 0 ? azurerm_public_ip.mgmt_public_ip[0].ip_address : azurerm_network_interface.mgmt_nic[0].private_ip_address

}

output "mgmtPublicDNS" {
  description = "fqdn to connect to the first vm provisioned."
  value       = length(local.mgmt_public_subnet_id) > 0 ? azurerm_public_ip.mgmt_public_ip[0].fqdn : azurerm_network_interface.mgmt_nic[0].private_ip_address

}


output "mgmtPort" {
  description = "Mgmt Port"
  value       = local.total_nics > 1 ? "443" : "8443"
}


output "f5_username" {
  value = (var.custom_user_data == null) ? var.f5_username : "Username as provided in custom runtime-init"
}

output "bigip_password" {
  description = <<-EOT
 "Password for bigip user ( if dynamic_password is choosen it will be random generated password or if azure_keyvault is choosen it will be key vault secret name )
  EOT
  value       = (var.custom_user_data == null) ? ((var.f5_password == "") ? (var.az_keyvault_authentication ? data.azurerm_key_vault_secret.bigip_admin_password[0].name : random_string.password.result) : var.f5_password) : "Password as provided in custom runtime-init"
}

output "onboard_do" {
  value = local.total_nics > 1 ? (local.total_nics == 2 ? local.clustermemberDO2 : local.clustermemberDO3) : local.clustermemberDO1
}

output "public_addresses" {
  description = "List of BIG-IP public addresses"
  value = {
    external_primary_public   = concat(azurerm_public_ip.external_public_ip.*.ip_address)
    external_secondary_public = concat(azurerm_public_ip.secondary_external_public_ip.*.ip_address)
  }
  // value       = concat(azurerm_public_ip.external_public_ip.*.ip_address, azurerm_public_ip.secondary_external_public_ip.*.ip_address)
}

output "private_addresses" {
  description = "List of BIG-IP private addresses"
  value = {
    mgmt_private = {
      private_ip  = concat(azurerm_network_interface.mgmt_nic.*.private_ip_address)
      private_ips = concat(azurerm_network_interface.mgmt_nic.*.private_ip_addresses)
    }
    public_private = {
      private_ip  = concat(azurerm_network_interface.external_public_nic.*.private_ip_address)
      private_ips = concat(azurerm_network_interface.external_public_nic.*.private_ip_addresses)
    }
    external_private = {
      private_ip  = concat(azurerm_network_interface.external_nic.*.private_ip_address)
      private_ips = concat(azurerm_network_interface.external_nic.*.private_ip_addresses)
    }
    internal_private = {
      private_ip  = concat(azurerm_network_interface.internal_nic.*.private_ip_address)
      private_ips = concat(azurerm_network_interface.internal_nic.*.private_ip_addresses)
    }
  }
}

output "bigip_instance_ids" {
  value = concat(azurerm_linux_virtual_machine.f5vm01.*.id)[0]
}

output "bigip_nic_ids" {
  description = "List of BIG-IP network interface IDs"
  value = {
    mgmt_nics     = azurerm_network_interface.mgmt_nic.*.id
    public_nics   = azurerm_network_interface.external_public_nic.*.id
    external_nics = azurerm_network_interface.external_nic.*.id
    internal_nics = azurerm_network_interface.internal_nic.*.id
  }
}
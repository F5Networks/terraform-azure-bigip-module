terraform {
  required_version = ">= 0.14.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">2.3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">2.1.2"
    }
  }
}

locals {
  bigip_map = {
    "mgmt_subnet_ids"            = var.mgmt_subnet_ids
    "mgmt_securitygroup_ids"     = var.mgmt_securitygroup_ids
    "external_subnet_ids"        = var.external_subnet_ids
    "external_securitygroup_ids" = var.external_securitygroup_ids
    "internal_subnet_ids"        = var.internal_subnet_ids
    "internal_securitygroup_ids" = var.internal_securitygroup_ids
  }

  mgmt_public_subnet_id = [
    for subnet in local.bigip_map["mgmt_subnet_ids"] :
    subnet["subnet_id"]
    if subnet["public_ip"] == true
  ]

  mgmt_public_private_ip_primary = [
    for private in local.bigip_map["mgmt_subnet_ids"] :
    private["private_ip_primary"]
    if private["public_ip"] == true && private["private_ip_primary"] != ""
  ]
  mgmt_public_index = [
    for index, subnet in local.bigip_map["mgmt_subnet_ids"] :
    index
    if subnet["public_ip"] == true
  ]
  mgmt_public_security_id = [
    for i in local.mgmt_public_index : local.bigip_map["mgmt_securitygroup_ids"][i]
  ]
  mgmt_private_subnet_id = [
    for subnet in local.bigip_map["mgmt_subnet_ids"] :
    subnet["subnet_id"]
    if subnet["public_ip"] == false
  ]
  mgmt_private_ip_primary = [
    for private in local.bigip_map["mgmt_subnet_ids"] :
    private["private_ip_primary"]
    if private["public_ip"] == false && private["private_ip_primary"] != ""
  ]
  mgmt_private_index = [
    for index, subnet in local.bigip_map["mgmt_subnet_ids"] :
    index
    if subnet["public_ip"] == false
  ]
  mgmt_private_security_id = [
    for i in local.mgmt_private_index : local.bigip_map["mgmt_securitygroup_ids"][i]
  ]
  external_public_subnet_id = [
    for subnet in local.bigip_map["external_subnet_ids"] :
    subnet["subnet_id"]
    if subnet["public_ip"] == true
  ]
  external_public_private_ip_primary = [
    for private in local.bigip_map["external_subnet_ids"] :
    private["private_ip_primary"]
    if private["public_ip"] == true
  ]
  external_public_private_ip_secondary = [
    for private in local.bigip_map["external_subnet_ids"] :
    private["private_ip_secondary"]
    if private["public_ip"] == true
  ]
  external_public_index = [
    for index, subnet in local.bigip_map["external_subnet_ids"] :
    index
    if subnet["public_ip"] == true
  ]
  external_public_security_id = [
    for i in local.external_public_index : local.bigip_map["external_securitygroup_ids"][i]
  ]
  external_private_subnet_id = [
    for subnet in local.bigip_map["external_subnet_ids"] :
    subnet["subnet_id"]
    if subnet["public_ip"] == false
  ]
  external_private_ip_primary = [
    for private in local.bigip_map["external_subnet_ids"] :
    private["private_ip_primary"]
    if private["public_ip"] == false
  ]
  external_private_ip_secondary = [
    for private in local.bigip_map["external_subnet_ids"] :
    private["private_ip_secondary"]
    if private["public_ip"] == false
  ]
  external_private_index = [
    for index, subnet in local.bigip_map["external_subnet_ids"] :
    index
    if subnet["public_ip"] == false
  ]
  external_private_security_id = [
    for i in local.external_private_index : local.bigip_map["external_securitygroup_ids"][i]
  ]
  internal_public_subnet_id = [
    for subnet in local.bigip_map["internal_subnet_ids"] :
    subnet["subnet_id"]
    if subnet["public_ip"] == true
  ]
  internal_public_index = [
    for index, subnet in local.bigip_map["internal_subnet_ids"] :
    index
    if subnet["public_ip"] == true
  ]
  internal_public_security_id = [
    for i in local.internal_public_index : local.bigip_map["internal_securitygroup_ids"][i]
  ]
  internal_private_subnet_id = [
    for subnet in local.bigip_map["internal_subnet_ids"] :
    subnet["subnet_id"]
    if subnet["public_ip"] == false
  ]
  internal_private_index = [
    for index, subnet in local.bigip_map["internal_subnet_ids"] :
    index
    if subnet["public_ip"] == false
  ]
  internal_private_ip_primary = [
    for private in local.bigip_map["internal_subnet_ids"] :
    private["private_ip_primary"]
    if private["public_ip"] == false
  ]
  internal_private_security_id = [
    for i in local.internal_private_index : local.bigip_map["internal_securitygroup_ids"][i]
  ]
  total_nics      = length(concat(local.mgmt_public_subnet_id, local.mgmt_private_subnet_id, local.external_public_subnet_id, local.external_private_subnet_id, local.internal_public_subnet_id, local.internal_private_subnet_id))
  vlan_list       = concat(local.external_public_subnet_id, local.external_private_subnet_id, local.internal_public_subnet_id, local.internal_private_subnet_id)
  selfip_list     = concat(azurerm_network_interface.external_nic.*.private_ip_address, azurerm_network_interface.external_public_nic.*.private_ip_address, azurerm_network_interface.internal_nic.*.private_ip_address)
  instance_prefix = format("%s-%s", var.prefix, random_id.module_id.hex)
  gw_bytes_nic    = local.total_nics > 1 ? element(split("/", local.selfip_list[0]), 0) : ""

  clustermemberDO1 = local.total_nics == 1 ? templatefile("${path.module}/templates/onboard_do_1nic.tpl", {
    hostname      = length(local.mgmt_public_subnet_id) > 0 ? azurerm_public_ip.mgmt_public_ip[0].fqdn : azurerm_network_interface.mgmt_nic[0].private_ip_address
    name_servers  = join(",", formatlist("\"%s\"", ["169.254.169.253"]))
    search_domain = "f5.com"
    ntp_servers   = join(",", formatlist("\"%s\"", ["169.254.169.123"]))
  }) : ""

  clustermemberDO2 = local.total_nics == 2 ? templatefile("${path.module}/templates/onboard_do_2nic.tpl", {
    hostname      = length(local.mgmt_public_subnet_id) > 0 ? azurerm_public_ip.mgmt_public_ip[0].fqdn : azurerm_network_interface.mgmt_nic[0].private_ip_address
    name_servers  = join(",", formatlist("\"%s\"", ["169.254.169.253"]))
    search_domain = "f5.com"
    ntp_servers   = join(",", formatlist("\"%s\"", ["169.254.169.123"]))
    vlan-name     = element(split("/", local.vlan_list[0]), length(split("/", local.vlan_list[0])) - 1)
    self-ip       = local.selfip_list[0]
    gateway       = join(".", concat(slice(split(".", local.gw_bytes_nic), 0, 3), [1]))
  }) : ""

  clustermemberDO3 = local.total_nics >= 3 ? templatefile("${path.module}/templates/onboard_do_3nic.tpl", {
    hostname      = length(local.mgmt_public_subnet_id) > 0 ? azurerm_public_ip.mgmt_public_ip[0].fqdn : azurerm_network_interface.mgmt_nic[0].private_ip_address
    name_servers  = join(",", formatlist("\"%s\"", ["169.254.169.253"]))
    search_domain = "f5.com"
    ntp_servers   = join(",", formatlist("\"%s\"", ["169.254.169.123"]))
    vlan-name1    = element(split("/", local.vlan_list[0]), length(split("/", local.vlan_list[0])) - 1)
    self-ip1      = local.selfip_list[0]
    vlan-name2    = element(split("/", local.vlan_list[1]), length(split("/", local.vlan_list[1])) - 1)
    self-ip2      = local.selfip_list[1]
    gateway       = join(".", concat(slice(split(".", local.gw_bytes_nic), 0, 3), [1]))
  }) : ""

  tags = merge(var.tags, {
    Prefix = format("%s", local.instance_prefix)
  source = "terraform" })
}

#
# Create a random id
#
resource "random_id" "module_id" {
  byte_length = 2
}

data "azurerm_resource_group" "bigiprg" {
  name = var.resource_group_name
}

data "azurerm_subscription" "current" {
}
data "azurerm_client_config" "current" {
}

resource "azurerm_user_assigned_identity" "user_identity" {
  count               = var.user_identity == null ? 1 : 0
  name                = format("%s-ident", local.instance_prefix)
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = merge(local.tags, {
    Name = format("%s-ident", local.instance_prefix)
    }
  )
}

data "azurerm_resource_group" "rg_keyvault" {
  name  = var.azure_secret_rg
  count = var.az_keyvault_authentication ? 1 : 0
}

data "azurerm_key_vault" "keyvault" {
  count               = var.az_keyvault_authentication ? 1 : 0
  name                = var.azure_keyvault_name
  resource_group_name = data.azurerm_resource_group.rg_keyvault[count.index].name
}

data "azurerm_key_vault_secret" "bigip_admin_password" {
  count        = var.az_keyvault_authentication ? 1 : 0
  name         = var.azure_keyvault_secret_name
  key_vault_id = data.azurerm_key_vault.keyvault[count.index].id
}


resource "azurerm_key_vault_access_policy" "example" {
  count        = var.az_keyvault_authentication ? 1 : 0
  key_vault_id = data.azurerm_key_vault.keyvault[count.index].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.user_identity == null ? azurerm_user_assigned_identity.user_identity[0].principal_id : var.user_identity

  key_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore",
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Restore", "Backup", "Purge",
  ]
}

#
# Create random password for BIG-IP
#
resource "random_string" "password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

# Create a Public IP for bigip
resource "azurerm_public_ip" "mgmt_public_ip" {
  count               = length(local.mgmt_public_subnet_id)
  name                = "${local.instance_prefix}-pip-mgmt-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  domain_name_label   = format("%s-mgmt-%s", local.instance_prefix, count.index)
  allocation_method   = "Static"   # Static is required due to the use of the Standard sku
  sku                 = "Standard" # the Standard sku is required due to the use of availability zones
  // availability_zone   = var.availabilityZones_public_ip
  tags = merge(local.tags, {
    Name = format("%s-pip-mgmt-%s", local.instance_prefix, count.index)
    }
  )
}

resource "azurerm_public_ip" "external_public_ip" {
  count               = length(local.external_public_subnet_id)
  name                = "${local.instance_prefix}-pip-ext-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  domain_name_label   = format("%s-ext-%s", local.instance_prefix, count.index)
  allocation_method   = "Static"   # Static is required due to the use of the Standard sku
  sku                 = "Standard" # the Standard sku is required due to the use of availability zones
  tags = merge(local.tags, {
    Name = format("%s-pip-ext-%s", local.instance_prefix, count.index)
    }
  )
}

resource "azurerm_public_ip" "secondary_external_public_ip" {
  count               = var.cfe_secondary_vip_disable ? 0 : length(local.external_public_subnet_id)
  name                = "${local.instance_prefix}-secondary-pip-ext-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  domain_name_label   = format("%s-sec-ext-%s", local.instance_prefix, count.index)
  allocation_method   = "Static"   # Static is required due to the use of the Standard sku
  sku                 = "Standard" # the Standard sku is required due to the use of availability zones
  tags = merge(local.tags, {
    Name = format("%s-secondary-pip-ext-%s", local.instance_prefix, count.index)
    }
  )
}

# Deploy BIG-IP with N-Nic interface 
resource "azurerm_network_interface" "mgmt_nic" {
  count               = length(local.bigip_map["mgmt_subnet_ids"])
  name                = "${local.instance_prefix}-mgmt-nic-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "${local.instance_prefix}-mgmt-ip-${count.index}"
    subnet_id                     = local.bigip_map["mgmt_subnet_ids"][count.index]["subnet_id"]
    private_ip_address_allocation = length(local.mgmt_public_private_ip_primary) > 0 ? "Static" : (length(local.mgmt_private_ip_primary) > 0 ? "Static" : "Dynamic")
    private_ip_address            = length(local.mgmt_public_private_ip_primary) > 0 ? local.mgmt_public_private_ip_primary[0] : (length(local.mgmt_private_ip_primary) > 0 ? local.mgmt_private_ip_primary[0] : null)
    public_ip_address_id          = local.bigip_map["mgmt_subnet_ids"][count.index]["public_ip"] ? azurerm_public_ip.mgmt_public_ip[count.index].id : null
  }
  tags = merge(local.tags, {
    Name = format("%s-mgmt-nic-%s", local.instance_prefix, count.index)
    }
  )
}

resource "azurerm_network_interface" "external_nic" {
  count                = length(local.external_private_subnet_id)
  name                 = "${local.instance_prefix}-ext-nic-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  enable_ip_forwarding = var.external_enable_ip_forwarding
  ip_configuration {
    name                          = "${local.instance_prefix}-ext-ip-${count.index}"
    subnet_id                     = local.external_private_subnet_id[count.index]
    primary                       = "true"
    private_ip_address_allocation = (length(local.external_private_ip_primary[count.index]) > 0 ? "Static" : "Dynamic")
    private_ip_address            = (length(local.external_private_ip_primary[count.index]) > 0 ? local.external_private_ip_primary[count.index] : null)
    //public_ip_address_id          = length(azurerm_public_ip.mgmt_public_ip.*.id) > count.index ? azurerm_public_ip.mgmt_public_ip[count.index].id : ""
  }
  ip_configuration {
    name                          = "${local.instance_prefix}-secondary-ext-ip-${count.index}"
    subnet_id                     = local.external_private_subnet_id[count.index]
    private_ip_address_allocation = (length(local.external_private_ip_secondary[count.index]) > 0 ? "Static" : "Dynamic")
    private_ip_address            = (length(local.external_private_ip_secondary[count.index]) > 0 ? local.external_private_ip_secondary[count.index] : null)
  }
  tags = merge(local.tags, var.externalnic_failover_tags, {
    Name = format("%s-ext-nic-%s", local.instance_prefix, count.index),
    }
  )
}

resource "azurerm_network_interface" "external_public_nic" {
  count                = length(local.external_public_subnet_id)
  name                 = "${local.instance_prefix}-ext-nic-public-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  enable_ip_forwarding = var.external_enable_ip_forwarding

  ip_configuration {
    name                          = "${local.instance_prefix}-ext-public-ip-${count.index}"
    subnet_id                     = local.external_public_subnet_id[count.index]
    primary                       = "true"
    private_ip_address_allocation = (length(local.external_public_private_ip_primary[count.index]) > 0 ? "Static" : "Dynamic")
    private_ip_address            = (length(local.external_public_private_ip_primary[count.index]) > 0 ? local.external_public_private_ip_primary[count.index] : null)
    public_ip_address_id          = azurerm_public_ip.external_public_ip[count.index].id
  }
  dynamic "ip_configuration" {
    for_each = var.cfe_secondary_vip_disable ? [] : [0]
    content {
      name                          = "${local.instance_prefix}-secondary-ext-public-ip-${count.index}"
      subnet_id                     = local.external_public_subnet_id[count.index]
      private_ip_address_allocation = (length(local.external_public_private_ip_secondary[count.index]) > 0 ? "Static" : "Dynamic")
      private_ip_address            = (length(local.external_public_private_ip_secondary[count.index]) > 0 ? local.external_public_private_ip_secondary[count.index] : null)
      public_ip_address_id          = azurerm_public_ip.secondary_external_public_ip[count.index].id
    }
  }
  tags = merge(local.tags, var.externalnic_failover_tags, {
    Name = format("%s-ext-public-nic-%s", local.instance_prefix, count.index)
    }
  )
}

resource "azurerm_network_interface" "internal_nic" {
  count               = length(local.internal_private_subnet_id)
  name                = "${local.instance_prefix}-int-nic${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  //enable_accelerated_networking = var.enable_accelerated_networking

  ip_configuration {
    name                          = "${local.instance_prefix}-int-ip-${count.index}"
    subnet_id                     = local.internal_private_subnet_id[count.index]
    private_ip_address_allocation = (length(local.internal_private_ip_primary[count.index]) > 0 ? "Static" : "Dynamic")
    private_ip_address            = (length(local.internal_private_ip_primary[count.index]) > 0 ? local.internal_private_ip_primary[count.index] : null)
    //public_ip_address_id          = length(azurerm_public_ip.mgmt_public_ip.*.id) > count.index ? azurerm_public_ip.mgmt_public_ip[count.index].id : ""
  }
  tags = merge(local.tags, var.internalnic_failover_tags, {
    Name = format("%s-internal-nic-%s", local.instance_prefix, count.index)
    }
  )
}

resource "azurerm_network_interface_security_group_association" "mgmt_security" {
  count                     = length(local.bigip_map["mgmt_securitygroup_ids"])
  network_interface_id      = azurerm_network_interface.mgmt_nic[count.index].id
  network_security_group_id = local.bigip_map["mgmt_securitygroup_ids"][count.index]
}

resource "azurerm_network_interface_application_security_group_association" "mgmt_security" {
  count                         = length(var.mgmt_app_securitygroup_ids)
  network_interface_id          = azurerm_network_interface.mgmt_nic[count.index].id
  application_security_group_id = var.mgmt_app_securitygroup_ids[count.index]
}

resource "azurerm_network_interface_security_group_association" "external_security" {
  count                     = length(local.external_private_security_id)
  network_interface_id      = azurerm_network_interface.external_nic[count.index].id
  network_security_group_id = local.external_private_security_id[count.index]
}

resource "azurerm_network_interface_application_security_group_association" "external_security" {
  count                         = length(var.external_app_securitygroup_ids)
  network_interface_id          = concat(azurerm_network_interface.external_nic.*.id, azurerm_network_interface.external_public_nic.*.id)[count.index]
  application_security_group_id = var.external_app_securitygroup_ids[count.index]
}

resource "azurerm_network_interface_security_group_association" "external_public_security" {
  count                     = length(local.external_public_security_id)
  network_interface_id      = azurerm_network_interface.external_public_nic[count.index].id
  network_security_group_id = local.external_public_security_id[count.index]
}

resource "azurerm_network_interface_security_group_association" "internal_security" {
  count                     = length(local.internal_private_security_id)
  network_interface_id      = azurerm_network_interface.internal_nic[count.index].id
  network_security_group_id = local.internal_private_security_id[count.index]
}
resource "azurerm_network_interface_application_security_group_association" "internal_security" {
  count                         = length(var.internal_app_securitygroup_ids)
  network_interface_id          = azurerm_network_interface.internal_nic[count.index].id
  application_security_group_id = var.internal_app_securitygroup_ids[count.index]
}



# Create F5 BIGIP1
resource "azurerm_linux_virtual_machine" "f5vm01" {
  lifecycle {
    ignore_changes = [
      admin_password,
      custom_data
    ]
  }
  name                            = var.vm_name == "" ? format("%s-f5vm01", local.instance_prefix) : var.vm_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  network_interface_ids           = concat(azurerm_network_interface.mgmt_nic.*.id, azurerm_network_interface.external_nic.*.id, azurerm_network_interface.external_public_nic.*.id, azurerm_network_interface.internal_nic.*.id)
  size                            = var.f5_instance_type
  disable_password_authentication = var.enable_ssh_key
  computer_name                   = var.vm_name == "" ? format("%s-f5vm01", local.instance_prefix) : var.vm_name
  admin_username                  = var.f5_username
  admin_password                  = var.az_keyvault_authentication ? data.azurerm_key_vault_secret.bigip_admin_password[0].value : random_string.password.result
  custom_data = base64encode(coalesce(var.custom_user_data, templatefile("${path.module}/templates/${var.script_name}.tmpl",
    {
      INIT_URL                   = var.INIT_URL
      DO_URL                     = var.DO_URL
      AS3_URL                    = var.AS3_URL
      TS_URL                     = var.TS_URL
      CFE_URL                    = var.CFE_URL
      FAST_URL                   = var.FAST_URL,
      DO_VER                     = format("v%s", split("-", split("/", var.DO_URL)[length(split("/", var.DO_URL)) - 1])[3])
      AS3_VER                    = format("v%s", split("-", split("/", var.AS3_URL)[length(split("/", var.AS3_URL)) - 1])[2])
      TS_VER                     = format("v%s", split("-", split("/", var.TS_URL)[length(split("/", var.TS_URL)) - 1])[2])
      CFE_VER                    = format("v%s", split("-", split("/", var.CFE_URL)[length(split("/", var.CFE_URL)) - 1])[3])
      FAST_VER                   = format("v%s", split("-", split("/", var.FAST_URL)[length(split("/", var.FAST_URL)) - 1])[3])
      vault_url                  = var.az_keyvault_authentication ? data.azurerm_key_vault.keyvault[0].vault_uri : ""
      secret_id                  = var.az_keyvault_authentication ? var.azure_keyvault_secret_name : ""
      az_keyvault_authentication = var.az_keyvault_authentication
      bigip_username             = var.f5_username
      ssh_keypair                = var.f5_ssh_publickey
      bigip_password             = (length(var.f5_password) > 0 ? var.f5_password : random_string.password.result)
  })))
  source_image_reference {
    offer     = var.f5_product_name
    publisher = var.image_publisher
    sku       = var.f5_image_name
    version   = var.f5_version
  }

  os_disk {
    caching                   = "ReadWrite"
    disk_size_gb              = 84
    name                      = "${local.instance_prefix}-osdisk-f5vm01"
    storage_account_type      = var.storage_account_type
    write_accelerator_enabled = false
  }

  admin_ssh_key {
    public_key = var.f5_ssh_publickey
    username   = var.f5_username
  }
  plan {
    name      = var.f5_image_name
    product   = var.f5_product_name
    publisher = var.image_publisher
  }
  zone = var.availability_zone

  tags = merge(local.tags, {
    Name = format("%s-f5vm01", local.instance_prefix)
    }
  )
  identity {
    type         = "UserAssigned"
    identity_ids = var.user_identity == null ? flatten([azurerm_user_assigned_identity.user_identity.*.id]) : [var.user_identity]
  }
  depends_on = [azurerm_network_interface_security_group_association.mgmt_security, azurerm_network_interface_security_group_association.internal_security, azurerm_network_interface_security_group_association.external_security, azurerm_network_interface_security_group_association.external_public_security]
}

## ..:: Run Startup Script ::..
resource "azurerm_virtual_machine_extension" "vmext" {
  name                 = format("%s-vmext1", local.instance_prefix)
  depends_on           = [azurerm_linux_virtual_machine.f5vm01]
  virtual_machine_id   = azurerm_linux_virtual_machine.f5vm01.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  tags = merge(local.tags, {
    Name = format("%s-vmext1", local.instance_prefix)
    }
  )

  settings = <<SETTINGS
    {
      "commandToExecute": "bash /var/lib/waagent/CustomData; exit 0;"
    }
SETTINGS
}

resource "time_sleep" "wait_for_azurerm_virtual_machine_f5vm" {
  depends_on      = [azurerm_virtual_machine_extension.vmext]
  create_duration = var.sleep_time
}

# Getting Public IP Assigned to BIGIP
# data "azurerm_public_ip" "f5vm01mgmtpip" {
#   name                = azurerm_public_ip.mgmt_public_ip[0].name
#   resource_group_name = var.resource_group_name
#   depends_on          = [azurerm_virtual_machine.f5vm01, azurerm_virtual_machine_extension.vmext, azurerm_public_ip.mgmt_public_ip[0]]
# }

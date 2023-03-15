# Deploys F5 BIG-IP Azure Cloud

* This Terraform module deploys `3-NIC` BIG-IP in Azure cloud
* Using module `count` feature we can also deploy multiple BIGIP instances(default value of `count` is **1**)
* Management interface associated with user provided **mgmt_subnet_ids** and **mgmt_securitygroup_ids**
* External interface associated with user provided **external_subnet_ids** and **external_securitygroup_ids**
* Internal interface associated with user provided **internal_subnet_ids** and **internal_securitygroup_ids**
* Random generated `password` for login to BIG-IP (in case of explicit `f5_password` not provided and default value of `az_key_vault_authentication` is false )

## Example Usage

```hcl
module "bigip" {
  count                       = var.instance_count
  source                      = "F5Networks/bigip-module/azure"
  prefix                      = format("%s-3nic", var.prefix)
  resource_group_name         = azurerm_resource_group.rg.name
  f5_ssh_publickey            = azurerm_ssh_public_key.f5_key.public_key
  mgmt_subnet_ids             = [{ "subnet_id" = data.azurerm_subnet.mgmt.id, "public_ip" = true, "private_ip_primary" = "10.2.1.5" }]
  mgmt_securitygroup_ids      = [module.mgmt-network-security-group.network_security_group_id]
  external_subnet_ids         = [{ "subnet_id" = data.azurerm_subnet.external-public.id, "public_ip" = true, "private_ip_primary" = "", "private_ip_secondary" = "" }]
  external_securitygroup_ids  = [module.external-network-security-group-public.network_security_group_id]
  internal_subnet_ids         = [{ "subnet_id" = data.azurerm_subnet.internal.id, "public_ip" = false, "private_ip_primary" = "" }]
  internal_securitygroup_ids  = [module.internal-network-security-group.network_security_group_id]
  availability_zone           = var.availability_zone
  availabilityZones_public_ip = var.availabilityZones_public_ip
}
```

* Modify `terraform.tfvars` according to the requirement by changing `location` and `AllowedIPs` variables as follows

```hcl
location = "eastus"
AllowedIPs = ["0.0.0.0/0"]
```

* Next, Run the following commands to `create` and `destroy` your configuration

```shell
$terraform init
$terraform plan
$terraform apply
$terraform destroy
```

### Optional Input Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Prefix for resources created by this module | `string` | tf-azure-bigip |
| cidr | Azure VPC CIDR | `string` | 10.2.0.0/16 |
| availabilityZones | If you want the VM placed in an Azure Availability Zone, and the Azure region you are deploying to supports it, specify the numbers of the existing Availability Zone you want to use | `List` | [1] |
| instance_count | Number of Bigip instances to create | `number` | 1 |

### Output Variables

| Name | Description |
|------|-------------|
| mgmtPublicIP | The actual ip address allocated for the resource |
| mgmtPublicDNS | fqdn to connect to the first vm provisioned |
| mgmtPort | Mgmt Port |
| f5\_username | BIG-IP username |
| bigip\_password | BIG-IP Password (if dynamic_password is choosen it will be random generated password or if azure_keyvault is choosen it will be key vault secret name ) |
| mgmtPublicURL | Complete url including DNS and port|  
| resourcegroup_name | Resource Group in which objects are created |
| public_addresses | List of BIG-IP public addresses |
| private_addresses | List of BIG-IP private addresses |

~> **NOTE**A local json file will get generated which contains the DO declaration

### Steps to clone and use the module locally

```shell
$git clone https://github.com/F5Networks/terraform-azure-bigip-module
$cd terraform-azure-bigip-module/examples/bigip_azure_3nic_deploy/
```

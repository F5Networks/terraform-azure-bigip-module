## Deploys F5 BIG-IP Azure Cloud

This Terraform module deploys 3-NIC BIG-IP in Azure and by using module count feature we can also deploy multiple BIGIP instances( default value of count as 1 ) with the following characteristics:

BIG-IP 3 Nic with management, external, internal interfaces associated with user provided subnet and security-group
  
A random generated password for login to BIG-IP ( Default value of az_key_vault_authentication is false )  

## Steps to clone and use the provisioner locally

```
$ git clone https://github.com/f5devcentral/terraform-azure-bigip-module
$ cd terraform-azure-bigip-module/examples/bigip_azure_3nic_deploy/

```

- Then follow the stated process in Example Usage below

## Example Usage

>Modify terraform.tfvars according to the requirement by changing `location` and `AllowedIPs` variables as follows

```
location = "eastus"
AllowedIPs = ["0.0.0.0/0"]
```
Next, Run the following commands to create and destroy your configuration

```
$ terraform init
$ terraform plan
$ terraform apply
$ terraform destroy

```

#### Optional Input Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Prefix for resources created by this module | `string` | tf-azure-bigip |
| cidr | Azure VPC CIDR | `string` | 10.2.0.0/16 |
| availabilityZones | If you want the VM placed in an Azure Availability Zone, and the Azure region you are deploying to supports it, specify the numbers of the existing Availability Zone you want to use | `List` | [1] |
| instance_count | Number of Bigip instances to create | `number` | 1 |

#### Output Variables

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

```
NOTE: A local json file will get generated which contains the DO declaration
```

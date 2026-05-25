terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm" ; version = "~> 3.100" } }
}
provider "azurerm" { features {} ; subscription_id = var.hub_subscription_id }

resource "azurerm_resource_group" "hub" {
  name = "rg-hub-network-${var.location_short}"
  location = var.location
  tags = var.tags
}

module "vwan" {
  source = "../../modules/vwan-hub"
  vwan_name = "vwan-mfgcorp-${var.location_short}"
  hub_name = "hub-mfgcorp-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  hub_address_prefix = "10.0.0.0/23"
  tags = var.tags
}

module "firewall" {
  source = "../../modules/firewall-policy"
  firewall_name = "afw-mfgcorp-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  virtual_hub_id = module.vwan.virtual_hub_id
  tags = var.tags
  network_rule_collections = [
    { name = "AllowEgress" ; priority = 300 ; action = "Allow" ; rules = [
      { name = "HTTPS" ; protocols = ["TCP"] ; source_addresses = ["10.0.0.0/8"] ; destination_addresses = ["*"] ; destination_ports = ["443"] },
      { name = "HTTP" ; protocols = ["TCP"] ; source_addresses = ["10.0.0.0/8"] ; destination_addresses = ["*"] ; destination_ports = ["80"] },
      { name = "DNS" ; protocols = ["UDP"] ; source_addresses = ["10.0.0.0/8"] ; destination_addresses = ["*"] ; destination_ports = ["53"] },
    ]},
    { name = "SpokeToSpoke" ; priority = 400 ; action = "Allow" ; rules = [
      { name = "FE-BE-SQL" ; protocols = ["TCP"] ; source_addresses = ["10.50.0.0/16"] ; destination_addresses = ["10.60.0.0/16"] ; destination_ports = ["1433"] },
      { name = "FE-BE-HTTPS" ; protocols = ["TCP"] ; source_addresses = ["10.50.0.0/16"] ; destination_addresses = ["10.60.0.0/16"] ; destination_ports = ["443"] },
      { name = "BE-DB" ; protocols = ["TCP"] ; source_addresses = ["10.60.0.0/16"] ; destination_addresses = ["10.60.2.0/24"] ; destination_ports = ["1433","3306"] },
      { name = "AD-DNS" ; protocols = ["TCP","UDP"] ; source_addresses = ["10.0.0.0/8"] ; destination_addresses = ["10.10.1.0/24"] ; destination_ports = ["53","88","389","445","636","3268"] },
    ]},
    { name = "DenyAll" ; priority = 4000 ; action = "Deny" ; rules = [
      { name = "DenyAllTraffic" ; protocols = ["Any"] ; source_addresses = ["*"] ; destination_addresses = ["*"] ; destination_ports = ["*"] },
    ]},
  ]
}

module "shared_vnet" {
  source = "../../modules/spoke-vnet"
  vnet_name = "vnet-shared-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  address_space = ["10.10.0.0/16"]
  virtual_hub_id = module.vwan.virtual_hub_id
  tags = var.tags
  subnets = [
    { name = "snet-ad-dns" ; prefix = "10.10.1.0/24" },
    { name = "snet-jumpbox" ; prefix = "10.10.2.0/24" },
    { name = "snet-monitoring" ; prefix = "10.10.3.0/24" },
    { name = "snet-mgmt" ; prefix = "10.10.4.0/24" },
  ]
}

module "nsg_ad" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-ad-dns-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  subnet_ids = [module.shared_vnet.subnet_ids["snet-ad-dns"]]
  tags = var.tags
  rules = [
    { name = "DNS" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Udp" ; source_port_range = "*" ; destination_port_range = "53" ; source_address_prefix = "10.0.0.0/8" ; destination_address_prefix = "*" },
    { name = "Kerberos" ; priority = 110 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "88" ; source_address_prefix = "10.0.0.0/8" ; destination_address_prefix = "*" },
    { name = "LDAP" ; priority = 120 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "389" ; source_address_prefix = "10.0.0.0/8" ; destination_address_prefix = "*" },
    { name = "LDAPS" ; priority = 130 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "636" ; source_address_prefix = "10.0.0.0/8" ; destination_address_prefix = "*" },
    { name = "SMB" ; priority = 140 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "445" ; source_address_prefix = "10.0.0.0/8" ; destination_address_prefix = "*" },
    { name = "GC" ; priority = 150 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3268" ; source_address_prefix = "10.0.0.0/8" ; destination_address_prefix = "*" },
    { name = "RDP" ; priority = 200 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAll" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "nsg_jump" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-jumpbox-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  subnet_ids = [module.shared_vnet.subnet_ids["snet-jumpbox"]]
  tags = var.tags
  rules = [
    { name = "RDP" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.4.0/24" ; destination_address_prefix = "*" },
    { name = "SSH" ; priority = 110 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "22" ; source_address_prefix = "10.10.4.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAll" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "rt_shared" {
  source = "../../modules/route-table"
  route_table_name = "rt-shared-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  subnet_ids = [module.shared_vnet.subnet_ids["snet-ad-dns"], module.shared_vnet.subnet_ids["snet-jumpbox"], module.shared_vnet.subnet_ids["snet-monitoring"], module.shared_vnet.subnet_ids["snet-mgmt"]]
  tags = var.tags
  routes = [{ name = "default-to-fw" ; address_prefix = "0.0.0.0/0" ; next_hop_type = "VirtualAppliance" ; next_hop_ip = module.firewall.firewall_private_ip }]
}

module "ad_vms" {
  source = "../../modules/vm-fleet"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  tags = var.tags
  vms = [
    { name = "vm-dc01" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.shared_vnet.subnet_ids["snet-ad-dns"] ; tags = { role = "DomainController", tier = "identity" } },
    { name = "vm-dc02" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.shared_vnet.subnet_ids["snet-ad-dns"] ; tags = { role = "DomainController", tier = "identity" } },
    { name = "vm-jump01" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.shared_vnet.subnet_ids["snet-jumpbox"] ; tags = { role = "Jumpbox", tier = "management" } },
  ]
}

module "monitoring" {
  source = "../../modules/monitoring"
  workspace_name = "law-mfgcorp-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location = var.location
  tags = var.tags
}

output "virtual_hub_id" { value = module.vwan.virtual_hub_id }
output "firewall_private_ip" { value = module.firewall.firewall_private_ip }

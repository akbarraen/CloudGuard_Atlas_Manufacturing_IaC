terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm" ; version = "~> 3.100" } }
}
provider "azurerm" { features {} ; subscription_id = var.subscription_id }

resource "azurerm_resource_group" "this" {
  name = "rg-prod-${var.location_short}"
  location = var.location
  tags = var.tags
}

module "spoke_vnet" {
  source = "../../modules/spoke-vnet"
  vnet_name = "vnet-prod-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  address_space = ["10.20.0.0/16"]
  virtual_hub_id = var.virtual_hub_id
  tags = var.tags
  subnets = [{ name = "snet-app" ; prefix = "10.20.1.0/24" }, { name = "snet-data" ; prefix = "10.20.2.0/24" }, { name = "snet-web" ; prefix = "10.20.3.0/24" }, { name = "snet-func" ; prefix = "10.20.4.0/24" }, { name = "snet-middleware" ; prefix = "10.20.5.0/24" }]
}

module "nsg_app" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-prod-app-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-app"]]
  tags = var.tags
  rules = [
    { name = "AllowHTTPS" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "443" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
    { name = "AllowHTTP" ; priority = 110 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "80" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
    { name = "AllowRDPJump" ; priority = 200 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "AllowSSHJump" ; priority = 210 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "22" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAllInbound" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "nsg_data" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-prod-data-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-data"]]
  tags = var.tags
  rules = [
    { name = "AllowSQLFromApp" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "1433" ; source_address_prefix = "10.20.0.0/16" ; destination_address_prefix = "*" },
    { name = "AllowRDPJump" ; priority = 200 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAllInbound" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "rt_app" {
  source = "../../modules/route-table"
  route_table_name = "rt-prod-app-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-app"]]
  tags = var.tags
  routes = [{ name = "default-to-fw" ; address_prefix = "0.0.0.0/0" ; next_hop_type = "VirtualAppliance" ; next_hop_ip = var.firewall_private_ip }]
}

module "rt_data" {
  source = "../../modules/route-table"
  route_table_name = "rt-prod-data-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-data"]]
  tags = var.tags
  routes = [{ name = "default-to-fw" ; address_prefix = "0.0.0.0/0" ; next_hop_type = "VirtualAppliance" ; next_hop_ip = var.firewall_private_ip }]
}

module "vms" {
  source = "../../modules/vm-fleet"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  vms = [
    { name = "vm-prod-app-001" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-002" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-003" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-004" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-005" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-006" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-007" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-008" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-009" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-010" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-011" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-012" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-013" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-014" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-015" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-016" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-017" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-018" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-019" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-020" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-021" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-022" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-023" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-024" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-025" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-026" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-027" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-028" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-029" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-030" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-031" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-032" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-033" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-034" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-035" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-036" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-037" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-038" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-039" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-040" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-041" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-042" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-043" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-044" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-045" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-046" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-047" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-048" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-049" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-050" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-051" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-052" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-053" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-054" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-055" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-056" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-057" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-058" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-059" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-app-060" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-prod-db-001" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-002" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-003" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-004" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-005" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-006" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-007" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-008" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-009" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-010" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-011" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-012" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-013" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-014" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-015" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-016" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-017" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-018" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-019" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-020" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-021" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-022" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-023" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-024" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-025" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-026" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-027" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-028" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-029" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-db-030" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-prod-mw-001" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-002" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-003" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-004" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-005" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-006" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-007" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-008" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-009" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-010" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-011" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-012" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-013" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-014" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-015" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-016" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-017" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-018" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-019" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-020" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-021" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-022" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-023" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-024" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-025" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-026" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-027" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-028" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-029" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-mw-030" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-prod-web-001" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-002" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-003" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-004" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-005" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-006" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-007" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-008" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-009" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-010" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-011" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-012" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-013" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-014" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-015" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-016" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-017" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-018" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-019" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-020" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-021" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-022" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-023" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-024" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-025" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-026" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-027" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-028" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-029" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-prod-web-030" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
  ]
}

module "webapps" {
  source = "../../modules/webapp-fleet"
  plan_name = "plan-prod-web-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  apps = [
    { name = "webapp-prod-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-04" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-05" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-06" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-07" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-08" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-09" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-10" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-11" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-12" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-13" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-14" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-prod-15" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
  ]
}

module "functions" {
  source = "../../modules/function-fleet"
  plan_name = "plan-prod-func-${var.location_short}"
  storage_account_name = "stfuncprod"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  functions = [
    { name = "func-prod-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-prod-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-prod-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-prod-04" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-prod-05" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-prod-06" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-prod-07" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-prod-08" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
  ]
}

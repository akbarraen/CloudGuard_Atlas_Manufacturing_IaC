terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm" ; version = "~> 3.100" } }
}
provider "azurerm" { features {} ; subscription_id = var.subscription_id }

resource "azurerm_resource_group" "this" {
  name = "rg-backend-${var.location_short}"
  location = var.location
  tags = var.tags
}

module "spoke_vnet" {
  source = "../../modules/spoke-vnet"
  vnet_name = "vnet-backend-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  address_space = ["10.60.0.0/16"]
  virtual_hub_id = var.virtual_hub_id
  tags = var.tags
  subnets = [{ name = "snet-app" ; prefix = "10.60.1.0/24" }, { name = "snet-data" ; prefix = "10.60.2.0/24" }, { name = "snet-middleware" ; prefix = "10.60.3.0/24" }, { name = "snet-batch" ; prefix = "10.60.4.0/24" }, { name = "snet-func" ; prefix = "10.60.5.0/24" }, { name = "snet-web" ; prefix = "10.60.6.0/24" }]
}

module "nsg_app" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-backend-app-${var.location_short}"
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
  nsg_name = "nsg-backend-data-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-data"]]
  tags = var.tags
  rules = [
    { name = "AllowSQLFromApp" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "1433" ; source_address_prefix = "10.60.0.0/16" ; destination_address_prefix = "*" },
    { name = "AllowRDPJump" ; priority = 200 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAllInbound" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "rt_app" {
  source = "../../modules/route-table"
  route_table_name = "rt-backend-app-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-app"]]
  tags = var.tags
  routes = [{ name = "default-to-fw" ; address_prefix = "0.0.0.0/0" ; next_hop_type = "VirtualAppliance" ; next_hop_ip = var.firewall_private_ip }]
}

module "rt_data" {
  source = "../../modules/route-table"
  route_table_name = "rt-backend-data-${var.location_short}"
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
    { name = "vm-be-api-001" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-002" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-003" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-004" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-005" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-006" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-007" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-008" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-009" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-010" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-011" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-012" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-013" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-014" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-015" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-016" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-017" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-018" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-019" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-020" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-021" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-022" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-023" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-024" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-025" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-026" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-027" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-028" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-029" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-030" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-031" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-032" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-033" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-034" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-035" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-036" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-037" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-038" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-039" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-api-040" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "APIServer", tier = "api" } },
    { name = "vm-be-db-001" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-002" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-003" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-004" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-005" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-006" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-007" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-008" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-009" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-010" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-011" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-012" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-013" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-014" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-015" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-016" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-017" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-018" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-019" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-020" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-021" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-022" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-023" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-024" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-025" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-026" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-027" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-028" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-029" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-db-030" ; size = "Standard_E8s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-be-mw-001" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-002" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-003" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-004" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-005" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-006" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-007" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-008" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-009" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-010" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-011" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-012" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-013" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-014" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-015" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-016" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-017" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-018" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-019" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-020" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-021" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-022" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-023" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-024" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-025" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-026" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-027" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-028" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-029" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-030" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-031" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-032" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-033" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-034" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-035" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-036" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-037" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-038" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-039" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-mw-040" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-middleware"] ; tags = { role = "Middleware", tier = "middleware" } },
    { name = "vm-be-batch-001" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-002" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-003" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-004" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-005" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-006" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-007" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-008" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-009" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-010" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-011" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-012" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-013" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-014" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-015" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-016" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-017" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-018" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-019" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-020" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-021" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-022" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-023" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-024" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-025" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-026" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-027" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-028" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-029" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
    { name = "vm-be-batch-030" ; size = "Standard_D8s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-batch"] ; tags = { role = "BatchProcessor", tier = "batch" } },
  ]
}

module "webapps" {
  source = "../../modules/webapp-fleet"
  plan_name = "plan-backend-web-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  apps = [

  ]
}

module "functions" {
  source = "../../modules/function-fleet"
  plan_name = "plan-backend-func-${var.location_short}"
  storage_account_name = "stfuncbackend"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  functions = [

  ]
}

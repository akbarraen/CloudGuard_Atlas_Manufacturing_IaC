terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm" ; version = "~> 3.100" } }
}
provider "azurerm" { features {} ; subscription_id = var.subscription_id }

resource "azurerm_resource_group" "this" {
  name = "rg-dev-${var.location_short}"
  location = var.location
  tags = var.tags
}

module "spoke_vnet" {
  source = "../../modules/spoke-vnet"
  vnet_name = "vnet-dev-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  address_space = ["10.30.0.0/16"]
  virtual_hub_id = var.virtual_hub_id
  tags = var.tags
  subnets = [{ name = "snet-app" ; prefix = "10.30.1.0/24" }, { name = "snet-data" ; prefix = "10.30.2.0/24" }, { name = "snet-web" ; prefix = "10.30.3.0/24" }, { name = "snet-func" ; prefix = "10.30.4.0/24" }]
}

module "nsg_app" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-dev-app-${var.location_short}"
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
  nsg_name = "nsg-dev-data-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-data"]]
  tags = var.tags
  rules = [
    { name = "AllowSQLFromApp" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "1433" ; source_address_prefix = "10.30.0.0/16" ; destination_address_prefix = "*" },
    { name = "AllowRDPJump" ; priority = 200 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAllInbound" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "rt_app" {
  source = "../../modules/route-table"
  route_table_name = "rt-dev-app-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-app"]]
  tags = var.tags
  routes = [{ name = "default-to-fw" ; address_prefix = "0.0.0.0/0" ; next_hop_type = "VirtualAppliance" ; next_hop_ip = var.firewall_private_ip }]
}

module "rt_data" {
  source = "../../modules/route-table"
  route_table_name = "rt-dev-data-${var.location_short}"
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
    { name = "vm-dev-app-001" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-002" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-003" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-004" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-005" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-006" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-007" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-008" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-009" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-010" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-011" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-012" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-013" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-014" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-015" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-016" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-017" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-018" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-019" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-020" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-021" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-022" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-023" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-024" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-025" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-026" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-027" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-028" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-029" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-030" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-031" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-032" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-033" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-034" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-035" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-036" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-037" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-038" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-039" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-app-040" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-dev-db-001" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-002" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-003" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-004" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-005" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-006" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-007" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-008" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-009" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-010" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-011" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-012" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-013" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-014" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-015" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-016" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-017" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-018" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-019" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-db-020" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-dev-web-001" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-002" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-003" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-004" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-005" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-006" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-007" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-008" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-009" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-010" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-011" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-012" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-013" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-014" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-015" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-016" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-017" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-018" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-019" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-dev-web-020" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
  ]
}

module "webapps" {
  source = "../../modules/webapp-fleet"
  plan_name = "plan-dev-web-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  apps = [
    { name = "webapp-dev-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-04" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-05" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-06" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-07" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-08" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-09" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-dev-10" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
  ]
}

module "functions" {
  source = "../../modules/function-fleet"
  plan_name = "plan-dev-func-${var.location_short}"
  storage_account_name = "stfuncdev"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  functions = [
    { name = "func-dev-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-dev-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-dev-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-dev-04" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-dev-05" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
  ]
}

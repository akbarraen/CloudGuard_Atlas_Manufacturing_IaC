terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm" ; version = "~> 3.100" } }
}
provider "azurerm" { features {} ; subscription_id = var.subscription_id }

resource "azurerm_resource_group" "this" {
  name = "rg-test-${var.location_short}"
  location = var.location
  tags = var.tags
}

module "spoke_vnet" {
  source = "../../modules/spoke-vnet"
  vnet_name = "vnet-test-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  address_space = ["10.40.0.0/16"]
  virtual_hub_id = var.virtual_hub_id
  tags = var.tags
  subnets = [{ name = "snet-app" ; prefix = "10.40.1.0/24" }, { name = "snet-data" ; prefix = "10.40.2.0/24" }, { name = "snet-web" ; prefix = "10.40.3.0/24" }, { name = "snet-func" ; prefix = "10.40.4.0/24" }]
}

module "nsg_app" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-test-app-${var.location_short}"
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
  nsg_name = "nsg-test-data-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-data"]]
  tags = var.tags
  rules = [
    { name = "AllowSQLFromApp" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "1433" ; source_address_prefix = "10.40.0.0/16" ; destination_address_prefix = "*" },
    { name = "AllowRDPJump" ; priority = 200 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAllInbound" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "rt_app" {
  source = "../../modules/route-table"
  route_table_name = "rt-test-app-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-app"]]
  tags = var.tags
  routes = [{ name = "default-to-fw" ; address_prefix = "0.0.0.0/0" ; next_hop_type = "VirtualAppliance" ; next_hop_ip = var.firewall_private_ip }]
}

module "rt_data" {
  source = "../../modules/route-table"
  route_table_name = "rt-test-data-${var.location_short}"
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
    { name = "vm-test-app-001" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-002" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-003" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-004" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-005" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-006" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-007" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-008" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-009" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-010" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-011" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-012" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-013" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-014" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-015" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-016" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-017" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-018" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-019" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-020" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-021" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-022" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-023" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-024" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-app-025" ; size = "Standard_D2s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppServer", tier = "app" } },
    { name = "vm-test-db-001" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-002" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-003" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-004" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-005" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-006" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-007" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-008" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-009" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-010" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-011" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-012" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-013" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-014" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-db-015" ; size = "Standard_D4s_v5" ; os = "windows" ; subnet_id = module.spoke_vnet.subnet_ids["snet-data"] ; tags = { role = "Database", tier = "data" } },
    { name = "vm-test-web-001" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-002" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-003" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-004" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-005" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-006" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-007" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-008" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-009" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
    { name = "vm-test-web-010" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebServer", tier = "web" } },
  ]
}

module "webapps" {
  source = "../../modules/webapp-fleet"
  plan_name = "plan-test-web-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  apps = [
    { name = "webapp-test-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-test-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-test-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-test-04" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-test-05" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
  ]
}

module "functions" {
  source = "../../modules/function-fleet"
  plan_name = "plan-test-func-${var.location_short}"
  storage_account_name = "stfunctest"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  functions = [
    { name = "func-test-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-test-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-test-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
  ]
}

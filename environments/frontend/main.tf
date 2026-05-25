terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm" ; version = "~> 3.100" } }
}
provider "azurerm" { features {} ; subscription_id = var.subscription_id }

resource "azurerm_resource_group" "this" {
  name = "rg-frontend-${var.location_short}"
  location = var.location
  tags = var.tags
}

module "spoke_vnet" {
  source = "../../modules/spoke-vnet"
  vnet_name = "vnet-frontend-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  address_space = ["10.50.0.0/16"]
  virtual_hub_id = var.virtual_hub_id
  tags = var.tags
  subnets = [{ name = "snet-app" ; prefix = "10.50.1.0/24" }, { name = "snet-data" ; prefix = "10.50.2.0/24" }, { name = "snet-web" ; prefix = "10.50.3.0/24" }, { name = "snet-func" ; prefix = "10.50.4.0/24" }, { name = "snet-cdn" ; prefix = "10.50.5.0/24" }]
}

module "nsg_app" {
  source = "../../modules/nsg-rules"
  nsg_name = "nsg-frontend-app-${var.location_short}"
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
  nsg_name = "nsg-frontend-data-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-data"]]
  tags = var.tags
  rules = [
    { name = "AllowSQLFromApp" ; priority = 100 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "1433" ; source_address_prefix = "10.50.0.0/16" ; destination_address_prefix = "*" },
    { name = "AllowRDPJump" ; priority = 200 ; direction = "Inbound" ; access = "Allow" ; protocol = "Tcp" ; source_port_range = "*" ; destination_port_range = "3389" ; source_address_prefix = "10.10.2.0/24" ; destination_address_prefix = "*" },
    { name = "DenyAllInbound" ; priority = 4096 ; direction = "Inbound" ; access = "Deny" ; protocol = "*" ; source_port_range = "*" ; destination_port_range = "*" ; source_address_prefix = "*" ; destination_address_prefix = "*" },
  ]
}

module "rt_app" {
  source = "../../modules/route-table"
  route_table_name = "rt-frontend-app-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  subnet_ids = [module.spoke_vnet.subnet_ids["snet-app"]]
  tags = var.tags
  routes = [{ name = "default-to-fw" ; address_prefix = "0.0.0.0/0" ; next_hop_type = "VirtualAppliance" ; next_hop_ip = var.firewall_private_ip }]
}

module "rt_data" {
  source = "../../modules/route-table"
  route_table_name = "rt-frontend-data-${var.location_short}"
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
    { name = "vm-fe-web-001" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-002" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-003" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-004" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-005" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-006" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-007" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-008" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-009" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-010" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-011" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-012" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-013" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-014" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-015" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-016" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-017" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-018" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-019" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-020" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-021" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-022" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-023" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-024" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-025" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-026" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-027" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-028" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-029" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-030" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-031" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-032" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-033" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-034" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-035" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-036" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-037" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-038" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-039" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-web-040" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { role = "WebFrontend", tier = "web" } },
    { name = "vm-fe-app-001" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-002" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-003" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-004" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-005" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-006" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-007" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-008" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-009" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-010" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-011" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-012" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-013" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-014" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-015" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-016" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-017" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-018" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-019" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-020" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-021" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-022" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-023" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-024" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-025" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-026" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-027" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-028" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-029" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-app-030" ; size = "Standard_D4s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-app"] ; tags = { role = "AppFrontend", tier = "app" } },
    { name = "vm-fe-cache-001" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-002" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-003" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-004" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-005" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-006" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-007" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-008" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-009" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
    { name = "vm-fe-cache-010" ; size = "Standard_D2s_v5" ; os = "linux" ; subnet_id = module.spoke_vnet.subnet_ids["snet-cdn"] ; tags = { role = "Cache", tier = "cache" } },
  ]
}

module "webapps" {
  source = "../../modules/webapp-fleet"
  plan_name = "plan-frontend-web-${var.location_short}"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  apps = [
    { name = "webapp-fe-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-04" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-05" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-06" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-07" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-08" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-09" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
    { name = "webapp-fe-10" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-web"] ; tags = { tier = "web" } },
  ]
}

module "functions" {
  source = "../../modules/function-fleet"
  plan_name = "plan-frontend-func-${var.location_short}"
  storage_account_name = "stfuncfrontend"
  resource_group_name = azurerm_resource_group.this.name
  location = var.location
  tags = var.tags
  functions = [
    { name = "func-fe-01" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-fe-02" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-fe-03" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
    { name = "func-fe-04" ; vnet_integration_subnet_id = module.spoke_vnet.subnet_ids["snet-func"] ; tags = { tier = "compute" } },
  ]
}

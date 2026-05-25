resource "azurerm_service_plan" "this" {
  name = var.plan_name
  resource_group_name = var.resource_group_name
  location = var.location
  os_type = "Linux"
  sku_name = "EP1"
  tags = var.tags
}
resource "azurerm_storage_account" "st" {
  name = var.storage_account_name
  resource_group_name = var.resource_group_name
  location = var.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  tags = var.tags
}
resource "azurerm_linux_function_app" "funcs" {
  for_each = { for fn in var.functions : fn.name => fn }
  name = each.value.name
  resource_group_name = var.resource_group_name
  location = var.location
  service_plan_id = azurerm_service_plan.this.id
  storage_account_name = azurerm_storage_account.st.name
  storage_account_access_key = azurerm_storage_account.st.primary_access_key
  tags = merge(var.tags, each.value.tags)
  site_config { application_stack { python_version = "3.11" } }
}
resource "azurerm_app_service_virtual_network_swift_connection" "vnet" {
  for_each = { for fn in var.functions : fn.name => fn if fn.vnet_integration_subnet_id != "" }
  app_service_id = azurerm_linux_function_app.funcs[each.key].id
  subnet_id = each.value.vnet_integration_subnet_id
}

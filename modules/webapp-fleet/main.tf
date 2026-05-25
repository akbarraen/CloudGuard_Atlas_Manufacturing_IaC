resource "azurerm_service_plan" "this" {
  name = var.plan_name
  resource_group_name = var.resource_group_name
  location = var.location
  os_type = "Linux"
  sku_name = "P1v3"
  tags = var.tags
}
resource "azurerm_linux_web_app" "apps" {
  for_each = { for app in var.apps : app.name => app }
  name = each.value.name
  resource_group_name = var.resource_group_name
  location = var.location
  service_plan_id = azurerm_service_plan.this.id
  tags = merge(var.tags, each.value.tags)
  site_config { always_on = true }
}
resource "azurerm_app_service_virtual_network_swift_connection" "vnet" {
  for_each = { for app in var.apps : app.name => app if app.vnet_integration_subnet_id != "" }
  app_service_id = azurerm_linux_web_app.apps[each.key].id
  subnet_id = each.value.vnet_integration_subnet_id
}

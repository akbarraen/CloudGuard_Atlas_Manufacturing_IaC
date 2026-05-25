resource "azurerm_log_analytics_workspace" "this" {
  name = var.workspace_name
  resource_group_name = var.resource_group_name
  location = var.location
  sku = "PerGB2018"
  retention_in_days = 90
  tags = var.tags
}
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.this.id
}
output "workspace_id" { value = azurerm_log_analytics_workspace.this.id }

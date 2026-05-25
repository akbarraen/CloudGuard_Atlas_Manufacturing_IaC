resource "azurerm_virtual_wan" "this" {
  name = var.vwan_name
  resource_group_name = var.resource_group_name
  location = var.location
  tags = var.tags
}
resource "azurerm_virtual_hub" "this" {
  name = var.hub_name
  resource_group_name = var.resource_group_name
  location = var.location
  virtual_wan_id = azurerm_virtual_wan.this.id
  address_prefix = var.hub_address_prefix
  tags = var.tags
}
output "virtual_wan_id" { value = azurerm_virtual_wan.this.id }
output "virtual_hub_id" { value = azurerm_virtual_hub.this.id }

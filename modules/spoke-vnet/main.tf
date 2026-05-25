resource "azurerm_virtual_network" "this" {
  name = var.vnet_name
  resource_group_name = var.resource_group_name
  location = var.location
  address_space = var.address_space
  tags = var.tags
}
resource "azurerm_subnet" "subnets" {
  for_each = { for s in var.subnets : s.name => s }
  name = each.value.name
  resource_group_name = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes = [each.value.prefix]
}
resource "azurerm_virtual_hub_connection" "this" {
  count = var.virtual_hub_id != "" ? 1 : 0
  name = "${var.vnet_name}-to-hub"
  virtual_hub_id = var.virtual_hub_id
  remote_virtual_network_id = azurerm_virtual_network.this.id
  internet_security_enabled = true
}
output "vnet_id" { value = azurerm_virtual_network.this.id }
output "subnet_ids" { value = { for k, v in azurerm_subnet.subnets : k => v.id } }

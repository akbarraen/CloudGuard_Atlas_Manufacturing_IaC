resource "azurerm_network_security_group" "this" {
  name = var.nsg_name
  resource_group_name = var.resource_group_name
  location = var.location
  tags = var.tags
}
resource "azurerm_network_security_rule" "rules" {
  for_each = { for r in var.rules : r.name => r }
  name = each.value.name
  priority = each.value.priority
  direction = each.value.direction
  access = each.value.access
  protocol = each.value.protocol
  source_port_range = each.value.source_port_range
  destination_port_range = each.value.destination_port_range
  source_address_prefix = each.value.source_address_prefix
  destination_address_prefix = each.value.destination_address_prefix
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
}
resource "azurerm_subnet_network_security_group_association" "assoc" {
  for_each = toset(var.subnet_ids)
  subnet_id = each.value
  network_security_group_id = azurerm_network_security_group.this.id
}
output "nsg_id" { value = azurerm_network_security_group.this.id }

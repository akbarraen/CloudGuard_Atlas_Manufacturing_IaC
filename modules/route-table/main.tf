resource "azurerm_route_table" "this" {
  name = var.route_table_name
  resource_group_name = var.resource_group_name
  location = var.location
  tags = var.tags
}
resource "azurerm_route" "routes" {
  for_each = { for r in var.routes : r.name => r }
  name = each.value.name
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.this.name
  address_prefix = each.value.address_prefix
  next_hop_type = each.value.next_hop_type
  next_hop_in_ip_address = lookup(each.value, "next_hop_ip", null)
}
resource "azurerm_subnet_route_table_association" "assoc" {
  for_each = toset(var.subnet_ids)
  subnet_id = each.value
  route_table_id = azurerm_route_table.this.id
}
output "route_table_id" { value = azurerm_route_table.this.id }

resource "azurerm_firewall" "this" {
  name = var.firewall_name
  resource_group_name = var.resource_group_name
  location = var.location
  sku_name = "AZFW_Hub"
  sku_tier = "Standard"
  virtual_hub { virtual_hub_id = var.virtual_hub_id ; public_ip_count = 1 }
  firewall_policy_id = azurerm_firewall_policy.this.id
  tags = var.tags
}
resource "azurerm_firewall_policy" "this" {
  name = "${var.firewall_name}-policy"
  resource_group_name = var.resource_group_name
  location = var.location
  sku = "Standard"
  tags = var.tags
}
resource "azurerm_firewall_policy_rule_collection_group" "net" {
  name = "DefaultNetworkRules"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority = 200
  dynamic "network_rule_collection" {
    for_each = var.network_rule_collections
    content {
      name = network_rule_collection.value.name
      priority = network_rule_collection.value.priority
      action = network_rule_collection.value.action
      dynamic "rule" {
        for_each = network_rule_collection.value.rules
        content {
          name = rule.value.name
          protocols = rule.value.protocols
          source_addresses = rule.value.source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_ports = rule.value.destination_ports
        }
      }
    }
  }
}
output "firewall_id" { value = azurerm_firewall.this.id }
output "firewall_private_ip" { value = azurerm_firewall.this.virtual_hub[0].private_ip_address }

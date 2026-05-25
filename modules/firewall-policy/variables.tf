variable "firewall_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "virtual_hub_id" { type = string }
variable "network_rule_collections" { type = list(object({ name = string ; priority = number ; action = string ; rules = list(object({ name = string ; protocols = list(string) ; source_addresses = list(string) ; destination_addresses = list(string) ; destination_ports = list(string) })) })) ; default = [] }
variable "tags" { type = map(string) ; default = {} }

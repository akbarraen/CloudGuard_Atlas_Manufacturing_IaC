variable "route_table_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subnet_ids" { type = list(string) ; default = [] }
variable "routes" { type = list(object({ name = string ; address_prefix = string ; next_hop_type = string ; next_hop_ip = optional(string) })) }
variable "tags" { type = map(string) ; default = {} }

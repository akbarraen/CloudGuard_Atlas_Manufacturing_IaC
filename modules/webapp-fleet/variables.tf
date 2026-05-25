variable "plan_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "apps" { type = list(object({ name = string ; vnet_integration_subnet_id = string ; tags = map(string) })) }
variable "tags" { type = map(string) ; default = {} }

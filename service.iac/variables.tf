variable "service_settings" {
  default = {}
}
variable "service_apps" {
  default = {}
}

variable "aws_vpc_id" {}
variable "aws_vpc_subnets_public" {}
variable "aws_vpc_subnets_private" {}

variable "evt_env_domain" {}
variable "evt_env_domain_zone_id" {}


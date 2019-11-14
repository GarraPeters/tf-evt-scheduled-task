module "service" {
  source = "./service.iac"

  evt_env_domain         = var.evt_env_domain
  evt_env_domain_zone_id = var.evt_env_domain_zone_id

  aws_vpc_id              = var.aws_vpc_id
  aws_vpc_subnets_public  = var.aws_vpc_subnets_public
  aws_vpc_subnets_private = var.aws_vpc_subnets_private


  service_settings = {
    "evt_srv_002" = {
      external = true
    }
  }

  service_apps = {
    "sch_123" = {
      service = "evt_scheduled_01"
      image   = "hello-world"
      // port    = "80"
    }
  }

}

module "ecs" {
  source = "./modules/aws/ecs"

  service_settings = var.service_settings
  service_apps     = var.service_apps

  aws_vpc_id              = var.aws_vpc_id
  aws_vpc_subnets_public  = var.aws_vpc_subnets_public
  aws_vpc_subnets_private = var.aws_vpc_subnets_private

  // service_apps_lb = module.loadbalancer.service_apps_elb

}


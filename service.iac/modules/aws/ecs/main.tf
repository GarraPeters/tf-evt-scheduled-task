## ECS task exectution role

// resource "aws_iam_role" "scheduled_task_ecs_execution" {
//   for_each = { for k, v in var.service_apps : k => v }

//   name               = "${each.key}-st-ecs-execution-role"
//   assume_role_policy = "${file("${path.module}/policies/scheduled-task-ecs-execution-assume-role-policy.json")}"
// }

// data "template_file" "scheduled_task_ecs_execution_policy" {
//   template = "${file("${path.module}/policies/scheduled-task-ecs-execution-policy.json")}"
// }

// resource "aws_iam_role_policy" "scheduled_task_ecs_execution" {
//   for_each = { for k, v in var.service_apps : k => v }
//   name     = "${each.key}-st-ecs-execution-policy"
//   role     = "${aws_iam_role.scheduled_task_ecs_execution[each.key].id}"
//   policy   = "${data.template_file.scheduled_task_ecs_execution_policy.rendered}"
// }

resource "aws_iam_role" "ecsTaskExecutionRole" {
  for_each = { for k, v in var.service_apps : k => v }

  name = "${each.key}_ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {}
}

data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  for_each = { for k, v in aws_iam_role.ecsTaskExecutionRole : k => v }

  role       = aws_iam_role.ecsTaskExecutionRole[each.key].name
  policy_arn = data.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn

  depends_on = [
    aws_iam_role.ecsTaskExecutionRole,
  ]
}

## ECS task role

resource "aws_iam_role" "scheduled_task_ecs" {
  for_each           = { for k, v in var.service_apps : k => v }
  name               = "${each.key}-st-ecs-role"
  assume_role_policy = "${file("${path.module}/policies/scheduled-task-ecs-assume-role-policy.json")}"
}

## Cloudwatch event role

resource "aws_iam_role" "scheduled_task_cloudwatch" {
  for_each           = { for k, v in var.service_apps : k => v }
  name               = "${each.key}-st-cloudwatch-role"
  assume_role_policy = "${file("${path.module}/policies/scheduled-task-cloudwatch-assume-role-policy.json")}"
}

data "template_file" "scheduled_task_cloudwatch_policy" {
  for_each = { for k, v in var.service_apps : k => v }
  template = "${file("${path.module}/policies/scheduled-task-cloudwatch-policy.json")}"

  vars = {
    // task_execution_role_arn = "${aws_iam_role.scheduled_task_ecs_execution[each.key].arn}"
    task_execution_role_arn = aws_iam_role.ecsTaskExecutionRole[each.key].arn
  }
}

resource "aws_iam_role_policy" "scheduled_task_cloudwatch_policy" {
  for_each = { for k, v in var.service_apps : k => v }
  name     = "${each.key}-st-cloudwatch-policy"
  role     = "${aws_iam_role.scheduled_task_cloudwatch[each.key].id}"
  policy   = "${data.template_file.scheduled_task_cloudwatch_policy[each.key].rendered}"
}


## ECR Repo
resource "aws_ecr_repository" "repo" {
  for_each = { for k, v in var.service_apps : k => v }
  name     = each.key
}

resource "aws_ecr_repository_policy" "repo" {
  for_each   = { for k, v in aws_ecr_repository.repo : k => v }
  repository = aws_ecr_repository.repo[each.key].name

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "${aws_ecr_repository.repo[each.key].name}",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages",
                "ecr:DeleteRepository",
                "ecr:BatchDeleteImage",
                "ecr:SetRepositoryPolicy",
                "ecr:DeleteRepositoryPolicy"
            ]
        }
    ]
}
EOF

  depends_on = [
    aws_ecr_repository.repo,
  ]
}

locals {
  service_name = length(keys(var.service_settings)) > 0 ? element(keys(var.service_settings), 0) : ""
}

resource "aws_ecs_cluster" "cls" {
  for_each = { for k, v in var.service_settings : k => v }

  name = each.key
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "app" {
  for_each = { for k, v in var.service_apps : k => v }
  name     = each.key
}

resource "aws_ecs_task_definition" "app" {
  for_each = { for k, v in var.service_apps : k => v }

  family                   = each.key
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole[each.key].arn
  // execution_role_arn       = aws_iam_role.scheduled_task_ecs_execution[each.key].arn
  task_role_arn = aws_iam_role.scheduled_task_ecs[each.key].arn

  container_definitions = <<EOT
[
  {
    "image": "${var.service_apps[each.key].image}",
    "name": "${each.key}",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-group": "${aws_cloudwatch_log_group.app[each.key].name}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOT

  depends_on = [
    aws_cloudwatch_log_group.app,
  ]
}

## Cloudwatch event

resource "aws_cloudwatch_event_rule" "scheduled_task" {
  for_each            = { for k, v in var.service_apps : k => v }
  name                = "${each.key}_scheduled_task"
  description         = "Run ${each.key} task at a scheduled time"
  schedule_expression = "cron(0/5 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "scheduled_task" {
  for_each  = { for k, v in var.service_apps : k => v }
  target_id = "${each.key}_scheduled_task_target"
  rule      = aws_cloudwatch_event_rule.scheduled_task[each.key].name
  arn       = aws_ecs_cluster.cls[local.service_name].id
  role_arn  = "${aws_iam_role.scheduled_task_cloudwatch[each.key].arn}"

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = "1"
    task_definition_arn = aws_ecs_task_definition.app[each.key].arn

    network_configuration {
      subnets          = var.aws_vpc_subnets_private.*.id
      assign_public_ip = false
    }
  }


}



// resource "aws_ecs_service" "app" {
//   for_each = { for k, v in var.service_apps : k => v }

//   name    = each.key
//   cluster = aws_ecs_cluster.cls[local.service_name].id
//   // task_definition         = aws_ecs_task_definition.app[each.key].arn
//   desired_count           = "1"
//   launch_type             = "FARGATE"
//   propagate_tags          = "TASK_DEFINITION"
//   enable_ecs_managed_tags = true

//   deployment_controller {
//     type = "ECS"
//   }

//   deployment_maximum_percent         = 200
//   deployment_minimum_healthy_percent = 75

//   network_configuration {
//     // security_groups  = [aws_security_group.ecs_srv[each.key].id]
//     subnets          = var.aws_vpc_subnets_private.*.id
//     assign_public_ip = false
//   }


//   tags = {
//     "ecs_service"                     = each.key
//     "ecs_cluster"                     = aws_ecs_cluster.cls[local.service_name].id
//     "active_task_definition_name"     = aws_ecs_task_definition.app[each.key].family
//     "active_task_definition_revision" = aws_ecs_task_definition.app[each.key].revision
//   }

//   // depends_on = [
//   //   aws_ecs_cluster.cls,
//   //   aws_ecs_task_definition.app,
//   //   aws_security_group.ecs_srv,
//   //   aws_alb_target_group.app_ecs_fargate,
//   // ]
// }

provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

################################################################################
# NETWORKS
################################################################################

resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
}

resource "aws_subnet" "frontend" {
  count                   = length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

resource "aws_security_group" "frontend" {
  name   = "frontend"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id
}

resource "aws_subnet" "backend" {
  count             = length(data.aws_availability_zones.available.names)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 100 + count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_security_group" "backend" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8099
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# LOAD BALANCER
################################################################################

resource "aws_alb" "main" {
  name            = "javaalmanac-sandboxes"
  subnets         = aws_subnet.frontend.*.id
  security_groups = [aws_security_group.frontend.id]
}

# Certificate for the public frontend

resource "aws_acm_certificate" "certificate" {
  domain_name       = "*.sandbox.javaalmanac.io"
  validation_method = "DNS"
}

# DNS entries for the public frontend

resource "aws_route53_zone" javaalmanac {
  name = "javaalmanac.io"
}

resource "aws_route53_record" "aliasA" {
  zone_id = aws_route53_zone.javaalmanac.zone_id
  name    = "*.sandbox.javaalmanac.io"
  type    = "A"
  alias {
    name                   = aws_alb.main.dns_name
    zone_id                = aws_alb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aliasAAAA" {
  zone_id = aws_route53_zone.javaalmanac.zone_id
  name    = "*.sandbox.javaalmanac.io"
  type    = "AAAA"
  alias {
    name                   = aws_alb.main.dns_name
    zone_id                = aws_alb.main.zone_id
    evaluate_target_health = true
  }
}

# Listener and separate target groups for each Java version

resource "aws_alb_listener" "sandboxes" {
  load_balancer_arn = aws_alb.main.id
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.certificate.id
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No such sandbox"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "java11" {
  listener_arn = aws_alb_listener.sandboxes.arn
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.java11.id
  }
  condition {
    host_header {
      values = ["java11.sandbox.javaalmanac.io"]
    }
  }
}

resource "aws_alb_target_group" "java11" {
  name        = "javaalmanac-sandbox-java11"
  port        = 8011
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener_rule" "java12" {
  listener_arn = aws_alb_listener.sandboxes.arn
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.java12.id
  }
  condition {
    host_header {
      values = ["java12.sandbox.javaalmanac.io"]
    }
  }
}

resource "aws_alb_target_group" "java12" {
  name        = "javaalmanac-sandbox-java12"
  port        = 8012
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener_rule" "java13" {
  listener_arn = aws_alb_listener.sandboxes.arn
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.java13.id
  }
  condition {
    host_header {
      values = ["java13.sandbox.javaalmanac.io"]
    }
  }
}

resource "aws_alb_target_group" "java13" {
  name        = "javaalmanac-sandbox-java13"
  port        = 8013
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener_rule" "java14" {
  listener_arn = aws_alb_listener.sandboxes.arn
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.java14.id
  }
  condition {
    host_header {
      values = ["java14.sandbox.javaalmanac.io"]
    }
  }
}

resource "aws_alb_target_group" "java14" {
  name        = "javaalmanac-sandbox-java14"
  port        = 8014
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/health"
  }
}

################################################################################
# CLUSTER AND TASKS
################################################################################

resource "aws_ecr_repository" "repository" {
  name                 = "javaalmanac/sandbox"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecs_cluster" "main" {
  name = "javalmanac-sandboxes"
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_ecs_task_definition" "javasandboxes" {
  family                   = "javalmanac-sandboxes"
  network_mode             = "awsvpc"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  container_definitions    = <<DEFINITION
[
  {
    "name": "java11",
    "image": "${aws_ecr_repository.repository.repository_url}:latest-11",
    "environment" : [
      { "name" : "PORT", "value" : "8011" }
    ],
    "portMappings": [
      { "containerPort": 8011, "hostPort": 8011 }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.javasandboxes.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "java11"
      }
    }
  },
  {
    "name": "java12",
    "image": "${aws_ecr_repository.repository.repository_url}:latest-12",
    "environment" : [
      { "name" : "PORT", "value" : "8012" }
    ],
    "portMappings": [
      { "containerPort": 8012, "hostPort": 8012 }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.javasandboxes.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "java12"
      }
    }
  },
  {
    "name": "java13",
    "image": "${aws_ecr_repository.repository.repository_url}:latest-13",
    "environment" : [
      { "name" : "PORT", "value" : "8013" }
    ],
    "portMappings": [
      { "containerPort": 8013, "hostPort": 8013 }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.javasandboxes.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "java13"
      }
    }
  },
  {
    "name": "java14",
    "image": "${aws_ecr_repository.repository.repository_url}:latest-14",
    "environment" : [
      { "name" : "PORT", "value" : "8014" }
    ],
    "portMappings": [
      { "containerPort": 8014, "hostPort": 8014 }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.javasandboxes.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "java14"
      }
    }
  }
]
DEFINITION
}

resource "aws_ecs_service" "main" {
  name            = "javasandboxes"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.javasandboxes.arn
  desired_count   = "1"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.backend.id]
    subnets          = aws_subnet.backend.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.java11.id
    container_name   = "java11"
    container_port   = "8011"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.java12.id
    container_name   = "java12"
    container_port   = "8012"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.java13.id
    container_name   = "java13"
    container_port   = "8013"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.java14.id
    container_name   = "java14"
    container_port   = "8014"
  }

  depends_on = [
    aws_alb_listener.sandboxes
  ]
}

resource "aws_cloudwatch_log_group" "javasandboxes" {
  name = "javasandboxes"
}

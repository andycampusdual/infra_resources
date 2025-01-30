data "aws_iam_policy_document" "example" {
  statement {
    sid    = "new policy"
    effect = "Allow"
 
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:sts::248189943700:assumed-role/AWSReservedSSO_EKS-alumnos_a4561514b13725b0/andy.garcia@campusdual.com"]
    }
 
    actions = [
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
      "ecr:DeleteRepositoryPolicy",
    ]
  }
}

# P default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Create new subnets
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_default_vpc.default_vpc.id
  cidr_block        = "172.31.200.0/24"
  availability_zone = "eu-west-3a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_default_vpc.default_vpc.id
  cidr_block        = "172.31.201.0/24"
  availability_zone = "eu-west-3b"
}

resource "aws_subnet" "subnet_c" {
  vpc_id            = aws_default_vpc.default_vpc.id
  cidr_block        = "172.31.202.0/24"
  availability_zone = "eu-west-3c"
}

resource "aws_ecr_repository" "mi_primer_ecr_repo" {
  name = "mi-primer-ecr-repo-agd"
}

resource "aws_ecs_cluster" "mi_cluster" {
  name = "agd-cluster-new" # Nombra el cluster
}

resource "aws_iam_role" "ecsTaskExecutionRoleNew_agd" {
  name               = "ecsTaskExecutionRoleNew_agd"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRoleNew_agd.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_secretsmanager_secret" "db_credentials_main" {
  name = "db_credentials_main"
}

resource "aws_secretsmanager_secret_version" "db_credentials_value_main" {
  secret_id     = aws_secretsmanager_secret.db_credentials_main.id
  secret_string = jsonencode({
    username = "admin"
    password = "password123"
  })
}

resource "aws_db_instance" "db_instance" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.39"
  instance_class       = "db.t3.micro"
  db_name              = "mydb"
  username             = "admin"
  password             = "password123"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.main.name
}

resource "aws_db_subnet_group" "main" {
  name       = "main-subnet-group"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id, aws_subnet.subnet_c.id]
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_default_vpc.default_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "mi_primer_task" {
  family                   = "mi-primer-task-agd" # Nombra tu primer task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "mi-primer-task-agd",
      "image": "${aws_ecr_repository.mi_primer_ecr_repo.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256,
      "environment": [
        {
          "name": "DB_HOST",
          "value": "${aws_db_instance.db_instance.address}"
        },
        {
          "name": "DB_USER",
          "valueFrom": "${aws_secretsmanager_secret.db_credentials_main.arn}:username"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "${aws_secretsmanager_secret.db_credentials_main.arn}:password"
        }
      ]
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] 
  network_mode             = "awsvpc" 
  memory                   = 512       
  cpu                      = 256        
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRoleNew_agd.arn}"
}

resource "aws_alb" "application_load_balancer" {
  name               = "test-lb-tf" # testea el load balancer
  load_balancer_type = "application"
  subnets = [ 
    "${aws_subnet.subnet_a.id}",
    "${aws_subnet.subnet_b.id}",
    "${aws_subnet.subnet_c.id}"
  ]
  #  security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Crear security group para el  load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_default_vpc.default_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" 
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" 
  }
}

resource "aws_ecs_service" "mi_primer_service_agd" {
  name            = "mi-primer-service-agd"                             
  cluster         = "${aws_ecs_cluster.mi_cluster.id}"             
  task_definition = "${aws_ecs_task_definition.mi_primer_task.arn}" 
  launch_type     = "FARGATE"
  desired_count   = 3 

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" 
    container_name   = "${aws_ecs_task_definition.mi_primer_task.family}"
    container_port   = 3000 
  }

  network_configuration {
    subnets          = ["${aws_subnet.subnet_a.id}", "${aws_subnet.subnet_b.id}", "${aws_subnet.subnet_c.id}"]
    assign_public_ip = true                                                
    security_groups  = ["${aws_security_group.service_security_group.id}"] 
  }
}

resource "aws_security_group" "service_security_group" {
  vpc_id = aws_default_vpc.default_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_appautoscaling_target" "ecs_scaling_target_main" {
  max_capacity         = 10
  min_capacity         = 1
  resource_id          = "service/${aws_ecs_cluster.mi_cluster.name}/${aws_ecs_service.mi_primer_service_agd.name}"
  scalable_dimension   = "ecs:service:DesiredCount"
  service_namespace    = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_scaling_policy_main" {
  name               = "scale-out-main"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_scaling_target_main.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_scaling_target_main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_scaling_target_main.service_namespace

  step_scaling_policy_configuration {
    adjustment_type          = "ChangeInCapacity"
    cooldown                 = 300
    metric_aggregation_type  = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high_main" {
  alarm_name          = "ecs-cpu-high-main"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "This metric monitors ECS CPU utilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.mi_cluster.name
    ServiceName = aws_ecs_service.mi_primer_service_agd.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_scaling_policy_main.arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_low_main" {
  alarm_name          = "ecs-cpu-low-main"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 25
  alarm_description   = "This metric monitors ECS CPU utilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.mi_cluster.name
    ServiceName = aws_ecs_service.mi_primer_service_agd.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_scaling_policy_main.arn]
}
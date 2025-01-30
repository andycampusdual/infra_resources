resource "aws_ecs_cluster" "agd_cluster" {
  name = "agd-cluster-new"
}

resource "aws_ecs_task_definition" "nginx_task" {
  family                   = "nginx-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "nginx"
    image     = "nginx"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.agd_cluster.id
  task_definition = aws_ecs_task_definition.nginx_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-0717aac9526c9ff4b"]  
    security_groups  = ["sg-062439e675f267ba8"]    
    assign_public_ip = true
  }
}

resource "aws_appautoscaling_target" "ecs_scaling_target" {
  max_capacity         = 10
  min_capacity         = 1
  resource_id          = "service/${aws_ecs_cluster.agd_cluster.name}/${aws_ecs_service.nginx_service.name}"
  scalable_dimension   = "ecs:service:DesiredCount"
  service_namespace    = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_scaling_policy" {
  name               = "scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_scaling_target.service_namespace

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

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "This metric monitors ECS CPU utilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.agd_cluster.name
    ServiceName = aws_ecs_service.nginx_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_scaling_policy.arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_low" {
  alarm_name          = "ecs-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 25
  alarm_description   = "This metric monitors ECS CPU utilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.agd_cluster.name
    ServiceName = aws_ecs_service.nginx_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_scaling_policy.arn]
}
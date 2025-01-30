resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRoleNew"  # Cambia el nombre para evitar conflicto

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ssm_parameter" "api_key" {
  name      = "/myapp/api_keyagd"
  type      = "SecureString"
  value     = "valor de la api key"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "db_credentialsagd2"
}

resource "aws_secretsmanager_secret_version" "db_credentials_value" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = "123456789"
  })
}

resource "aws_ecs_task_definition" "my_task_with_secrets" {
  family                   = "mi-tarea-secrets"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn  # Asegúrate de incluir esto

  container_definitions = jsonencode([{
    name      = "web-serverapp"
    image     = "nginx"
    essential = true
    environment = [
      {
        name  = "API_KEY"
        valueFrom = aws_ssm_parameter.api_key.arn
      }
    ]
    secrets = [
      {
        name      = "DB_CREDENTIALS"
        valueFrom = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  }])
}
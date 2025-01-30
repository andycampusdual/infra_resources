provider "aws" {
  region = "eu-west-3" # Reemplaza con tu región de AWS
}
# Crear un repositorio ECR
resource "aws_ecr_repository" "ecr_agd" {
  name = "ecr-agd"
 
  tags = {
    Name        = "ecr-agd"
    Environment = "dev"
  }
}


# Configurar una Política de Ciclo de Vida para el Repositorio
resource "aws_ecr_lifecycle_policy" "my_lifecycle_policy" {
    repository = aws_ecr_repository.ecr_agd.name
 
    policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
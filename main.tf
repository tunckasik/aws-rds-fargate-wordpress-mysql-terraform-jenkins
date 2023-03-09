terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.57.1"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}
# Define the ECS task definition
resource "aws_ecs_task_definition" "example" {
  family                   = "example-task"
  container_definitions    = jsonencode([
    {
      name            = "wordpress-container"
      image           = "alitunckasik/wordpress"
      portMappings    = [
        {
          containerPort = 80
          hostPort      = 80
        },
      ]
      essential       = true
    },
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
}
# Define the ECS service that will run the task
resource "aws_ecs_service" "example" {
  name            = "example-service"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.example.arn
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.private.*.id[0]]
    security_groups  = [aws_security_group.example.id]
    assign_public_ip = false
  }
}
# Define any required resources, such as the VPC and subnets:
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "private" {
  count = 2
  cidr_block = "10.0.${count.index}.0/24"
  vpc_id = aws_vpc.example.id
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "example" {
  name_prefix = "example-sg"
  vpc_id = aws_vpc.example.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "example" {
  name = "example-cluster"
}


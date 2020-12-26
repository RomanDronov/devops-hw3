provider "aws" {
    region = "us-east-2"
}
variable "server_port" {
    description = "HTTP requests port"
    type = number
    default = 8080
}
resource "aws_launch_configuration" "example_ec2" {
  image_id = "ami-0c55b159cbfafe1f0" 
  instance_type = "t2.micro"

  user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p "${var.server_port}" & 
                EOF

  security_groups = [aws_security_group.asg_ec2_example.id]

    lifecycle {
      create_before_destroy = true
  }
}

resource "aws_security_group" "asg_ec2_example" {
    name = "asg_ec2_example"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_autoscaling_group" "autoscaling_example" {
    launch_configuration = aws_launch_configuration.example_ec2.id

    min_size = 2 
    max_size = 10

    load_balancers = [aws_elb.elb_example.name]
    health_check_type = "ELB"
    availability_zones = data.aws_availability_zones.all.names

    tag {
        key = "Name"
        value = "autoscaling_example"
        propagate_at_launch = true
    }
}

data "aws_availability_zones" "all" {}
resource "aws_elb" "elb_example" {
    name = "elbexample"
    availability_zones = data.aws_availability_zones.all.names
    security_groups = [aws_security_group.elb.id]

    health_check{
        target = "HTTP:${var.server_port}/"
        interval = 30
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }

    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = var.server_port
        instance_protocol = "http"
    }
}
resource "aws_security_group" "elb" {
    name = "terraform-el"

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

output "dns_name" {
    value = aws_elb.elb_example.dns_name
    description = "DNS name"
}
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "test_db"
  username             = "root"
  password             = "cdjfdioer234rojrfeefr4"
  parameter_group_name = "default.mysql5.7"
}
resource "aws_api_gateway_rest_api" "api" {
 name = "api-gateway"
 description = "Proxy to handle requests to our API"
}
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "my-function"
}
resource "aws_api_gateway_method" "methodDemo" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}
resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.methodDemo.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "https://ltd7o7t0sl.execute-api.us-east-2.amazonaws.com/my-function"
 
  request_parameters =  {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}
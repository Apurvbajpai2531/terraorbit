data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}


resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y nginx
              echo "<h1>TerraOrbit - #TerraWeek Challenge by TrainWithShubham</h1>" > /usr/share/nginx/html/index.html
              systemctl enable nginx
              systemctl start nginx
              EOF

  depends_on = [aws_route_table_association.public]
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
}

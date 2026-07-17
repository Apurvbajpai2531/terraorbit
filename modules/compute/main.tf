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
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y nginx
              cat > /usr/share/nginx/html/index.html << 'HTML'
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <title>TerraOrbit</title>
                <style>
                  body {
                    margin: 0;
                    height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    background: linear-gradient(135deg, #1a1a2e, #16213e);
                    font-family: Arial, sans-serif;
                    color: white;
                    text-align: center;
                  }
                  .card {
                    background: rgba(255,255,255,0.08);
                    padding: 40px 60px;
                    border-radius: 16px;
                    box-shadow: 0 0 30px rgba(0,0,0,0.4);
                  }
                  h1 { color: #7f5af0; margin-bottom: 10px; }
                  p { color: #ccc; }
                  .badge {
                    display: inline-block;
                    margin-top: 20px;
                    padding: 8px 16px;
                    background: #7f5af0;
                    border-radius: 20px;
                    font-size: 14px;
                  }
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>🚀 TerraOrbit</h1>
                  <p>AWS Infrastructure provisioned entirely with Terraform</p>
                  <div class="badge">TrainWithShubham #TerraWeek Challenge</div>
                </div>
              </body>
              </html>
              HTML
              systemctl enable nginx
              systemctl start nginx
              EOF
  tags      = merge(var.common_tags, { Name = "${var.name_prefix}-web" })
}

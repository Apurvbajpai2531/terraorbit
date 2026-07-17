# 🚀 TerraOrbit — 7-Day AWS Infrastructure-as-Code Project
### Built for the TrainWithShubham #TerraWeek Challenge (July 12–17, 2026)

## 1. What we're building

**TerraOrbit** is a single, end-to-end AWS project that grows a little bigger every day of the challenge, until by Day 7 you have a modular, remote-state-backed, CI/CD-driven, multi-workspace Terraform codebase.

**Final architecture:**
- A custom VPC with 2 public + 2 private subnets across 2 AZs
- An Internet Gateway + route tables
- A Security Group–protected EC2 (t2.micro, free tier) running Nginx, serving a "TerraOrbit" landing page
- An S3 bucket for static assets/logs (versioned, free tier)
- Remote state in S3 + state locking via DynamoDB
- Everything refactored into reusable **modules** (`network`, `compute`, `s3-website`)
- Multi-region provider aliasing + the `random` provider for unique names
- `dev` / `stage` / `prod` **workspaces**
- A GitHub Actions pipeline running `fmt → validate → plan → apply`

**Every resource used is AWS Free Tier eligible** (VPC, EC2 t2.micro, S3, DynamoDB on-demand, IAM). The only cost risk: an **unused Elastic IP** or **forgetting to `terraform destroy`** at day's end — always tear down before you close your laptop.

---

## 2. Prerequisites (do this once, before Day 1)

1. AWS account (Free Tier) → create an **IAM user** (not root) with `AdministratorAccess` for learning purposes, and generate an Access Key.
2. Install AWS CLI, Terraform, Git.

```bash
# Terraform (Linux/WSL example)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y
terraform -version

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version
```

3. Configure credentials:

```bash
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region: ap-south-1   (or your preferred free-tier region)
# Default output format: json
```

4. Create your project folder and git repo:

```bash
mkdir terraorbit && cd terraorbit
git init
echo ".terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl
*.tfvars
!example.tfvars" > .gitignore
```

---

## 3. Day 1 (Sunday) — Introduction to Terraform

**Goal:** understand IaC, install/verify tooling, write and apply your first config.

```bash
touch main.tf provider.tf outputs.tf
```

`provider.tf`
```hcl
terraform {
  required_version = ">= 1.7.0"
}

provider "aws" {
  region = "ap-south-1"
}
```

`main.tf`
```hcl
data "aws_caller_identity" "current" {}
```

`outputs.tf`
```hcl
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
```

Commands:
```bash
terraform init
terraform plan
terraform apply -auto-approve
terraform show
```

Commit:
```bash
git add .
git commit -m "Day 1: Terraform installed, first config applied - #TerraWeek"
```

---

## 4. Day 2 (Monday) — HCL: Variables, Data Types, Expressions

**Goal:** externalize config with variables/locals, practice HCL data types.

`variables.tf`
```hcl
variable "project_name" {
  type    = string
  default = "terraorbit"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
```

`locals.tf`
```hcl
locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Challenge   = "TerraWeek"
  }, var.extra_tags)

  name_prefix = "${var.project_name}-${var.environment}"
  is_prod     = var.environment == "prod" ? true : false
}
```

Practice in the REPL:
```bash
terraform console
> local.name_prefix
> local.is_prod
> [for c in var.public_subnet_cidrs : cidrhost(c, 4)]
> exit
```

Format & validate (do this every day from now on):
```bash
terraform fmt -recursive
terraform validate
git add . && git commit -m "Day 2: variables, locals, HCL expressions - #TerraWeek"
```

---

## 5. Day 3 (Tuesday) — Managing Resources: Network + Compute

**Goal:** define real resources, dependencies, provisioners, lifecycle rules.

`network.tf`
```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-${count.index}" })
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-${count.index}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
  depends_on     = [aws_internet_gateway.igw]
}
```

`security.tf`
```hcl
resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-web-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"] # replace with `curl ifconfig.me`
  }
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

  lifecycle {
    create_before_destroy = true
  }
  tags = local.common_tags
}
```

`compute.tf`
```hcl
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
```

`outputs.tf` (append)
```hcl
output "web_public_ip" {
  value = aws_instance.web.public_ip
}
```

Apply and test:
```bash
terraform plan
terraform apply -auto-approve
curl http://$(terraform output -raw web_public_ip)
git add . && git commit -m "Day 3: VPC, subnets, SG, EC2 web server - #TerraWeek"
```

---

## 6. Day 4 (Wednesday) — Remote State Management

**Goal:** move from local `.tfstate` to a locked, shared S3 backend.

Bootstrap the backend resources **once**, in a separate tiny config (`bootstrap/` folder) so they aren't destroyed with the rest of your stack:

```bash
mkdir bootstrap && cd bootstrap
```
`bootstrap/main.tf`
```hcl
provider "aws" { region = "ap-south-1" }

resource "aws_s3_bucket" "tf_state" {
  bucket = "terraorbit-tfstate-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration { status = "Enabled" }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_dynamodb_table" "lock" {
  name         = "terraorbit-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

output "bucket_name" { value = aws_s3_bucket.tf_state.bucket }
```
```bash
terraform init && terraform apply -auto-approve
terraform output bucket_name
cd ..
```

Back in the root project, add `backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "terraorbit-tfstate-XXXXXXXX"  # from bootstrap output
    key            = "terraorbit/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraorbit-tf-locks"
    encrypt        = true
  }
}
```

Migrate state:
```bash
terraform init -migrate-state
```

Practice state commands:
```bash
terraform state list
terraform state show aws_instance.web
terraform state mv aws_security_group.web aws_security_group.web_sg   # then rename in code to match, or revert
```

Test locking by running `terraform plan` in two terminals at once — second one should wait/lock-error.

```bash
git add . && git commit -m "Day 4: S3 + DynamoDB remote state and locking - #TerraWeek"
```

---

## 7. Day 5 (Thursday) — Refactor into Modules

**Goal:** turn Day 3's flat resources into reusable modules.

```bash
mkdir -p modules/network modules/compute modules/s3-website
```

Move `network.tf` + `security.tf` content into `modules/network/main.tf`, with their own `variables.tf`/`outputs.tf`. Move `compute.tf` into `modules/compute/main.tf` similarly. Create a small `modules/s3-website` module for the static-assets bucket.

Root `main.tf` becomes:
```hcl
module "network" {
  source               = "./modules/network"
  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  common_tags          = local.common_tags
}

module "compute" {
  source          = "./modules/compute"
  name_prefix     = local.name_prefix
  instance_type   = var.instance_type
  subnet_id       = module.network.public_subnet_ids[0]
  security_group_id = module.network.web_sg_id
  common_tags     = local.common_tags
}

module "s3_website" {
  source      = "./modules/s3-website"
  name_prefix = local.name_prefix
  common_tags = local.common_tags
}
```

Each module exposes its own `variables.tf` (inputs) and `outputs.tf` (e.g. `vpc_id`, `public_subnet_ids`, `web_sg_id`, `instance_public_ip`, `bucket_name`).

> **Module versioning note:** once stable, push `modules/network` to its own repo and reference it as:
> `source = "git::https://github.com/<you>/terraform-aws-network.git?ref=v1.0.0"`

```bash
terraform init
terraform plan
terraform apply -auto-approve
git add . && git commit -m "Day 5: refactored into network/compute/s3-website modules - #TerraWeek"
```

---

## 8. Day 6 (Friday, Part 1) — Providers

**Goal:** pin provider versions, add aliasing and a second provider.

`versions.tf`
```hcl
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

`provider.tf` (append an aliased DR-region provider)
```hcl
provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dr"
  region = "us-east-1"
}
```

Use the `random` provider for a globally-unique bucket suffix instead of hardcoding:
```hcl
resource "random_id" "bucket_suffix" {
  byte_length = 4
}
```

Check what's wired up:
```bash
terraform providers
terraform init -upgrade
git add . && git commit -m "Day 6: provider version pinning, aliasing, random provider - #TerraWeek"
```

---

## 9. Day 7 (Friday/Advanced) — Workspaces, CI/CD, Best Practices

**Goal:** environment isolation + automation + final polish.

Workspaces:
```bash
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod
terraform workspace select dev
```

Reference `terraform.workspace` in naming so `dev`/`stage`/`prod` never collide:
```hcl
locals {
  name_prefix = "${var.project_name}-${terraform.workspace}"
}
```

GitHub Actions pipeline — `.github/workflows/terraform.yml`:
```yaml
name: Terraform CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: .
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-south-1

      - run: terraform init
      - run: terraform fmt -check -recursive
      - run: terraform validate
      - run: terraform plan -out=tfplan

      - name: Apply (main branch only)
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
```

Add repo secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` in GitHub → Settings → Secrets.

Best-practice pass:
```bash
terraform fmt -recursive
terraform validate
# optional linting
tflint --init && tflint
```

Final `README.md` should include: architecture summary, prerequisites, how to run each day, screenshots of the Nginx page, and the line:
> "TrainWithShubham #TerraWeek Challenge"

```bash
git add . && git commit -m "Day 7: workspaces, GitHub Actions CI/CD, final docs - #TerraWeek"
git push -u origin main
```

---

## 10. Cleanup (do this after judging / to avoid any charges)

```bash
terraform workspace select dev   && terraform destroy -auto-approve
terraform workspace select stage && terraform destroy -auto-approve
terraform workspace select prod  && terraform destroy -auto-approve

# then remove the bootstrap backend resources LAST
cd bootstrap
terraform destroy -auto-approve
```

---

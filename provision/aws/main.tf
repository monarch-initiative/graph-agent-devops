variable "tags" {
  type = map
  default = { Name = "test-graph-agent-devops" }
}

variable "instance_type" {
  default = "t2.large"
}

variable "disk_size" {
  default = 200
}

variable "public_key_path" {
  default = "/tmp/ga-ssh.pub"
}

variable "use_elastic_ip" {
  type = bool
  description = "whether to use an elastic ip or not"
  default = true
}

provider "aws" {
  region = "us-east-1"
  shared_credentials_files = [ "/tmp/ga-aws-credentials" ]
  profile = "default"
}

variable "open_ports" {
  type = list
  default = [22, 80]
}

// Standard Ubuntu 24.04 LTS.
variable "ami" {
  default = "ami-04b4f1a9cf54c11d0"
}

// optional will be created if value is not an menty string
variable "dns_record_name" {
  type = string
  description = "type A DNS record wich will be mapped to public ip"
  default = ""
}

variable "dns_zone_id" {
  type = string
  description = "zone id for dns record."
  default = ""
}

module "base" {
  source = "git::https://github.com/geneontology/devops-aws-go-instance.git?ref=V3.1"
  instance_type = var.instance_type
  ami = var.ami
  use_elastic_ip = var.use_elastic_ip
  dns_record_name = var.dns_record_name
  dns_zone_id = var.dns_zone_id
  public_key_path = var.public_key_path
  tags = var.tags
  open_ports = var.open_ports
  disk_size = var.disk_size
  vpc_id = "vpc-b4a2c8c9"
  subnet_id = "subnet-bb1b3f9a"
}

output "dns_records" {
  value = module.base.dns_records
}

output "public_ip" {
   value                  = module.base.public_ip
}

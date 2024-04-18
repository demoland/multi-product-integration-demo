variable "subnet_id" {
  type    = string
  default = "subnet-022759a44dd1b0aaf"
}

variable "region" {
  type    = string
  default = "us-east-2"
}

source "amazon-ebs" "amd" {
  region                      = var.region
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-mantic-23.10-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }
  instance_type = "t3a.medium"
  ssh_username  = "ubuntu"
  ami_name      = "amd64-{{timestamp}}"
  tags = {
    timestamp      = "{{timestamp}}"
    consul_enabled = true
    nomad_enabled  = true
  }
}

source "amazon-ebs" "arm" {
  region                      = var.region
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-mantic-23.10-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }
  instance_type = "t4g.medium"
  ssh_username  = "ubuntu"
  ami_name      = "arm64-{{timestamp}}"
  tags = {
    timestamp      = "{{timestamp}}"
    consul_enabled = true
    nomad_enabled  = true
  }
}

build {
  sources = [
    "source.amazon-ebs.amd",
    "source.amazon-ebs.arm"
  ]

  hcp_packer_registry {
    bucket_name = "ubuntu-mantic-hashi"
    description = "Ubuntu Mantic Minotaur with Nomad and Consul installed"

    bucket_labels = {
      "os"             = "Ubuntu",
      "ubuntu-version" = "23.10",
    }

    build_labels = {
      "timestamp"      = timestamp()
      "consul_enabled" = true
      "nomad_enabled"  = true
    }
  }

  provisioner "shell" {
    inline = [
      "echo Ubuntu: $(lsb_release -cs)",
      "sudo apt-get update",
      "wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg",
      "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee -a /etc/apt/sources.list.d/hashicorp.list",
      "sudo apt update",
      "sudo apt install -y consul nomad curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo curl -L -o cni-plugins.tgz \"https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-$([ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)\"-v1.3.0.tgz",
      "sudo mkdir -p /opt/cni/bin",
      "sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz",
    ]
  }
}
provider "aws" {
  region        = "${var.aws_region}"
}

resource "aws_key_pair" "keypair" {
  key_name   = "${var.aws_prefix}_key"
  public_key = "${file(var.aws_local_public_key)}"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true

  tags {
    Name               = "${var.aws_prefix}_vpc"
  }
}

resource "aws_subnet" "vpc_subnet_management" {
  vpc_id      = "${aws_vpc.vpc.id}"
  cidr_block  = "10.0.0.0/22"
  tags {
    Name      = "${var.aws_prefix}_subnet_management"
  }
}

resource "aws_subnet" "vpc_subnet_external" {
  vpc_id      = "${aws_vpc.vpc.id}"
  cidr_block  = "10.0.1.0/22"
  tags {
    Name      = "${var.aws_prefix}_subnet_external"
  }
}

resource "aws_subnet" "vpc_subnet_internal" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.2.0/22"
  tags {
    Name = "${var.aws_prefix}_subnet_internal"
  }
}

resource "aws_security_group" "ssh_https_ping" {
  name        = "${var.aws_prefix}_secgroup_ssh_https_ping"
  description = "SSH, HTTPS and Ping only for ${var.aws_prefix}"
  vpc_id      = "${aws_vpc.vpc.id}"

  # inbound ssh access from the world
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound https access from the world
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound icmp echo request
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound icmp echo request
  egress {
    from_port   = 8
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound icmp echo reply
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.aws_prefix}_secgroup_ssh_https_ping"
  }
}

resource "aws_security_group" "all_traffic" {
  name          = "${var.aws_prefix}_all_traffic"
  description   = "All traffic in and out"
  vpc_id        = "${aws_vpc.vpc.id}"

  # all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.aws_prefix}_all_traffic"
  }
}

resource "aws_route_table" "vpc_rt" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.aws_prefix}_rt"
  }
}

resource "aws_route_table_association" "vpc_subnet_external_rt_association" {
  subnet_id      = "${aws_subnet.vpc_subnet_external.id}"
  route_table_id = "${aws_route_table.vpc_rt.id}"
}

resource "aws_instance" "f5_lab_vm" {
  ami                     = "${lookup(var.f5_ami, var.aws_region)}"
  instance_type           = "${var.aws_type}"
  key_name                = "${aws_key_pair.keypair.key_name}"
  subnet_id               = "${aws_subnet.vpc_subnet_management.id}"
  vpc_security_group_ids  = ["${aws_security_group.ssh_https_ping.id}"]
  tags {
    Name = "${var.aws_prefix}_f5_lab_vm"
  }
}

resource "aws_network_interface" "eth1" {
  subnet_id         = "${aws_subnet.vpc_subnet_external.id}"
  security_groups   = ["${aws_security_group.all_traffic.id}"]
  attachment {
      instance      = "${aws_instance.f5_lab_vm.id}"
      device_index  = 1
  }

  tags {
    Name              = "${var.aws_prefix}_eth1_external"
  }
}

resource "aws_network_interface" "eth2" {
  subnet_id         = "${aws_subnet.vpc_subnet_internal.id}"
  security_groups   = ["${aws_security_group.all_traffic.id}"]
  attachment {
      instance      = "${aws_instance.f5_lab_vm.id}"
      device_index  = 2
  }

  tags {
    Name              = "${var.aws_prefix}_eth2_internal"
  }
}

resource "aws_eip" "f5_public_ip" {
  vpc       = true
  instance  = "${aws_instance.f5_lab_vm.id}"

  tags {
    Name    = "${var.aws_prefix}_eip_management"
  }
}

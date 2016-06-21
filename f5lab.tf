provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_key_pair" "keypair" {
  key_name   = "${var.aws_prefix}_key"
  public_key = "${file(var.aws_local_public_key)}"
}

resource "aws_vpc" "f5_vpc" {
  cidr_block          = "10.0.0.0/16"
  instance_tenancy    = "default"
  enable_dns_support  = true
  tags {
    Name              = "${var.aws_prefix}_vpc"
  }
}

resource "aws_internet_gateway" "f5_gateway" {
    vpc_id = "${aws_vpc.f5_vpc.id}"
    tags {
      Name = "${var.aws_prefix}_gateway"
    }
}

resource "aws_eip" "f5_nat_gateway_ip" {
  vpc = true
}

resource "aws_subnet" "f5_vpc_subnet_management" {
  vpc_id            = "${aws_vpc.f5_vpc.id}"
  availability_zone = "${var.aws_availability_zone}"
  cidr_block        = "10.0.0.0/24"
  tags {
    Name            = "${var.aws_prefix}_subnet_management"
  }
}

resource "aws_subnet" "f5_vpc_subnet_external" {
  vpc_id            = "${aws_vpc.f5_vpc.id}"
  availability_zone = "${var.aws_availability_zone}"
  cidr_block        = "10.0.1.0/24"
  tags {
    Name            = "${var.aws_prefix}_subnet_external"
  }
}

resource "aws_subnet" "f5_vpc_subnet_internal" {
  vpc_id            = "${aws_vpc.f5_vpc.id}"
  availability_zone = "${var.aws_availability_zone}"
  cidr_block        = "10.0.2.0/24"
  tags {
    Name            = "${var.aws_prefix}_subnet_internal"
  }
}

resource "aws_nat_gateway" "f5_nat_gateway" {
  depends_on    = ["aws_internet_gateway.f5_gateway"]
  allocation_id = "${aws_eip.f5_nat_gateway_ip.id}"
  subnet_id     = "${aws_subnet.f5_vpc_subnet_management.id}"
}

resource "aws_security_group" "f5_ssh_https_ping" {
  name          = "${var.aws_prefix}_f5_ssh_https_ping_secgroup"
  description   = "SSH, HTTPS and Ping only for ${var.aws_prefix}"
  vpc_id        = "${aws_vpc.f5_vpc.id}"

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
    Name        = "${var.aws_prefix}_f5_ssh_https_ping_secgroup"
  }
}

resource "aws_security_group" "f5_all_traffic" {
  name          = "${var.aws_prefix}_f5_all_traffic_secgroup"
  description   = "All traffic in and out"
  vpc_id        = "${aws_vpc.f5_vpc.id}"

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
    Name        = "${var.aws_prefix}_f5_all_traffic_secgroup"
  }
}

resource "aws_route_table" "f5_vpc_rt" {
  vpc_id = "${aws_vpc.f5_vpc.id}"
  tags {
    Name = "${var.aws_prefix}_rt"
  }
}

resource "aws_route_table_association" "f5_vpc_subnet_external_rt_association" {
  subnet_id      = "${aws_subnet.f5_vpc_subnet_external.id}"
  route_table_id = "${aws_route_table.f5_vpc_rt.id}"
}

resource "aws_route" "f5_nat_gateway_route" {
  route_table_id         = "${aws_route_table.f5_vpc_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.f5_gateway.id}"
}

resource "aws_route_table_association" "f5_vpc_subnet_management_rt_association" {
  subnet_id      = "${aws_subnet.f5_vpc_subnet_management.id}"
  route_table_id = "${aws_route_table.f5_vpc_rt.id}"
}

resource "aws_instance" "f5_lab_vm" {
  depends_on             = ["aws_internet_gateway.f5_gateway"]
  ami                    = "${lookup(var.f5_ami, var.aws_region)}"
  availability_zone
  = "${var.aws_availability_zone}"
  instance_type          = "${var.aws_type}"
  key_name               = "${aws_key_pair.keypair.key_name}"
  subnet_id              = "${aws_subnet.f5_vpc_subnet_management.id}"
  vpc_security_group_ids = ["${aws_security_group.f5_ssh_https_ping.id}"]
  tags {
    Name                 = "${var.aws_prefix}_f5_lab_vm"
  }
}

resource "aws_network_interface" "f5_eth1" {
  subnet_id        = "${aws_subnet.f5_vpc_subnet_external.id}"
  security_groups  = ["${aws_security_group.f5_all_traffic.id}"]
  private_ips = ["10.0.1.50", "10.0.1.51"]
  attachment {
      instance     = "${aws_instance.f5_lab_vm.id}"
      device_index = 1
  }
  tags {
    Name           = "${var.aws_prefix}_f5_eth1_external"
  }
}

resource "aws_network_interface" "f5_eth2" {
  subnet_id        = "${aws_subnet.f5_vpc_subnet_internal.id}"
  security_groups  = ["${aws_security_group.f5_all_traffic.id}"]
  attachment {
      instance     = "${aws_instance.f5_lab_vm.id}"
      device_index = 2
  }
  tags {
    Name            = "${var.aws_prefix}_f5_eth2_internal"
  }
}

resource "aws_eip" "f5_public_ip" {
  vpc       = true
  instance  = "${aws_instance.f5_lab_vm.id}"
}

output "Instructions" {
  value = "Now run 'ssh root@${aws_eip.f5_public_ip.public_ip} tmsh modify auth password admin'"
}

output "Management access" {
  value = "https://${aws_eip.f5_public_ip.public_ip}"
}

output "External subnet private ips" {
  value = "${join(", ", aws_network_interface.f5_eth1.private_ips)}"
}

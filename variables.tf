variable "aws_region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "aws_prefix" {
  description = "AWS prefix to name and tag resources with"
  default     = "f5-lab"
}

variable "aws_local_public_key" {
  default     = "~/.ssh/id_rsa.pub"
  description = "Location of public key material to import into the <aws_prefix>_keypair"
}

variable "aws_type" {
  default     = "m3.xlarge"
  description = "Instance type. m3.xlarge, m3.2xlarge or cc2.8xlarge only"
}

variable "f5_ami" {
    type        = "map"
    description = "map of region to ami id for f5 lab amis"

    default = {
        us-east-1       = "ami-e692848c"
        us-west-1       = "ami-9cb3cffc"
        us-west-2       = "ami-47ef1b27"
        eu-west-1       = "ami-3ecc4f4d"
        eu-central-1    = "ami-764dac19"
        ap-northeast-1  = "ami-ed160583"
        ap-southeast-1  = "ami-a7f227c4"
        ap-southeast-2  = "ami-894a68ea"
        sa-east-1       = "ami-0b20af67"
    }
}
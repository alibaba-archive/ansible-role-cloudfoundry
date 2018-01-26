variable "alicloud_access_key" {
}

variable "alicloud_secret_key" {
}

variable "alicloud_region" {
}

variable "vpc_cidr" {
  default = "172.16.0.0/12"
}
variable "vswitch_cidr_bosh" {
  default = "172.16.0.0/24"
}
variable "bosh_gateway" {
  default = "172.16.0.1"
}

variable "vswitch_cidr_cf" {
  type = "list"
  default = ["172.16.10.0/24", "172.16.11.0/24", "172.16.12.0/24"]
}

variable "cf_gateway" {
  type = "list"
  default = ["172.16.10.1", "172.16.11.1", "172.16.12.1"]
}

variable "router_private_ip" {
  default = "172.16.0.27"
}
variable "uaa_private_ip" {
  default = "172.16.0.25"
}
variable "bosh_ip" {
  default = "172.16.0.3"
}
variable "rule_policy" {
  default = "accept"
}
variable "instance_type" {
  default = "ecs.n4.small"
}
# Image variables
variable "image_name_regex" {
  description = "The ECS image's name regex used to fetch specified image."
  default = "^ubuntu_16.*_64"
}
variable "disk_category"{
  default = "cloud_efficiency"
}
variable "ecs_password"{
  default = "Test12345"
}
variable "prefix"{
  default = "_v16_1016"
}
variable "domain_name" {
  description = "The domain name used to access to your application, like aliyun.com"
}
variable "key_pair_name" {
  default = "private-key-for-bosh"
}
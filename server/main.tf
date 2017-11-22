provider "alicloud" {
  access_key = "${var.alicloud_access_key}"
  secret_key = "${var.alicloud_secret_key}"
  region = "${var.alicloud_region}"
}

data "alicloud_instance_types" "1c2g" {
  cpu_core_count = 2
  memory_size = 4
}

// Images data source for image_id
data "alicloud_images" "default" {
  most_recent = true
  owners = "system"
  name_regex = "${var.image_name_regex}"
}

data "alicloud_zones" "default" {
  "available_instance_type"= "${data.alicloud_instance_types.1c2g.instance_types.0.id}"
  "available_disk_category"= "${var.disk_category}"
}

resource "alicloud_vpc" "default" {
  name = "for_cf${var.prefix}"
  cidr_block = "${var.vpc_cidr}"
}

resource "alicloud_vswitch" "bosh" {
  name = "for_bosh${var.prefix}"
  vpc_id = "${alicloud_vpc.default.id}"
  cidr_block = "${var.vswitch_cidr_bosh}"
  availability_zone = "${data.alicloud_zones.default.zones.0.id}"
}
resource "alicloud_vswitch" "cf" {
  count = "${length(var.vswitch_cidr_cf)}"
  name = "vswitch_for_cf${var.prefix}-${count.index}"
  vpc_id = "${alicloud_vpc.default.id}"
  cidr_block = "${element(var.vswitch_cidr_cf, count.index)}"
  availability_zone = "${data.alicloud_zones.default.zones.0.id}"
}
//
resource "alicloud_nat_gateway" "default" {
  vpc_id = "${alicloud_vpc.default.id}"
  spec = "Small"
  name = "for_bosh${var.prefix}"
  bandwidth_packages = [{
    ip_count = 2
    bandwidth = 10
    zone = "${data.alicloud_zones.default.zones.0.id}"
  }]
  depends_on = [
    "alicloud_vswitch.bosh"]
}
resource "alicloud_snat_entry" "bosh"{
  snat_table_id = "${alicloud_nat_gateway.default.snat_table_ids}"
  source_vswitch_id = "${alicloud_vswitch.bosh.id}"
  snat_ip = "${element(split(",", alicloud_nat_gateway.default.bandwidth_packages.0.public_ip_addresses),0)}"
}
resource "alicloud_snat_entry" "cf"{
  count = "${length(var.vswitch_cidr_cf)}"
  snat_table_id = "${alicloud_nat_gateway.default.snat_table_ids}"
  source_vswitch_id = "${element(alicloud_vswitch.cf.*.id, count.index)}"
  snat_ip = "${element(split(",", alicloud_nat_gateway.default.bandwidth_packages.0.public_ip_addresses),0)}"
}

resource "alicloud_forward_entry" "ssh"{
  forward_table_id = "${alicloud_nat_gateway.default.forward_table_ids}"
  external_ip = "${element(split(",", alicloud_nat_gateway.default.bandwidth_packages.0.public_ip_addresses),1)}"
  external_port = "22"
  ip_protocol = "tcp"
  internal_ip = "${alicloud_instance.default.private_ip}"
  internal_port = "22"
}

resource "alicloud_security_group" "sg" {
  name = "bosh_init_sg${var.prefix}"
  description = "tf_sg"
  vpc_id = "${alicloud_vpc.default.id}"
}

resource "alicloud_security_group_rule" "all-in" {
  type = "ingress"
  ip_protocol = "all"
  nic_type = "intranet"
  policy = "accept"
  port_range = "-1/-1"
  priority = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "http-out" {
  type = "egress"
  ip_protocol = "all"
  nic_type = "intranet"
  policy = "accept"
  port_range = "-1/-1"
  priority = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip = "0.0.0.0/0"
}

resource "alicloud_slb" "http" {
  name = "http_for_cf${var.prefix}"
  vswitch_id = "${alicloud_vswitch.cf.0.id}"
  internet_charge_type = "paybytraffic"
//  internet=true
  listener = [
    {
      "instance_port" = "80"
      "lb_port" = "80"
      "lb_protocol" = "http"
      "bandwidth" = "10"
    },
    {
      "instance_port" = "443"
      "lb_port" = "443"
      "lb_protocol" = "tcp"
      "bandwidth" = "10"
    }]
}

resource "alicloud_slb" "tcp" {
  name = "tcp_for_cf${var.prefix}"
  vswitch_id = "${alicloud_vswitch.cf.0.id}"
//  internet=true
  internet_charge_type = "paybytraffic"
  listener = [
    {
      "instance_port" = "80"
      "lb_port" = "80"
      "lb_protocol" = "tcp"
      "bandwidth" = "10"
    },
    {
      "instance_port" = "443"
      "lb_port" = "443"
      "lb_protocol" = "tcp"
      "bandwidth" = "10"
    }]
}

resource "alicloud_instance" "default" {
  security_groups = [
    "${alicloud_security_group.sg.id}"]

  vswitch_id = "${alicloud_vswitch.bosh.id}"

  password = "${var.ecs_password}"

  # series III
  instance_charge_type = "PostPaid"
  instance_type = "${data.alicloud_instance_types.1c2g.instance_types.0.id}"
  internet_max_bandwidth_out = 0

  system_disk_category = "cloud_efficiency"
  system_disk_size = 100
  image_id = "${data.alicloud_images.default.images.0.id}"
  instance_name = "for_bosh_director${var.prefix}"


  provisioner "local-exec" {
    command = <<EOF
        echo [CloudFoundaryServer] > ../hosts
        echo ${element(split(",", alicloud_nat_gateway.default.bandwidth_packages.0.public_ip_addresses),1)} ansible_user=root ansible_ssh_pass=${var.ecs_password} >> ../hosts
        echo \n
        echo internal_cidr: ${var.vswitch_cidr_bosh} >> ../group_vars/all
        echo internal_gw: ${var.bosh_gateway} >> ../group_vars/all
        echo internal_ip: ${var.bosh_ip} >> ../group_vars/all
        echo security_group_id: ${alicloud_security_group.sg.id} >> ../group_vars/all
        echo vswitch_id: ${alicloud_vswitch.bosh.id} >> ../group_vars/all
        echo bosh_zone: ${alicloud_vswitch.bosh.availability_zone} >> ../group_vars/all
        echo system_domain: ${alicloud_eip.default.ip_address}.${var.domain_name} >> ../group_vars/all
        echo "########deployment cf variables########" >> ../group_vars/all
        echo zone_1: ${alicloud_vswitch.cf.0.availability_zone} >> ../group_vars/all
        echo vswitch_id_1: ${alicloud_vswitch.cf.0.id} >> ../group_vars/all
        echo vswitch_range_1: ${alicloud_vswitch.cf.0.cidr_block} >> ../group_vars/all
        echo vswitch_gateway_1: ${element(var.cf_gateway, 0)} >> ../group_vars/all
        echo zone_2: ${alicloud_vswitch.cf.1.availability_zone} >> ../group_vars/all
        echo vswitch_id_2: ${alicloud_vswitch.cf.1.id} >> ../group_vars/all
        echo vswitch_range_2: ${alicloud_vswitch.cf.1.cidr_block} >> ../group_vars/all
        echo vswitch_gateway_2: ${element(var.cf_gateway, 1)} >> ../group_vars/all
        echo zone_3: ${alicloud_vswitch.cf.2.availability_zone} >> ../group_vars/all
        echo vswitch_id_3: ${alicloud_vswitch.cf.2.id} >> ../group_vars/all
        echo vswitch_range_3: ${alicloud_vswitch.cf.2.cidr_block} >> ../group_vars/all
        echo vswitch_gateway_3: ${element(var.cf_gateway, 2)} >> ../group_vars/all
        echo tcp_slb_id: ${alicloud_slb.tcp.id} >> ../group_vars/all
        echo http_slb_id: ${alicloud_slb.http.id} >> ../group_vars/all
  EOF
  }
}


resource "alicloud_eip" "default" {
  bandwidth=10
}

//resource "alicloud_eip_association" "default" {
//  instance_id="${alicloud_instance.default.id}"
//  allocation_id="${alicloud_eip.default.0.id}"
//}

//resource "alicloud_eip_association" "http" {
//  instance_id="${alicloud_slb.http.id}"
//  allocation_id="${alicloud_eip.default.0.id}"
//}
//
//resource "alicloud_eip_association" "tcp" {
//  instance_id="${alicloud_slb.tcp.id}"
//  allocation_id="${alicloud_eip.default.1.id}"
//}
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
  availability_zone = "${lookup(data.alicloud_zones.default.zones[count.index%length(data.alicloud_zones.default.zones)], "id")}"
}

resource "alicloud_nat_gateway" "default" {
  vpc_id = "${alicloud_vpc.default.id}"
  name = "for_bosh${var.prefix}"
}

resource "alicloud_eip" "default" {
  bandwidth = 10
}

resource "alicloud_eip_association" "default" {
  allocation_id = "${alicloud_eip.default.id}"
  instance_id = "${alicloud_nat_gateway.default.id}"
}

resource "alicloud_snat_entry" "bosh"{
  snat_table_id = "${alicloud_nat_gateway.default.snat_table_ids}"
  source_vswitch_id = "${alicloud_vswitch.bosh.id}"
  snat_ip = "${alicloud_eip.default.ip_address}"
}

resource "alicloud_security_group" "sg" {
  count = 3
  name = "bosh_init_sg${var.prefix}"
  description = "tf_sg"
  vpc_id = "${alicloud_vpc.default.id}"
}

resource "alicloud_security_group_rule" "all-in" {
  count = 3
  type = "ingress"
  ip_protocol = "all"
  nic_type = "intranet"
  policy = "accept"
  port_range = "-1/-1"
  priority = 1
  security_group_id = "${element(alicloud_security_group.sg.*.id, count.index)}"
  cidr_ip = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "http-out" {
  count = 3
  type = "egress"
  ip_protocol = "all"
  nic_type = "intranet"
  policy = "accept"
  port_range = "-1/-1"
  priority = 1
  security_group_id = "${element(alicloud_security_group.sg.*.id, count.index)}"
  cidr_ip = "0.0.0.0/0"
}

resource "alicloud_slb" "http" {
  name = "http_for_cf${var.prefix}"
  internet_charge_type = "paybytraffic"
  internet=true
}

resource "alicloud_slb_listener" "http-80" {
  load_balancer_id = "${alicloud_slb.http.id}"
  backend_port = "80"
  frontend_port = "80"
  protocol = "http"
  bandwidth = 10
  health_check = "off"
}
resource "alicloud_slb_listener" "http-443" {
  load_balancer_id = "${alicloud_slb.http.id}"
  backend_port = "443"
  frontend_port = "443"
  protocol = "tcp"
  bandwidth = 10
  health_check="off"
}

resource "alicloud_slb" "tcp" {
  name = "tcp_for_cf${var.prefix}"
  internet_charge_type = "paybytraffic"
  internet=true
}

resource "alicloud_slb_listener" "tcp-80" {
  load_balancer_id = "${alicloud_slb.tcp.id}"
  backend_port = "80"
  frontend_port = "80"
  protocol = "tcp"
  bandwidth = 10
}
resource "alicloud_slb_listener" "tcp-443" {
  load_balancer_id = "${alicloud_slb.tcp.id}"
  backend_port = "443"
  frontend_port = "443"
  protocol = "tcp"
  bandwidth = 10
}

resource "alicloud_key_pair" "key_pair" {
  key_name="${var.key_pair_name}"
  key_file = "../roles/bosh-deploy/files/${var.key_pair_name}.pem"
}
resource "alicloud_dns_record" "record" {
  name = "${var.domain_name}"
  host_record = "*"
  type = "A"
  value = "${alicloud_slb.http.address}"
}

resource "alicloud_instance" "default" {
  security_groups = [
    "${alicloud_security_group.sg.0.id}"]

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

  internet_max_bandwidth_out=10

  provisioner "local-exec" {
    command = <<EOF
        echo [CloudFoundaryServer] > ../hosts
        echo ${alicloud_instance.default.public_ip} ansible_user=root ansible_ssh_pass=${var.ecs_password} >> ../hosts
        echo \n
        echo internal_cidr: ${var.vswitch_cidr_bosh} >> ../group_vars/all
        echo internal_gw: ${var.bosh_gateway} >> ../group_vars/all
        echo internal_ip: ${var.bosh_ip} >> ../group_vars/all
        echo security_group_id_1: ${element(alicloud_security_group.sg.*.id,0)} >> ../group_vars/all
        echo security_group_id_2: ${element(alicloud_security_group.sg.*.id,1)} >> ../group_vars/all
        echo security_group_id_3: ${element(alicloud_security_group.sg.*.id,2)} >> ../group_vars/all
        echo vswitch_id: ${alicloud_vswitch.bosh.id} >> ../group_vars/all
        echo bosh_zone: ${alicloud_vswitch.bosh.availability_zone} >> ../group_vars/all
        echo http_slb_ip: ${alicloud_slb.http.address} >> ../group_vars/all
        echo key_pair_name: ${alicloud_key_pair.key_pair.key_name} >> ../group_vars/all
        echo private_key: ${var.key_pair_name}.pem >> ../group_vars/all
        echo "########deployment cf variables########" >> ../group_vars/all
        echo az1_zone: ${alicloud_vswitch.cf.0.availability_zone} >> ../group_vars/all
        echo az1_vswitch_id: ${alicloud_vswitch.cf.0.id} >> ../group_vars/all
        echo az1_vswitch_range: ${alicloud_vswitch.cf.0.cidr_block} >> ../group_vars/all
        echo az1_vswitch_gateway: ${element(var.cf_gateway, 0)} >> ../group_vars/all
        echo az2_zone: ${alicloud_vswitch.cf.1.availability_zone} >> ../group_vars/all
        echo az2_vswitch_id: ${alicloud_vswitch.cf.1.id} >> ../group_vars/all
        echo az2_vswitch_range: ${alicloud_vswitch.cf.1.cidr_block} >> ../group_vars/all
        echo az2_vswitch_gateway: ${element(var.cf_gateway, 1)} >> ../group_vars/all
        echo az3_zone: ${alicloud_vswitch.cf.2.availability_zone} >> ../group_vars/all
        echo az3_vswitch_id: ${alicloud_vswitch.cf.2.id} >> ../group_vars/all
        echo az3_vswitch_range: ${alicloud_vswitch.cf.2.cidr_block} >> ../group_vars/all
        echo az3_vswitch_gateway: ${element(var.cf_gateway, 2)} >> ../group_vars/all
        echo tcp_slb_id_array: ${alicloud_slb.tcp.id} >> ../group_vars/all
        echo http_slb_id_array: ${alicloud_slb.http.id} >> ../group_vars/all
  EOF
  }
}

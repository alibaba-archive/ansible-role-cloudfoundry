# Ansible Role: CloudFoundry
Installs and deploys cloudfoundry on RHEL/CentOS or Debian/Ubuntu servers based on Alibaba Cloud.

Prepare
=======
This module uses terraform to create server and ansible to deploy bosh and cloudfoundry.

1. Install ansible

       $ sudo pip install ansible
2. Install terraform
   * Download terraform and terraform-provider-alicloud and unarchive them

         $ wget https://releases.hashicorp.com/terraform/0.10.0/terraform_0.10.0_linux_amd64.zip
         $ unzip terraform_0.10.0_linux_amd64.zip
         $ wget -qO- https://github.com/alibaba/terraform-provider/releases/download/V1.2.2/terraform-provider-alicloud_linux-amd64.tgz | tar -xzvf -

   * Build a work directory, such as /root/work/terraform

         $ mkdir -p /root/work/terraform

   * Copy terraform package to above directory

         $ mv ./terraform /root/work/terraform/
         $ mv ./bin/terraform-provider-alicloud /root/work/terraform/
   * Set PATH

         $ export PATH="/root/work/terraform:$PATH"

   ~> **NOTE:** Above terraform packages only support Linux OS.
   For more packages, refer to [terraform](https://releases.hashicorp.com/terraform/?_ga=2.10495730.736095916.1505112587-366911210.1497366445)
   and [terraform-provider-alicloud](https://github.com/alibaba/terraform-provider/releases).

Role Variables
==============
Available variables are listed below, along with default values (see group_vars/all):

### bosh variables
This role supports bosh v255.3 and its light stemcell is v1003 which support `cn-beijing` region.

    bosh_version: 255.3
    bosh_stemcell_version: 1003

### cloudfoundry variables
This role supports cloudfoundry v217 and v215. Its light stemcell is v1003 which support `cn-beijing` region.

    cf_release_name: cf
    cf_release_version: 217
    cf_stemcell_version: 1003

The cloudfoundry default user account details.

    cf_user_email: cps@aliyun.com
    cf_user_password: Cps123456


### other variables
If you want to delete Alicloud resources, you can set parameter `delete` to `true`.

    delete: false

`NOTE`:
If you happened the following error while running the role:

    "Finding deployments:", "  Director responded with non-successful status code '401' response 'Not authorized: '/deployments'", "'", "Exit code 1"]

you can login the remote server and run the command:

    $ bosh -e my-bosh l

and then try to run the role again.

Usage
=====
Execute the following command with Alicloud Access Key and Region ID:

    $ ansible-playbook -i hosts deploy.yml --extra-vars "alicloud_access_key=XXXXXX alicloud_secret_key=XXXXXX alicloud_region=cn-beijing"

Author
======

This role was created in 2017 by He Guimin(@xiaozhu36, heguimin36@163.com), author of Alibaba Cloud.
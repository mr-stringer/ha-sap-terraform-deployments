module "local_execution" {
  source  = "../generic_modules/local_exec"
  enabled = var.pre_deployment
}

# This locals entry is used to store the IP addresses of all the machines.
# Autogenerated addresses example based in 19.168.135.0/24
# Iscsi server: 192.168.135.4
# Monitoring: 192.168.135.5
# Hana ips: 192.168.135.10, 192.168.135.11
# Hana cluster vip: 192.168.135.12
# Hana cluster vip secondary: 192.168.135.13
# DRBD ips: 192.168.135.20, 192.168.135.21
# DRBD cluster vip: 192.168.135.22
# Netweaver ips: 192.168.135.30, 192.168.135.31, 192.168.135.32, 192.168.135.33
# Netweaver virtual ips: 192.168.135.34, 192.168.135.35, 192.168.135.36, 19.168.135.37
# If the addresses are provided by the user they will always have preference
locals {
  iscsi_ip          = var.iscsi_srv_ip != "" ? var.iscsi_srv_ip : cidrhost(local.iprange, 4)
  monitoring_srv_ip = var.monitoring_srv_ip != "" ? var.monitoring_srv_ip : cidrhost(local.iprange, 5)

  hana_ip_start              = 10
  hana_ips                   = length(var.hana_ips) != 0 ? var.hana_ips : [for ip_index in range(local.hana_ip_start, local.hana_ip_start + var.hana_count) : cidrhost(local.iprange, ip_index)]
  hana_cluster_vip           = var.hana_cluster_vip != "" ? var.hana_cluster_vip : cidrhost(local.iprange, local.hana_ip_start + var.hana_count)
  hana_cluster_vip_secondary = var.hana_cluster_vip_secondary != "" ? var.hana_cluster_vip_secondary : cidrhost(local.iprange, local.hana_ip_start + var.hana_count + 1)

  # 2 is hardcoded for drbd because we always deploy 2 machines
  drbd_ip_start    = 20
  drbd_ips         = length(var.drbd_ips) != 0 ? var.drbd_ips : [for ip_index in range(local.drbd_ip_start, local.drbd_ip_start + 2) : cidrhost(local.iprange, ip_index)]
  drbd_cluster_vip = var.drbd_cluster_vip != "" ? var.drbd_cluster_vip : cidrhost(local.iprange, local.drbd_ip_start + 2)

  netweaver_xscs_server_count = var.netweaver_enabled ? (var.netweaver_ha_enabled ? 2 : 1) : 0
  netweaver_count             = var.netweaver_enabled ? local.netweaver_xscs_server_count + var.netweaver_app_server_count : 0
  netweaver_vitual_ips_count  = var.netweaver_ha_enabled ? max(local.netweaver_count, 3) : max(local.netweaver_count, 2) # We need at least 2 virtual ips, if ASCS and PAS are in the same machine

  netweaver_ip_start    = 30
  netweaver_ips         = length(var.netweaver_ips) != 0 ? var.netweaver_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_count) : cidrhost(local.iprange, ip_index)]
  netweaver_virtual_ips = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_vitual_ips_count) : cidrhost(local.iprange, ip_index + local.netweaver_vitual_ips_count)]

  # Check if iscsi server has to be created
  use_sbd       = var.hana_cluster_fencing_mechanism == "sbd" || var.drbd_cluster_fencing_mechanism == "sbd" || var.netweaver_cluster_fencing_mechanism == "sbd"
  iscsi_enabled = var.sbd_storage_type == "iscsi" && ((var.hana_count > 1 && var.hana_ha_enabled) || var.drbd_enabled || (local.netweaver_count > 1 && var.netweaver_ha_enabled)) && local.use_sbd ? true : false
}

module "common_variables" {
  source                 = "../generic_modules/common_variables"
  provider_type          = "libvirt"
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  additional_packages    = var.additional_packages
  public_key_location    = var.public_key_location
  provisioner            = var.provisioner
  provisioning_log_level = var.provisioning_log_level
  background             = var.background
  monitoring_enabled     = var.monitoring_enabled
  monitoring_srv_ip      = var.monitoring_enabled ? module.monitoring.output_data.private_address : ""
  qa_mode                = var.qa_mode
}

module "iscsi_server" {
  source                = "./modules/iscsi_server"
  common_variables      = module.common_variables.configuration
  iscsi_count           = local.iscsi_enabled == true ? 1 : 0
  source_image          = var.iscsi_source_image
  volume_name           = var.iscsi_source_image != "" ? "" : (var.iscsi_volume_name != "" ? var.iscsi_volume_name : local.generic_volume_name)
  vcpu                  = var.iscsi_vcpu
  memory                = var.iscsi_memory
  bridge                = "br0"
  storage_pool          = var.storage_pool
  isolated_network_id   = local.internal_network_id
  isolated_network_name = local.internal_network_name
  host_ips              = [local.iscsi_ip]
  lun_count             = var.iscsi_lun_count
  iscsi_disk_size       = var.sbd_disk_size
}

module "hana_node" {
  source                              = "./modules/hana_node"
  common_variables                    = module.common_variables.configuration
  name                                = "hana"
  source_image                        = var.hana_source_image
  volume_name                         = var.hana_source_image != "" ? "" : (var.hana_volume_name != "" ? var.hana_volume_name : local.generic_volume_name)
  hana_count                          = var.hana_count
  vcpu                                = var.hana_node_vcpu
  memory                              = var.hana_node_memory
  bridge                              = "br0"
  isolated_network_id                 = local.internal_network_id
  isolated_network_name               = local.internal_network_name
  storage_pool                        = var.storage_pool
  host_ips                            = local.hana_ips
  hana_sid                            = var.hana_sid
  hana_instance_number                = var.hana_instance_number
  hana_cost_optimized_sid             = var.hana_cost_optimized_sid
  hana_cost_optimized_instance_number = var.hana_cost_optimized_instance_number
  hana_master_password                = var.hana_master_password
  hana_cost_optimized_master_password = var.hana_cost_optimized_master_password == "" ? var.hana_master_password : var.hana_cost_optimized_master_password
  hana_primary_site                   = var.hana_primary_site
  hana_secondary_site                 = var.hana_secondary_site
  hana_inst_folder                    = var.hana_inst_folder
  hana_inst_media                     = var.hana_inst_media
  hana_platform_folder                = var.hana_platform_folder
  hana_sapcar_exe                     = var.hana_sapcar_exe
  hana_archive_file                   = var.hana_archive_file
  hana_extract_dir                    = var.hana_extract_dir
  hana_disk_size                      = var.hana_node_disk_size
  hana_fstype                         = var.hana_fstype
  hana_cluster_vip                    = local.hana_cluster_vip
  hana_cluster_vip_secondary          = var.hana_active_active ? local.hana_cluster_vip_secondary : ""
  ha_enabled                          = var.hana_ha_enabled
  fencing_mechanism                   = var.hana_cluster_fencing_mechanism
  sbd_storage_type                    = var.sbd_storage_type
  sbd_disk_id                         = module.hana_sbd_disk.id
  iscsi_srv_ip                        = module.iscsi_server.output_data.private_addresses.0
  hwcct                               = var.hwcct
  scenario_type                       = var.scenario_type
}

module "drbd_node" {
  source                = "./modules/drbd_node"
  common_variables      = module.common_variables.configuration
  name                  = "drbd"
  source_image          = var.drbd_source_image
  volume_name           = var.drbd_source_image != "" ? "" : (var.drbd_volume_name != "" ? var.drbd_volume_name : local.generic_volume_name)
  drbd_count            = var.drbd_enabled == true ? 2 : 0
  vcpu                  = var.drbd_node_vcpu
  memory                = var.drbd_node_memory
  bridge                = "br0"
  host_ips              = local.drbd_ips
  drbd_cluster_vip      = local.drbd_cluster_vip
  drbd_disk_size        = var.drbd_disk_size
  fencing_mechanism     = var.drbd_cluster_fencing_mechanism
  sbd_storage_type      = var.sbd_storage_type
  sbd_disk_id           = module.drbd_sbd_disk.id
  iscsi_srv_ip          = module.iscsi_server.output_data.private_addresses.0
  isolated_network_id   = local.internal_network_id
  isolated_network_name = local.internal_network_name
  storage_pool          = var.storage_pool
  nfs_mounting_point    = var.drbd_nfs_mounting_point
  nfs_export_name       = var.netweaver_sid
}

module "monitoring" {
  source                = "./modules/monitoring"
  common_variables      = module.common_variables.configuration
  name                  = "monitoring"
  monitoring_enabled    = var.monitoring_enabled
  source_image          = var.monitoring_source_image
  volume_name           = var.monitoring_source_image != "" ? "" : (var.monitoring_volume_name != "" ? var.monitoring_volume_name : local.generic_volume_name)
  vcpu                  = var.monitoring_vcpu
  memory                = var.monitoring_memory
  bridge                = "br0"
  storage_pool          = var.storage_pool
  isolated_network_id   = local.internal_network_id
  isolated_network_name = local.internal_network_name
  monitoring_srv_ip     = local.monitoring_srv_ip
  hana_targets          = concat(local.hana_ips, var.hana_ha_enabled ? [local.hana_cluster_vip] : [local.hana_ips[0]]) # we use the vip for HA scenario and 1st hana machine for non HA to target the active hana instance
  drbd_targets          = var.drbd_enabled ? local.drbd_ips : []
  netweaver_targets     = local.netweaver_virtual_ips
}

module "netweaver_node" {
  source                    = "./modules/netweaver_node"
  common_variables          = module.common_variables.configuration
  xscs_server_count         = local.netweaver_xscs_server_count
  app_server_count          = var.netweaver_enabled ? var.netweaver_app_server_count : 0
  name                      = "netweaver"
  source_image              = var.netweaver_source_image
  volume_name               = var.netweaver_source_image != "" ? "" : (var.netweaver_volume_name != "" ? var.netweaver_volume_name : local.generic_volume_name)
  vcpu                      = var.netweaver_node_vcpu
  memory                    = var.netweaver_node_memory
  bridge                    = "br0"
  storage_pool              = var.storage_pool
  isolated_network_id       = local.internal_network_id
  isolated_network_name     = local.internal_network_name
  host_ips                  = local.netweaver_ips
  virtual_host_ips          = local.netweaver_virtual_ips
  fencing_mechanism         = var.netweaver_cluster_fencing_mechanism
  sbd_storage_type          = var.sbd_storage_type
  shared_disk_id            = module.netweaver_shared_disk.id
  iscsi_srv_ip              = module.iscsi_server.output_data.private_addresses.0
  hana_ip                   = var.hana_ha_enabled ? local.hana_cluster_vip : element(local.hana_ips, 0)
  hana_sid                  = var.hana_sid
  hana_instance_number      = var.hana_instance_number
  hana_master_password      = var.hana_master_password
  netweaver_sid             = var.netweaver_sid
  ascs_instance_number      = var.netweaver_ascs_instance_number
  ers_instance_number       = var.netweaver_ers_instance_number
  pas_instance_number       = var.netweaver_pas_instance_number
  netweaver_master_password = var.netweaver_master_password
  netweaver_product_id      = var.netweaver_product_id
  netweaver_inst_media      = var.netweaver_inst_media
  netweaver_inst_folder     = var.netweaver_inst_folder
  netweaver_extract_dir     = var.netweaver_extract_dir
  netweaver_swpm_folder     = var.netweaver_swpm_folder
  netweaver_sapcar_exe      = var.netweaver_sapcar_exe
  netweaver_swpm_sar        = var.netweaver_swpm_sar
  netweaver_sapexe_folder   = var.netweaver_sapexe_folder
  netweaver_additional_dvds = var.netweaver_additional_dvds
  netweaver_nfs_share       = var.drbd_enabled ? "${local.drbd_cluster_vip}:/${var.netweaver_sid}" : var.netweaver_nfs_share
  ha_enabled                = var.netweaver_ha_enabled
}

variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "bastion_host" {
  description = "Bastion host address"
  type        = string
  default     = ""
}

variable "monitoring_enabled" {
  description = "enable the host to be monitored by exporters, e.g node_exporter"
  type        = bool
  default     = false
}

variable "compute_zones" {
  description = "gcp compute zones data"
  type        = list(string)
}

variable "network_subnet_name" {
  description = "Subnet name to attach the network interface of the nodes"
  type        = string
}

variable "os_image" {
  description = "Image used to create the machine"
  type        = string
}

variable "monitoring_srv_ip" {
  description = "Monitoring server address"
  type        = string
  default     = ""
}

variable "hana_targets" {
  description = "IPs of HANA hosts you want to monitor."
  type        = list(string)
}

variable "hana_targets_ha" {
  description = "IPs of HANA HA hosts you want to monitor."
  type        = list(string)
}

variable "hana_targets_vip" {
  description = "VIPs of HANA DBs you want to monitor."
  type        = list(string)
}

variable "drbd_targets" {
  description = "IPs of DRBD hosts you want to monitor"
  type        = list(string)
  default     = []
}

variable "drbd_targets_ha" {
  description = "IPs of DRBD HA hosts you want to monitor"
  type        = list(string)
  default     = []
}

variable "drbd_targets_vip" {
  description = "VIPs of DRBD NFS services you want to monitor"
  type        = list(string)
  default     = []
}

variable "netweaver_targets" {
  description = "IPs of Netweaver hosts you want to monitor."
  type        = list(string)
  default     = []
}

variable "netweaver_targets_ha" {
  description = "IPs of Netweaver HA hosts you want to monitor."
  type        = list(string)
  default     = []
}

variable "netweaver_targets_vip" {
  description = "VIPs of Netweaver Instances you want to monitor."
  type        = list(string)
  default     = []
}

variable "on_destroy_dependencies" {
  description = "Resources objects need in the on_destroy script (everything that allows ssh connection)"
  type        = any
  default     = []
}

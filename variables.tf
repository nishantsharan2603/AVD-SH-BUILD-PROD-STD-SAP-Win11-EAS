variable "resource_group_location" {
  default     = "eastasia"
  description = "Location of the resource group."
}

variable "rg" {
  type        = string
  default     = "resg-avd-compute"
  description = "Name of the Resource group in which to deploy session host"
}

variable "bol" {
  type        = bool
  default     ="true"
}

variable "rdsh_count" {
  description = "Number of AVD machines to deploy"
  default     = 1
}

variable "prefix" {
  type        = string
  default     = "azavdfthost"
  description = "Prefix of the name of the AVD machine(s)"
}

variable "domain_name" {
  type        = string
  default     = "crb.apmoller.net"
  description = "Name of the domain to join"
}

variable "domain_user_upn" {
  type        = string
  default     = "SA-VDICompManage01" # do not include domain name as this is appended
  description = "Username for domain join (do not include domain name as this is appended)"
}

variable "vm_size" {
  description = "Size of the machine to deploy"
  default     = "Standard_E4ds_v5"
}

variable "ou_path" {
  default = "OU=Eastasia,OU=SessionHosts,OU=AVD,OU=VDI,OU=Production,OU=Clients,DC=CRB,DC=APMOLLER,DC=NET"
}

variable "local_admin_username" {
  type        = string
  default     = "avdadministrator"
  description = "local admin username"
}

variable "hostpoolname" {
  description = "Host Pool Name to Register Session Hosts"
  default     = "HP-STD-PROD-SAP-EAS"
}

variable "artifactslocation" {
  description = "Location of WVD Artifacts"
  default     = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip"
}
variable "rfc3339" {
  default     = "2022-07-22T12:43:13Z"
  description = "token expiration"

}

variable "image_number" {
  default     = "0.20220716.11"
  description = "Latest Image Number"

}

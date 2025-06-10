variable "subscription_id" {
  type      = string
  sensitive = true
}

variable "location" {
  type    = string
  default = "East US"
}

variable "gh_repo" {
  type = string
}

variable "sbn" {
  type = string

}

variable "sbn_rg" {
  type = string

}


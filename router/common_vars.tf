# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
variable "ansible_inventory" {
  type = string
}

variable "ansible_dir" {
  type = string
}

variable "modules_dir" {
  type = string
}


locals {
  ansible_inventory = var.ansible_inventory
  ansible_dir       = var.ansible_dir
  modules_dir       = var.modules_dir
}
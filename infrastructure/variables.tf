variable "AWS_REGION" {
  default = "us-east-1"
}

variable "app_tier" {
  type    = string
  default = "dev"
}
variable "AMIS" {
  type = map(string)
  default = {
    us-east-1 = "ami-13be557e"
  }
}
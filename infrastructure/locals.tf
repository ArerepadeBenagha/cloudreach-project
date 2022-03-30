locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Service     = "cloudreach"
    Owner       = "cloudreach"
    Department  = "devOps engineering"
    ManagedWith = "terraform"
    Environment = "dev"
    casecode    = "esc300"
  }

  network = {
    Department  = "devOps engineering"
    ManagedWith = "terraform"
    Environment = "dev"
    Network     = "main network"
  }
}
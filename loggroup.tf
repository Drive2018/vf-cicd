resource "aws_cloudwatch_log_group" "common_loggroup" {
  name = format("vf-%s-%s-ecom-common-loggroup", var.env_account_config["account_environment"], var.env_account_config["vf_region"])
  retention_in_days = 90

  tags = {
    Name               = format("vf-%s-%s-ecom-common-loggroup", var.env_account_config["account_environment"], var.env_account_config["vf_region"])
    Application        = var.tag_manager["Application"]
    Brand              = var.tag_manager["Brand"]
    BusinessOwnerEmail = var.tag_manager["BusinessOwnerEmail"]
    CostCenter         = var.tag_manager["CostCenter"]
    Environment        = var.tag_manager["Environment"]
    TechOwnerEmail     = var.tag_manager["TechOwnerEmail"]
  }
}


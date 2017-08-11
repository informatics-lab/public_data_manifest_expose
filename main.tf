
variable "aws_region" {default = "eu-west-2"}
provider "aws" {
  region = "${var.aws_region}"
  profile = "adminpublicdata"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "manifest_copy_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
    
  ]
}
EOF
}



data "template_file" "iam_policy" {
  template = "${file("${path.module}/policy.json")}"
  vars {
    account_id    = "${data.aws_caller_identity.current.account_id}"
    region = "${var.aws_region}"
  }
}

resource "aws_iam_role_policy" "s3-access-policy" {
    name = "s3-access-policy"
    role = "${aws_iam_role.iam_for_lambda.id}"
    policy = "${data.template_file.iam_policy.rendered}"
}




data "external" "zip_lambda" {
  program = ["bash", "build.sh"]
}

resource "aws_lambda_function" "mainfest_lambda" {
  filename         = "${data.external.zip_lambda.result["path"]}"
  function_name    = "aws_lambda_handeler"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "lambda.aws_lambda_handeler"
  source_code_hash ="${base64sha256(file("${data.external.zip_lambda.result["path"]}"))}"
  runtime          = "python3.6"
  timeout          = 60
}


resource "aws_cloudwatch_event_rule" "every_6_hour" {
    name = "every-6-hours"
    description = "Fires every 6 hours"
    schedule_expression = "rate(6 hours)"
}

resource "aws_cloudwatch_event_target" "public_data_manifest_update" {
    rule = "${aws_cloudwatch_event_rule.every_6_hour.name}"
    target_id = "public_data_manifest_update"
    arn = "${aws_lambda_function.mainfest_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.mainfest_lambda.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.every_6_hour.arn}"
}




# # Useful for checking are correct users (e.g. public data user)
data "aws_caller_identity" "current" {}

# output "account_id" {
#   value = "${data.aws_caller_identity.current.account_id}"
# }

# output "caller_arn" {
#   value = "${data.aws_caller_identity.current.arn}"
# }

# output "caller_user" {
#   value = "${data.aws_caller_identity.current.user_id}"
# }

output "policy" {
  value = "${data.template_file.iam_policy.rendered}"
}
provider "aws" {
}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_event_rule" "EventRule" {
  name = "detect-network-changes"
  description = "A CloudWatch Event Rule that detects changes to network configuration and publishes change events to an SNS topic for notification."
  is_enabled = true
  event_pattern = <<PATTERN
{
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "ec2.amazonaws.com"
    ],
    "eventName": [
      "AttachInternetGateway",
      "AssociateRouteTable",
      "CreateCustomerGateway",
      "CreateInternetGateway",
      "CreateRoute",
      "CreateRouteTable",
      "DeleteCustomerGateway",
      "DeleteInternetGateway",
      "DeleteRoute",
      "DeleteRouteTable",
      "DeleteDhcpOptions",
      "DetachInternetGateway",
      "DisassociateRouteTable",
      "ReplaceRoute",
      "ReplaceRouteTableAssociation"
    ]
  }
}
PATTERN

}

resource "aws_cloudwatch_event_target" "TargetForEventRule" {
  rule = aws_cloudwatch_event_rule.EventRule.name
  target_id = "target-id1"
  arn = module.SnsTopic.arn
}

module "SnsTopic" {
  source = "github.com/asecurecloud/tf_sns_email"

  display_name = "event-rule-action"
  email_address = "email@example.com"
  stack_name = "tf-cfn-stack-SnsTopic-eqzuZ"
}

data "aws_iam_policy_document" "topic-policy-PolicyForSnsTopic" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
      "SNS:Receive"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      module.SnsTopic.arn
    ]

    sid = "__default_statement_ID"
  }
  
  statement {
    actions = [
      "sns:Publish"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [
      module.SnsTopic.arn
    ]

    sid = "TrustCWEToPublishEventsToMyTopic"
  }
}

resource "aws_sns_topic_policy" "PolicyForSnsTopic" {
  arn = module.SnsTopic.arn
  policy = data.aws_iam_policy_document.topic-policy-PolicyForSnsTopic.json
}

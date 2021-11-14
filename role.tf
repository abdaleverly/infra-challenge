# ec2 instance
resource "aws_iam_instance_profile" "web" {
  name = "${var.stack_name}-webserver-profile"
  role = aws_iam_role.web.name
}

resource "aws_iam_role" "web" {
  name = "${var.stack_name}-webserver-role"
  path = "/"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy" "web" {
  name = "${var.stack_name}-web-policy"
  role = aws_iam_role.web.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "kms:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.artifact.arn}",
        "${aws_s3_bucket.artifact.arn}/*"
      ]
    }
  ]
}
POLICY
}

## codebuild
resource "aws_iam_role" "build" {
  name = "${var.stack_name}-build-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codebuild.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "build" {
  name = "${var.stack_name}-build-policy"
  role = aws_iam_role.build.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "kms:*",
        "codestar-connections:UseConnection"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.artifact.arn}",
        "${aws_s3_bucket.artifact.arn}/*"
      ]
    }
  ]
}
POLICY
}

# codedeploy
resource "aws_iam_role" "codedeploy" {
  name = "${var.stack_name}-codedeploy-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "codedeploy" {
  name = "${var.stack_name}-codedeploy-policy"
  role = aws_iam_role.codedeploy.name

  policy = <<-POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "kms:*",
        "codestar-connections:UseConnection"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.artifact.arn}",
        "${aws_s3_bucket.artifact.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy.name
}


# codepipeline
data "aws_iam_policy_document" "pipeline" {
  statement {
    sid = "artifactBucketAccess"
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.artifact.arn}", 
      "${aws_s3_bucket.artifact.arn}/*"
    ]
  }
  statement {
    sid = "codebuildAccess"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = [aws_codebuild_project.web.arn]
  }
  statement {
    sid = "LogPermissions"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    sid = "codestarpermissions"
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = ["*"]
  }
  statement {
    sid = "codedeploypermissions"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
      "kms:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name = "${var.stack_name}-pipeline-policy"
  role = aws_iam_role.pipeline.name

  policy = data.aws_iam_policy_document.pipeline.json
}

resource "aws_iam_role" "pipeline" {
  name = "${var.stack_name}-pipeline-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codepipeline.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
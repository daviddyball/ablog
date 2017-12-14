provider "aws" {
  region = "eu-west-1"
}

data "template_file" "web_userdata" {
  template = "${file("templates/web_userdata.tpl")}"
}

data "template_file" "web_iam_role" {
  template = "${file("templates/web_iam_role.tpl")}"
}

resource "aws_vpc" "production" {
  cidr_block = "192.168.0.0/16"
}

resource "aws_internet_gateway" "production" {
  vpc_id = "${aws_vpc.production.id}"

  depends_on = [
    "aws_vpc.production",
  ]
}

resource "aws_route_table" "production" {
  vpc_id = "${aws_vpc.production.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.production.id}"
  }

  depends_on = [
    "aws_vpc.production",
  ]
}

resource "aws_subnet" "web_1a" {
  vpc_id            = "${aws_vpc.production.id}"
  cidr_block        = "192.168.0.0/24"
  availability_zone = "eu-west-1a"

  tags {
    Name = "web_1a"
  }

  depends_on = [
    "aws_vpc.production",
  ]
}

resource "aws_subnet" "web_1b" {
  vpc_id            = "${aws_vpc.production.id}"
  cidr_block        = "192.168.1.0/24"
  availability_zone = "eu-west-1b"

  tags {
    Name = "web_1b"
  }

  depends_on = [
    "aws_vpc.production",
  ]
}

resource "aws_route_table_association" "web" {
  route_table_id = "${aws_route_table.production.id}"
  subnet_id      = "${aws_subnet.web_1a.id}"

  depends_on = [
    "aws_route_table.production",
  ]
}

resource "aws_security_group" "web" {
  name        = "web"
  description = "Web Tier"
  vpc_id      = "${aws_vpc.production.id}"

  ingress = {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.web_alb.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_alb" {
  name        = "web_alb"
  description = "Web Tier ALB"
  vpc_id      = "${aws_vpc.production.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "web" {
  name               = "web"
  assume_role_policy = "${data.template_file.web_iam_role.rendered}"
}

resource "aws_iam_instance_profile" "web" {
  name = "web"
  role = "${aws_iam_role.web.name}"
}

resource "aws_launch_configuration" "web" {
  name_prefix                 = "web_"
  image_id                    = "ami-63b0341a"
  instance_type               = "t2.nano"
  iam_instance_profile        = "${aws_iam_instance_profile.web.id}"
  key_name                    = "ablog"
  security_groups             = ["${aws_security_group.web.id}"]
  associate_public_ip_address = true
  user_data                   = "${data.template_file.web_userdata.rendered}"
  enable_monitoring           = false

  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb" "web" {
  name            = "web"
  security_groups = ["${aws_security_group.web_alb.id}"]
  subnets         = ["${aws_subnet.web_1a.id}", "${aws_subnet.web_1b.id}"]
}

resource "aws_alb_target_group" "web" {
  name                 = "web"
  port                 = "80"
  protocol             = "HTTP"
  vpc_id               = "${aws_vpc.production.id}"
  deregistration_delay = 30

  health_check {
    interval            = 60
    timeout             = 30
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = 200
  }
}

resource "aws_alb_listener" "web" {
  load_balancer_arn = "${aws_alb.web.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.web.arn}"
    type             = "forward"
  }
}

resource "aws_autoscaling_group" "web" {
  availability_zones        = ["eu-west-1a", "eu-west-1b"]
  name                      = "web"
  desired_capacity          = 0
  max_size                  = 3
  min_size                  = 0
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.web.name}"
  target_group_arns         = ["${aws_alb_target_group.web.arn}"]
  default_cooldown          = 300
  vpc_zone_identifier       = ["${aws_subnet.web_1a.id}", "${aws_subnet.web_1b.id}"]
}

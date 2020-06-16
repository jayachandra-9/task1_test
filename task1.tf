provider "aws" {
  region = "ap-south-1"
  profile = "jai"
}


	


resource "aws_security_group" "My_VPC_Security_Group" {
  vpc_id       = "vpc-70899418"
  name         = "My VPC Security Group"
  description  = "My VPC Security Group"
  
  # allow ingress of port 22
  ingress {
    cidr_blocks =  ["0.0.0.0/0"] 
    from_port   =80
    to_port     = 80
    protocol    = "tcp"
  } 
  ingress {
    cidr_blocks =  ["0.0.0.0/0"] 
    from_port   =22
    to_port     = 22
    protocol    = "tcp"
  } 
  
  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
   Name = "My VPC Security Group"
   Description = "My VPC Security Group"
}
}

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name =  "mykeypair1"
  security_groups =[aws_security_group.My_VPC_Security_Group.name]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/jai/Downloads/mykeypair1.pem")
    host     = aws_instance.web.public_ip
  }


  provisioner "remote-exec"{
  inline=[
    "sudo yum install httpd php git -y",
    "sudo systemctl restart httpd",
    "sudo systemctl enable httpd"
  ]
  }
  tags = {
    Name = "myos1"
  }

}
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "jaiebs"
  }
}



resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.web.id
  force_detach=true
}

resource "null_resource" "null_local2"{
  depends_on=[
    aws_volume_attachment.ebs_att,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key =  file("/home/jai/Downloads/mykeypair1.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
  inline=[
    "sudo mkfs.ext4 /dev/xvdh",
    "sudo mount /dev/xvdh /var/www/html",
    "sudo rm -rf /var/www/html",
    "sudo git clone https://github.com/jayachandra-9/multi_cloud.git  /var/www/html"
  ]
  }
}
resource "null_resource" "nulllocal3"  {
	depends_on = [
	    null_resource.null_local2,
	  ]
	

		provisioner "local-exec" {
		    command = "google-chrome  ${aws_instance.web.public_ip}"
	  	}
	}
resource "aws_s3_bucket" "jai_143" {
 // bucket = "jai-test-bucket"
  acl    = "public-read"
  force_destroy=true
  versioning{
  enabled = true
  }
  provisioner "local-exec" {
    command = "sudo git clone https://github.com/jayachandra-9/task1_test.git"
  }
   provisioner "local-exec"{
    when = destroy
    command = "sudo rm -rf test"
  }
}
resource "aws_s3_bucket_object" "my_bucket_object"{
  depends_on =  [aws_s3_bucket.jai_143,
  ]
  key = "1.png"
  bucket = aws_s3_bucket.jai_143.id
  source = "/home/jai/Downloads/1.png"
  content_type = "images/png"
  acl = "public-read"
  
}
locals {
  s3_origin_id = "jai_143-origin"
}


resource "aws_cloudfront_distribution" "first-s3-cf" {
  origin {
    domain_name = aws_s3_bucket.jai_143.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  enabled = true


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }
  viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
       }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("/home/jai/Downloads/mykeypair1.pem")
    host = aws_instance.web.public_ip
  }
  provisioner "remote-exec"{
    inline = ["sudo -i <<EOF",
	  "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.my_bucket_object.key}' width='336' height='448'>\" >> /var/www/html/index.html","EOF",]
  }
}





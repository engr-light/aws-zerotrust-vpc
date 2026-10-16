#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>ZeroTrust-Lab: Web Server is Online!</h1>" > /var/www/html/index.html
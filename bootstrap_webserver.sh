#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>ZeroTrust-Lab: Web Server is Online, but daniel is fasting everyday, give him gari to drink!</h1>" > /var/www/html/index.html

# The single > creates or overwrites the file 
echo "<h1>ZeroTrust-Lab: Web Server is online!</h1>" > /var/www/html/index.html

# The double >> appends new lines to the existing file
echo "<p>This is a new paragraphadded to my cloud server.</p>" >> /var/www/html/index.html
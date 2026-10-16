# ZeroTrust-Lab: AWS Multi-Tier VPC & Web Server Architecture

A production-aligned, multi-tier Virtual Private Cloud (VPC) network infrastructure built on Amazon Web Services (AWS) in the Europe (Stockholm) region (eu-north-1). This lab demonstrates secure network segmentation, route table management, custom security group firewalls, automated instance bootstrapping via user-data, and live architectural verification aligned with the AWS Certified Solutions Architect – Associate (SAA-C03) standard.

---

## Architecture Overview

The infrastructure isolates public-facing application resources from private backend tiers using dedicated subnets and deterministic routing policies.

                              +-------------------------------------------------------+
                              |                    Internet Gateway                   |
                              +---------------------------+---------------------------+
                                                          | (0.0.0.0/0)
                                                          v
+---------------------------------------------------------------------------------------------------+
|  AWS VPC: ZeroTrust-Lab (10.0.0.0/16) - Region: eu-north-1                                        |
|                                                                                                   |
|  +---------------------------------------------------------------------------------------------+  |
|  | Public Route Table (0.0.0.0/0 -> Internet Gateway)                                          |  |
|  |                                                                                             |  |
|  |  +---------------------------------------+   +---------------------------------------+      |  |
|  |  | Public Subnet 1 (eu-north-1a)         |   | Public Subnet 2 (eu-north-1b)         |      |  |
|  |  |                                       |   |                                       |      |  |
|  |  |  +---------------------------------+  |   |  (Standby for Multi-AZ redundancy)    |      |  |
|  |  |  | EC2: Public-Web-Server          |  |   +---------------------------------------+      |  |
|  |  |  | Type: t3.micro                  |  |                                                  |  |
|  |  |  | OS: Amazon Linux 2023           |  |                                                  |  |
|  |  |  | Security Group: web-server-sg   |  |                                                  |  |
|  |  |  | Inbound: TCP 80, TCP 22         |  |                                                  |  |
|  |  |  +---------------------------------+  |                                                  |  |
|  |  +---------------------------------------+                                                  |  |
|  +---------------------------------------------------------------------------------------------+  |
|                                                                                                   |
|  +---------------------------------------------------------------------------------------------+  |
|  | Private Route Table (Local Only: 10.0.0.0/16 -> local)                                      |  |
|  |                                                                                             |  |
|  |  +---------------------------------------+   +---------------------------------------+      |  |
|  |  | Private Subnet 1 (eu-north-1a)        |   | Private Subnet 2 (eu-north-1b)        |      |  |
|  |  | (Isolated Data Tier - Zero Egress)    |   | (Isolated Data Tier - Zero Egress)    |      |  |
|  |  +---------------------------------------+   +---------------------------------------+      |  |
|  +---------------------------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------------------------+

---

## Network & Subnet Topology

| Resource | Logical ID / Name | CIDR Block | Availability Zone | Routing Target | Internet Accessible |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **VPC** | ZeroTrust-Lab | 10.0.0.0/16 | Multi-AZ | Local | No (Container) |
| **Public Subnet 1** | ZeroTrust-Lab-public-1 | 10.0.0.0/20 | eu-north-1a | igw-xxxxxxxx | Yes (Public IPv4) |
| **Public Subnet 2** | ZeroTrust-Lab-public-2 | 10.0.16.0/20 | eu-north-1b | igw-xxxxxxxx | Yes (Public IPv4) |
| **Private Subnet 1**| ZeroTrust-Lab-private-1| 10.0.128.0/20| eu-north-1a | local | No (Isolated) |
| **Private Subnet 2**| ZeroTrust-Lab-private-2| 10.0.144.0/20| eu-north-1b | local | No (Isolated) |
| **Internet Gateway**| ZeroTrust-Lab-igw | N/A | Regional | VPC Boundary | Full Egress/Ingress |

---

## Routing & Traffic Engineering

### 1. Public Route Table
Routes external traffic out to the internet through the attached Internet Gateway (IGW).
* 10.0.0.0/16 -> local: Handles intra-VPC communication.
* 0.0.0.0/0 -> igw-xxxxxxxx: Grants internet-bound egress and external routability to instances possessing public IPv4 addresses.

### 2. Private Route Table (Zero-Egress Design)
Strictly handles internal traffic routing with no default internet gateway or external egress path.
* 10.0.0.0/16 -> local: Restricts communication strictly within the VPC perimeter.
* Architectural Note: In accordance with cost-optimization and zero-trust principles, NAT Gateways were deliberately excluded. Backend subnets remain isolated from unauthorized outbound connections, conserving recurring cloud compute budgets while eliminating untrusted egress vectors.

---

## Security Group Configuration

The instance is guarded by a stateful host firewall (web-server-sg).

### Inbound Rules (Ingress)
| Type | Protocol | Port Range | Source | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **HTTP** | TCP | 80 | 0.0.0.0/0 | Public web server traffic |
| **SSH** | TCP | 22 | 0.0.0.0/0 | Administrative shell access |

### Outbound Rules (Egress)
| Type | Protocol | Port Range | Destination | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **All Traffic** | All | All | 0.0.0.0/0 | Allow package manager downloads & system updates |

---

## Automated Instance Provisioning (User Data)

The EC2 instance was bootstrapped using the following initialization shell script passed during launch. The script handles dependency installation, service registration, and web page generation:

#!/bin/bash
# Update repository package metadata
dnf update -y

# Install Apache Web Server (httpd)
dnf install -y httpd

# Start and enable httpd service to persist across reboots
systemctl start httpd
systemctl enable httpd

# Deploy test web application index file
echo "<h1>ZeroTrust-Lab: Web Server is Online!</h1>" > /var/www/html/index.html

---

## Verification & Troubleshooting Case Study

### Issue: Inbound HTTP Connection Timeout
* Symptom: The browser returned ERR_CONNECTION_TIMED_OUT when attempting to query the instance's public IPv4 address.
* Root Cause Analysis:
  1. Subnet Routing: The route table for the host subnet correctly mapped 0.0.0.0/0 to the Internet Gateway.
  2. Instance State: Status checks reported 3/3 checks passed (System and Instance reachable).
  3. Stateful Inspection: Inspection of web-server-sg revealed that only Port 22 (SSH) had been registered during the initial console launch step, dropping all inbound TCP packets on Port 80 without a reset flag.
* Resolution: Navigated to the security group interface, appended an inbound rule for HTTP (TCP 80) bound to 0.0.0.0/0, and saved changes. Because AWS Security Groups are stateful, rule updates applied instantaneously, and the web page resolved with zero downtime.

---

## Teardown & Cost Management

To prevent ongoing compute charges while retaining network configurations for future lab expansion:
1. Navigate to EC2 > Instances.
2. Select Public-Web-Server.
3. Select Instance state > Terminate instance.
4. Confirm termination to release the allocated virtual machine and attached EBS volume.
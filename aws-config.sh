#!/bin/bash

# Set your domain here
YOUR_DOMAIN="mark-isaacs.com"
REGION="us-east-1"
# Don't change these
BUCKET_NAME="www.${YOUR_DOMAIN}"
LOG_BUCKET_NAME="${BUCKET_NAME}-logs"

# One fresh bucket please!
aws s3 mb s3://$BUCKET_NAME --region $REGION
# And another for the logs
aws s3 mb s3://$LOG_BUCKET_NAME --region $REGION
# And bucket for redirects
aws s3 mb s3://$YOUR_DOMAIN --region $REGION


# Let AWS write the logs to this location
aws s3api put-bucket-acl --bucket $LOG_BUCKET_NAME \
--grant-write 'URI="http://acs.amazonaws.com/groups/s3/LogDelivery"' \
--grant-read-acp 'URI="http://acs.amazonaws.com/groups/s3/LogDelivery"'

# Setup logging
LOG_POLICY="{\"LoggingEnabled\":{\"TargetBucket\":\"$LOG_BUCKET_NAME\",\"TargetPrefix\":\"$BUCKET_NAME\"}}"
aws s3api put-bucket-logging --bucket $BUCKET_NAME --bucket-logging-status $LOG_POLICY

# Create website config
echo "{
    \"IndexDocument\": {
        \"Suffix\": \"index.html\"
    },
    \"ErrorDocument\": {
        \"Key\": \"404.html\"
    },
    \"RoutingRules\": [
        {
            \"Redirect\": {
                \"ReplaceKeyWith\": \"index.html\"
            },
            \"Condition\": {
                \"KeyPrefixEquals\": \"/\"
            }
        }
    ]
}" > website.json

aws s3api put-bucket-website --bucket $BUCKET_NAME --website-configuration file://website.json

# Set this bucket policy if you still want to test from AWS bucket
#{
#    "Version": "2012-10-17",
#    "Statement": [
#        {
#            "Sid": "PublicReadGetObject",
#            "Effect": "Allow",
#            "Principal": "*",
#            "Action": "s3:GetObject",
#            "Resource": "arn:aws:s3:::www.MYDOMAINNAME.com/*",
#            "Condition": {
#                "IpAddress": {
#                    "aws:SourceIp": [
#                        "2400:cb00::/32",
#                        "2405:8100::/32",
#                        "2405:b500::/32",
#                        "2606:4700::/32",
#                        "2803:f800::/32",
#                        "2c0f:f248::/32",
#                        "2a06:98c0::/29",
#                        "103.21.244.0/22",
#                        "103.22.200.0/22",
#                        "103.31.4.0/22",
#                        "104.16.0.0/12",
#                        "108.162.192.0/18",
#                        "131.0.72.0/22",
#                        "141.101.64.0/18",
#                        "162.158.0.0/15",
#                        "172.64.0.0/13",
#                        "173.245.48.0/20",
#                        "188.114.96.0/20",
#                        "190.93.240.0/20",
#                        "197.234.240.0/22",
#                        "198.41.128.0/17"
#                    ]
#                }
#            }
#        }
#    ]
#}


# Set this bucket policy to limit access to Cloudflare only... deny reads for all else!

{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Sid": "Deny-All-Read-Except-CloudFlare",
           "Action": "s3:GetObject",
           "Effect": "Deny",
           "Resource": "arn:aws:s3:::www.mark-isaacs.com/*",
           "Condition": {
               "NotIpAddress": {
                   "aws:SourceIp": [
                       "103.21.244.0/22",
                       "103.22.200.0/22",
                       "103.31.4.0/22",
                       "104.16.0.0/12",
                       "108.162.192.0/18",
                       "131.0.72.0/22",
                       "141.101.64.0/18",
                       "162.158.0.0/15",
                       "172.64.0.0/13",
                       "173.245.48.0/20",
                       "188.114.96.0/20",
                       "190.93.240.0/20",
                       "197.234.240.0/22",
                       "198.41.128.0/17",
                       "2400:cb00::/32",
                       "2405:8100::/32",
                       "2405:b500::/32",
                       "2606:4700::/32",
                       "2803:f800::/32",
                       "2c0f:f248::/32",
                       "2a06:98c0::/29"
                   ]
               }
           },
           "Principal": {
               "AWS": "*"
           }
        },
        {
            "Effect": "Deny",
            "Action": [
                "s3:PutObject",
                "s3:DeleteObject"
            ],
           "Principal": {
               "AWS": "*"
           },
            "Resource": "arn:aws:s3:::www.mark-isaacs.com/*",
            "Condition": {
                "NotIpAddress": {
                  "aws:SourceIp": "197.245.38.54/16"
                }
            }
        }
   ]
}


# Copy over pages - not static js/img/css/downloads
#aws s3 sync --acl "public-read" --sse "AES256" public/ s3://$BUCKET_NAME --exclude 'post'
#aws s3 sync --acl "public-read" --sse "AES256" output2/ s3://www.mark-isaacs.com --exclude 'post'


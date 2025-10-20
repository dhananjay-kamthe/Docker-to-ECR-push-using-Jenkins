🚀 Continuous Delivery of Docker Images to AWS ECR Using Jenkins, Lambda & Terraform
🧩 Project Summary

This project demonstrates how to implement an end-to-end CI/CD pipeline for Dockerized applications.
Each source code commit automatically triggers Jenkins to build and push a Docker image to Amazon ECR, which then notifies AWS Lambda through EventBridge. Lambda logs image details in DynamoDB and sends alerts using Amazon SNS.

You can set this up in two ways:

🧰 Manual Deployment (via AWS Console & Jenkins)

⚙️ Automated Deployment (via Terraform Infrastructure as Code)

🎯 Workflow Overview

When you push code to GitHub:

🏗️ Jenkins builds a Docker image

📦 The image is pushed to Amazon ECR

⚡ ECR sends an event to EventBridge

🧠 Lambda is triggered

🗃️ Lambda logs image data into DynamoDB

📧 SNS sends a notification email

🧱 System Architecture
---
sequenceDiagram
  participant Developer
  participant GitHub
  participant Jenkins
  participant ECR
  participant EventBridge
  participant Lambda
  participant DynamoDB
  participant SNS

  Developer->>GitHub: Push new code
  GitHub->>Jenkins: Trigger build webhook
  Jenkins->>Docker: Build container
  Jenkins->>ECR: Push image to repository
  ECR->>EventBridge: Publish "Image Push" event
  EventBridge->>Lambda: Trigger Lambda
  Lambda->>DynamoDB: Store metadata
  Lambda->>SNS: Send notification
---
🧩 SECTION 1 — Manual Setup (Without Terraform)
🧭 Workflow Summary 
---
Step	Task	Description
1️⃣	Create ECR Repository	Stores Docker images
2️⃣	Setup App Code	Node.js sample application
3️⃣	Configure Jenkins	Build & push automation
4️⃣	Setup Lambda	Handle logging and alerts
5️⃣	Configure DynamoDB + SNS	Store data and send notifications
6️⃣	Create EventBridge Rule	Triggers Lambda
7️⃣	Verify Pipeline	Validate end-to-end flow
1️⃣ Create an Amazon ECR Repository
---
Steps:

Go to AWS Console → ECR → Create repository

Repository name: sample-app-repo

Tag mutability: Mutable

(Optional) Enable scan on push

Repository URI Example:
---
123456789012.dkr.ecr.ap-south-1.amazonaws.com/sample-app-repo
---
2️⃣ Application Source Code
Folder Structure
---
auto-ecr-pipeline/
├── app/
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
└── jenkins/
    └── Jenkinsfile
---
app/index.js
---
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;
app.get('/', (_, res) => res.json({ msg: 'Hello from AWS CI/CD pipeline!' }));
app.listen(port, () => console.log(`Server running on port ${port}`));
---
app/package.json
---
{
  "name": "docker-ci-app",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "express": "^4.18.2" }
}
---
app/Dockerfile
---
FROM node:18-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
---
3️⃣ Jenkins Configuration
🔹 Required Plugins

Docker

Pipeline

GitHub Integration

Amazon ECR (optional)

🔹 Add Credentials

In Jenkins → Manage Credentials:

Type: Username with password

ID: aws-creds-id

Username: AWS_ACCESS_KEY_ID

Password: AWS_SECRET_ACCESS_KEY

🔹 Jenkinsfile
---
pipeline {
  agent any

  environment {
    AWS_REGION = 'ap-south-1'
    AWS_ACCOUNT = '123456789012'
    ECR_REPO = 'sample-app-repo'
    ECR_URL = "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.IMAGE_TAG = new Date().format("yyyyMMdd-HHmmss") + "-" +
                          sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        dir('app') {
          sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
        }
      }
    }

    stage('Push to ECR') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds-id', usernameVariable: 'AWS_ID', passwordVariable: 'AWS_SECRET')]) {
          sh '''
            export AWS_ACCESS_KEY_ID=$AWS_ID
            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
            docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URL}:${IMAGE_TAG}
            docker push ${ECR_URL}:${IMAGE_TAG}
            aws events put-events --entries "[{\\"Source\\":\\"custom.jenkins\\",\\"DetailType\\":\\"ECR Image Push\\",\\"Detail\\":\\"{\\\\\\"repository\\\\\\":\\\\\\"${ECR_REPO}\\\\\\",\\\\\\"imageTag\\\\\\":\\\\\\"${IMAGE_TAG}\\\\\\"}\\"}]"
          '''
        }
      }
    }
  }

  post {
    success { echo "✅ Image pushed to ECR: ${ECR_URL}:${IMAGE_TAG}" }
    failure { echo "❌ Build failed." }
  }
}
---
4️⃣ Configure GitHub Webhook

Go to Repo → Settings → Webhooks → Add Webhook

Payload URL:
---
http://<jenkins-server-ip>:8080/github-webhook/
---
Content type: application/json

Event: “Just the push event”

Save the webhook.

5️⃣ Create AWS Lambda Function

Runtime: Python 3.10
Function Name: ecr-postprocessor

lambda/ecr_postprocessor.py
---

import json, os, boto3
from datetime import datetime

ddb = boto3.client('dynamodb')
sns = boto3.client('sns')

def lambda_handler(event, context):
    detail = event.get('detail', {})
    repo = detail.get('repository', 'unknown')
    tag = detail.get('imageTag', 'unknown')
    ts = datetime.utcnow().isoformat()

    ddb.put_item(
        TableName=os.environ['DDB_TABLE'],
        Item={
            'imageTag': {'S': tag},
            'repository': {'S': repo},
            'timestamp': {'S': ts}
        }
    )

    sns.publish(
        TopicArn=os.environ['SNS_ARN'],
        Message=f"New image pushed: {repo}:{tag} at {ts}",
        Subject="ECR Image Push Notification"
    )
    return {'status': 'ok'}
---

Environment Variables
---
DDB_TABLE = sample-app-image-log
SNS_ARN   = arn:aws:sns:ap-south-1:123456789012:sample-app-topic
---
6️⃣ DynamoDB & SNS Setup

DynamoDB Table

Name: sample-app-image-log

Partition Key: imageTag (String)

SNS Topic

Name: sample-app-topic

Add an email subscription and confirm via your inbox.

7️⃣ EventBridge Rule

Event pattern:
---
{
  "source": ["custom.jenkins"],
  "detail-type": ["ECR Image Push"]
}
---

Target: Lambda Function (ecr-postprocessor)

✅ Validation Checklist

Push code to GitHub → Jenkins builds image

Image uploaded to ECR

EventBridge triggers Lambda

Lambda writes record to DynamoDB

SNS sends notification email 🎉

🧩 SECTION 2 — Terraform Deployment
Directory Structure
---
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
└── lambda/
    └── ecr_postprocessor.py
---

Deploy Terraform
---
cd terraform
terraform init
terraform apply -auto-approve
---

Terraform Outputs:

ECR Repository URI

Lambda Function Name

SNS Topic ARN

Use these in your Jenkins configuration.

🧹 Clean Up Resources
---
terraform destroy -auto-approve
---
✨ Benefits
Feature	Benefit
Fully Automated	End-to-end CI/CD pipeline
Infrastructure as Code	Reproducible and consistent setup
Scalable	Works across multiple regions
Event-Driven	Real-time image deployment
Modular	Easy to extend and maintain
🔮 Possible Enhancements

Integrate AWS Secrets Manager for Jenkins credentials

Add CloudWatch alarms for Lambda errors

Implement Blue/Green deployment for safer rollouts

Extend with AWS CodePipeline

👨‍💻 Author

Dhananjay Kamthe
🚀 DevOps | AWS | Terraform | CI/CD Automation
📧 dhananjaykamthe2@gmail.com

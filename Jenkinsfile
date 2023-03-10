pipeline {
    agent any
    tools {
        terraform 'terraform'
    }

    environment {
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID = sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        DOCKERHUB = "alitunckasik"
        APP_REPO_NAME = "bronze/jenkins-project"
        APP_NAME = "todo"
    }

    stages {

        stage('Build App Docker Images') {
            steps {
                echo 'Building App Images'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:postgresql" -f ./postgresql/dockerfile-postgresql .'
                sh 'docker image ls'
            }
        }

        stage('Push Images to ECR Repo') {
            steps {
                echo 'Pushing App Images to ECR Repo'
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:postgresql"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:nodejs"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:react"'
            }
        }

        stage('Create Infrastructure for the App') {
            steps {
                echo 'Creating Infrastructure for the App on AWS Cloud'
                sh 'terraform init'
                sh 'terraform apply --auto-approve'
            }
        }

        stage('Create ECR Repo') {
            steps {
                echo 'Creating ECR Repo for App'
                sh """
                aws ecr create-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --image-scanning-configuration scanOnPush=false \
                  --image-tag-mutability MUTABLE \
                  --region ${AWS_REGION}
                """
            }
        }

        stage('Substitute Terraform Outputs into .env Files') {
            steps {
                echo 'Substituting Terraform Outputs into .env Files'
                script {
                    env.NODEJS_IP = sh(script: 'terraform output -raw nodejs_public_ip', returnStdout:true).trim()
                    env.DB_HOST = sh(script: 'terraform output -raw postgresql_private_ip', returnStdout:true).trim()
                }
                sh 'echo ${DB_HOST}'
                sh 'echo ${NODEJS_IP}'
                sh 'envsubst < nodejs-env-template > ./nodejs/server/.env'
                sh 'cat ./nodejs/server/.env'
                sh 'envsubst < react-env-template > ./react/client/.env'
                sh 'cat ./react/client/.env'
            }
        }

        stage('Wait for the Instance') {
            steps {
                script {
                    echo 'Waiting for the Instance'
                    id = sh(script: 'aws ec2 describe-instances --filters Name=tag-value,Values=postgresql Name=instance-state-name,Values=running --query Reservations[*].Instances[*].[InstanceId] --output text',  returnStdout:true).trim()
                    sh 'aws ec2 wait instance-status-ok --instance-ids $id'
                }
            }
        }

        stage('Deploy the App') {
            steps {
                echo 'Deploy the App'
                sh 'ls -l'
                sh 'ansible --version'
                sh 'ansible-inventory --graph'
                ansiblePlaybook credentialsId: 'ssh', disableHostKeyChecking: true, installation: 'ansible', inventory: 'inventory_aws_ec2.yml', playbook: 'playbook.yml'
             }
        }

        stage('Destroy the Infrastructure'){
            steps{
                timeout(time:5, unit:'DAYS'){
                    input message:'Do you want to terminate?'
                }
                sh """
                docker image prune -af
                terraform destroy --auto-approve
                aws ecr delete-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --region ${AWS_REGION} \
                  --force
                """
            }
        }
    }

    post {
        always {
            echo 'Deleting All Local Images'
            sh 'docker image prune -af'
        }
        failure {
            echo 'Deleting the Image Repository on ECR Due to the Failure'
            sh """
                aws ecr delete-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --region ${AWS_REGION} \
                  --force
                """
            echo 'Deleting Terraform Stack Due to the Failure'
                sh 'terraform destroy --auto-approve'
        }
    }
}
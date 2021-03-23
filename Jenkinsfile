def ENVIRONMENTS = [
    'POC': [env: 'pc-poc'],
    'DEV': [env: 'cm-dev'],
    'QA': [env: 'cm-qa'],
    'PROD': [env: 'cm-prod']
]

def allowed_environments = get_environments(ENVIRONMENTS, env.JOB_NAME)

pipeline {
    agent none
    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
    }
    environment{
        PLAN_STATUS=""
        AWS_ENVIRONMENT=""
    }
    parameters {
        choice(name: 'ENVIRONMENT', choices: allowed_environments, description: 'The environment.')
        password(name: 'AWS_CREDENTIALS', defaultValue: '', description: 'Enter AWS credentials. e.g. export AWS_ACCESS_KEY_ID=[...] export AWS_SECRET_ACCESS_KEY=[...] export AWS_SESSION_TOKEN=[...]')
    }
    stages{
        stage('Validate inputs and user') {
            agent {
                label 'master'
            }
            steps{
                script{
                    if (params.AWS_CREDENTIALS == null || params.AWS_CREDENTIALS.toString().trim() == ""){
                        error("AWS credentials not present. Pls insert the values in this way: export AWS_ACCESS_KEY_ID=[...] export AWS_SECRET_ACCESS_KEY=[...] export AWS_SESSION_TOKEN=[...]")
                    }
                    AWS_ENVIRONMENT=ENVIRONMENTS["${ENVIRONMENT}"]['env']
                    env.AWS_ACCESS_KEY_ID=get_aws_credentials_from_input.getCredential("AWS_ACCESS_KEY_ID")
                    env.AWS_SECRET_ACCESS_KEY=get_aws_credentials_from_input.getCredential("AWS_SECRET_ACCESS_KEY")
                    env.AWS_SESSION_TOKEN=get_aws_credentials_from_input.getCredential("AWS_SESSION_TOKEN")
                    def user_id = sh label: '', returnStdout: true, script: 'aws sts get-caller-identity | jq .\'UserId\' -r | awk \'{split($0,a,":"); print a[2]}\''
                    wrap([$class: 'BuildUser']) {
                        currentBuild.displayName = "${BUILD_NUMBER} - User: ${BUILD_USER}, Environment: ${ENVIRONMENT}"
                        currentBuild.description = "AWS user: ${user_id}"
                    }
                }
            }
        }
        stage('Create Terraform plan') {
            agent {
                docker {
                    image 'hashicorp/terraform:0.14.3'
                    args '--entrypoint=""'
                }
            }
            steps{
                script{
                    dir('terraform'){
                        sh label: 'configure_terraform', script: "terraform init -backend-config=\"../config/nora/${AWS_ENVIRONMENT}-init.tfvars\" --reconfigure --upgrade"
                        sh label: 'run_terraform_plan', script: "terraform plan -var-file=\"../config/nora/${AWS_ENVIRONMENT}-apply.tfvars\" -no-color -out tfplan | tee tfplan_state"
                        PLAN_STATUS = sh label: 'plan_status', returnStdout: true, script: 'cat tfplan_state | grep "Plan:\\|No changes"'
                        echo "Plan status: ${PLAN_STATUS}"
                    }
                }
            }
        }
        stage('Approval') {
            agent { label 'master' }
            when {
                expression{ ! PLAN_STATUS.startsWith("No changes") }
            }
            steps{
                script {
                    input(id: 'confirm', message: "Apply Terraform? ${PLAN_STATUS}")
                }
            }
        }
        stage('Apply Terraform plan') {
            agent {
                docker {
                    image 'hashicorp/terraform:0.14.3'
                    args '--entrypoint=""'
                }
            }
            when {
                expression{ ! PLAN_STATUS.startsWith("No changes") }
            }
            steps{
                script{
                    dir('terraform'){ 
                        sh label: 'run_terraform_plan', script: "terraform apply -no-color -input=false tfplan"
                        terraform_output = sh label: 'output_terraform', returnStdout: true, script: "terraform output -json"
                        terraform_output_json = readJSON text: "${terraform_output}"
                      }
                }
            }
        }
        stage('Terraform output') {
            agent {
                docker {
                    image 'hashicorp/terraform:0.14.3'
                    args '--entrypoint=""'
                }
            }
            steps{
                script{
                    dir('terraform'){
                        terraform_output = sh label: 'output_terraform', returnStdout: true, script: "terraform output -json"
                        terraform_output_json = readJSON text: "${terraform_output}"
                      }
                }
            }
        }
// 		stage('Serverless deploy') {
//             agent {
//                 dockerfile {
//                     filename "serverless/Dockerfile"
//                     additionalBuildArgs '-t node:vf-serverless --pull'
//                     args '-u root'
//                 }
//             }
//             steps {
//                 script {
//                     dir('serverless'){
//                         try{
//                             sh label: 'serverless', script: "serverless deploy --stage ${AWS_ENVIRONMENT} --vf_region ${terraform_output_json.vf_region.value} --api_id ${terraform_output_json.api_id.value} --api_root_id ${terraform_output_json.api_root_id.value} --api_event_id ${terraform_output_json.event_id.value} --sqs_receiver_id ${terraform_output_json.sqs_receiver_id.value} --sqs_receiver_name ${terraform_output_json.sqs_receiver_name.value} --sqs_receiver_arn ${terraform_output_json.sqs_receiver_arn.value} --cognito_arn ${terraform_output_json.cognito_arn.value} -v"
//                         } finally {
//                             sh label: 'serverless_permissions', script: 'if [ -d ".serverless" ]; then chmod -R 777 .serverless; fi'
//
//                         }
//                     }
//                 }
//             }
//         }
    }
    post {
        cleanup {
            node('master') {
                sh 'rm -rf * .git/'
            }
        }
    }
}

@NonCPS
def get_environments(all_environments, job_name) {
    return all_environments.keySet().findAll{label -> job_name.contains(label.toLowerCase())}.join('\n')
}
@rest @dcos
@mandatory(DCOS_CLI_HOST,DCOS_CLI_USER,DCOS_CLI_PASSWORD,BOOTSTRAP_IP,REMOTE_USER,PEM_FILE_PATH,DCOS_PASSWORD)
Feature: Check multiple deployments which share vhost

  Scenario Outline:[01] Deploy different services nginx
    Given I create file '<id>-config.json' based on 'schemas/nginx-qa-config.json' as 'json' with:
      | $.id                                | REPLACE | <id>          | string |
      | $.labels.HAPROXY_0_VHOST            | REPLACE | <vhost>       | string |
      | $.labels.HAPROXY_0_PATH             | REPLACE | <path>        | string |
      | $.labels.HAPROXY_0_BACKEND_WEIGHT   | REPLACE | <weight>      | string |
      | $.labels.DCOS_PACKAGE_NAME          | REPLACE | <id>          | string |
      | $.labels.DCOS_SERVICE_NAME          | REPLACE | <id>          | string |
      | $.container.docker.image            | UPDATE  | !{EXTERNAL_DOCKER_REGISTRY}/nginx:1.10.3-alpine | n/a |
    Given I open a ssh connection to '${DCOS_CLI_HOST}' with user '${DCOS_CLI_USER}' and password '${DCOS_CLI_PASSWORD}'
    And I outbound copy 'target/test-classes/<id>-config.json' through a ssh connection to '/tmp'
    And I run 'dcos marathon app add /tmp/<id>-config.json' in the ssh connection
    And I run 'rm -f /tmp/<id>-config.json' in the ssh connection
    Examples:
      | id                   | vhost                      | path      | weight  |
      | nginx-qa-testqa      | nginx-qa.!{EOS_DNS_SEARCH} |           | 0       |
      | nginx-qa-testqa1     | nginx-qa.!{EOS_DNS_SEARCH} | testqa1   | 1       |
      | nginx-qa-testqa2     | nginx-qa.!{EOS_DNS_SEARCH} | testqa2   | 2       |
      | nginx-qa-testqa3     | nginx-qa.!{EOS_DNS_SEARCH} | testqa3   | 3       |

  Scenario Outline:[02] Check deployment for different services nginx
    Given I open a ssh connection to '${DCOS_CLI_HOST}' with user '${DCOS_CLI_USER}' and password '${DCOS_CLI_PASSWORD}'
    And in less than '100' seconds, checking each '10' seconds, the command output 'dcos task | grep -w '<id>' | awk '{print $4}' | grep R | wc -l' contains '1' with exit status '0'
    And I run 'dcos marathon task list | grep -w /'<id>' | grep True | awk '{print $5}'' in the ssh connection with exit status '0' and save the value in environment variable 'nginxTaskId'
    And in less than '100' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{nginxTaskId} | jq -c 'select(.state=="TASK_RUNNING" and .healthCheckResults[].alive==true)' | wc -l' contains '1' with exit status '0'
    Examples:
      | id                   |
      | nginx-qa-testqa      |
      | nginx-qa-testqa1     |
      | nginx-qa-testqa2     |
      | nginx-qa-testqa3     |

  Scenario:[03] Check rules in MarathonLB
    Given I open a ssh connection to '${DCOS_CLI_HOST}' with user '${DCOS_CLI_USER}' and password '${DCOS_CLI_PASSWORD}'
    And I run 'curl -XGET http://!{PUBLIC_NODE}:9090/_haproxy_getconfig' in the ssh connection with exit status '0' and save the value in environment variable 'haproxy_getConfig'
    And I run 'echo '!{haproxy_getConfig}' | grep -A12 'frontend marathon_http_in' > /tmp/rules.txt' locally
    And I run 'echo !{EOS_DNS_SEARCH} | sed 's/\./\_/g'' locally and save the value in environment variable 'dnsSearchParsed'
    And I run 'sed -i -e 's/_nginx-qa_labs_stratio_com/_nginx-qa_!{dnsSearchParsed}/g' -e 's/nginx-qa.labs.stratio.com/nginx-qa.!{EOS_DNS_SEARCH}/g' target/test-classes/schemas/marathonlb_http_rules.txt' locally
    And I run 'sed -i 's/nginx-qa.labs.stratio.com/nginx-qa.!{EOS_DNS_SEARCH}/g' target/test-classes/schemas/marathonlb_https_rules.txt' locally
    And I run 'diff target/test-classes/schemas/marathonlb_http_rules.txt /tmp/rules.txt' locally with exit status '0'
    And I run 'echo '!{haproxy_getConfig}' | grep -A9 'frontend marathon_https_in' > /tmp/rules.txt' locally
    And I run 'diff target/test-classes/schemas/marathonlb_https_rules.txt /tmp/rules.txt' locally with exit status '0'
    And I run 'rm -f /tmp/rules.txt' locally

  Scenario Outline:[04] Check deployment for different services nginx
    Given I open a ssh connection to '${DCOS_CLI_HOST}' with user '${DCOS_CLI_USER}' and password '${DCOS_CLI_PASSWORD}'
    And I run 'dcos marathon app remove <id>' in the ssh connection
    And I run 'dcos task | grep -w '<id>' | awk '{print $4}' | grep R' in the ssh connection with exit status '1'
    Examples:
      | id                   |
      | nginx-qa-testqa      |
      | nginx-qa-testqa1     |
      | nginx-qa-testqa2     |
      | nginx-qa-testqa3     |

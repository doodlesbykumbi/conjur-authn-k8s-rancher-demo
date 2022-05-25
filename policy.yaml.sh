cat << EOL
---
# In the spirit of
# https://docs.cyberark.com/Product-Doc/OnlineHelp/AAM-DAP/Latest/en/Content/Integrations/k8s-ocp/k8s-app-identity.htm?tocpath=Integrations%7COpenShift%252FKubernetes%7CSet%20up%20applications%7C_____4

# Define test app host
- !host
  id: ${host_login}
  annotations:
    authn-k8s/namespace: default
    authn-k8s/authentication-container-name: authenticator
    # authn-k8s/service-account: <service-account>
    # authn-k8s/deployment: <deployment>
    # authn-k8s/deployment-config: <deployment-config>
    # authn-k8s/stateful-set: <stateful-set>

# Enroll a Kubernetes authentication service
- !policy
  id: ${authn_service_id}
  annotations:
    description: K8s Authenticator policy definitions
  body:
  # vars for ocp/k8s api url & access creds
  - !variable kubernetes/service-account-token
  - !variable kubernetes/ca-cert
  - !variable kubernetes/api-url
  # vars for CA for this service ID
  - !variable ca/cert
  - !variable ca/key
  - !webservice
    annotations:
      description: Authenticator service for K8s cluster
  # Grant 'test-app' host authentication privileges
  - !permit
    role: !host /${host_login}
    privilege: [ read, authenticate ]
    resource: !webservice
EOL

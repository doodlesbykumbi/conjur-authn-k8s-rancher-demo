cat << EOL
---
${conjur_configmap}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: test-app
  name: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      serviceAccountName: default
      containers:
      - image: curlimages/curl
        imagePullPolicy: Always
        command: ["sleep", "infinity"]
        name: test-app
        ports:
        - containerPort: 8080
        env:
          - name: CONJUR_APPLIANCE_URL
            value: "${conjur_appliance_url}"
          - name: CONJUR_ACCOUNT
            value: "${conjur_account}"
          - name: CONJUR_AUTHN_TOKEN_FILE
            value: /run/conjur/access-token
        volumeMounts:
          - mountPath: /run/conjur
            name: conjur-access-token
            readOnly: true
      - image: cyberark/conjur-authn-k8s-client:edge
        imagePullPolicy: Always
        name: authenticator
        env:
          - name: DEBUG
            value: "true"
          - name: MY_POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: MY_POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: MY_POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
          - name: CONJUR_AUTHN_URL
            value: "${conjur_authn_url}"
          - name: CONJUR_ACCOUNT
            value: "${conjur_account}"
          - name: CONJUR_AUTHN_LOGIN
            value: "host/${host_login}"
          - name: CONJUR_SSL_CERTIFICATE
            valueFrom:
              configMapKeyRef:
                name: conjur-config
                key: ssl-certificate
        volumeMounts:
          - mountPath: /run/conjur
            name: conjur-access-token
      volumes:
        - name: conjur-access-token
          emptyDir:
            medium: Memory
EOL

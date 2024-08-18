
# bitnami-sealed-secrets-workshop
* references
    * https://fluxcd.io/flux/guides/sealed-secrets/
    * https://foxutech.medium.com/bitnami-sealed-secrets-kubernetes-secret-management-86c746ef0a79
    * https://www.digitalocean.com/community/developer-center/how-to-encrypt-kubernetes-secrets-using-sealed-secrets-in-doks
    * https://chatgpt.com/
    * https://www.civo.com/learn/sealed-secrets-in-git
    * https://medium.com/@abdullah.devops.91/how-to-use-sealed-secrets-in-kubernetes-b6c69c84d1c2
    * https://github.com/bitnami-labs/sealed-secrets

## preface
* goals of this workshop
    * understand the problem of secrets in GitOps approach
    * introduction into Bitnami Sealed Secrets
        * using kubeseal
        * k8s configuration
    * plugging secrets in helm deployments
* workshop plan
    1. configuration
        1. install the sealed secrets controller
            * latest version: https://github.com/bitnami-labs/sealed-secrets/tags
            * `kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/controller.yaml`
        1. verify relevant Pod is running
            * `kubectl get pods -n kube-system | grep sealed-secrets`
        1. install kubeseal CLI
            * `brew install kubeseal`
    1. deploying secrets
        1. verify secret is not yet created
            * `kubectl get secrets my-secret`
                * if created => drop all secrets
                    * `kubectl delete secrets --all`
                    * verify once again
        1. create `raw-secrets.yaml` file
            ```
            apiVersion: v1
            kind: Secret
            metadata:
              name: my-secret
            type: Opaque
            data:
              secret.value: c2VjcmV0dmFsdWU=  # base64 encoded value of 'secretvalue'
            ```
        1. seal secret using kubeseal
            * `kubeseal < raw-secrets.yaml > sealed-secrets.yaml`
        1. deploy sealed secret
            1. `kubectl create -f sealed-secrets.yaml`
            * verify it was created
                * `kubectl get sealedsecret my-secret -o yaml > existing-sealedsecret.yaml`
                    * might be securely committed to git
        1. verify that secret resource is created
            * `kubectl get secret my-secret -o yaml`
    * updating
        1. prepare new secret
            1. base64 encode some value
                * `echo -n "secretvalue1" | base64`
                    * output: `c2VjcmV0dmFsdWUx`
            1. prepare tmp-raw-secret.yaml
                ```
                apiVersion: v1
                kind: Secret
                metadata:
                  name: my-secret
                type: Opaque
                data:
                  secret.value: c2VjcmV0dmFsdWUx  # base64 encoded value of 'secretvalue1'
                ```
            1. encrypt it
                `kubeseal < tmp-raw-secret.yaml > tmp-sealed.yaml`
        1. edit current sealed secrets
            * get one: `kubectl get sealedsecret my-secret -o yaml > existing-sealedsecret.yaml`
            * add line
                ```
                secret.value2: AgAB0pMsRW/efFkcMcYmd9Sjmuen7VLJ0zwR+uktwyQbmu3OKEmTqbFHiqZPXl9y6iApXrWMutzH8owZ/tlcNpcOuF5L7IL4Q7R+bC7GdTEsyq6kltKOFeida1FAZxZm+7QrS6S04dppJ/920PaWJ0uKcQB3dcCXHFZcy+qN2CiZ+kQUeBZKf+e+MBRVk3HWCBO21lQRjN5gFHoEuSD7qsA2jZRMWUjc5Otj+yBFiSijMWwlYTkg4FfizqNgqLBqe1X6fTg9YmUN1dWv7onGhtzdG349GiTTT22jGmEgdY/XqP1TUkIW4URfOKClz83Sz4nQJlxlLJ3q+s1v5+IdC0DWNp3rdIXwGDpqsFDM+MSc90YFhr4pYZNZVwEwiYKcecu2iEStu5BGW06VoXSIZ2l6bEm36FsTTs8nsaXL3cfurz5/O2Q67a04mOHVOse1DAszjj8dSANo3Lchmd00x9cFJfQ178W1N4Cyisi7W4bm05BYy733rjJzsjm+/q8gHfXaQv2v7p5m3BuxmX59aH7JE7OkaDqpaxAnGD/bqP4Jp7cisSLWd+Q6/3lqssaFPJxSZ2gaz+O3R0Ly/jt8M5kgfHvrxpl1DolJM+C/xNryRdLNeRCwWJu2lxlyf35M1nxyuN4nmvlNpgzqbCQzSt6vjoUbXjActETS91BxLui1hitMzX9mR4Lsomi06LML4Tr5LDbW2qt8ZN7/ag8=
                ```
        1. deploy
            * `kubectl apply -f existing-sealedsecret.yaml`
        1. verify changes
            * `kubectl get secret my-secret -o yaml`
            * should contain
                ```
                secret.value: c2VjcmV0dmFsdWU=
                secret.value2: c2VjcmV0dmFsdWUx
                ```

* Bitnami sealed-secrets
    * store secrets safely in a public or private Git repository
    * encrypt your Kubernetes Secrets into SealedSecrets
    * sealed secrets can be decrypted only by the controller running in your cluster
    * comes with a companion CLI tool called kubeseal
        * With kubeseal you can create SealedSecret custom resources in YAML format and store those in your Git repositor
    * At startup, the sealed-secrets controller generates a 4096-bit RSA key pair and persists the private and public keys as Kubernetes secrets
        * You can retrieve the generated public key certificate using kubeseal and store it on your local disk
            * # kubeseal --fetch-cert > public-key-cert.pem
            * kubeseal encrypts the Secret using the public key that it fetches at runtime from the controller running in the Kubernetes cluster.
            * If a user does not have direct access to the cluster, then a cluster administrator may retrieve the public key from the controller logs and make it accessible to the user.
    * Sealed Secrets is an open-source Kubernetes controller and a client-side CLI tool from Bitnami that aims to solve the “storing secrets in Git” part of the problem, using asymmetric crypto encryption.
    * The public key can be safely stored in a Git repository, for example, or even given to the world.
    * Private Key Backup
        1. kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > master.key
        1. store the master.key file somewhere safe (secure vault)
    * Use Vault to securely store the master.key
    * The Sealed Secrets controller in the Sealed Secrets ecosystem is responsible for watching for Sealed Secret custom resources. When it detects one, it decrypts the enclosed secret using its private key and then creates a standard Kubernetes Secret.
    * Encrypted SealedSecret resources are designed to be safe to be looked at without gaining any knowledge about the secrets it conceals.
        * This implies that we cannot allow users to read a SealedSecret meant for a namespace they wouldn't have access to and just push a copy of it in a namespace where they can read secrets from.
        * Sealed-secrets thus behaves as if each namespace had its own independent encryption key and thus once you seal a secret for a namespace, it cannot be moved in another namespace and decrypted there.
            * We don't technically use an independent private key for each namespace, but instead we include the namespace name during the encryption process, effectively achieving the same result.
    * Furthermore, namespaces are not the only level at which RBAC configurations can decide who can see which secret.
        * In fact, it's possible that users can access a secret called foo in a given namespace but not any other secret in the same namespace.
        * We cannot thus by default let users freely rename SealedSecret resources otherwise a malicious user would be able to decrypt any SealedSecret for that namespace by just renaming it to overwrite the one secret user does have access to.
            * We use the same mechanism used to include the namespace in the encryption key to also include the secret name.
        * You might have a use case for moving a sealed secret to other namespaces (e.g. you might not know the namespace name upfront), or you might not know the name of the secret (e.g. it could contain a unique suffix based on the hash of the contents etc).
                    * The scope is nothing but the context or visibility of a sealed secret within a Kubernetes cluster.
                    * There are 3 types of scopes in Sealed Secrets:
                        * Scope Type	Description
                          strict	The name and namespace of the secret are included in the encrypted data. Therefore, you must seal the secret using the same name and namespace.
                          namespace-wide	You can freely rename the sealed secret within a given namespace.
                          cluster-wide	You have the flexibility to unseal the secret using any name and in any namespace.
    * SealedSecrets are from the POV of an end user a "write only" device.
        * The idea is that the SealedSecret can be decrypted only by the controller running in the target cluster and nobody else (not even the original author) is able to obtain the original Secret from the SealedSecret.
    * How Sealed Secrets Work:
      A Sealed Secrets Controller is deployed in the Kubernetes cluster.
      Users encrypt their Secret into a SealedSecret using kubeseal and the controller's public key.
      The SealedSecret is committed to version control, just like any other resource.
      Once applied to the cluster, the Sealed Secrets Controller decrypts the SealedSecret and creates a standard Secret.
      The standard Secret is then used by your pods, ensuring a secure secret management lifecycle.
    * Sealed Secrets is composed of two parts:
      A cluster-side controller / operator
      A client-side utility: kubeseal
        * The kubeseal utility uses asymmetric crypto to encrypt secrets that only the controller can decrypt.
    * By default the controller resources are being created in “kube-system” namespace.
    * command $ kubeseal < mysql-secret.yaml > mysql-sealedsecret.yaml performs the following action
        1. Reads the Secret from a File: It takes the mysql-secret.yaml file as input. This file should contain a Kubernetes Secret object in YAML format. The secret typically includes sensitive information that you want to encrypt, such as passwords, tokens, or keys.
        1. Encrypts the Secret: The kubeseal utility uses the public key of the Sealed Secrets controller deployed in your Kubernetes cluster to encrypt the content of the Secret. This encryption process converts the sensitive data within the Secret into a securely encrypted form, which can only be decrypted by the Sealed Secrets controller in the cluster.
        1. Generates a SealedSecret: The output of the encryption process is a new Kubernetes resource of kind SealedSecret, which contains the encrypted data. This SealedSecret is specifically designed to be safely stored in version control systems, shared among team members, or used in continuous integration/continuous deployment (CI/CD) pipelines without exposing the encrypted sensitive information.
        1. Writes the SealedSecret to a File: The encrypted SealedSecret is then written to the mysql-sealedsecret.yaml file. This file can be applied to your Kubernetes cluster using kubectl apply, similar to how you would deploy other Kubernetes resources.
    * encrypted secrets can be safely versioned and shared, with decryption only possible within the cluster by the Sealed Secrets controller
    * Updating Sealed Secrets
        * If you want to add or update existing sealed secrets without having the cleartext for the other items, you can just copy&paste the new encrypted data items and merge it into an existing sealed secret.
        * You can use the --merge-into command to update an existing sealed secrets if you don't want to copy&paste:
    * Getting the Public Key.
        * kubeseal --fetch-cert > mypublickey.pem
    * Backup and Restore.
        * kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key.backup.yaml
        * kubectl apply -f sealed-secrets-key.backup.yaml // To restore, apply your backup key to the cluster:
    * Viewing Encrypted Data.
        * Directly viewing encrypted data within a Sealed Secret is not possible due to its encrypted nature.
    * An alternative workflow is to store the certificate somewhere (e.g. local disk) with kubeseal --fetch-cert >mycert.pem, and use it offline with kubeseal --cert mycert.pem. The certificate is also printed to the controller log on startup.
    * Sealing key renewal
        * are automatically renewed every 30 days
        * Sealed secrets are not automatically rotated and old keys are not deleted when new keys are generated. Old SealedSecret resources can be still decrypted (that's because old sealing keys are not deleted).
    * User secret rotation
        * If a sealing key somehow leaks out of the cluster you must consider all your SealedSecret resources encrypted with that key as compromised. No amount of sealing key rotation in the cluster or even re-encryption of existing SealedSecrets files can change that.
        * The best practice is to periodically rotate all your actual secrets (e.g. change the password) and craft new SealedSecret resources with those new secrets.
    * image verification
        * images are being signed using cosign
        * signatures have been saved in our GitHub Container Registry
        * script
            ```
            # export the COSIGN_VARIABLE setting up the GitHub container registry signs path
            export COSIGN_REPOSITORY=ghcr.io/bitnami-labs/sealed-secrets-controller/signs

            # verify the image uploaded in Dockerhub
            cosign verify --key .github/workflows/cosign.pub docker.io/bitnami/sealed-secrets-controller:latest
            ```

* GitOps workflow
    * Once the sealed-secrets controller is installed, the admin fetches the public key and shares it with the teams that operate on the fleet clusters via Git.
    * When a team member wants to create a Kubernetes Secret on a cluster, they uses kubeseal and the public key corresponding to that cluster to generate a SealedSecret.
    * steps
        create a Kubernetes Secret manifest locally with the db credentials e.g. db-auth.yaml
        encrypt the secret with kubeseal as db-auth-sealed.yaml
        delete the original secret file db-auth.yaml
        create a Kubernetes Deployment manifest for the app e.g. app-deployment.yaml
        add the Secret to the Deployment manifest as a volume mount or env var using the original name db-auth
        commit the manifests db-auth-sealed.yaml and app-deployment.yaml to a Git repository that’s being synced by the GitOps toolkit controllers

* problem
    * Traditional Secrets in Kubernetes are stored in etcd with base64 encoding, which can be easily decoded if the etcd is compromised or if unauthorized access is gained.
    * Kubernetes Secret’s file contains just the base64 encoded value of our sensitive information
        * example
            ```
            apiVersion: v1
            kind: Secret
            metadata:
              name: mysecret
            type: Opaque
            data:
              username: d2VsY29tZSB0bw==
              password: Zm94dXRlY2g=
            ```
        * echo -n Zm94dXRlY2g= | base64 -d

helm install bitnami-sealed-secrets-workshop ./helm
helm uninstall bitnami-sealed-secrets-workshop
docker ps
kubectl get pods
kubectl logs secret-app-5946c9489-n2fkt -n default


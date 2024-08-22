
# bitnami-sealed-secrets-workshop
* references
    * https://fluxcd.io/flux/guides/sealed-secrets/
    * https://foxutech.medium.com/bitnami-sealed-secrets-kubernetes-secret-management-86c746ef0a79
    * https://www.digitalocean.com/community/developer-center/how-to-encrypt-kubernetes-secrets-using-sealed-secrets-in-doks
    * https://chatgpt.com/
    * https://www.civo.com/learn/sealed-secrets-in-git
    * https://medium.com/@abdullah.devops.91/how-to-use-sealed-secrets-in-kubernetes-b6c69c84d1c2
    * https://github.com/bitnami-labs/sealed-secrets
    * https://medium.com/@megaurav25/sealed-secret-mastery-guide-04f8ed9d2005

## preface
* goals of this workshop
    * understand the problem of keeping secrets in GitOps approach
        * and how Bitnami Sealed Secrets addresses it
    * introduction into Bitnami Sealed Secrets
        * using kubeseal
        * k8s configuration
    * showing how to plug secrets in helm deployments
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
                  secret.value2: c2VjcmV0dmFsdWUx  # base64 encoded value of 'secretvalue1'
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
    * plugging into spring boot app
        1. deploy app
            * helm install bitnami-sealed-secrets-workshop ./helm
            * for uninstall: helm uninstall bitnami-sealed-secrets-workshop
        1. verify logs
            1. kubectl logs $(kubectl get pods | grep secret-app | awk '{print $1}')
                * should print: `secret: secretvalue`

## introduction
* k8s `Secrets`
    * typically includes sensitive information that you want to encrypt, such as passwords, tokens, or keys
    * contains just the base64 encoded value
        * can be easily decoded
            * example: `echo -n Zm94dXRlY2g= | base64 -d`
    * stored in etcd
        * if compromised => unauthorized access is gained
    * cannot be stored in git
        * we need encrypted format
* problem: managing secrets manually in Kubernetes can be cumbersome
    * especially in environments with many clusters (development, staging, production) or frequent updates to secrets
* problem: during the CI/CD process, unencrypted secrets might inadvertently get exposed

## Bitnami sealed-secrets
* aims to solve the "storing secrets in Git" part of the problem
    * using asymmetric crypto encryption

* components
    * kubeseal
        * companion CLI
        * encrypts the Secret using the public key that it fetches at runtime from the controller
            * public key can be stored in git if user does not have direct access to the cluster
                * `kubeseal --cert mycert.pem`
        * example: `kubeseal < mysql-secret.yaml > mysql-sealedsecret.yaml`
            1. reads the Secret from a file
                * takes the `mysql-secret.yaml` file as input
                * file should contain a Kubernetes Secret object in YAML format
            1. encrypts the Secret
                * uses the public key of the Sealed Secrets controller
                    * can only be decrypted by the Sealed Secrets controller
            1. generates a SealedSecret
                * output of the encryption process is a new Kubernetes resource of kind SealedSecret
            1. writes the SealedSecret to a file
                * written to the `mysql-sealedsecret.yaml` file
                    * can be applied to Kubernetes cluster using `kubectl apply`
    * sealed-secrets controller
        * generates a 4096-bit RSA key pair and persists the private and public keys as Kubernetes secrets
        * responsible for watching for Sealed Secret custom resources
            * decrypts the enclosed secret using its private key and then creates a standard Kubernetes Secret
        * decrypts the SealedSecret and creates a standard Secret
            * standard Secret is then used by pods
        * by default created in "kube-system" namespace
    * SealedSecret CRD (custom resource definition)
        * specifically designed to be safely stored in version control systems
        * designed to be safe to be looked at without gaining any knowledge about the secrets it conceals
            * viewing decrypted data within a Sealed Secret is not possible
        * are from the POV of an end user a "write only" device
            * can be decrypted only by the controller
        * updating
            * two methods
                1. copy&paste
                    * generate sealed secret => download existing one => copy&paste => kubectl apply
                1. `--merge-into` (instead of copy&paste)
                    ```
                    kubectl create secret generic temp-secret --dry-run=client --from-literal=NEW_SECRET="new-secret-value" -o yaml \
                    | kubeseal --merge-into sealed-secret.yaml -o sealed-secret.yaml
                    ```
    * private key (sealed key)
        * use Vault to securely store the master.key
        * backup
            1. `kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > master.key`
            1. store the `master.key` file somewhere safe (secure vault)
        * are automatically renewed every 30 days
            * secrets are not automatically rotated
                * old keys are not deleted when new keys are generated
        * secret rotation
            * sealing key is compromised => all secrets encrypted with that key are compromised
                * re-encryption of existing SealedSecrets files cannot change that
            * best practice:periodically rotate all secrets (e.g. change the password)
    * public key
        * retrieve: `kubeseal --fetch-cert > public-key-cert.pem`



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
* image verification
    * images are being signed using cosign
    * signatures have been saved in GitHub Container Registry
    * script
        ```
        # export the COSIGN_VARIABLE setting up the GitHub container registry signs path
        export COSIGN_REPOSITORY=ghcr.io/bitnami-labs/sealed-secrets-controller/signs

        # verify the image uploaded in Dockerhub
        cosign verify --key .github/workflows/cosign.pub docker.io/bitnami/sealed-secrets-controller:latest
        ```
* GitOps workflow
    1. sealed-secrets controller is installed
    1. admin fetches the public key and shares it via Git
    1. when a team member wants to create a Kubernetes Secret => kubeseal + public key + raw secret = SealedSecret

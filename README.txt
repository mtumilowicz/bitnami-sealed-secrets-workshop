* https://www.hungrycoders.com/blog/understanding-relaxed-binding-in-spring-boot

* references
    * https://fluxcd.io/flux/guides/sealed-secrets/
    * https://foxutech.medium.com/bitnami-sealed-secrets-kubernetes-secret-management-86c746ef0a79
    * https://www.digitalocean.com/community/developer-center/how-to-encrypt-kubernetes-secrets-using-sealed-secrets-in-doks
    * https://chatgpt.com/
    * https://www.civo.com/learn/sealed-secrets-in-git
    * https://medium.com/@abdullah.devops.91/how-to-use-sealed-secrets-in-kubernetes-b6c69c84d1c2
    * https://github.com/bitnami-labs/sealed-secrets

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
    * There are 3 types of scopes in Sealed Secrets:
        * The scope is nothing but the context or visibility of a sealed secret within a Kubernetes cluster.
        * Scope Type	Description
          strict	The name and namespace of the secret are included in the encrypted data. Therefore, you must seal the secret using the same name and namespace.
          namespace-wide	You can freely rename the sealed secret within a given namespace.
          cluster-wide	You have the flexibility to unseal the secret using any name and in any namespace.
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
        * To update a Sealed Secret, you must re-encrypt and apply the new Sealed Secret.
        * There’s no direct update operation due to the one-way nature of encryption
        * do your needed changes in the original secret YAML file, then re-generate the sealed secret out of it again using a command similar to the following
    * Getting the Public Key.
        * kubeseal --fetch-cert > mypublickey.pem
    * Backup and Restore.
        * kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key.backup.yaml
        * kubectl apply -f sealed-secrets-key.backup.yaml // To restore, apply your backup key to the cluster:
    * Viewing Encrypted Data.
        * Directly viewing encrypted data within a Sealed Secret is not possible due to its encrypted nature.

* workshop plan
    1. Install the Sealed Secrets Controller in Your Cluster.
        * kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.0/controller.yaml
    1. You can ensure that the relevant Pod is running as expected by executing the following command:
        # kubectl get pods -n kube-system | grep sealed-secrets
    1. Install the kubeseal CLI
    1. create raw-secrets.yaml file
        ```
        apiVersion: v1
        kind: Secret
        metadata:
          name: my-secret
        type: Opaque
        data:
          secret.value: c2VjcmV0dmFsdWU=  # base64 encoded value of 'secretvalue'
        ```
    1. transform it into a sealed secret with the help of kubeseal
        * kubeseal < mysql-secret.yaml > mysql-sealedsecret.yaml

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


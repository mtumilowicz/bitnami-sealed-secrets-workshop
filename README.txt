helm install bitnami-sealed-secrets-workshop ./helm
helm uninstall bitnami-sealed-secrets-workshop
docker ps
kubectl get pods
kubectl logs secret-app-5946c9489-n2fkt -n default
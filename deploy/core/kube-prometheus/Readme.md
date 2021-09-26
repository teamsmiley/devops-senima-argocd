# customize kube-prometheus

<https://app.gitbook.com/@teamsmiley/s/devops/prometheus/customize-kube-prometheus>

```sh
cd core/kube-prometheus
docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) quay.io/coreos/jsonnet-ci ./build.sh c4.jsonnet
```

이러면 이제 컴파일 된 내용이 nanifests에 들어간다. 이걸 argocd에서 자동 배포하면 된다.

## etcd 모니터링

cfssl이 필요

```sh
ssh master01

# Copy etcd CA cert from etcd server "/etc/ssl/etcd/ssl/ca.pem"
sudo cp /etc/ssl/etcd/ssl/ca.pem /home/ubuntu/

# Copy etcd CA cert from etcd server "/etc/ssl/etcd/ssl/ca-key.pem"
sudo cp /etc/ssl/etcd/ssl/ca-key.pem /home/ubuntu/

cd /home/ubuntu/

sudo apt install golang-cfssl

cat > client.json.yaml <<EOF
{
  "CN": "etcd-ca",
  "hosts": [""],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{}]
}
EOF

sudo chmod 755 *.pem

# Generate client certificate
cfssl gencert -ca ca.pem -ca-key ca-key.pem client.json | cfssljson -bare etcd-client
```

관련 파일이 만들어진다. 전부 로컬로 가져온다.

```bash
scp master01:~/ca.pem ~/Desktop/GitHub/argocd-c4/core/kube-prometheus/etcd
scp master01:~/etcd-client-key.pem ~/Desktop/GitHub/argocd-c4/core/kube-prometheus/etcd
scp master01:~/etcd-client.pem ~/Desktop/GitHub/argocd-c4/core/kube-prometheus/etcd
```

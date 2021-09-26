local ingress(name, namespace, rules,tls) = {
  apiVersion: 'networking.k8s.io/v1',
  kind: 'Ingress',
  metadata: {
    name: name,
    namespace: namespace,
    annotations: {
      'kubernetes.io/ingress.class': 'nginx',
      'cert-manager.io/cluster-issuer': 'dns-issuer-aws-live',
      'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
      'nginx.ingress.kubernetes.io/auth-type': 'basic',
      'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
      'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
    },
  },
  spec: { tls: tls, rules: rules },
};

local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // Monitoring all namespaces
  (import 'kube-prometheus/addons/all-namespaces.libsonnet') +
  // Monitoring external etcd
  (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/managed-cluster.libsonnet') +
  // (import 'kube-prometheus/addons/node-ports.libsonnet') +
  // (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
  // (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },

      prometheus+: {
        namespaces: [],
      },

      kubePrometheus+: {
        platform: 'kubeadm',
      },

      alertmanager+: {
        config: importstr 'alertmanager/config.yaml',
      },

      etcd+: {
        serverName: '',
        ips: ['172.16.4.11', '172.16.4.12', '172.16.4.13'],
        clientCA: importstr 'etcd/ca.pem',
        clientKey: importstr 'etcd/etcd-client-key.pem',
        clientCert: importstr 'etcd/etcd-client.pem',
        //serverName: 'etcd.kube-system.svc.cluster.local',
        insecureSkipVerify: true,
      },

      grafana+:: {
        // Add DataSource
        datasources+: [
          {
            name: 'prometheus',
            type: 'prometheus',
            access: 'proxy',
            orgId: 1,
            url: 'http://prometheus-k8s:9090',
            editable: false,
          },
          {
            name: 'loki',
            type: 'loki',
            access: 'proxy',
            orgId: 1,
            url: 'http://core-loki-stack:3100',
            editable: false,
          },
        ],

        config+: {
          sections+: {
            'security': {
              admin_user: 'admin',
              admin_password: 'YOURPASS'
            },
            server+: {
              root_url: 'https://grafana.c4.YourDomain.com/',
            },
          },
        },
      },

      kubernetesControlPlane+: {
        mixin+: {
          _config+: {
            cpuThrottlingPercent: 60,
          },
        },
      },

    },

    // Configure External URL's per application
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          externalUrl: 'https://alert.c4.YourDomain.com',
        },
      },
    },

    prometheus+:: {
      prometheus+: {
        spec+: {
          externalUrl: 'https://prom.c4.YourDomain.com',
        },
      },
    },

    // Create ingress objects per application
    ingress+:: {
      'alertmanager-main': ingress(
        'alertmanager-main',
        $.values.common.namespace,
        [{
          host: 'alert.c4.YourDomain.com',
          http: {
            paths: [{
              path: '/',
              pathType: 'Prefix',
              backend: {
                service: {
                  name: 'alertmanager-main',
                  port: {
                    name: 'web',
                  },
                },
              },
            }],
          },
        }],
        [{
          hosts: ['alert.c4.YourDomain.com'],
          secretName: 'alert-tls'
        }],
      ),
      grafana: {
          apiVersion: 'networking.k8s.io/v1',
          kind: 'Ingress',
          metadata: {
            name: 'grafana',
            namespace: $.values.common.namespace,
            annotations: {
              'cert-manager.io/cluster-issuer': 'dns-issuer-aws-live',
              'kubernetes.io/ingress.class': 'nginx',
              'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true'
            }
          },
          spec: { 
            rules: [{
              host: 'grafana.c4.YourDomain.com',
              http: {
                paths: [{
                  path: '/',
                  pathType: 'Prefix',
                  backend: {
                    service: {
                      name: 'grafana',
                      port: {
                        name: 'http',
                      },
                    },
                  },
                }],
              },
            }], 
            tls: [{
              hosts: ['grafana.c4.YourDomain.com'],
              secretName: 'grafana-tls',
            },],
          },  
      },
      'prometheus-k8s': ingress(
        'prometheus-k8s',
        $.values.common.namespace,
        [{
          host: 'prom.c4.YourDomain.com',
          http: {
            paths: [{
              path: '/',
              pathType: 'Prefix',
              backend: {
                service: {
                  name: 'prometheus-k8s',
                  port: {
                    name: 'web',
                  },
                },
              },
            }],
          },
        }],
        [{
          hosts: ['prom.c4.YourDomain.com'],
          secretName: 'prom-tls'
        }],
      ),
    },
  } + {
    // Create basic auth secret - replace 'auth' file with your own
    ingress+:: {
      'basic-auth-secret': {
        apiVersion: 'v1',
        kind: 'Secret',
        metadata: {
          name: 'basic-auth',
          namespace: $.values.common.namespace,
        },
        data: { auth: std.base64(importstr 'auth') },
        type: 'Opaque',
      },
    },
  };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
// { ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }

{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
{ [name + '-ingress']: kp.ingress[name] for name in std.objectFields(kp.ingress) }
#
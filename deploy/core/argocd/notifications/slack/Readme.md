# argocd slack notification

## how to apply in project

```bash
kccc
kcuc c4
kubectl patch AppProjects default -n argocd --patch "$(cat core/argocd/notifications/slack/trigger.yml)" --type=merge
```

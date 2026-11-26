#!/usr/bin/env bash
# AkOps Labs check for the Kubernetes project. Please don't edit this file.
set -uo pipefail
fail=0
pass() { echo "PASS  $1"; }
bad() { echo "FAIL  $1"; fail=1; }

for f in deployment service ingress hpa; do
  [ -f "k8s/$f.yaml" ] && pass "k8s/$f.yaml exists" || bad "k8s/$f.yaml exists"
done
grep -rEq '#[[:space:]]*TODO:' k8s/ && bad "no # TODO: lines left in k8s/" || pass "no TODOs left"

if ! kubectl apply -f k8s/; then bad "kubectl apply -f k8s/ works"; echo; echo "Some checks failed."; exit 1; fi
pass "kubectl apply -f k8s/ works"

chk() { # chk "label" kind/name "python expression on o (the object)"
  if kubectl get "$2" -o json 2>/dev/null | python3 -c "import json,sys; o=json.load(sys.stdin); s=o.get('spec',{}); assert ($3)" 2>/dev/null; then pass "$1"; else bad "$1"; fi
}
C="s['template']['spec']['containers'][0]"
chk "Deployment web runs 2+ replicas" deploy/web "s['replicas']>=2"
chk "the image is pinned (not latest)" deploy/web "':' in $C['image'] and not $C['image'].endswith(':latest')"
chk "requests and limits for cpu and memory" deploy/web "all(k in $C['resources'].get(t,{}) for t in ('requests','limits') for k in ('cpu','memory'))"
chk "readiness and liveness probes on port 80" deploy/web "all(str($C[p]['httpGet']['port']) in ('80','http') for p in ('readinessProbe','livenessProbe'))"
chk "Service web selects app=web on port 80" svc/web "s['selector'].get('app')=='web' and s['ports'][0]['port']==80 and s.get('type','ClusterIP')=='ClusterIP'"
chk "Ingress sends / to service web:80" ingress/web "any(p['path']=='/' and p['backend']['service']['name']=='web' and p['backend']['service']['port']['number']==80 for r in s['rules'] for p in r['http']['paths'])"
chk "Ingress uses the nginx class" ingress/web "s.get('ingressClassName')=='nginx'"
chk "HPA scales web between 2 and 5+ at a CPU target" hpa/web "s['scaleTargetRef']['name']=='web' and s['minReplicas']>=2 and s['maxReplicas']>s['minReplicas'] and any(m.get('resource',{}).get('name')=='cpu' for m in s['metrics'])"

if kubectl rollout status deployment/web --timeout=180s; then
  pass "the Deployment rolls out"
  ready=$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')
  [ "${ready:-0}" -ge 2 ] && pass "2+ pods are ready" || bad "2+ pods are ready (got ${ready:-0})"
  kubectl port-forward svc/web 8080:80 >/dev/null 2>&1 &
  pf=$!
  sleep 4
  curl -fsS localhost:8080 | grep -qi nginx && pass "the app answers through the Service" || bad "curl localhost:8080 through kubectl port-forward svc/web"
  kill $pf 2>/dev/null
else
  bad "the Deployment rolls out (kubectl rollout status deployment/web)"
  kubectl describe deploy web | tail -20
  kubectl get pods
fi

echo
[ $fail -eq 0 ] && echo "All checks passed. Push and submit your repo on AkOps Labs." || echo "Some checks failed. Fix them and push again."
exit $fail

#!/usr/bin/env bash
# Measure why act's action fetches run at ~3 MB/s, from inside the cluster.
#
# Run this in a shell that has a working kube context (kubie).
#
# BACKGROUND. A docker-build-push job spent 2m04s in "Set up job" against 21s of actual build.
# act git-clones the FULL history of every action a job references, and the Forgejo mirrors are
# full upstream mirrors: docker/build-push-action is 181 MB, docker/login-action 134 MB. ~440 MB
# per job, and the cost tracked size almost exactly — about 3 MB/s.
#
# 3 MB/s is very slow for pod-to-pod. github.com served its 8 MB share TEN TIMES faster over the
# WAN than the in-cluster mirror did. Two candidates, and they need different fixes:
#
#   STORAGE  Forgejo's git data is on longhorn-general — network-replicated block storage. Pack
#            generation reads pack files off it. The dind DaemonSet already learned this lesson
#            and moved its image store to a node hostPath.
#   CPU      Forgejo requests 100m with NO CPU limit. Pack generation is CPU-bound, so under node
#            contention it gets whatever CFS shares 100m buys.
#
# This distinguishes them. It only reads.
#
# WHY IT MATTERS: if Forgejo can do 50 MB/s once unthrottled, the same 440 MB costs ~9s and the
# tag-scoped mini-mirror cutover (which force-pushes truncated history over live action repos) may
# not be worth its risk. Measure before committing to that.
set -uo pipefail

NS=forgejo
REPO=${1:-docker/build-push-action}

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

say "Forgejo pod"
kubectl -n "$NS" get pods -l app.kubernetes.io/name=forgejo -o wide 2>/dev/null \
  || kubectl -n "$NS" get pods -o wide | grep -E 'forgejo-[0-9a-f]{8,}' || true

POD=$(kubectl -n "$NS" get pods -l app.kubernetes.io/name=forgejo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -z "${POD:-}" ] && { echo "could not resolve the Forgejo pod; set it manually below"; }

say "Requests / limits (expect cpu request 100m, no cpu limit)"
kubectl -n "$NS" get pod "$POD" -o jsonpath='{range .spec.containers[*]}{.name}{"\t"}{.resources}{"\n"}{end}' 2>/dev/null

say "CPU throttling so far (cgroup v2: nr_throttled / throttled_usec)"
# If throttled_usec is ~0 the CPU hypothesis is dead and it is storage. Note this is cumulative
# since pod start, so compare against the burst measured below rather than reading it absolutely.
kubectl -n "$NS" exec "$POD" -c forgejo -- sh -c 'cat /sys/fs/cgroup/cpu.stat 2>/dev/null || cat /sys/fs/cgroup/cpu/cpu.stat' 2>/dev/null \
  || echo "(cpu.stat not readable in this container)"

say "Live CPU/memory"
kubectl -n "$NS" top pod "$POD" --containers 2>/dev/null || echo "(metrics-server unavailable)"

say "Storage backing the git data"
kubectl -n "$NS" get pvc forgejo-data -o custom-columns=NAME:.metadata.name,SC:.spec.storageClassName,SIZE:.spec.resources.requests.storage,STATUS:.status.phase 2>/dev/null

say "Longhorn volume health (a degraded/rebuilding replica would explain slow reads on its own)"
kubectl -n longhorn-system get volumes.longhorn.io -o custom-columns=NAME:.metadata.name,STATE:.status.state,ROBUST:.status.robustness,NODE:.status.currentNodeID 2>/dev/null \
  | grep -E "NAME|$(kubectl -n "$NS" get pvc forgejo-data -o jsonpath='{.spec.volumeName}' 2>/dev/null)" || echo "(longhorn CRDs not readable)"

say "THE MEASUREMENT: clone $REPO from inside the cluster, over the same URL act uses"
# Deliberately the in-cluster service address, not the ingress: act clones
# http://forgejo-http.forgejo.svc.cluster.local:3000/<owner>/<repo>, so anything measured through
# the ingress would include a different path and prove nothing about the number in the job log.
kubectl -n "$NS" run git-throughput-probe-$RANDOM \
  --rm -i --restart=Never \
  --image=harbor.webgrip.dev/dockerhub/alpine/git:latest \
  --overrides='{"spec":{"tolerations":[{"operator":"Exists"}]}}' \
  -- sh -c "
    set -e
    start=\$(date +%s)
    git clone --quiet http://forgejo-http.forgejo.svc.cluster.local:3000/${REPO} /tmp/probe
    end=\$(date +%s)
    bytes=\$(du -sk /tmp/probe/.git | cut -f1)
    secs=\$((end-start)); [ \$secs -eq 0 ] && secs=1
    echo \"cloned \$((bytes/1024)) MB in \${secs}s  ->  \$((bytes/secs/1024)) MB/s\"
  " 2>/dev/null || echo "probe failed — check the image is pullable and the namespace allows pod creation"

say "Read it like this"
cat <<'EOF'
  ~3 MB/s  + throttled_usec climbing during the clone   -> CPU. Raise the request; propose to the
                                                           session that owns cluster scheduling.
  ~3 MB/s  + throttling flat                            -> storage. Longhorn read path. Bigger
                                                           decision (Forgejo git data is the source
                                                           of truth for every repo).
  >30 MB/s                                              -> the mirrors were never the bottleneck at
                                                           that moment; the 3 MB/s was contention
                                                           during a CI burst. Re-run this DURING a
                                                           burst before drawing conclusions.
EOF

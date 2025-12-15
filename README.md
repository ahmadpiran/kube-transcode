# Kube-Transcode 

**In-Progress**

A distributed image/video processing pipeline.

## The core architecture

Frontend (Go Deployment/Service): Accepted the upload, saved the file locally (in the container's volume), and pushed a job to the queue.

Queue (Redis Deployment/Service): Persisted the job detail ({"filename":"test.txt",...}).

Worker (Go Deployment): Blocked on the queue, picked up the job, simulated processing for 5 seconds, and logged the completion.




# Usage

As it uses `LoadBalancer` service type, you must deploy it on a public cloud(AWS/AZURE/GCP).

```bash
kubectl apply -f ./k8s/redis.yaml
kubuctl apply -f ./k8s/frontend.yaml
kubectl apply -f ./k8s/worker.yaml
```
To see the external IP:

```bash
kubectl get service frontend -w
```

Press Ctrl+C once you see an IP Address.

Create a test file:
```bash
echo "Hello Kube-Transcode" > test.txt
```

Test it:

```bash
curl -F "file=@test.txt" http://<EXTERNAL-IP>/upload
```

To Verify:

```bash
# Get the worker pod name
kubectl get pods -l app=worker

# Check logs
kubectl logs <worker-pod-name>
```

# License
MIT
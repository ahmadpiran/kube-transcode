package main

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	redisAddr = "localhost:6379"
	queueName = "job_queue"
)

var ctx = context.Background()

type Job struct {
	Filename string `json:"filename"`
	Status   string `json:"status"`
}

func main() {
	// 1. Connect to Redis
	rdb := redis.NewClient(&redis.Options{
		Addr: redisAddr,
	})

	fmt.Println("Worker started. Waiting for jobs...")

	for {
		// 2. Block and wait for a job (0 means wait indefinitely)
		// BLPOP returns: [queue_name, value]
		result, err := rdb.BLPop(ctx, 0, queueName).Result()
		if err != nil {
			fmt.Printf("Redis connection error: %v\n", err)
			time.Sleep(1 * time.Second) // Wait before retrying
			continue
		}

		// result[1] contains the JSON payload
		rawJSON := result[1]
		
		var job Job
		if err := json.Unmarshal([]byte(rawJSON), &job); err != nil {
			fmt.Printf("Error parsing JSON: %v\n", err)
			continue
		}

		// 3. Simulate Processing
		fmt.Printf("[START] Processing %s...\n", job.Filename)
		
		// Simulate heavy work (transcoding)
		time.Sleep(5 * time.Second) 
		
		fmt.Printf("[DONE] Finished %s\n", job.Filename)
	}
}
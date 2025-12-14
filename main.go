package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/redis/go-redis/v9"
)

const (
	uploadPath = "./uploads"
	redisAddr  = "localhost:6379" // Default for local dev
	queueName  = "job_queue"
)

var rdb *redis.Client
var ctx = context.Background()

// Job represents the task we send to the worker
type Job struct {
	Filename string `json:"filename"`
	Status   string `json:"status"`
}

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 10<<20) // 10MB limit

	file, handler, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Error retrieving file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// 1. Save File Locally
	if err := os.MkdirAll(uploadPath, os.ModePerm); err != nil {
		http.Error(w, "Unable to create upload directory", http.StatusInternalServerError)
		return
	}
	dstPath := filepath.Join(uploadPath, handler.Filename)
	dst, err := os.Create(dstPath)
	if err != nil {
		http.Error(w, "Unable to create destination file", http.StatusInternalServerError)
		return
	}
	defer dst.Close()
	if _, err := io.Copy(dst, file); err != nil {
		http.Error(w, "Error saving file", http.StatusInternalServerError)
		return
	}

	// 2. Push Job to Redis
	job := Job{Filename: handler.Filename, Status: "pending"}
	jsonJob, err := json.Marshal(job)
	if err != nil {
		http.Error(w, "Error encoding job", http.StatusInternalServerError)
		return
	}

	// RPUSH adds the job to the tail of the queue
	err = rdb.RPush(ctx, queueName, jsonJob).Err()
	if err != nil {
		fmt.Printf("Redis Error: %v\n", err)
		http.Error(w, "File saved, but failed to queue job", http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "Upload successful & Job queued: %s\n", handler.Filename)
	fmt.Printf("Job queued for: %s\n", handler.Filename)
}

func main() {
	// Initialize Redis
	rdb = redis.NewClient(&redis.Options{
		Addr: redisAddr,
	})

	// Ping to check connection
	if err := rdb.Ping(ctx).Err(); err != nil {
		fmt.Printf("Could not connect to Redis: %v\n", err)
		// We don't exit here to allow the server to start even if Redis is down (for now)
	} else {
		fmt.Println("Connected to Redis successfully")
	}

	http.HandleFunc("/upload", uploadHandler)

	port := ":8080"
	fmt.Printf("Frontend Server starting on port %s...\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		fmt.Printf("Failed to start server: %v\n", err)
	}
}
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os/exec"
	"strings"

	"github.com/streadway/amqp"
)

type FileStatus string

const (
	PENDING    FileStatus = "pending"
	PROCESSING FileStatus = "processing"
	FINISHED   FileStatus = "finished"
	ERROR      FileStatus = "error"
)

type Task struct {
	FileID       string `json:"file_id"`
	FilePath     string `json:"file_path"`
	OutputFormat string `json:"output_format"`
}

func updateFileStatus(fileID string, fileStatus FileStatus) error {
	_, err := conn.Exec(context.Background(), "UPDATE files SET status=$1 WHERE id=$2", fileStatus, fileID)
	return err
}

func processVideo(filePath string, outputFormat string) error {
	splitPath := strings.Split(filePath, "/")
	filename := splitPath[len(splitPath)-1]
	outputFilePath := fmt.Sprintf("storage/converted/%s.%s", filename, outputFormat)
	fmt.Println(outputFilePath)
	cmd := exec.Command("ffmpeg", "-i", filePath, outputFilePath)
	return cmd.Run()
}

func processVideoAsync(task Task, delivery amqp.Delivery) {
	if err := updateFileStatus(task.FileID, PROCESSING); err != nil {
		log.Printf("Failed to update file status to PROCESSING: %s", err)
		return
	}

	if err := processVideo(task.FilePath, task.OutputFormat); err != nil {
		log.Printf("Error processing video: %s", err)
		updateFileStatus(task.FileID, ERROR)
		delivery.Ack(false)
		return
	}

	updateFileStatus(task.FileID, FINISHED)
	delivery.Ack(false)
}

func fileCallback(delivery amqp.Delivery) {
	var task Task
	if err := json.Unmarshal(delivery.Body, &task); err != nil {
		log.Printf("Failed to unmarshal message: %s", err)
		delivery.Nack(false, false)
		return
	}
	processVideoAsync(task, delivery)
}

func startRabbitMQConsumer() {
	fmt.Println("Starting RabbitMQ consumer")
	_, err := rabbitmqChannel.QueueDeclare("file_tasks", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("Failed to declare a queue: %s", err)
	}

	msgs, err := rabbitmqChannel.Consume("file_tasks", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("Failed to register a consumer: %s", err)
	}

	for msg := range msgs {
		fileCallback(msg)
	}
}

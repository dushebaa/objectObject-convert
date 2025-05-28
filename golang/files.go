package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/streadway/amqp"
)

var (
	STORAGE_PATH = fmt.Sprintf("%s/storage", os.Getenv("PWD")) // Current working directory
)

type FileMetadata struct {
	FileID   string `json:"file_id"`
	Filename string `json:"filename"`
}

func init() {
	// Ensure storage directory exists
	os.MkdirAll(STORAGE_PATH, os.ModePerm)
}

func processFile(w http.ResponseWriter, r *http.Request) {
	outputFormat := r.FormValue("output_format")
	authorization := r.Header.Get("Authorization")

	// Read the uploaded file
	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	defer file.Close()

	fileID := fmt.Sprintf("%s", uuid.New()) // Unique file ID
	filePath := filepath.Join(STORAGE_PATH, fileID)

	// Save file to local filesystem
	fileBytes, err := ioutil.ReadAll(file)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := ioutil.WriteFile(filePath, fileBytes, 0644); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Verify user token
	user, err := verifyToken(authorization)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	_, err = conn.Exec(
		context.Background(),
		"INSERT INTO files (id, filename, user_id, status, output_format) VALUES ($1, $2, $3, $4, $5)",
		fileID,
		header.Filename,
		user["user_id"],
		PENDING,
		strings.ToLower(outputFormat),
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Push task to RabbitMQ
	rabbitmqChannel.QueueDeclare("file_tasks", false, false, false, false, nil)

	body, _ := json.Marshal(map[string]interface{}{
		"file_id":       fileID,
		"file_path":     filePath,
		"output_format": strings.ToLower(outputFormat),
	})
	rabbitmqChannel.Publish("", "file_tasks", false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        body,
	})

	json.NewEncoder(w).Encode(map[string]string{"file_id": fileID, "file_name": header.Filename})
}

func downloadFile(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	fileID := vars["file_id"]
	authorization := r.Header.Get("Authorization")

	user, err := verifyToken(authorization)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	row := conn.QueryRow(context.Background(), "SELECT * FROM files WHERE id = $1", fileID)
	var file struct {
		ID           string
		Filename     string
		Status       string
		OutputFormat string
		UserId       int32
	}
	if err := row.Scan(&file.ID, &file.Filename, &file.Status, &file.OutputFormat, &file.UserId); err != nil {
		http.Error(w, fmt.Sprintf("File with id %s not found", fileID), http.StatusNotFound)
		return
	}
	if float64(file.UserId) != user["user_id"] {
		http.Error(w, "Unauthorized", http.StatusForbidden)
		return
	}
	fmt.Println(file)

	if file.Status != string(FINISHED) {
		http.Error(w, "File has not been processed", http.StatusBadRequest)
		return
	}

	convertedFileName := fmt.Sprintf("%s.%s", fileID, file.OutputFormat)
	filePath := filepath.Join(STORAGE_PATH, "converted", convertedFileName)
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		http.Error(w, "File not found on disk", http.StatusNotFound)
		return
	}

	http.ServeFile(w, r, filePath)
}

func fileStatus(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	fileID := vars["file_id"]
	authorization := r.Header.Get("Authorization")

	user, err := verifyToken(authorization)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	row := conn.QueryRow(context.Background(), "SELECT * FROM files WHERE id = $1", fileID)
	var file struct {
		ID           string
		Filename     string
		Status       string
		OutputFormat string
		UserId       int32
	}
	if err := row.Scan(&file.ID, &file.Filename, &file.Status, &file.OutputFormat, &file.UserId); err != nil {
		http.Error(w, fmt.Sprintf("File with id %s not found", fileID), http.StatusNotFound)
		return
	}
	if float64(file.UserId) != user["user_id"] {
		http.Error(w, "Unauthorized", http.StatusForbidden)
		return
	}

	result := map[string]any{
		"filename": file.Filename,
		"file_id":  file.ID,
		"status":   file.Status,
	}

	if file.Status == string(FINISHED) {
		result["download_url"] = fmt.Sprintf("/files/%s/download/", fileID)
	}

	json.NewEncoder(w).Encode(result)
}

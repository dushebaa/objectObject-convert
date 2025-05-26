package main

import (
	"context"
	"log"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v4"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
	"github.com/rs/cors"
	"github.com/streadway/amqp"
)

var (
	config          Config
	redisClient     *redis.Client
	rabbitmqChannel *amqp.Channel
	conn            *pgx.Conn
)

func initRabbitMQ() {
	var err error
	conn, err := amqp.Dial(config.app.RabbitmqURL)
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %s", err)
	}
	rabbitmqChannel, err = conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open a channel: %s", err)
	}
}

func initPostgres() *pgx.Conn {
	conn, err := pgx.Connect(context.Background(), config.app.DatabaseURL)
	if err != nil {
		log.Fatalf("DB connection failed: %s", err)
	}
	return conn
}

func init() {
	if err := godotenv.Load(); err != nil {
		log.Print("No .env file found")
	}
}

func serve() {
	router := mux.NewRouter()
	c := cors.New(cors.Options{
		AllowedMethods:   []string{"GET", "POST", "HEAD", "OPTIONS"},
		AllowCredentials: true,
		AllowedHeaders:   []string{"Content-Type", "Authorization"},
	})

	// auth
	router.HandleFunc("/auth/signup", signup).Methods("POST")
	router.HandleFunc("/auth/login", login).Methods("POST")

	// files
	router.HandleFunc("/files/process", processFile).Methods("POST")
	router.HandleFunc("/files/{file_id}/download/", downloadFile).Methods("GET")
	router.HandleFunc("/files/{file_id}/status/", fileStatus).Methods("GET")

	log.Println("Starting server")
	handler := c.Handler(router)
	log.Fatal(http.ListenAndServe(":8000", handler))
}

func main() {
	config = *NewConfig()
	redisClient = redis.NewClient(&redis.Options{
		Addr: config.app.RedisURL,
	})
	// rabbit
	initRabbitMQ()
	go startRabbitMQConsumer()

	// db
	conn = initPostgres()
	defer conn.Close(context.Background())

	serve()
}

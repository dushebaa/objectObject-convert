package main

import (
	"os"
)

type AppConfig struct {
	DatabaseURL string
	RedisURL    string
	RabbitmqURL string
	SecretKey   string
}

type Config struct {
	app AppConfig
}

// New returns a new Config struct
func NewConfig() *Config {
	return &Config{
		app: AppConfig{
			DatabaseURL: getEnv("DATABASE_URL", "postgresql://postgres@localhost/cloudvault"),
			RedisURL:    getEnv("REDIS_URL", "redis://127.0.0.1"),
			RabbitmqURL: getEnv("RABBITMQ_URL", "amqp://localhost:5672"),
			SecretKey:   getEnv("PWD_SECRET", "qweasdasdqweqwe123"),
		},
	}
}

// Simple helper function to read an environment or return a default value
func getEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}

	return defaultVal
}

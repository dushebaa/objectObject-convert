package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/dgrijalva/jwt-go"
)

type UserDto struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func signup(w http.ResponseWriter, r *http.Request) {
	var user UserDto
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	_, err := conn.Exec(context.Background(), "INSERT INTO users (username, password) VALUES ($1, $2)", user.Username, user.Password) // In production, hash passwords
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "User  created"})
}

func login(w http.ResponseWriter, r *http.Request) {
	var user UserDto
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	var dbUser struct {
		ID       int64  `db:"id"`
		Username string `db:"username"`
		Password string `db:"password"`
	}
	err := conn.QueryRow(context.Background(), "SELECT id, username, password FROM users WHERE username = $1", user.Username).Scan(&dbUser.ID, &dbUser.Username, &dbUser.Password)
	if err != nil {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		return
	}

	if dbUser.Password != user.Password { // Use proper password hashing
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		return
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"username": user.Username,
		"user_id":  dbUser.ID,
		"exp":      time.Now().Add(time.Hour * 1).Unix(), // 1-hour expiration
	})

	tokenString, err := token.SignedString([]byte(config.app.SecretKey))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// set the session in Redis
	err = redisClient.Set(context.Background(), fmt.Sprintf("session:%s", user.Username), tokenString, time.Hour).Err()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"token": tokenString})
}

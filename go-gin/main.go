package main

import (
	"database/sql"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

var db *sql.DB

type CalcRequest struct {
	A int `json:"a" binding:"required"`
	B int `json:"b" binding:"required"`
}

type CalcResponse struct {
	Result float64 `json:"result"`
}

type HealthResponse struct {
	Status string `json:"status"`
}

type UserResponse struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	CreatedAt string `json:"created_at"`
}

func initDB() {
	host := getEnv("DB_HOST", "postgres")
	port := getEnv("DB_PORT", "5432")
	user := getEnv("DB_USER", "benchmark")
	password := getEnv("DB_PASSWORD", "benchmark123")
	dbname := getEnv("DB_NAME", "benchmark")

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal(err)
	}

	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(time.Hour)

	if err = db.Ping(); err != nil {
		log.Fatal(err)
	}

	log.Println("Database connected")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	initDB()
	defer db.Close()
	// Modo release para melhor performance
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()
	router.Use(gin.Recovery())

	// Calculate endpoint
	router.POST("/calculate", func(c *gin.Context) {
		var req CalcRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid JSON"})
			return
		}

		// Operação matemática: distância euclidiana
		result := math.Sqrt(float64(req.A*req.A + req.B*req.B))

		c.JSON(http.StatusOK, CalcResponse{Result: result})
	})

	// User endpoint (I/O bound)
	router.GET("/user/:id", func(c *gin.Context) {
		userID := c.Param("id")

		var user UserResponse
		var createdAt time.Time

		err := db.QueryRow(
			"SELECT id, name, email, created_at FROM users WHERE id = $1",
			userID,
		).Scan(&user.ID, &user.Name, &user.Email, &createdAt)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		user.CreatedAt = createdAt.Format(time.RFC3339)
		c.JSON(http.StatusOK, user)
	})

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, HealthResponse{Status: "ok"})
	})

	log.Println("Go Gin API running on :8000")
	log.Fatal(router.Run("0.0.0.0:8000"))
}

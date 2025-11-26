package main

import (
	"database/sql"
	"fmt"
	"log"
	"math"
	"os"
	"time"

	"github.com/gofiber/fiber/v2"
	_ "github.com/lib/pq"
)

var db *sql.DB

type CalcRequest struct {
	A int `json:"a"`
	B int `json:"b"`
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
	app := fiber.New(fiber.Config{
		Prefork:       false,
		CaseSensitive: true,
		StrictRouting: false,
		ServerHeader:  "Fiber",
		AppName:       "Benchmark API",
	})

	// Calculate endpoint
	app.Post("/calculate", func(c *fiber.Ctx) error {
		var req CalcRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid JSON",
			})
		}

		// Operação matemática: distância euclidiana
		result := math.Sqrt(float64(req.A*req.A + req.B*req.B))

		return c.JSON(CalcResponse{Result: result})
	})

	// User endpoint (I/O bound)
	app.Get("/user/:id", func(c *fiber.Ctx) error {
		userID, err := c.ParamsInt("id")
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid user ID",
			})
		}

		var user UserResponse
		var createdAt time.Time

		err = db.QueryRow(
			"SELECT id, name, email, created_at FROM users WHERE id = $1",
			userID,
		).Scan(&user.ID, &user.Name, &user.Email, &createdAt)

		if err == sql.ErrNoRows {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
				"error": "User not found",
			})
		}
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Database error",
			})
		}

		user.CreatedAt = createdAt.Format(time.RFC3339)
		return c.JSON(user)
	})

	// Health check endpoint
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(HealthResponse{Status: "ok"})
	})

	log.Println("Go Fiber API running on :8000")
	log.Fatal(app.Listen(":8000"))
}

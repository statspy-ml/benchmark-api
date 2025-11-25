package main

import (
	"log"
	"math"

	"github.com/gofiber/fiber/v2"
)

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

func main() {
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

	// Health check endpoint
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(HealthResponse{Status: "ok"})
	})

	log.Println("Go Fiber API running on :8000")
	log.Fatal(app.Listen(":8000"))
}

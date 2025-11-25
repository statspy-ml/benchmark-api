package main

import (
	"log"
	"math"
	"net/http"

	"github.com/gin-gonic/gin"
)

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

func main() {
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

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, HealthResponse{Status: "ok"})
	})

	log.Println("Go Gin API running on :8000")
	log.Fatal(router.Run("0.0.0.0:8000"))
}

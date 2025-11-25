package main

import (
	"encoding/json"
	"log"
	"math"
	"net/http"
	"runtime"
)

type CalcRequest struct {
	A int `json:"a"`
	B int `json:"b"`
}

type CalcResponse struct {
	Result float64 `json:"result"`
}

// Health check response
type HealthResponse struct {
	Status string `json:"status"`
}

// Handler para cálculo matemático
func calculateHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CalcRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Operação matemática: distância euclidiana
	result := math.Sqrt(float64(req.A*req.A + req.B*req.B))

	response := CalcResponse{Result: result}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Handler para health check
func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{Status: "ok"}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	// Configura o número de CPUs
	runtime.GOMAXPROCS(runtime.NumCPU())

	// Rotas
	http.HandleFunc("/calculate", calculateHandler)
	http.HandleFunc("/health", healthHandler)

	// Inicia o servidor
	log.Println("Go API running on :8000")
	log.Fatal(http.ListenAndServe(":8000", nil))
}

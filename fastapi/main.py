import math

from pydantic import BaseModel

from fastapi import FastAPI

app = FastAPI()


class CalcRequest(BaseModel):
    a: int
    b: int


class CalcResponse(BaseModel):
    result: float


class HealthResponse(BaseModel):
    status: str


@app.post("/calculate", response_model=CalcResponse)
async def calculate(request: CalcRequest):
    result = math.sqrt(request.a**2 + request.b**2)
    return CalcResponse(result=result)


@app.get("/health", response_model=HealthResponse)
async def health():
    """
    Health check endpoint
    """
    return HealthResponse(status="ok")

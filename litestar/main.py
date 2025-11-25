import math

from pydantic import BaseModel

from litestar import Litestar, get, post


# Request model
class CalcRequest(BaseModel):
    a: int
    b: int


# Response model
class CalcResponse(BaseModel):
    result: float


# Health response model
class HealthResponse(BaseModel):
    status: str


@post("/calculate", status_code=200)
async def calculate(data: CalcRequest) -> CalcResponse:
    """
    Calcula a distância euclidiana entre dois números
    """
    result = math.sqrt(data.a**2 + data.b**2)
    return CalcResponse(result=result)


@get("/health")
async def health() -> HealthResponse:
    """
    Health check endpoint
    """
    return HealthResponse(status="ok")


app = Litestar(route_handlers=[calculate, health])

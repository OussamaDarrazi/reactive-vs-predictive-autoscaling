from fastapi import FastAPI, Query
import hashlib
import binascii
import os
import time
import numpy as np

app = FastAPI()


# constants
CPU_ITERATIONS = int(os.getenv("CPU_ITERATIONS", "1000000"))
MEMORY_MB = int(os.getenv("MEMORY_MB", "100"))
MATRIX_SIZE = int(os.getenv("MATRIX_SIZE", "300"))

SALT = b"study_salt"



@app.get("/cpu")
def cpu(payload: str | None = Query(default=None), iterations: int = Query(default=CPU_ITERATIONS)):
    """"""
    message = payload or "default_payload"

    dk = hashlib.pbkdf2_hmac(
        "sha256",
        message.encode(),
        SALT,
        iterations
    )

    return {
        "hash": binascii.hexlify(dk).decode()
    }



@app.get("/memory")
def memory(size_mb: int = Query(default=MEMORY_MB)):
    """"""
    block = bytearray(size_mb * 1024 * 1024)

    # force allocation
    for i in range(0, len(block), 4096):
        block[i] = 1

    time.sleep(0.2)

    return {"allocated_mb": size_mb}



@app.get("/matmul")
def matmul(size: int = Query(default=MATRIX_SIZE)):
    """"""
    a = np.random.rand(size, size)
    b = np.random.rand(size, size)

    c = np.dot(a, b)

    return {
        "size": size,
        "checksum": float(np.sum(c))
    }
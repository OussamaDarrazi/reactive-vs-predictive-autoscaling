#!/bin/bash

export CPU_ITERATIONS=100000
export MEMORY_MB=1
export MATRIX_SIZE=1000

# prevent BLAS thread oversubscription
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

gunicorn main:app \
  -k uvicorn.workers.UvicornWorker \
  --workers 2 \
  --bind 0.0.0.0:8000
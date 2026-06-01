#!/bin/bash

export CPU_ITERATIONS=1000000
export MEMORY_MB=100
export MATRIX_SIZE=300

# prevent BLAS thread oversubscription
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

gunicorn main:app \
  -k uvicorn.workers.UvicornWorker \
  --workers 2 \
  --bind 0.0.0.0:8000
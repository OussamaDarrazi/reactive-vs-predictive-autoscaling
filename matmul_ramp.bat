for /L %%i in (1,1,30) do (
    locust -f .\loadtest\locustfile-matmul-ramp.py ^
        --host http://192.168.164.135 ^
        --csv .\loadtest\ramp\data\matmul\matmul%%i ^
        --csv-full-history ^
        -u 120 -r  0.2  -t 600 ^
        --headless ^
        --only-summary
)
for /L %%i in (1,1,10) do (
    locust -f .\loadtest\locustfile-memory-ramp.py ^
        --host http://192.168.164.135 ^
        --csv .\loadtest\ramp\data\memory\memory%%i ^
        --csv-full-history ^
        -u 1000 -r 1 -t 1000 ^
        --headless ^
        --only-summary
)
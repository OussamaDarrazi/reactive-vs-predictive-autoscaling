for /L %%i in (1,1,30) do (
    locust -f .\loadtest\locustfile-cpu-ramp.py ^
        --host http://192.168.164.135 ^
        --csv .\loadtest\ramp\data\cpu\cpu%%i ^
        --csv-full-history ^
        -u 60 -r 0.2 -t 300 ^
        --headless ^
        --only-summary
)
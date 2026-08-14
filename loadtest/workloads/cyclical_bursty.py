from .config import *
from locust import LoadTestShape
import math


class CyclicalBursty(LoadTestShape):

    MIN_RPS_MULTIPLIER = 0.5
    MAX_RPS_MULTIPLIER = 1.5

    BURST_DURATION = 5 * 60
    BURST_MULTIPLIER = 4.0

    def __init__(self):
        super().__init__()

        min_rps = self.MIN_RPS_MULTIPLIER * SATURATION_RPS
        max_rps = self.MAX_RPS_MULTIPLIER * SATURATION_RPS

        self.A = (min_rps + max_rps) / 2
        self.B = (max_rps - min_rps) / 2

    def tick(self):
        elapsed = self.get_run_time()

        if elapsed >= EXPERIMENT_DURATION:
            return None

        target_rps = self.get_target_rps(elapsed)

        return (
            self.rps_to_users(target_rps),
            self.spawn_rate,
        )

    @property
    def spawn_rate(self):
        return SPAWN_RATE

    @staticmethod
    def rps_to_users(target_rps):
        return max(1, math.ceil(target_rps))

    def get_target_rps(self, elapsed):

        cycle_time = elapsed % CYCLE_TIME

        if cycle_time >= CYCLE_TIME - self.BURST_DURATION:
            return self.BURST_MULTIPLIER * SATURATION_RPS

        return self.A + self.B * math.sin(
            2 * math.pi * elapsed / CYCLE_TIME
        )
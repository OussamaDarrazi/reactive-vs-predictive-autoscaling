from .config import *
from locust import LoadTestShape
import math


class CyclicalStable(LoadTestShape):

    MIN_RPS_MULTIPLIER = 0.75
    MAX_RPS_MULTIPLIER = 2.0

    def __init__(self):
        super().__init__()

        min_rps = self.MIN_RPS_MULTIPLIER * SATURATION_RPS
        max_rps = self.MAX_RPS_MULTIPLIER * SATURATION_RPS

        self.sine_offset = (min_rps + max_rps) / 2
        self.sine_amplitude = (max_rps - min_rps) / 2

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
        return self.sine_offset + self.sine_amplitude * math.sin(
            2 * math.pi * elapsed / CYCLE_TIME
        )
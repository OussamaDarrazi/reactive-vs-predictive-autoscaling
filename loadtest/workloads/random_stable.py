from .config import *
from locust import LoadTestShape
import math
import random


class RandomStable(LoadTestShape):

    MIN_RPS_MULTIPLIER = 0.8
    MAX_RPS_MULTIPLIER = 2.0

    def __init__(self):
        super().__init__()

        self.random = random.Random(42)

        self.min_rps = self.MIN_RPS_MULTIPLIER * SATURATION_RPS
        self.max_rps = self.MAX_RPS_MULTIPLIER * SATURATION_RPS

        self.current_level = self.min_rps
        self.level_start_time = 0

        # ~4.3-minute plateaus for a 30-minute cycle
        self.level_duration = CYCLE_TIME / 7

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
        """
        Converts target RPS into VUs.

        This assumes approximately one VU generates one RPS.
        """
        return max(1, math.ceil(target_rps))

    def get_target_rps(self, elapsed):
        """
        Selects a random workload level and keeps it constant
        for one plateau interval.
        """

        if elapsed - self.level_start_time >= self.level_duration:

            self.current_level = self.random.uniform(
                self.min_rps,
                self.max_rps,
            )

            self.level_start_time = elapsed

        return self.current_level
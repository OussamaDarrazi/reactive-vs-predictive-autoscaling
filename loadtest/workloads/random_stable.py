from .config import *
from locust import LoadTestShape    
import math
import random

class RandomStable(LoadTestShape):

    def __init__(self):
        super().__init__()

        self.random = random.Random(42)

        self.current_level = MIN_RPS
        self.level_start_time = 0

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
        Randomly selects one of the four workload levels.

        Once selected, the level is maintained for a full
        derived plateau duration before another level is chosen.
        """

        if elapsed - self.level_start_time >= self.level_duration:

            self.current_level = self.random.choice(
                LOAD_LEVELS
            )

            self.level_start_time = elapsed

        return self.current_level

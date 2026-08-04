# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src").resolve()))

from epedit import IDD, IDF

import time
import tracemalloc
import gc
import unittest


class TestParserPerformance(unittest.TestCase):
    def test_performance(self):
        repeat = 5

        memory_total = 0.0
        duration_idd_total = 0.0
        duration_idf_total = 0.0

        # 메모리 추적 시작
        tracemalloc.start()

        for _ in range(repeat):
            # 이전 반복에서 생성되었다가 버려진 파싱 객체들을 메모리에서 완전히 정리
            gc.collect()
            # 이번 1회 파싱 동안의 순수한 피크를 재기 위해 추적 기록을 초기화
            tracemalloc.clear_traces()

            # 1. IDD 파싱 시간 측정
            start_time = time.perf_counter()
            idd = IDD.from_file("./idds/V24-2-0-Energy+.idd")
            duration_idd_total += (time.perf_counter() - start_time)

            # 2. IDF 파싱 및 문자열 변환 시간 측정
            start_time = time.perf_counter()
            idf = IDF.from_file(idd, "/Applications/EnergyPlus-24-2-0/ExampleFiles/RefBldgOutPatientNew2004_Chicago.idf")
            _ = str(idf)
            duration_idf_total += (time.perf_counter() - start_time)

            # 3. 메모리 측정
            current_memory, peak_memory = tracemalloc.get_traced_memory()
            memory_total += (current_memory / 1024.0 / 1024.0)

        # 추적 종료
        tracemalloc.stop()

        # 결과 출력
        avg_memory = memory_total / repeat
        max_peak_memory = peak_memory / 1024.0 / 1024.0
        avg_duration_idd = duration_idd_total / repeat
        avg_duration_idf = duration_idf_total / repeat

        print(f"\nAverage Memory: {avg_memory:.2f} MB")
        print(f"Absolute Peak Memory: {max_peak_memory:.2f} MB")
        # 파이썬의 perf_counter는 초(second) 단위이므로 보기 좋게 출력합니다.
        print(f"Duration IDD: {avg_duration_idd:.6f} s")
        print(f"Duration IDF: {avg_duration_idf:.6f} s")

if __name__ == '__main__':
    unittest.main()

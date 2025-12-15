import argparse
import multiprocessing as mp
import time
import os
import sys
import math
import threading

def cpu_worker(stop_event):
    """Endlos rechenlastige Schleife, die periodisch prüft, ob gestoppt werden soll."""
    # leichte Variation pro Worker, damit Threads nicht exakt synchron laufen
    local_counter = 0
    last_report = time.time()
    while not stop_event.is_set():
        # CPU-Intensive Arbeit: berechne viele trigonometrische Operationen
        # (keine IO, nur CPU)
        x = 0.0
        for i in range(20000):
            # kleine FPU-Last
            x += math.sin(i) * math.cos(i**0.5)
        local_counter += 1
        # gelegentlich kurz schlafen, um die Last steuerbar zu machen
        if local_counter % 10 == 0:
            time.sleep(0.01)

def mem_alloc_worker(stop_event, mb):
    """Allokiert kurzzeitig einen Bytearray in der gegebenen Größe (MB)."""
    try:
        # Allokation in 10 MB Blöcken, prüft zwischendurch stop_event
        blocks = mb // 10
        remainder = mb % 10
        allocated = []
        for _ in range(blocks):
            if stop_event.is_set():
                return
            allocated.append(bytearray(10 * 1024 * 1024))
            time.sleep(0.1)
        if remainder and not stop_event.is_set():
            allocated.append(bytearray(remainder * 1024 * 1024))
        # Halte den Speicher bis Stop durch CTRL+C oder Killfile
        while True:
            if stop_event.is_set():
                break
            time.sleep(1)
        # Freigabe (allocated geht außer Scope)
    except MemoryError:
        print("MemoryError: nicht genug RAM verfügbar für gewünschte Allokation.")

def monitor_killfile(stop_event, killfile_path):
    """Überwacht das Vorhandensein einer Kill-Datei; wenn vorhanden -> stop_event setzen."""
    if not killfile_path:
        return
    while not stop_event.is_set():
        if os.path.exists(killfile_path):
            stop_event.set()
            break
        time.sleep(1)

def main():
    num_workers = 4
    mem_mb = 4000
    killfile = "C:\\Windows\\Temp\\KillMe.txt"
    stop_event = mp.Event()

    workers = []
    for i in range(num_workers):
        p = mp.Process(target=cpu_worker, args=(stop_event))
        p.start()
        workers.append(p)

    mem_thread = None
    mem_thread = threading.Thread(target=mem_alloc_worker, args=(stop_event, mem_mb), daemon=True)
    mem_thread.start()

    kill_monitor = threading.Thread(target=monitor_killfile, args=(stop_event, killfile), daemon=True)
    kill_monitor.start()

    try:
        while True:
            if stop_event.is_set():
                break
            time.sleep(0.5)
    except KeyboardInterrupt:
        stop_event.set()

    # Warte auf Prozesse
    for p in workers:
        p.join(timeout=5)
        if p.is_alive():
            p.terminate()
    if mem_thread:
        mem_thread.join(timeout=2)

if __name__ == "__main__":
    main()

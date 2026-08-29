import argparse
import csv
import statistics
import subprocess
from pathlib import Path


EXPECTED_CRC = {
    4096: 0xA2912082,
    65536: 0xB11DE6A1,
    1048576: 0x04D0E435,
}

EXPECTED_TOTAL_BYTES = 8 * 1024 * 1024


def make_command(binary: Path, qemu: str, cpu: str, native: bool) -> list[str]:
    if native:
        return [str(binary)]

    return [qemu, "-cpu", cpu, str(binary)]


def run_once(binary: Path, qemu: str, cpu: str, native: bool) -> dict[int, dict[str, int]]:
    command = make_command(binary, qemu, cpu, native)

    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"{binary.name} failed with exit code {result.returncode}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]

    if len(lines) != 3:
        raise RuntimeError(f"{binary.name}: expected 3 result lines, got {len(lines)}")

    parsed: dict[int, dict[str, int]] = {}

    for line in lines:
        fields = line.split()

        if len(fields) != 4:
            raise RuntimeError(f"{binary.name}: malformed benchmark line: {line!r}")

        size = int(fields[0], 16)
        iterations = int(fields[1], 16)
        elapsed_ns = int(fields[2], 16)
        crc = int(fields[3], 16)

        if size not in EXPECTED_CRC:
            raise RuntimeError(f"{binary.name}: unexpected buffer size {size}")

        if crc != EXPECTED_CRC[size]:
            raise RuntimeError(
                f"{binary.name}: CRC mismatch for {size} bytes: "
                f"expected {EXPECTED_CRC[size]:08X}, got {crc:08X}"
            )

        if elapsed_ns <= 0:
            raise RuntimeError(f"{binary.name}: invalid elapsed time {elapsed_ns}")

        total_bytes = size * iterations

        if total_bytes != EXPECTED_TOTAL_BYTES:
            raise RuntimeError(
                f"{binary.name}: expected {EXPECTED_TOTAL_BYTES} processed bytes, "
                f"got {total_bytes}"
            )

        parsed[size] = {
            "iterations": iterations,
            "elapsed_ns": elapsed_ns,
            "crc": crc,
        }

    return parsed


def size_label(size: int) -> str:
    if size == 4096:
        return "4 KiB"

    if size == 65536:
        return "64 KiB"

    if size == 1048576:
        return "1 MiB"

    return f"{size} B"


def main() -> None:
    parser = argparse.ArgumentParser()

    parser.add_argument("--bitwise", required=True)
    parser.add_argument("--table", required=True)
    parser.add_argument("--hardware", required=True)

    parser.add_argument("--qemu", default="qemu-aarch64")
    parser.add_argument("--cpu", default="max")
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--csv")

    args = parser.parse_args()

    if args.samples < 1:
        raise SystemExit("--samples must be at least 1")

    engines = {
        "bitwise": Path(args.bitwise).resolve(),
        "table": Path(args.table).resolve(),
        "hardware": Path(args.hardware).resolve(),
    }

    for binary in engines.values():
        if not binary.is_file():
            raise SystemExit(f"Binary not found: {binary}")

    measurements: dict[str, dict[int, list[int]]] = {
        engine: {size: [] for size in EXPECTED_CRC}
        for engine in engines
    }

    engine_names = list(engines)

    # Rotate execution order between samples to reduce systematic ordering bias.
    for sample_index in range(args.samples):
        shift = sample_index % len(engine_names)
        order = engine_names[shift:] + engine_names[:shift]

        for engine in order:
            rows = run_once(
                engines[engine],
                args.qemu,
                args.cpu,
                args.native,
            )

            for size, row in rows.items():
                measurements[engine][size].append(row["elapsed_ns"])

    mode = "native AArch64" if args.native else f"QEMU user-mode ({args.cpu})"

    print(f"Mode       : {mode}")
    print(f"Samples    : {args.samples}")
    print("Per case   : 8.00 MiB processed")
    print()

    header = (
        f"{'Buffer':<10}"
        f"{'Engine':<12}"
        f"{'Median ms':>12}"
        f"{'Min ms':>12}"
        f"{'Max ms':>12}"
        f"{'MiB/s':>12}"
        f"{'vs bitwise':>12}"
    )

    print(header)
    print("-" * len(header))

    csv_rows = []

    for size in sorted(EXPECTED_CRC):
        bitwise_median = statistics.median(measurements["bitwise"][size])

        for engine in engine_names:
            values = measurements[engine][size]

            median_ns = statistics.median(values)
            min_ns = min(values)
            max_ns = max(values)

            seconds = median_ns / 1_000_000_000
            throughput = 8.0 / seconds

            relative = bitwise_median / median_ns

            print(
                f"{size_label(size):<10}"
                f"{engine:<12}"
                f"{median_ns / 1_000_000:>12.3f}"
                f"{min_ns / 1_000_000:>12.3f}"
                f"{max_ns / 1_000_000:>12.3f}"
                f"{throughput:>12.2f}"
                f"{relative:>11.2f}x"
            )

            csv_rows.append(
                {
                    "buffer_size": size,
                    "engine": engine,
                    "samples": args.samples,
                    "median_ns": int(median_ns),
                    "min_ns": min_ns,
                    "max_ns": max_ns,
                    "mib_per_second": throughput,
                    "relative_to_bitwise": relative,
                    "mode": mode,
                }
            )

        print()

    if args.csv:
        output = Path(args.csv)
        output.parent.mkdir(parents=True, exist_ok=True)

        with output.open("w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=csv_rows[0].keys())
            writer.writeheader()
            writer.writerows(csv_rows)

        print(f"CSV written to: {output}")


if __name__ == "__main__":
    main()
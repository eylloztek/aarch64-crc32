import argparse
import subprocess
import tempfile
import zlib
from pathlib import Path


def run_program(qemu: str, cpu: str | None, binary: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    command = [qemu]

    if cpu:
        command.extend(["-cpu", cpu])

    command.append(str(binary))
    command.extend(args)

    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )


def check_file_case(qemu: str, cpu: str | None, binary: Path, root: Path, label: str, name: str, filename: str, payload: bytes) -> None:
    path = root / filename
    path.write_bytes(payload)

    expected = f"{zlib.crc32(payload) & 0xFFFFFFFF:08X}\n"
    result = run_program(qemu, cpu, binary, [str(path)])

    if result.returncode != 0:
        raise AssertionError(f"{name}: expected exit code 0, got {result.returncode}")

    if result.stdout != expected:
        raise AssertionError(f"{name}: expected stdout {expected!r}, got {result.stdout!r}")

    if result.stderr:
        raise AssertionError(f"{name}: unexpected stderr {result.stderr!r}")

    print(f"[PASS] {label}: {name}: {expected.strip()}")


def check_error_case(qemu: str, cpu: str | None, binary: Path, label: str, name: str, args: list[str], expected_code: int, expected_stderr: str) -> None:
    result = run_program(qemu, cpu, binary, args)

    if result.returncode != expected_code:
        raise AssertionError(f"{name}: expected exit code {expected_code}, got {result.returncode}")

    if result.stdout:
        raise AssertionError(f"{name}: unexpected stdout {result.stdout!r}")

    if result.stderr != expected_stderr:
        raise AssertionError(f"{name}: expected stderr {expected_stderr!r}, got {result.stderr!r}")

    print(f"[PASS] {label}: {name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--qemu", default="qemu-aarch64")
    parser.add_argument("--cpu")
    parser.add_argument("--label", default="crc32")
    args = parser.parse_args()

    binary = Path(args.binary).resolve()

    if not binary.is_file():
        raise SystemExit(f"Binary not found: {binary}")

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)

        check_file_case(args.qemu, args.cpu, binary, root, args.label, "empty file", "empty.bin", b"")
        check_file_case(args.qemu, args.cpu, binary, root, args.label, "standard CRC vector", "standard.txt", b"123456789")
        check_file_case(args.qemu, args.cpu, binary, root, args.label, "small text file", "hello.txt", b"hello")
        check_file_case(args.qemu, args.cpu, binary, root, args.label, "binary file", "binary data.bin", bytes([0x00, 0x01, 0x7F, 0x80, 0xFF]))
        check_file_case(args.qemu, args.cpu, binary, root, args.label, "all byte values", "all-bytes.bin", bytes(range(256)))
        check_file_case(args.qemu, args.cpu, binary, root, args.label, "exact 4096-byte file", "exact-4096.bin", bytes(range(256)) * 16)

        large_payload = bytes((i * 37 + 11) & 0xFF for i in range(10000))
        check_file_case(args.qemu, args.cpu, binary, root, args.label, "multi-read 10000-byte file", "large-10000.bin", large_payload)

        check_error_case(
            args.qemu,
            args.cpu,
            binary,
            args.label,
            "missing argument",
            [],
            1,
            "Usage: aarch64-crc32 <file>\n",
        )

        check_error_case(
            args.qemu,
            args.cpu,
            binary,
            args.label,
            "nonexistent file",
            [str(root / "does-not-exist.bin")],
            2,
            "[ERROR] could not open file\n",
        )

        check_error_case(
            args.qemu,
            args.cpu,
            binary,
            args.label,
            "directory read",
            [str(root)],
            3,
            "[ERROR] could not read file\n",
        )

    print(f"[PASS] {args.label} file CRC32 integration tests passed (10/10)")


if __name__ == "__main__":
    main()
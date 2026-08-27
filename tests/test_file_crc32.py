import argparse
import subprocess
import tempfile
import zlib
from pathlib import Path


def run_program(qemu: str, binary: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [qemu, str(binary), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def check_file_case(qemu: str, binary: Path, root: Path, name: str, filename: str, payload: bytes) -> None:
    path = root / filename
    path.write_bytes(payload)

    expected = f"{zlib.crc32(payload) & 0xFFFFFFFF:08X}\n"
    result = run_program(qemu, binary, str(path))

    if result.returncode != 0:
        raise AssertionError(f"{name}: expected exit code 0, got {result.returncode}")

    if result.stdout != expected:
        raise AssertionError(f"{name}: expected stdout {expected!r}, got {result.stdout!r}")

    if result.stderr:
        raise AssertionError(f"{name}: unexpected stderr {result.stderr!r}")

    print(f"[PASS] {name}: {expected.strip()}")


def check_error_case(qemu: str, binary: Path, name: str, args: list[str], expected_code: int, expected_stderr: str) -> None:
    result = run_program(qemu, binary, *args)

    if result.returncode != expected_code:
        raise AssertionError(f"{name}: expected exit code {expected_code}, got {result.returncode}")

    if result.stdout:
        raise AssertionError(f"{name}: unexpected stdout {result.stdout!r}")

    if result.stderr != expected_stderr:
        raise AssertionError(f"{name}: expected stderr {expected_stderr!r}, got {result.stderr!r}")

    print(f"[PASS] {name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--qemu", default="qemu-aarch64")
    args = parser.parse_args()

    binary = Path(args.binary).resolve()

    if not binary.is_file():
        raise SystemExit(f"Binary not found: {binary}")

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)

        check_file_case(args.qemu, binary, root, "empty file", "empty.bin", b"")
        check_file_case(args.qemu, binary, root, "standard CRC vector", "standard.txt", b"123456789")
        check_file_case(args.qemu, binary, root, "small text file", "hello.txt", b"hello")
        check_file_case(args.qemu, binary, root, "binary file", "binary data.bin", bytes([0x00, 0x01, 0x7F, 0x80, 0xFF]))
        check_file_case(args.qemu, binary, root, "exact 4096-byte file", "exact-4096.bin", bytes(range(256)) * 16)

        large_payload = bytes((i * 37 + 11) & 0xFF for i in range(10000))
        check_file_case(args.qemu, binary, root, "multi-read 10000-byte file", "large-10000.bin", large_payload)

        check_error_case(
            args.qemu,
            binary,
            "missing argument",
            [],
            1,
            "Usage: aarch64-crc32 <file>\n",
        )

        check_error_case(
            args.qemu,
            binary,
            "nonexistent file",
            [str(root / "does-not-exist.bin")],
            2,
            "[ERROR] could not open file\n",
        )

        check_error_case(
            args.qemu,
            binary,
            "directory read",
            [str(root)],
            3,
            "[ERROR] could not read file\n",
        )
        
        check_file_case(
            args.qemu,
            binary,
            root,
            "all byte values",
            "all-bytes.bin",
            bytes(range(256)),
        )

    print("[PASS] File CRC32 integration tests passed (10/10)")


if __name__ == "__main__":
    main()
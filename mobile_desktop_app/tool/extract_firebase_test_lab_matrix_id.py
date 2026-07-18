#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print(
            "usage: extract_firebase_test_lab_matrix_id.py SUBMISSION_JSON",
            file=sys.stderr,
        )
        return 2
    with Path(sys.argv[1]).open(encoding="utf-8") as source:
        response = json.load(source)
    matrix_id = response.get("testMatrixId") if isinstance(response, dict) else None
    if not isinstance(matrix_id, str) or re.fullmatch(
        r"matrix-[a-z0-9]+", matrix_id
    ) is None:
        print("gcloud did not return a valid Test Lab matrix ID", file=sys.stderr)
        return 1
    print(matrix_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

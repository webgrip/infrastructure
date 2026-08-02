#!/usr/bin/env python3
"""Prove a seccomp profile denies what it claims and allows what the workload needs.

This exists because the cve-gate profile shipped a clone() rule that did the exact opposite of
its own comment, and nothing caught it until the container failed to start in CI — on the first
occasion the gate ever really executed, three releases after the profile was written.

The bug was a semantic inversion, not a typo. SCMP_CMP_MASKED_EQ tests (arg & value) == valueTwo.
Docker's default profile ALLOWS clone when (flags & <all CLONE_NEW* bits>) == 0. That rule was
copied across with the action changed to SCMP_ACT_ERRNO, which flips its meaning: it denied every
clone creating NO namespace (i.e. every ordinary thread) and permitted every clone that did. A
profile cannot be read for correctness by eye — the same six fields mean opposite things depending
on the action attached to them. So it gets evaluated instead.

Run against the profile the container is actually given, in the same step that gives it.
"""

import json
import sys

# linux/sched.h
CLONE_NEW = {
    "CLONE_NEWNS": 0x00020000,
    "CLONE_NEWCGROUP": 0x02000000,
    "CLONE_NEWUTS": 0x04000000,
    "CLONE_NEWIPC": 0x08000000,
    "CLONE_NEWUSER": 0x10000000,
    "CLONE_NEWPID": 0x20000000,
    "CLONE_NEWNET": 0x40000000,
}

# The flags a Go runtime uses for an ordinary OS thread (runtime/os_linux.go newosproc).
GO_THREAD_FLAGS = (
    0x00000100  # CLONE_VM
    | 0x00000200  # CLONE_FS
    | 0x00000400  # CLONE_FILES
    | 0x00000800  # CLONE_SIGHAND
    | 0x00010000  # CLONE_THREAD
    | 0x00080000  # CLONE_SETTLS
    | 0x00100000  # CLONE_PARENT_SETTID
    | 0x00200000  # CLONE_CHILD_CLEARTID
)

# Syscalls the profile must deny outright, whatever else it does.
MUST_DENY = [
    "mount", "umount2", "pivot_root", "setns", "unshare", "ptrace", "bpf",
    "perf_event_open", "init_module", "finit_module", "delete_module", "keyctl",
    "io_uring_setup", "io_uring_enter", "io_uring_register", "reboot",
]


def arg_matches(spec, value):
    """Evaluate one OCI seccomp arg comparison against a concrete syscall argument."""
    op, v, v2 = spec["op"], spec["value"], spec.get("valueTwo", 0)
    if op == "SCMP_CMP_MASKED_EQ":
        return (value & v) == v2
    if op == "SCMP_CMP_EQ":
        return value == v
    if op == "SCMP_CMP_NE":
        return value != v
    if op == "SCMP_CMP_LT":
        return value < v
    if op == "SCMP_CMP_LE":
        return value <= v
    if op == "SCMP_CMP_GT":
        return value > v
    if op == "SCMP_CMP_GE":
        return value >= v
    raise ValueError(f"unhandled seccomp op {op}")


def resolve(profile, syscall, args=()):
    """The action the kernel would take for this syscall with these arguments.

    Rules are scanned in order; the first whose name and every arg comparison match wins.
    Multiple args within one rule are ANDed — which is why 'any of these bits' needs one rule
    per bit and cannot be folded into a single entry.
    """
    for rule in profile.get("syscalls", []):
        if syscall not in rule.get("names", []):
            continue
        specs = rule.get("args") or []
        if all(arg_matches(s, args[s["index"]] if s["index"] < len(args) else 0) for s in specs):
            return rule["action"]
    return profile["defaultAction"]


def main(path):
    with open(path) as fh:
        profile = json.load(fh)

    failures, checks = [], 0

    def check(desc, got, want):
        nonlocal checks
        checks += 1
        if got != want:
            failures.append(f"{desc}\n      expected {want}, got {got}")

    # The regression that took down run 224: a Go program must be able to start a thread.
    check(
        "clone() for an ordinary Go thread must be permitted",
        resolve(profile, "clone", (GO_THREAD_FLAGS,)),
        "SCMP_ACT_ALLOW",
    )

    # ...and the thing the block is actually for must still be denied, one flag at a time and
    # in combination with the ordinary thread flags (how a real escape attempt would look).
    for name, bit in CLONE_NEW.items():
        check(f"clone({name}) must be denied", resolve(profile, "clone", (bit,)), "SCMP_ACT_ERRNO")
        check(
            f"clone(GO_THREAD_FLAGS|{name}) must be denied",
            resolve(profile, "clone", (GO_THREAD_FLAGS | bit,)),
            "SCMP_ACT_ERRNO",
        )

    for name in MUST_DENY:
        check(f"{name}() must be denied", resolve(profile, name), "SCMP_ACT_ERRNO")

    if failures:
        print(f"seccomp profile {path} FAILED {len(failures)}/{checks} checks:", file=sys.stderr)
        for f in failures:
            print(f"  ✗ {f}", file=sys.stderr)
        return 1

    print(f"seccomp profile {path}: {checks}/{checks} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "ops/security/seccomp/cve-gate.json"))

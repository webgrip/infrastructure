#!/usr/bin/env python3
import hashlib
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ARG_LINE = re.compile(r'^ARG (?P<name>[A-Z0-9_]+)=(?P<quote>"?)(?P<value>[^"\s]*)(?P=quote)\s*$')
CHANGED_VERSION = re.compile(r'^\+ARG (?P<prefix>[A-Z0-9_]+)_VERSION=')
URL = re.compile(r'https?://[^\s"\']+')
REFERENCE = re.compile(r'\$\{(\w+)\}|\$(\w+)')


def changed_version_prefixes(dockerfile, base):
    diff = subprocess.run(
        ['git', 'diff', '--unified=0', base, '--', str(dockerfile)],
        check=True, capture_output=True, text=True,
    ).stdout
    return {match['prefix'] for line in diff.splitlines() if (match := CHANGED_VERSION.match(line))}


def changed_dockerfiles(base):
    names = subprocess.run(
        ['git', 'diff', '--name-only', base, '--', 'ops/docker/*/Dockerfile'],
        check=True, capture_output=True, text=True,
    ).stdout
    return [Path(name) for name in names.split()]


def instructions(lines):
    joined, current = [], ''
    for line in lines:
        current += line.rstrip('\n').rstrip('\\') + ' '
        if not line.rstrip('\n').endswith('\\'):
            joined.append(current)
            current = ''
    return joined


def arg_values(lines):
    return {match['name']: match['value'] for line in lines if (match := ARG_LINE.match(line.strip()))}


def expand(text, values):
    return REFERENCE.sub(lambda match: values.get(match[1] or match[2], match[0]), text)


def download_url(checksum_name, version_name, lines, values):
    for instruction in instructions(lines):
        if instruction.startswith('ARG ') or f'${{{checksum_name}}}' not in instruction:
            continue
        for url in URL.findall(instruction):
            if version_name in url:
                return expand(url, values)
    raise SystemExit(f'no download URL uses ${{{version_name}}} next to ${{{checksum_name}}}')


def sha256_of(url):
    digest = hashlib.sha256()
    with urllib.request.urlopen(url, timeout=120) as response:
        while chunk := response.read(1 << 20):
            digest.update(chunk)
    return digest.hexdigest()


def update(dockerfile, prefixes):
    lines = dockerfile.read_text().splitlines(keepends=True)
    values = arg_values(lines)
    checksum_names = re.compile(rf'^({"|".join(map(re.escape, prefixes))})_SHA256(_[A-Z0-9]+)?$')
    for index, line in enumerate(lines):
        match = ARG_LINE.match(line.strip())
        if not match or not (owner := checksum_names.match(match['name'])):
            continue
        url = download_url(match['name'], f'{owner[1]}_VERSION', lines, values)
        checksum = sha256_of(url)
        if checksum != match['value']:
            lines[index] = line.replace(match['value'], checksum)
            print(f'{dockerfile}: {match["name"]} {checksum} ({url})')
    dockerfile.write_text(''.join(lines))


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
    for dockerfile in changed_dockerfiles(base):
        if prefixes := changed_version_prefixes(dockerfile, base):
            update(dockerfile, prefixes)


if __name__ == '__main__':
    main()

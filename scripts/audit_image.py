"""Inspect every saved Docker layer, including files hidden by later layers.

A bounded credential-pattern/context-canary check, not a proof against all secrets.
The stronger boundary is an explicit context allowlist and no build credentials.
"""
import argparse
import json
from pathlib import PurePosixPath
import re
import tarfile

PATTERNS = [rb'BUILD_CONTEXT_EXCLUSION_CANARY', rb'-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/=\r\n]{64,}',
            rb'github_pat_[A-Za-z0-9_]{40,}', rb'gh[pousr]_[A-Za-z0-9]{30,}']


def check_member(name, data):
    path = PurePosixPath(name)
    if path.name.startswith('.env') or ('.ssh' in path.parts and path.name in {'authorized_keys', 'id_rsa', 'id_ed25519'}):
        raise ValueError(f'Forbidden credential path in image: {name}')
    if any(re.search(pattern, data) for pattern in PATTERNS):
        # Never print the matching content.
        raise ValueError(f'Credential/canary pattern found in image member: {name}')


def audit(archive):
    files = 0
    with tarfile.open(archive, 'r:*') as outer:
        manifests = json.load(outer.extractfile('manifest.json'))
        if len(manifests) != 1:
            raise ValueError('Exactly one candidate image required')
        for config in [manifests[0]['Config']]:
            check_member(config, outer.extractfile(config).read())
        layers = manifests[0]['Layers']
        if not isinstance(layers, list) or not layers:
            raise ValueError('Image must contain at least one layer')
        for layer in layers:
            with outer.extractfile(layer) as stream, tarfile.open(fileobj=stream, mode='r|*') as contents:
                for member in contents:
                    check_member(member.name, b'')
                    if not member.isfile():
                        continue
                    files += 1
                    with contents.extractfile(member) as source:
                        carry = b''
                        while chunk := source.read(1024 * 1024):
                            check_member(member.name, carry + chunk)
                            carry = chunk[-16384:]
    return {'layers_scanned': len(layers), 'files_scanned': files, 'credential_patterns_found': 0,
            'scope': 'context canary and listed credential patterns; not general vulnerability scanning'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('archive')
    args = parser.parse_args()
    print(json.dumps(audit(args.archive)))

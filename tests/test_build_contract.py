import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BuildContractTests(unittest.TestCase):
    def test_base_is_amd64_digest_pinned(self):
        lock = json.loads((ROOT / 'image/runtime-lock.json').read_text())
        self.assertRegex(lock['base'], r'^nvidia/cuda@sha256:[a-f0-9]{64}$')
        self.assertEqual(lock['platform'], 'linux/amd64')
        self.assertEqual(lock['python']['version'], '3.14.7')

    def test_dockerfile_matches_lock(self):
        lock = json.loads((ROOT / 'image/runtime-lock.json').read_text())
        dockerfile = (ROOT / 'image/Dockerfile').read_text()
        self.assertIn('FROM ' + lock['base'], dockerfile)
        self.assertIn(lock['python']['url'], dockerfile)
        self.assertIn(lock['python']['sha256'], dockerfile)
        self.assertNotIn('CUDA_CACHE_DISABLE=1', dockerfile)
        self.assertFalse(lock['rebuild_bit_identical'])

    def test_image_does_not_break_vast_ssh_bootstrap(self):
        """Incident 2026-09-28: deleting the SSH host keys made Vast's `sshd` start
        fail ("no hostkeys available -- exiting") and its port-forward never
        recovered, so readiness polling saw `connection refused` for the whole
        window. A stock Ubuntu + openssh-server install ships host keys; the image
        must not deviate from that."""
        dockerfile = (ROOT / 'image/Dockerfile').read_text()
        for forbidden in ('rm -f /etc/ssh/ssh_host', 'rm -rf /etc/ssh/ssh_host',
                          'ssh-keygen -R', 'PasswordAuthentication yes'):
            self.assertNotIn(forbidden, dockerfile)
        self.assertIn('openssh-server', dockerfile)
        self.assertIn('mkdir -p /run/sshd', dockerfile)
        # The platform starts sshd from the image at container start and does not
        # generate host keys at runtime, so they must exist in the image.
        self.assertIn('ssh-keygen -A', dockerfile)
        # ...and the audit must tolerate exactly those host key paths, no more.
        audit = (ROOT / 'scripts/audit_image.py').read_text()
        self.assertIn("'etc/ssh/ssh_host_rsa_key',", audit)
        self.assertIn('SSH_HOST_KEY_PATHS', audit)
        # Host keys must exist at build time. `ssh-keygen -A` is the safe
        # "generate every missing host-key type" command; a bare delete leaves
        # the image keyless and Vast's sshd then exits on first start.
        # The platform starts sshd from the image at container start and does not
        # generate host keys at runtime, so the image must ship them.
        self.assertIn('ssh-keygen -A', dockerfile)
        self.assertNotIn('/etc/init.d/ssh', dockerfile)
        audit = (ROOT / 'scripts/audit_image.py').read_text()
        self.assertIn('SSH_HOST_KEY_PATHS', audit)

    def test_requirements_match_locked_hashes(self):
        lock = json.loads((ROOT / 'image/runtime-lock.json').read_text())
        lines = (ROOT / 'image/requirements.lock').read_text().splitlines()
        self.assertEqual(len(lines), len(lock['wheels']))
        for wheel in lock['wheels']:
            self.assertIn(f"{wheel['name']}=={wheel['version']} --hash=sha256:{wheel['sha256']}", lines)

    def test_build_context_is_allowlisted(self):
        ignore = (ROOT / 'image/.dockerignore').read_text().splitlines()
        self.assertEqual(ignore[0], '**')
        self.assertEqual(set(ignore[1:]), {'!Dockerfile', '!runtime-lock.json', '!requirements.lock', '!verify_runtime.py', '!THIRD_PARTY_NOTICES.md'})
        dockerfile = (ROOT / 'image/Dockerfile').read_text()
        self.assertNotIn('COPY . ', dockerfile)
        self.assertNotIn('COPY ..', dockerfile)
        self.assertIn('pip check', dockerfile)
        self.assertIn('verify_runtime.py --mode cpu', dockerfile)

    def test_publication_requires_terms_and_follows_security_checks(self):
        workflow=(ROOT/'.github/workflows/build.yml').read_text()
        self.assertIn('accept_redistribution_terms:', workflow)
        self.assertIn('packages: write', workflow)
        self.assertLess(workflow.index('scripts/check_security.py'), workflow.index('docker push'))
        self.assertIn('docker --config "$anonymous" manifest inspect', workflow)
        self.assertIn('candidate-${GITHUB_SHA}-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}', workflow)

    def test_workflow_does_not_publish_by_default(self):
        workflow = (ROOT / '.github/workflows/build.yml').read_text()
        self.assertIn('workflow_dispatch:', workflow)
        self.assertIn('default: false', workflow)
        self.assertIn('if: inputs.publish', workflow)
        self.assertIn('docker build --pull', workflow)
        self.assertIn(' image', workflow)
        self.assertNotIn('pull_request_target', workflow)


if __name__ == '__main__':
    unittest.main()

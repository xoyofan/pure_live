"""Narrow public-fixture exception; ordinary secret scanning stays strict.

The TLS fixture files were removed from the repository, so the exemption
semantics are exercised through a synthetic whitelist entry injected into the
audit module instead of on-disk fixture files.
"""
import hashlib
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("repository_audit", ROOT / "tool/audit_repository.py")
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)

FIXTURE = "test/fixtures/tls/example-key.pem"
# The PEM markers are concatenated at runtime so this test source does not
# itself contain a private-key literal for the audit it exercises.
_PRIVATE_KEY_MARK = "-----BEGIN " + "PRIVATE KEY" + "-----"
_FIXTURE_BODY = (
    "MII" + "EvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKj"
    "MzEfYyjiWA4R4/M2bS1GB4t7NXp98C3SC6dVMvDuictGeurT8jNbvJZHtCSuYEvu"
)
FIXTURE_BYTES = "\n".join([_PRIVATE_KEY_MARK, _FIXTURE_BODY, "-----END " + "PRIVATE KEY" + "-----", ""]).encode("utf-8")
FIXTURE_SHA256 = hashlib.sha256(FIXTURE_BYTES).hexdigest()


class RepositorySecretAuditTest(unittest.TestCase):
    def setUp(self):
        self._original = dict(audit.PUBLIC_TLS_TEST_KEYS)
        audit.PUBLIC_TLS_TEST_KEYS[FIXTURE] = FIXTURE_SHA256

    def tearDown(self):
        audit.PUBLIC_TLS_TEST_KEYS.clear()
        audit.PUBLIC_TLS_TEST_KEYS.update(self._original)

    def scan(self, path, data):
        return audit.secret_findings(path, data.decode("utf-8"), hashlib.sha256(data).hexdigest())

    def test_exact_reviewed_fixture_is_reported_but_not_a_secret_failure(self):
        errors, notes = self.scan(FIXTURE, FIXTURE_BYTES)
        self.assertEqual(errors, [])
        self.assertEqual(len(notes), 1)
        self.assertEqual(notes[0]["rule"], "reviewed_public_tls_test_key")

    def test_same_public_key_outside_the_exact_path_is_rejected(self):
        for path in ("android/key.pem", "test/fixtures/tls/other-key.pem", "test/another/key.pem"):
            with self.subTest(path=path):
                errors, notes = self.scan(path, FIXTURE_BYTES)
                self.assertEqual(errors[0]["rule"], "private_key")
                self.assertEqual(notes, [])

    def test_modified_or_replaced_key_at_fixture_path_is_rejected(self):
        for changed in (FIXTURE_BYTES + b"\n", FIXTURE_BYTES.replace(b"\n", b"\r\n"), FIXTURE_BYTES.replace(b"M", b"N", 1)):
            with self.subTest(size=len(changed)):
                errors, notes = self.scan(FIXTURE, changed)
                self.assertEqual(errors[0]["rule"], "private_key")
                self.assertEqual(notes, [])

    def test_missing_digest_never_exempts_a_fixture(self):
        errors, notes = audit.secret_findings(FIXTURE, FIXTURE_BYTES.decode("utf-8"), None)
        self.assertEqual(errors[0]["rule"], "private_key")
        self.assertEqual(notes, [])

    def test_appending_a_token_triggers_both_rules(self):
        data = FIXTURE_BYTES + ("ghp_" + "A" * 30).encode()
        errors, notes = self.scan(FIXTURE, data)
        self.assertEqual({e["rule"] for e in errors}, {"private_key", "github_token"})
        self.assertEqual(notes, [])

    def test_other_secret_types_are_never_exempted_even_with_a_matching_digest(self):
        for token, rule in (("ghp_" + "A" * 30, "github_token"), ("AKIA" + "A" * 16, "aws_access_key")):
            errors, notes = audit.secret_findings(FIXTURE, token, FIXTURE_SHA256)
            self.assertEqual(errors[0]["rule"], rule)
            self.assertEqual(notes, [])


if __name__ == "__main__":
    unittest.main()

"""Release の送信ゲートを、SDK の起動や実キーなしで検査します。"""
import os
from pathlib import Path
import subprocess
import unittest


GUARD = Path(__file__).with_name("check_revenuecat_release.sh")


class RevenueCatReleaseGuardTests(unittest.TestCase):
    def run_guard(self, **overrides):
        # 形式の検査専用です。SDK を呼ばず、接続成功の代用にはしません。
        values = {
            "CONFIGURATION": "Release",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.atani.inkwell",
            "REVENUECAT_MODE": "observer",
            "REVENUECAT_PUBLIC_SDK_KEY": "appl_UnitTestFormatOnly12345",
            "REVENUECAT_DATA_SHARING_APPROVED": "YES",
            "REVENUECAT_INTEGRATION_READY": "YES",
            "REVENUECAT_PRIVACY_READY": "YES",
            "REVENUECAT_RELEASE_ENABLED": "YES",
        }
        values.update(overrides)
        environment = {k: v for k, v in os.environ.items() if not k.startswith("REVENUECAT_")}
        return subprocess.run(["/bin/sh", str(GUARD)], env=environment | values,
                              capture_output=True, text=True, check=False)

    def test_disabled_shipping_configuration_passes(self):
        result = self.run_guard(REVENUECAT_MODE="disabled", REVENUECAT_PUBLIC_SDK_KEY="")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_complete_observer_configuration_passes_without_printing_values(self):
        result = self.run_guard()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout + result.stderr, "")

    def test_each_readiness_gate_blocks_release(self):
        for gate in ["DATA_SHARING_APPROVED", "INTEGRATION_READY", "PRIVACY_READY", "RELEASE_ENABLED"]:
            for closed_value in ["", "NO", "true", "$(UNRESOLVED)"]:
                with self.subTest(gate=gate, value=closed_value):
                    result = self.run_guard(**{"REVENUECAT_" + gate: closed_value})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn("appl_", result.stdout + result.stderr)

    def test_wrong_bundle_unknown_mode_and_disabled_key_fail(self):
        for values in [{"PRODUCT_BUNDLE_IDENTIFIER": "com.atani.inkwell.widget"},
                       {"REVENUECAT_MODE": "Observer"}, {"REVENUECAT_MODE": ""},
                       {"REVENUECAT_MODE": "disabled"}]:
            with self.subTest(values=values):
                self.assertNotEqual(self.run_guard(**values).returncode, 0)

    def test_private_test_placeholder_unresolved_and_malformed_keys_fail_without_exposure(self):
        for key in ["", "sk_secretFixture", "test_StoreFixture", "$(KEY)",
                    "appl_yourKey12345", "appl_EXAMPLE12345", "appl_placeholder12345",
                    "appl_replace12345", "appl_short", "appl_bad key12345", "appl_bad$key12345"]:
            with self.subTest(kind="invalid public key"):
                result = self.run_guard(REVENUECAT_PUBLIC_SDK_KEY=key)
                self.assertNotEqual(result.returncode, 0)
                if key:
                    self.assertNotIn(key, result.stdout + result.stderr)

    def test_debug_build_is_handled_by_runtime_gates(self):
        result = self.run_guard(CONFIGURATION="Debug", REVENUECAT_PRIVACY_READY="NO")
        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()

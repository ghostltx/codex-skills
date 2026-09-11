import importlib.util
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"


def load_module(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS_DIR / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class GPTImage25SubmitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.image_gen = load_module("rh100_image_gen")
        cls.i2i = load_module("rh100_i2i")
        cls.batch = load_module("rh100_i2i_batch")

    def run_image_gen(self, argv, response=None):
        captured = {}

        def fake_post(url, payload):
            captured["url"] = url
            captured["payload"] = payload
            return response or {"taskId": "task-123", "status": "QUEUED"}

        with patch.object(self.image_gen, "json_post", side_effect=fake_post), patch.object(
            sys, "argv", ["rh100_image_gen.py", *argv, "--no-open"]
        ):
            self.image_gen.main()
        return captured

    def test_text_to_image_uses_sunburst_endpoint_and_defaults(self):
        captured = self.run_image_gen(["--prompt", "产品摄影"])
        self.assertEqual(captured["url"], self.image_gen.T2I_URL)
        self.assertEqual(
            captured["payload"],
            {
                "prompt": "产品摄影",
                "aspectRatio": "1:1",
                "resolution": "2k",
                "background": "auto",
                "quality": "high",
                "outputFormat": "png",
            },
        )
        self.assertIn("rhart-image-g-2.5-official-token/sunburst", captured["url"])

    def test_precision_edit_accepts_sixteen_references_and_forwards_new_fields(self):
        argv = ["--prompt", "替换背景", "--background", "transparent", "--quality", "max", "--output-format", "webp"]
        for number in range(16):
            argv.extend(["--image-url", f"https://example.com/{number}.png"])
        captured = self.run_image_gen(argv)
        self.assertEqual(captured["url"], self.image_gen.EDIT_URLS["precision"])
        self.assertEqual(len(captured["payload"]["imageUrls"]), 16)
        self.assertEqual(captured["payload"]["background"], "transparent")
        self.assertEqual(captured["payload"]["quality"], "max")
        self.assertEqual(captured["payload"]["outputFormat"], "webp")
        self.assertNotIn("instanceType", captured["payload"])

    def test_fast_edit_routes_to_flare(self):
        captured = self.run_image_gen(
            [
                "--prompt",
                "快速替换背景",
                "--image-url",
                "https://example.com/source.png",
                "--edit-mode",
                "fast",
            ]
        )
        self.assertEqual(captured["url"], self.image_gen.EDIT_URLS["fast"])
        self.assertIn("/flare/edit", captured["url"])

    def test_edit_rejects_seventeen_references(self):
        argv = ["rh100_image_gen.py", "--prompt", "替换背景", "--no-open"]
        for number in range(17):
            argv.extend(["--image-url", f"https://example.com/{number}.png"])
        with patch.object(sys, "argv", argv), self.assertRaisesRegex(
            SystemExit, "at most 16 images"
        ):
            self.image_gen.main()

    def test_standalone_edit_uses_same_payload_contract(self):
        captured = {}

        def fake_post(url, payload):
            captured["url"] = url
            captured["payload"] = payload
            return {"taskId": "task-456"}

        with patch.object(self.i2i, "json_post", side_effect=fake_post):
            self.i2i.submit_task(
                image_urls=["https://example.com/source.png"],
                prompt="编辑产品",
                aspect_ratio="16:9",
                resolution="4k",
                background="opaque",
                quality="xhigh",
                output_format="jpeg",
            )
        self.assertEqual(captured["url"], self.i2i.EDIT_URLS["precision"])
        self.assertEqual(captured["payload"]["outputFormat"], "jpeg")
        self.assertEqual(captured["payload"]["quality"], "xhigh")
        self.assertNotIn("instanceType", captured["payload"])

    def test_standalone_edit_rejects_more_than_sixteen_references(self):
        with self.assertRaisesRegex(ValueError, "1 to 16 images"):
            self.i2i.submit_task(
                image_urls=[f"https://example.com/{number}.png" for number in range(17)],
                prompt="编辑产品",
                aspect_ratio="1:1",
                resolution="2k",
            )

    def test_batch_forwards_the_sunburst_options(self):
        args = SimpleNamespace(
            prompt="编辑产品",
            aspect_ratio="3:2",
            resolution="4k",
            background="opaque",
            quality="xhigh",
            output_format="jpeg",
            edit_mode="fast",
            webhook_url="https://example.com/webhook",
        )
        job = {"name": "product_v1", "imageUrls": ["https://example.com/source.png"]}
        with patch.object(
            self.batch.rh100_i2i,
            "submit_task",
            return_value={"taskId": "task-789", "status": "QUEUED"},
        ) as submit_task:
            updated = self.batch.submit_one(job, args)
        self.assertEqual(updated["taskId"], "task-789")
        self.assertEqual(
            submit_task.call_args.kwargs,
            {
                "image_urls": ["https://example.com/source.png"],
                "prompt": "编辑产品",
                "aspect_ratio": "3:2",
                "resolution": "4k",
                "background": "opaque",
                "quality": "xhigh",
                "output_format": "jpeg",
                "edit_mode": "fast",
                "webhook_url": "https://example.com/webhook",
            },
        )

    def test_batch_rejects_more_than_fifteen_extra_references(self):
        argv = [
            "rh100_i2i_batch.py",
            "submit",
            "--image",
            "https://example.com/target.png",
            "--prompt",
            "编辑产品",
            "--no-open",
        ]
        for number in range(16):
            argv.extend(["--reference", f"https://example.com/reference-{number}.png"])
        with patch.object(sys, "argv", argv), self.assertRaisesRegex(
            SystemExit, "at most 15 reference images"
        ):
            self.batch.main()


if __name__ == "__main__":
    unittest.main()

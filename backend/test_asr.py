"""
测试 ASR 服务
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))

from dotenv import load_dotenv
load_dotenv()

import dashscope
from dashscope.audio.asr import Recognition

# 设置 API Key
api_key = os.getenv("DASHSCOPE_API_KEY")
if not api_key:
    print("请设置 DASHSCOPE_API_KEY 环境变量")
    sys.exit(1)

dashscope.api_key = api_key

def test_models():
    """测试不同的 ASR 模型"""

    # 创建一个简单的测试音频（你需要替换成实际的音频文件）
    test_audio_path = "test_audio.wav"

    if not os.path.exists(test_audio_path):
        print(f"请先创建测试音频文件: {test_audio_path}")
        print("或者修改代码使用已有的音频文件")
        return

    with open(test_audio_path, "rb") as f:
        audio_data = f.read()

    import base64
    audio_base64 = base64.b64encode(audio_data).decode("utf-8")

    models = [
        "sensevoice-v1",
        "paraformer-v2",
        "paraformer-realtime-v2",
    ]

    for model in models:
        print(f"\n{'='*50}")
        print(f"测试模型: {model}")
        print('='*50)

        try:
            recognition = Recognition(
                model=model,
                format="wav",
                sample_rate=16000,
            )

            result = recognition.call(audio_content=audio_base64)

            print(f"Status: {result.status_code}")
            print(f"Message: {result.message}")
            print(f"Output: {result.output}")

            if result.output:
                sentence = result.output.get("sentence", {})
                text = sentence.get("text", "")
                print(f"识别文本: {text}")

        except Exception as e:
            print(f"错误: {e}")
            import traceback
            traceback.print_exc()


def list_available_models():
    """列出可用的 ASR 模型"""
    print("DashScope ASR 可用模型:")
    print("- sensevoice-v1: 多语言，支持标点、情感")
    print("- paraformer-v2: 中英文，高精度")
    print("- paraformer-realtime-v2: 实时流式")
    print("- paraformer-8k-v1: 8kHz 采样率")
    print("- paraformer-mtl-zh: 中文多任务")


if __name__ == "__main__":
    list_available_models()
    print("\n" + "="*50)
    print("要测试 ASR，请：")
    print("1. 准备一个 test_audio.wav 文件")
    print("2. 运行: python test_asr.py")
    print("="*50)

    # 如果有测试音频，运行测试
    if os.path.exists("test_audio.wav"):
        test_models()

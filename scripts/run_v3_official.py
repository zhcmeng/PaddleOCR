import argparse
import os
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from paddleocr import PPStructureV3  # noqa: E402
import paddle  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="待解析的 PDF 路径")
    parser.add_argument(
        "--output",
        default=str(REPO_ROOT / "outputs" / "v3_research_output"),
        help="输出目录",
    )
    parser.add_argument(
        "--pages",
        default="0-10",
        help="要处理的页码范围，例如 0-10",
    )
    args = parser.parse_args()

    input_pdf = Path(args.input).expanduser().resolve()
    save_folder = Path(args.output).expanduser().resolve()
    output_path = Path(save_folder)
    output_path.mkdir(parents=True, exist_ok=True)

    print(f"Paddle version: {paddle.__version__}")
    print(f"GPU available: {paddle.device.is_compiled_with_cuda()}")
    print("正在初始化 PP-StructureV3 引擎 (开启图表识别)...")

    engine = PPStructureV3(
        use_chart_recognition=True,
        use_table_recognition=True,
        device="gpu",
    )

    print(f"开始解析 PDF: {input_pdf}")
    result = engine.predict(input=str(input_pdf), pages=args.pages)

    print("处理完成，正在生成 Markdown 并保存资源...")
    markdown_list = []

    for i, page_res in enumerate(result):
        if hasattr(page_res, "markdown"):
            markdown_list.append(page_res.markdown)
        else:
            print(f"第 {i + 1} 页未获取到 markdown 信息")

    if not markdown_list:
        print("未生成任何 Markdown 内容")
        return

    full_markdown_res = engine.concatenate_markdown_pages(markdown_list)
    full_markdown_text = full_markdown_res.get("markdown_texts", "")

    md_file = output_path / "research_report_v3_demo.md"
    with open(md_file, "w", encoding="utf-8") as f:
        f.write(full_markdown_text)

    all_images_saved = 0
    for i, page_info in enumerate(markdown_list):
        images_dict = page_info.get("markdown_images", {})
        for img_path_str, img_obj in images_dict.items():
            full_img_path = output_path / img_path_str.replace("/", os.sep)
            full_img_path.parent.mkdir(parents=True, exist_ok=True)
            img_obj.save(str(full_img_path))
            all_images_saved += 1
            print(f"已保存资源 (Page {i + 1}): {full_img_path}")

    print(f"DEBUG: 总计保存了 {all_images_saved} 张图片")
    print(f"\n[成功] 演示报告已生成: {md_file}")
    print(f"资源目录: {output_path / 'imgs'}")


if __name__ == "__main__":
    main()

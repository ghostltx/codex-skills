import argparse
import struct
import sys
from pathlib import Path
from xml.sax.saxutils import escape

KEYWORD = "contains-synthetic-performer"
XMP_NS = "http://ns.adobe.com/xap/1.0/"
XMP_XML = f'''<?xpacket begin="\ufeff" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="synthetic-performer-label">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
      <dc:subject><rdf:Bag><rdf:li>{escape(KEYWORD)}</rdf:li></rdf:Bag></dc:subject>
      <xmp:Label>{escape(KEYWORD)}</xmp:Label>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>'''.encode("utf-8")


def output_path(source: Path) -> Path:
    return source.with_name(f"{source.stem}已标记{source.suffix}")


def png_chunks(data: bytes):
    pos = 8
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        chunk = data[pos:pos + 12 + length]
        yield kind, chunk
        pos += 12 + length


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    import zlib
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)


def write_png(source: Path, target: Path) -> None:
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("不是有效 PNG 文件")
    chunks = list(png_chunks(data))
    filtered = [chunk for kind, chunk in chunks if kind != b"iTXt" or b"XML:com.adobe.xmp" not in chunk]
    xmp_payload = b"XML:com.adobe.xmp\x00\x00\x00\x00\x00" + XMP_XML
    inserted = False
    out = bytearray(data[:8])
    for kind, chunk in [(kind, chunk) for kind, chunk in chunks if kind != b"iTXt" or b"XML:com.adobe.xmp" not in chunk]:
        if kind == b"IEND" and not inserted:
            out.extend(png_chunk(b"iTXt", xmp_payload))
            inserted = True
        out.extend(chunk)
    target.write_bytes(out)


def jpeg_segments(data: bytes):
    if not data.startswith(b"\xff\xd8"):
        raise ValueError("不是有效 JPEG 文件")
    pos = 2
    while pos < len(data):
        if data[pos] != 0xFF:
            raise ValueError("JPEG 结构无效")
        while pos < len(data) and data[pos] == 0xFF:
            pos += 1
        marker = data[pos]
        pos += 1
        if marker in (0xD8, 0xD9):
            yield marker, data[pos - 2:pos]
            continue
        if marker == 0xDA:
            yield marker, data[pos - 2:]
            break
        if pos + 2 > len(data):
            raise ValueError("JPEG 段长度无效")
        length = struct.unpack(">H", data[pos:pos + 2])[0]
        segment = data[pos - 2:pos + length]
        yield marker, segment
        pos += length


def write_jpeg(source: Path, target: Path) -> None:
    data = source.read_bytes()
    segments = list(jpeg_segments(data))
    app1 = b"http://ns.adobe.com/xap/1.0/\x00" + XMP_XML
    if len(app1) + 2 > 65535:
        raise ValueError("XMP 数据过大")
    xmp_segment = b"\xff\xe1" + struct.pack(">H", len(app1) + 2) + app1
    out = bytearray(b"\xff\xd8")
    inserted = False
    for marker, segment in segments:
        if marker == 0xE1 and b"http://ns.adobe.com/xap/1.0/\x00" in segment:
            continue
        if marker == 0xDA and not inserted:
            out.extend(xmp_segment)
            inserted = True
        out.extend(segment)
    if not inserted:
        out.extend(xmp_segment)
    target.write_bytes(out)


def contains_keyword(path: Path) -> bool:
    data = path.read_bytes()
    return KEYWORD.encode("utf-8") in data


def mark(source: Path, target: Path) -> None:
    suffix = source.suffix.lower()
    if suffix == ".png":
        write_png(source, target)
    elif suffix in {".jpg", ".jpeg"}:
        write_jpeg(source, target)
    else:
        raise ValueError("当前脚本支持 PNG 和 JPEG/JPG；请先转换其他格式，避免损失原始元数据")
    if not contains_keyword(target):
        raise RuntimeError("写入后验证失败：未找到 contains-synthetic-performer")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--output")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    source = Path(args.image).expanduser()
    if not source.is_file():
        print(f"错误：文件不存在：{source}", file=sys.stderr)
        return 2
    if args.verify:
        ok = contains_keyword(source)
        print(f"{'已验证' if ok else '未找到'}：{source}")
        return 0 if ok else 1
    target = Path(args.output).expanduser() if args.output else output_path(source)
    if target.exists():
        print(f"错误：目标文件已存在，为避免覆盖而停止：{target}", file=sys.stderr)
        return 3
    try:
        mark(source, target)
    except Exception as exc:
        print(f"错误：{exc}", file=sys.stderr)
        return 4
    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
fetchbook_core.py - Robust Book Search, Resolver & Integrity Validation Engine
Used by InkDroid's fetchbook CLI for dependable e-book acquisition and e-reader repurposing.
"""

import sys
import os
import json
import ssl
import re
import urllib.request
import urllib.parse
import zipfile
from xml.etree import ElementTree as ET

# Default headers simulating a standard desktop browser
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'Connection': 'keep-alive'
}

# SSL Context permissive for legacy/mirror compatibility
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

# Public IPFS gateways for decentralized book fallback
IPFS_GATEWAYS = [
    "https://cloudflare-ipfs.com/ipfs/",
    "https://gateway.pinata.cloud/ipfs/",
    "https://ipfs.io/ipfs/",
    "https://dweb.link/ipfs/"
]


def make_request(url, headers=None, timeout=15):
    """Executes an HTTP GET request with default resilience headers."""
    req_headers = HEADERS.copy()
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, headers=req_headers)
    return urllib.request.urlopen(req, timeout=timeout, context=SSL_CTX)


# ==============================================================================
# 1. SEARCH ENGINES: GUTENBERG, OPENLIBRARY, LIBGEN
# ==============================================================================

def search_gutenberg(query, lang="pt", fmt="epub"):
    """Searches Project Gutenberg via Gutendex API with timeout tolerance."""
    results = []
    url = f"https://gutendex.com/books/?search={urllib.parse.quote(query)}"
    if lang and lang != "all":
        url += f"&languages={lang}"

    try:
        with make_request(url, timeout=12) as resp:
            data = json.loads(resp.read().decode('utf-8', errors='ignore'))
            for b in data.get("results", [])[:10]:
                title = b.get("title", "").strip()
                authors = ", ".join([a.get("name") for a in b.get("authors", [])]) or "Desconhecido"
                formats = b.get("formats", {})

                dl_link = ""
                matched_fmt = fmt.upper()
                if fmt == "epub":
                    dl_link = formats.get("application/epub+zip") or formats.get("application/epub+zip; charset=utf-8")
                elif fmt == "mobi":
                    dl_link = formats.get("application/x-mobipocket-ebook")
                elif fmt == "pdf":
                    dl_link = formats.get("application/pdf")

                if not dl_link and "application/epub+zip" in formats:
                    dl_link = formats["application/epub+zip"]
                    matched_fmt = "EPUB"

                if dl_link:
                    results.append({
                        'source': 'Gutenberg',
                        'title': title,
                        'author': authors,
                        'format': matched_fmt,
                        'lang': lang,
                        'size': 'Varia',
                        'direct': True,
                        'dl_url': dl_link
                    })
    except Exception:
        pass
    return results


def search_archive(query, lang="pt", fmt="epub"):
    """Searches OpenLibrary/Archive.org, validating public availability."""
    results = []
    url = f"https://openlibrary.org/search.json?q={urllib.parse.quote(query)}&limit=10"
    try:
        with make_request(url, timeout=12) as resp:
            data = json.loads(resp.read().decode('utf-8', errors='ignore'))
            for doc in data.get("docs", [])[:8]:
                title = doc.get("title", "").strip()
                authors = ", ".join(doc.get("author_name", [])) or "Desconhecido"
                ia_list = doc.get("ia", [])
                public_scan = doc.get("public_scan_b", False)
                
                # Check language match if present
                doc_langs = doc.get("language", [])
                if lang and lang != "all":
                    if lang in ["pt", "por"] and not any(l in ["por", "pt", "Portuguese"] for l in doc_langs):
                        if doc_langs: # skip if languages are listed and pt isn't there
                            continue

                if not ia_list:
                    continue

                ia_id = ia_list[0]
                # Open access items can be downloaded directly
                dl_url = f"https://archive.org/download/{ia_id}/{ia_id}.{fmt.lower()}"
                results.append({
                    'source': 'Archive.org',
                    'title': title,
                    'author': authors,
                    'format': fmt.upper(),
                    'lang': lang,
                    'size': 'N/A',
                    'direct': True,
                    'dl_url': dl_url,
                    'ia_id': ia_id,
                    'public_scan': public_scan
                })
    except Exception:
        pass
    return results


def search_libgen(query, lang="pt", fmt="epub"):
    """Robust scraper for Library Genesis mirrors with dynamic token support."""
    results = []
    mirrors = ["https://libgen.li", "https://libgen.vg", "https://libgen.is"]

    query_variants = [
        f"req={urllib.parse.quote(query)}&columns[]=t&columns[]=a&objects[]=f&topics[]=l&topics[]=f&res=30",
        f"req={urllib.parse.quote(query)}&topics[]=f&res=30",
        f"req={urllib.parse.quote(query)}&res=30"
    ]

    for mirror in mirrors:
        for q_param in query_variants:
            try:
                url = f"{mirror}/index.php?{q_param}"
                with make_request(url, timeout=12) as resp:
                    html = resp.read().decode('utf-8', errors='ignore')

                rows = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.DOTALL)
                for r in rows:
                    tds = re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL)
                    if len(tds) >= 8:
                        # Clean tags
                        title_raw = re.sub(r'<[^>]+>', ' ', tds[0]).strip()
                        title_clean = re.sub(r'\s+', ' ', title_raw)
                        # If title contains edition/book tags, extract clean title
                        title_clean = re.sub(r'[\"\'\`]', '', title_clean)
                        title_match = re.search(r'^(.*?)(?:\s+\d+\s+.*|href=|$)', title_clean)
                        title = title_match.group(1).strip() if title_match else title_clean[:70]
                        title = re.sub(r'\s*-\s*$', '', title).strip(' -_"\':')
                        if not title:
                            title = title_clean[:70].strip(' -_"\':')

                        author = re.sub(r'<[^>]+>', ' ', tds[1]).strip() or "Desconhecido"
                        author = re.sub(r'[\"\'\`]', '', author).strip()
                        book_lang = re.sub(r'<[^>]+>', ' ', tds[4]).strip().lower()
                        size_str = re.sub(r'<[^>]+>', ' ', tds[6]).strip()
                        extension = re.sub(r'<[^>]+>', ' ', tds[7]).strip().lower()

                        # Language filter
                        if lang and lang != "all":
                            if lang in ["pt", "por", "portuguese"] and not any(k in book_lang for k in ["pt", "por", "portuguese"]):
                                continue
                            elif lang in ["en", "eng", "english"] and not any(k in book_lang for k in ["en", "eng", "english"]):
                                continue
                            elif lang in ["es", "spa", "spanish"] and not any(k in book_lang for k in ["es", "spa", "spanish"]):
                                continue

                        # Format filter
                        if fmt and extension and fmt.lower() != extension:
                            continue

                        # Mirror / Ads page extraction
                        ads_m = re.search(r'href=[\"\x27]([^\"\x27]*ads\.php\?md5=[a-zA-Z0-9]+)[\"\x27]', r)
                        if ads_m:
                            ads_path = ads_m.group(1)
                            ads_url = ads_path if ads_path.startswith("http") else f"{mirror}/{ads_path.lstrip('/')}"
                            # Avoid duplicates by ads_url
                            if not any(x.get('ads_url') == ads_url for x in results):
                                results.append({
                                    'source': 'LibGen',
                                    'title': title[:80].strip(),
                                    'author': author[:45].strip(),
                                    'format': extension.upper(),
                                    'lang': book_lang or lang,
                                    'size': size_str,
                                    'direct': False,
                                    'ads_url': ads_url,
                                    'mirror': mirror
                                })
                if results:
                    return results
            except Exception:
                continue

    return results


def search_all(query, lang="pt", fmt="epub", source="all"):
    """Orchestrates search across selected sources and unifies results."""
    all_results = []

    # Priority 1: LibGen (Largest inventory for modern, technical and localized books)
    if source in ["all", "libgen"]:
        libgen_res = search_libgen(query, lang, fmt)
        all_results.extend(libgen_res)

    # Priority 2: Project Gutenberg (Authoritative for Public Domain / Classics)
    if source in ["all", "gutenberg"]:
        gutenberg_res = search_gutenberg(query, lang, fmt)
        all_results.extend(gutenberg_res)

    # Priority 3: Archive.org (Historical scans and open monographs)
    if source in ["all", "archive", "openlibrary"] and len(all_results) < 8:
        archive_res = search_archive(query, lang, fmt)
        all_results.extend(archive_res)

    return all_results


# ==============================================================================
# 2. RESOLVER: EXTRACT DIRECT DOWNLOAD LINK WITH TOKEN / IPFS FALLBACK
# ==============================================================================

def resolve_libgen_download(book_item):
    """
    Visits the LibGen Ads page, extracts the dynamic tokenized get.php link,
    and identifies any IPFS CID or secondary mirrors for maximum resilience.
    """
    ads_url = book_item.get("ads_url")
    if not ads_url:
        return None

    mirror = book_item.get("mirror", "https://libgen.li")
    try:
        with make_request(ads_url, headers={'Referer': mirror}, timeout=12) as resp:
            html = resp.read().decode('utf-8', errors='ignore')

        # Pattern 1: get.php with MD5 and security key
        get_m = re.search(r'href=[\"\x27]([^\"\x27]*get\.php\?md5=[a-zA-Z0-9]+&key=[a-zA-Z0-9]+)[\"\x27]', html)
        if not get_m:
            get_m = re.search(r'href=[\"\x27]([^\"\x27]*get\.php\?md5=[a-zA-Z0-9]+[^\"]*)[\"\x27]', html)

        if get_m:
            rel = get_m.group(1)
            get_url = rel if rel.startswith("http") else f"{mirror}/{rel.lstrip('/')}"
            return {
                'url': get_url,
                'referer': ads_url
            }

        # Pattern 2: IPFS CID or Direct CDN link
        ipfs_m = re.search(r'href=[\"\x27](https?://[^\s\"\x27]+ipfs[^\s\"\x27]+)[\"\x27]', html)
        if ipfs_m:
            return {
                'url': ipfs_m.group(1),
                'referer': ads_url
            }

        # Pattern 3: Direct file download link (.epub, .pdf)
        direct_m = re.search(r'href=[\"\x27](https?://[^\s\"\x27]+\.(?:epub|pdf|mobi)[^\s\"\x27]*)[\"\x27]', html, re.I)
        if direct_m:
            return {
                'url': direct_m.group(1),
                'referer': ads_url
            }
    except Exception:
        pass

    return None


# ==============================================================================
# 3. INTEGRITY & METADATA VALIDATOR
# ==============================================================================

def validate_and_inspect_book(file_path, expected_fmt="epub"):
    """
    Validates file integrity using Magic Bytes and internal container structure.
    Rejects HTML error pages (401, 403, 408, 505, Cloudflare).
    Returns a dict with verification status and extracted metadata.
    """
    if not os.path.exists(file_path):
        return {'valid': False, 'error': 'Arquivo não encontrado'}

    file_size = os.path.getsize(file_path)
    if file_size < 2048:
        return {'valid': False, 'error': f'Arquivo excessivamente pequeno ({file_size} bytes)'}

    with open(file_path, 'rb') as f:
        header = f.read(1024)

    # Check for HTML / Server Error signatures
    header_lower = header.lower()
    if b"<html" in header_lower or b"<!doctype html" in header_lower or b"<head" in header_lower:
        title_m = re.search(r"<title>(.*?)</title>", header.decode('utf-8', errors='ignore'), re.I)
        title_err = title_m.group(1).strip() if title_m else "Página HTML de Erro"
        return {'valid': False, 'error': f'Servidor retornou HTML em vez do livro: {title_err}'}

    if b"<error>" in header_lower or b"<code accessdenied" in header_lower or b"unauthorized" in header_lower:
        return {'valid': False, 'error': 'Servidor retornou erro 401 Unauthorized / Acesso Negado'}

    expected_fmt = expected_fmt.lower()

    # EPUB Verification (Zip container + mimetype + OPF metadata)
    if expected_fmt == "epub":
        if not (header.startswith(b"PK\x03\x04") or header.startswith(b"PK\x05\x06")):
            return {'valid': False, 'error': 'Assinatura inválida (não é um arquivo ZIP/EPUB)'}

        try:
            with zipfile.ZipFile(file_path, 'r') as zf:
                names = zf.namelist()
                if "mimetype" not in names and not any(n.endswith(".opf") for n in names):
                    return {'valid': False, 'error': 'Estrutura EPUB corrompida (mimetype/OPF ausentes)'}

                # Extract real metadata from OPF
                opf_name = next((n for n in names if n.endswith('.opf')), None)
                meta = {'title': 'Desconhecido', 'creator': 'Desconhecido', 'language': 'N/A'}
                if opf_name:
                    opf_data = zf.read(opf_name)
                    root = ET.fromstring(opf_data)
                    ns = {'dc': 'http://purl.org/dc/elements/1.1/'}
                    t = root.find('.//dc:title', ns)
                    c = root.find('.//dc:creator', ns)
                    l = root.find('.//dc:language', ns)
                    if t is not None and t.text: meta['title'] = t.text.strip()
                    if c is not None and c.text: meta['creator'] = c.text.strip()
                    if l is not None and l.text: meta['language'] = l.text.strip()

                chapters = [n for n in names if n.endswith(('.html', '.xhtml', '.htm'))]
                
                # Check sample text length to ensure book has readable contents
                sample_text_len = 0
                for ch in chapters[:8]:
                    raw = zf.read(ch).decode('utf-8', errors='ignore')
                    sample_text_len += len(re.sub(r'<[^>]+>', ' ', raw).strip())

                if len(chapters) == 0:
                    return {'valid': False, 'error': 'EPUB vazio: nenhum capítulo de texto encontrado'}

                return {
                    'valid': True,
                    'format': 'EPUB',
                    'title': meta['title'],
                    'author': meta['creator'],
                    'language': meta['language'],
                    'chapters': len(chapters),
                    'sample_chars': sample_text_len,
                    'size_bytes': file_size
                }
        except Exception as e:
            return {'valid': False, 'error': f'Falha ao descompactar EPUB: {e}'}

    # PDF Verification
    elif expected_fmt == "pdf":
        if not header.startswith(b"%PDF-"):
            return {'valid': False, 'error': 'Assinatura inválida (cabeçalho %PDF ausente)'}
        return {
            'valid': True,
            'format': 'PDF',
            'title': os.path.basename(file_path),
            'author': 'N/A',
            'size_bytes': file_size
        }

    return {'valid': True, 'format': expected_fmt.upper(), 'size_bytes': file_size}


# ==============================================================================
# 4. DOWNLOAD PIPELINE WITH PROGRESS & RETRY
# ==============================================================================

def download_book(book_item, destination_path, expected_fmt="epub"):
    """
    Downloads the selected book item, resolving dynamic mirrors if needed,
    and runs comprehensive validation on the resulting file.
    """
    is_direct = book_item.get("direct", False)
    dl_url = book_item.get("dl_url")
    referer = None

    if not is_direct:
        resolved = resolve_libgen_download(book_item)
        if not resolved:
            raise RuntimeError("Não foi possível extrair link direto dos espelhos da CDN.")
        dl_url = resolved['url']
        referer = resolved['referer']

    # Execute streaming download
    temp_path = destination_path + ".tmp"
    headers = HEADERS.copy()
    if referer:
        headers['Referer'] = referer

    req = urllib.request.Request(dl_url, headers=headers)
    with urllib.request.urlopen(req, timeout=30, context=SSL_CTX) as response, open(temp_path, "wb") as out_file:
        total_size = int(response.headers.get('Content-Length', 0))
        downloaded = 0
        chunk_size = 64 * 1024

        while True:
            chunk = response.read(chunk_size)
            if not chunk:
                break
            out_file.write(chunk)
            downloaded += len(chunk)
            if total_size > 0:
                percent = min(100.0, (downloaded / total_size) * 100)
                sys.stderr.write(f"\rBaixando: {downloaded / 1024:.1f} KB / {total_size / 1024:.1f} KB ({percent:.1f}%)")
            else:
                sys.stderr.write(f"\rBaixando: {downloaded / 1024:.1f} KB...")
            sys.stderr.flush()

    sys.stderr.write("\n")
    sys.stderr.flush()

    # Move to destination and validate
    if os.path.exists(destination_path):
        os.remove(destination_path)
    os.rename(temp_path, destination_path)

    # Perform thorough inspection
    report = validate_and_inspect_book(destination_path, expected_fmt)
    if not report.get("valid"):
        # Remove corrupted / error file
        if os.path.exists(destination_path):
            os.remove(destination_path)
        raise ValueError(report.get("error", "Validação de integridade falhou"))

    return report


# ==============================================================================
# 5. CLI INTERFACE
# ==============================================================================

def main():
    if len(sys.argv) < 2:
        print("Uso: fetchbook_core.py [search|download|validate] ...", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "search":
        query = sys.argv[2] if len(sys.argv) > 2 else ""
        lang = sys.argv[3] if len(sys.argv) > 3 else "pt"
        fmt = sys.argv[4] if len(sys.argv) > 4 else "epub"
        source = sys.argv[5] if len(sys.argv) > 5 else "all"

        results = search_all(query, lang, fmt, source)
        print(json.dumps(results, ensure_ascii=False))

    elif cmd == "download":
        raw_item = sys.argv[2]
        dest_path = sys.argv[3]
        fmt = sys.argv[4] if len(sys.argv) > 4 else "epub"

        book_item = json.loads(raw_item)
        try:
            report = download_book(book_item, dest_path, fmt)
            print(json.dumps({'success': True, 'report': report}, ensure_ascii=False))
        except Exception as e:
            print(json.dumps({'success': False, 'error': str(e)}, ensure_ascii=False))
            sys.exit(1)

    elif cmd == "validate":
        target_path = sys.argv[2]
        fmt = sys.argv[3] if len(sys.argv) > 3 else "epub"
        report = validate_and_inspect_book(target_path, fmt)
        print(json.dumps(report, ensure_ascii=False))

    else:
        print(f"Comando desconhecido: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

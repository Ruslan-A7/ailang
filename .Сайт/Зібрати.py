# Автор: Ruslan_A7 (RA7).
# Розробник: Codex (GPT-6.1 Sol) від OpenAI під управлінням RA7.
# Створено з використанням AILang.
# Ліцензія: RA7 Open Free License — https://ra7.iuid.cc/LICENSE.
# Версія файла: 0.11.1.
"""Статичний сайт і ZIP-пакети; лише стандартна бібліотека Python 3.11+."""
from pathlib import Path
from html import escape
import hashlib
import json
import re
import shutil
import zipfile

from Зміст import TEXT, DOCUMENTS, DEVELOPER, LICENSE, GITHUB
from Зміст import PACKAGE_ROOT, PACKAGE_SOURCE, PACKAGE_SETTINGS

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / '.Джерело'
OUT = ROOT / '.Результат' / 'Сайт'
RELEASES = ROOT / '.Результат' / 'Публікація'
VERSION = (ROOT / 'VERSION').read_text(encoding='utf-8-sig').strip()
if not re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', VERSION):
    raise ValueError('VERSION має містити X.Y.Z')
HEADER = f'<!--\nАвтор: Ruslan_A7 (RA7).\nРозробник: {DEVELOPER}.\nСтворено з використанням AILang.\nЛіцензія: RA7 Open Free License — {LICENSE}.\n-->\n'
JS_HEADER = f'/* Автор: Ruslan_A7 (RA7).\n * Розробник: {DEVELOPER}.\n * Створено з використанням AILang.\n * Ліцензія: {LICENSE}. */\n'
ARROW = '<svg aria-hidden="true" viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'
DOWN = '<svg aria-hidden="true" viewBox="0 0 24 24"><path d="M12 3v12m-5-5 5 5 5-5M5 16v5h14v-5"/></svg>'
MENU = '<svg aria-hidden="true" viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16"/></svg>'
STARTER_NAME = f'ailang-{VERSION}-uk-starter.zip'
SOURCES = {}
for slug, relative, uk, en in DOCUMENTS:
    path = SOURCE / relative
    if path.is_symlink() or not path.resolve().is_relative_to(SOURCE.resolve()):
        raise ValueError('Посилання поза авторською папкою')
    SOURCES[relative] = path.read_bytes()
actual = {str(path.relative_to(SOURCE)).replace('\\', '/') for path in SOURCE.rglob('*') if path.is_file()}
if actual != set(SOURCES):
    raise ValueError('Список документації не відповідає файлам .Джерело; оновіть DOCUMENTS')
HASHES = {name: hashlib.sha256(data).hexdigest() for name, data in SOURCES.items()}


def write(relative, content):
    path = OUT / relative
    if not path.resolve().is_relative_to(OUT.resolve()):
        raise ValueError('Шлях поза папкою сайту')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8', newline='\n')


def safe_url(value):
    return value.startswith(('https://', 'http://', '#')) or not re.match(r'^[a-zA-Z][\w+.-]*:', value)


def inline(value):
    # HTML авторського Markdown завжди екранується; довільний код не виконується.
    tokens = []
    def save(markup):
        tokens.append(markup)
        return f'\x00{len(tokens)-1}\x00'
    value = re.sub(r'`([^`]+)`', lambda m: save('<code>' + escape(m[1]) + '</code>'), value)
    def link(match):
        label, url = match[1], match[2]
        return save(f'<a href="{escape(url, quote=True)}">{escape(label)}</a>') if safe_url(url) else escape(label)
    value = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', link, value)
    value = escape(value)
    value = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', value)
    value = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', r'<em>\1</em>', value)
    value = re.sub(r'\x00(\d+)\x00', lambda m: tokens[int(m[1])], value)
    return value


def markdown(raw):
    lines = raw.splitlines()
    output, headings, paragraph, lists = [], [], [], []
    fenced, code_lines, skipped_title = False, [], False
    def flush():
        if paragraph:
            output.append('<p>' + inline(' '.join(paragraph)) + '</p>')
            paragraph.clear()
    def close_lists(level=-1):
        while lists and lists[-1][0] > level:
            _, kind = lists.pop()
            output.append(f'</li></{kind}>')
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('```'):
            flush(); close_lists()
            if fenced:
                output.append('<pre><code>' + escape('\n'.join(code_lines)) + '</code></pre>')
                code_lines.clear()
            fenced = not fenced
            continue
        if fenced:
            code_lines.append(line); continue
        heading = re.match(r'^(#{1,6})\s+(.+)', stripped)
        if heading:
            flush(); close_lists()
            if len(heading[1]) == 1 and not skipped_title:
                skipped_title = True
                continue
            level = max(2, len(heading[1]))
            anchor = f'section-{len(headings)+1}'
            headings.append((anchor, re.sub(r'[*`]', '', heading[2])))
            output.append(f'<h{level} id="{anchor}">{inline(heading[2])}</h{level}>')
            continue
        if not stripped:
            flush(); continue
        item = re.match(r'^(\s*)([-*]|\d+\.)\s+(.+)', line)
        if item:
            flush()
            indent, kind = len(item[1].expandtabs(4)), 'ol' if item[2][0].isdigit() else 'ul'
            close_lists(indent)
            if lists and lists[-1][0] == indent:
                if lists[-1][1] == kind:
                    output.append('</li><li>')
                else:
                    close_lists(indent-1); output.append(f'<{kind}><li>'); lists.append((indent, kind))
            else:
                output.append(f'<{kind}><li>'); lists.append((indent, kind))
            output.append(inline(item[3].rstrip())); continue
        close_lists()
        if stripped.startswith('> '):
            flush(); output.append('<blockquote>' + inline(stripped[2:]) + '</blockquote>')
        elif stripped in ('---', '***', '___'):
            flush(); output.append('<hr>')
        else:
            paragraph.append(stripped)
    flush(); close_lists()
    if code_lines:
        output.append('<pre><code>' + escape('\n'.join(code_lines)) + '</code></pre>')
    return '\n'.join(output), headings


def header(lang, kind='home', slug='index'):
    t = TEXT[lang]
    prefix = '' if lang == 'uk' else 'en/'
    page = 'index.html' if kind == 'home' else f'docs/{slug}.html'
    # Відносні URL підтримують розміщення в довільній підпапці сервера.
    depth = (prefix + page).count('/')
    base = '../' * depth
    home = base + prefix + 'index.html'
    docs = base + prefix + 'docs/index.html'
    other = base + (('en/' if lang == 'uk' else '') + page)
    languages = f'<strong aria-current="true">{lang.upper()}</strong><a href="{other}" lang="{("en" if lang == "uk" else "uk")}">{("EN" if lang == "uk" else "UK")}</a>'
    nav = f'<a href="{home}#idea">{t["nav"][0]}</a><a href="{home}#features">{t["nav"][1]}</a><a href="{docs}"' + (' aria-current="page"' if kind == 'docs' else '') + f'>{t["nav"][2]}</a>'
    return base, home, docs, f'''<a class="skip" href="#main">{t['skip']}</a>
<header class="header"><div class="wrap header-inner">
<a class="brand" href="{home}" aria-label="AILang"><img src="{base}assets/logo.png" alt="" width="39" height="39"><span><em>AI</em>Lang</span></a>
<nav id="navigation" class="navigation" aria-label="{t['menu']}">{nav}</nav>
<div class="header-actions"><div class="languages" aria-label="Language">{languages}</div>
<a class="nav-download" href="{base}downloads/{STARTER_NAME}" download>{t['download']}{DOWN}</a>
<button class="menu-toggle" data-menu aria-controls="navigation" aria-expanded="false" aria-label="{t['menu']}">{MENU}</button></div>
</div></header>'''


def footer(lang, base, home, docs):
    t = TEXT[lang]
    return f'''<footer class="footer"><div class="wrap"><div class="footer-top">
<a class="brand" href="{home}"><span><em>AI</em>Lang</span></a>
<div class="footer-links"><a href="{docs}">{t['doc_title']}</a><a href="{GITHUB}">GitHub</a><a href="{LICENSE}">RA7 Open Free License</a></div></div>
<div class="credits"><p>{t['author_label']}: <a href="https://ra7.iuid.cc">Ruslan_A7 (RA7)</a></p><p>{t['developer_label']}: {DEVELOPER}</p></div>
<div class="footer-bottom"><span>{t['footer_line']}</span><span class="version">v{VERSION}</span></div></div></footer>'''


def shell(lang, title, body, kind='home', slug='index'):
    t = TEXT[lang]
    base, home, docs, top = header(lang, kind, slug)
    scripts = (f'<script src="{base}{("en/" if lang == "en" else "")}docs/search-data.js" defer></script>' if kind == 'docs' else '')
    return HEADER + f'''<!doctype html>
<html lang="{lang}" class="no-js"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark"><meta name="theme-color" content="#080d18">
<title>{escape(title)}</title><meta name="description" content="{escape(t['description'], quote=True)}">
<meta property="og:title" content="{escape(title, quote=True)}"><meta property="og:description" content="{escape(t['description'], quote=True)}"><meta property="og:type" content="website"><meta property="og:image" content="{base}assets/banner.png">
<link rel="icon" href="{base}assets/logo.png" type="image/png"><link rel="stylesheet" href="{base}assets/site.css">
{scripts}<script src="{base}assets/site.js" defer></script></head><body>{top}{body}{footer(lang, base, home, docs)}</body></html>'''


def landing(lang, package_size):
    t = TEXT[lang]
    base = '' if lang == 'uk' else '../'
    docs = 'docs/index.html'
    download = f'{base}downloads/{STARTER_NAME}'
    flow = '<i aria-hidden="true">→</i>'.join(f'<span><b>0{i+1}</b>{text}</span>' for i, text in enumerate(t['strip']))
    features = ''.join(f'<article class="feature"><span class="number">{num}</span><h3>{title}</h3><p>{text}</p></article>' for num, title, text in t['features'])
    steps = ''.join(f'<div class="step"><div><h3>{title}</h3><p>{text}</p></div></div>' for title, text in t['steps'])
    links = ''.join(f'<a class="doc-link" href="docs/{slug}.html">{title}{ARROW}</a>' for slug, title in t['docs_links'])
    example = escape(t['example'])
    example = re.sub(r'^(# .+)$', r'<span class="code-heading">\1</span>', example, flags=re.M)
    example = re.sub(r'(\*\*.+?\*\*)', r'<span class="code-strong">\1</span>', example)
    body = f'''<main id="main">
<section class="hero"><div class="wrap hero-grid"><div><span class="eyebrow">{t['eyebrow']}</span><h1>{t['hero']}</h1><p class="hero-description">{t['intro']}</p>
<div class="buttons"><a class="button primary" href="{download}" download>{t['download']}{DOWN}</a><a class="button secondary" href="{docs}">{t['read']}{ARROW}</a></div><p class="hero-note">{t['hero_note']}</p></div>
<figure class="hero-art"><img src="{base}assets/logo.png" alt="{t['image_alt']}" width="1254" height="1254" fetchpriority="high"><figcaption><span class="status-dot"></span>{t['badge']}<span aria-hidden="true">/</span><span class="version">v{VERSION}</span></figcaption></figure></div></section>
<div class="wrap"><div class="flow">{flow}</div></div>
<section class="section wrap" id="idea"><div class="idea-grid"><div><span class="section-label">{t['idea_label']}</span><h2>{t['idea_title']}</h2><p class="body-copy">{t['idea_body']}</p><p class="body-small">{t['idea_detail']}</p></div>
<div><div class="code-window"><div class="code-top"><i></i><i></i><i></i><span class="file-name">{t['example_path']}</span></div><span class="example-label">{t['example_label']}</span><pre>{example}</pre></div><p class="caption">{t['example_note']}</p></div></div></section>
<section class="features section" id="features"><div class="wrap"><span class="section-label">{t['features_label']}</span><div class="section-heading"><h2>{t['features_title']}</h2><span class="small-note">Markdown · .ail · .ail.md</span></div><div class="features-grid">{features}</div></div></section>
<section class="section wrap" id="start"><span class="section-label">{t['start_label']}</span><h2>{t['start_title']}</h2><div class="start-grid"><div class="steps">{steps}</div><div class="tree"><div class="tree-title">{t['tree_label']}</div><pre>your-project/
├── <b>.Постачальники/</b>
│   └── RA7/
│       └── AILang/
│           ├── VERSION
│           └── .Джерело/
│               ├── AGENTS.md
│               ├── AILang.md
│               ├── .Інструкції/
│               └── .Налаштування/
├── <b>.Ідея/</b>
├── <b>.Джерело/</b>
├── .Результат/
├── .Документація/
├── .План/
├── .Інструменти/
├── .Залежності/
├── AGENTS.md
├── ПОЧАТОК.md
└── VERSION</pre></div></div></section>
<section class="docs-teaser section wrap" id="documentation"><div class="docs-grid"><div><span class="section-label">{t['docs_label']}</span><h2>{t['docs_title']}</h2><p class="body-copy">{t['docs_body']}</p><a class="text-link" href="{docs}">{t['docs_cta']}{ARROW}</a></div><div class="doc-links">{links}</div></div></section>
<section class="download-section wrap" id="download"><div class="download-panel"><div><span class="section-label">{t['download_label']}</span><h2>{t['download_title']}</h2><div class="release-line">AILang v{VERSION}</div></div><div><p>{t['download_body']}</p><a class="button primary" href="{download}" download>{t['download']}{DOWN}</a><span class="download-meta">{t['zip_note']} · {package_size} KB</span><a class="download-secondary" href="{GITHUB}">{t['download_source']}</a></div></div><p class="roadmap">{t['roadmap']}</p></section>
</main>'''
    return shell(lang, t['title'], body)


def documentation(lang):
    t = TEXT[lang]
    prefix = '' if lang == 'uk' else 'en/'
    base = '../' if lang == 'uk' else '../../'
    docs = [(slug, relative, uk if lang == 'uk' else en) for slug, relative, uk, en in DOCUMENTS]
    data = {'resultsLabel': t['results'], 'empty': t['search_empty'], 'documents': []}
    for slug, relative, title in docs:
        raw = SOURCES[relative].decode('utf-8-sig')
        data['documents'].append({'slug': slug, 'title': title, 'text': raw})
    write(prefix + 'docs/search-data.js', JS_HEADER + 'window.AILANG_DOCS=' + json.dumps(data, ensure_ascii=False).replace('<', '\\u003c') + ';\n')
    for index, (slug, relative, title) in enumerate([('index', '', t['doc_title'])] + docs):
        sidebar_links = ''.join(f'<li><a href="{key}.html"' + (' aria-current="page"' if key == slug else '') + f'>{escape(label)}</a></li>' for key, _, label in [('index', '', t['all_docs'])] + docs)
        sidebar = f'''<aside class="docs-sidebar"><a class="sidebar-title" href="index.html">AILang / {t['doc_title']}</a><label class="search-label" for="doc-search">{t['search']}</label><input class="search-input" id="doc-search" type="search" maxlength="160" placeholder="{t['search_hint']}" autocomplete="off" aria-controls="search-results"><ul class="sidebar-links">{sidebar_links}</ul></aside>'''
        notice = f'<p class="language-notice">{t["language_note"]}</p>' if t['language_note'] else ''
        article = f'<p class="doc-lead">{t["doc_intro"]}</p>{notice}'
        if slug == 'index':
            article += '<div class="doc-card-grid">' + ''.join(f'<a class="doc-card" href="{key}.html"><span class="number">{i+1:02}</span>{escape(label)}</a>' for i, (key, _, label) in enumerate(docs)) + '</div>'
        else:
            raw = SOURCES[relative].decode('utf-8-sig')
            rendered, headings = markdown(raw)
            raw_url = base + 'source/' + slug + '.md'
            article = notice + f'<p class="source-notice">{t["source_note"]}</p><div class="doc-actions"><a href="{raw_url}" download="{escape(Path(relative).name, quote=True)}">{t["source"]} ↓</a><span>{t["doc_version"]}: {VERSION}</span><button class="copy-button" data-copy="raw-source" data-success="{t["copied"]}" data-failure="{t["copy_failed"]}">{t["copy"]}</button></div><p class="copy-status" id="copy-status" role="status"></p>'
            if headings:
                article += '<details class="toc"><summary>' + t['contents'] + '</summary><ul>' + ''.join(f'<li><a href="#{anchor}">{escape(label)}</a></li>' for anchor, label in headings) + '</ul></details>'
            encoded_source = re.sub(r' +(?=\r?$)', lambda match: '&#32;' * len(match[0]), escape(raw), flags=re.M)
            article += f'<article class="prose" lang="uk">{rendered}</article><div id="raw-source" hidden>{encoded_source}</div>'
            prev = docs[index-2] if index > 1 else ('index', '', t['all_docs'])
            after = docs[index] if index < len(docs) else None
            article += '<nav class="doc-pagination" aria-label="' + t['doc_title'] + '">'
            article += f'<a href="{prev[0]}.html"><small>← {t["previous"]}</small>{escape(prev[2])}</a>'
            if after:
                article += f'<a href="{after[0]}.html"><small>{t["next"]} →</small>{escape(after[2])}</a>'
            article += '</nav>'
        body = f'<main id="main" class="wrap docs-layout">{sidebar}<div class="doc-main"><div class="breadcrumb"><a href="{base}{prefix}index.html">AILang</a> / <a href="index.html">{t["doc_title"]}</a></div><h1>{escape(title)}</h1><section id="search-results" class="search-results" aria-label="{t["search"]}" hidden></section>{article}</div></main>'
        write(prefix + f'docs/{slug}.html', shell(lang, f'{title} — AILang', body, 'docs', slug))


def starter():
    destination = OUT / 'downloads' / STARTER_NAME
    destination.parent.mkdir(parents=True, exist_ok=True)
    entry = HEADER + f'''# Новий проєкт на AILang

Ідея: передати агенту правила реалізації авторського опису.

Прочитай {PACKAGE_SOURCE}/AGENTS.md, {PACKAGE_SOURCE}/AILang.md та всі пов’язані інструкції й налаштування. Опис продукту знаходиться в кореневій .Джерело, а контекст у .Ідея. До реалізації ознайомся з ними, уточни суттєве та підготуй план. Цей AGENTS.md власник може доповнити своїми вимогами.
'''
    guide = HEADER + f'''# Початок роботи

Ідея: налаштувати новий проєкт з AILang {VERSION}.

1. Розпакуйте архів у порожню папку. Для існуючого проєкту спершу погодьте міграцію, не перезаписуйте власний AGENTS.md.
2. Заповніть {PACKAGE_SETTINGS} параметрами свого продукту.
3. Опишіть ідею в .Ідея, а потрібний функціонал — у кореневій .Джерело файлами .ail або .ail.md.
4. Попросіть агента прочитати AGENTS.md і продовжити за правилами AILang.

Кореневий VERSION містить початкову версію нового продукту 0.1.0. Версія AILang записана в {PACKAGE_ROOT}/VERSION.

Зберігайте сторонні інструкції в `.Постачальники/<постачальник>/<проєкт>`. Окремий модуль можна додати як пакет у підпапку проєкту. У скорочених згадках опускайте лише `.Постачальники/`, наприклад `RA7/AILang/.Джерело/AGENTS.md`.

Розробник AILang: {DEVELOPER}.
Створено з використанням AILang. © 2026 AILang.
Ліцензія: {LICENSE}.
'''
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        for relative, data in SOURCES.items():
            archive.writestr(f'{PACKAGE_SOURCE}/{relative}', data)
        archive.writestr(f'{PACKAGE_ROOT}/VERSION', VERSION + '\n')
        archive.writestr('AGENTS.md', entry)
        archive.writestr('ПОЧАТОК.md', guide)
        archive.writestr('VERSION', '0.1.0\n')
        for folder in ('.Ідея', '.Джерело', '.Результат', '.Документація', '.План', '.Інструменти', '.Залежності', '.Постачальники'):
            archive.writestr(folder + '/', '')
    # Перевірка цілісності реального пакета, включно з прихованими папками та Unicode.
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise ValueError('Пошкоджений ZIP')
        for relative, expected in HASHES.items():
            if hashlib.sha256(archive.read(f'{PACKAGE_SOURCE}/{relative}')).hexdigest() != expected:
                raise ValueError('Авторський файл змінено в ZIP')
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    write('downloads/' + STARTER_NAME + '.sha256', digest + '  ' + STARTER_NAME + '\n')
    return max(1, round(destination.stat().st_size / 1024))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for slug, relative, _, _ in DOCUMENTS:
        data = SOURCES[relative]
        destination = OUT / 'source' / (slug + '.md')
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    assets = OUT / 'assets'
    assets.mkdir(exist_ok=True)
    for name in ('site.css', 'site.js'):
        shutil.copyfile(Path(__file__).parent / name, assets / name)
    for original, name in [('ailang-logo-neural.png', 'logo.png'), ('ailang-banner-neural.png', 'banner.png')]:
        shutil.copyfile(ROOT / '.Результат' / 'Медіа' / original, assets / name)
    size = starter()
    write('index.html', landing('uk', size))
    write('en/index.html', landing('en', size))
    documentation('uk')
    documentation('en')
    manifest = {'version': VERSION, 'language': 'uk', 'developer': DEVELOPER, 'sourceFiles': HASHES, 'starter': STARTER_NAME}
    write('package.json', json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    # .nojekyll залишає доступними вкладені папки з крапкою на GitHub Pages.
    write('.nojekyll', '')
    for relative, expected in HASHES.items():
        if hashlib.sha256((SOURCE / relative).read_bytes()).hexdigest() != expected:
            raise ValueError('Джерело змінилося під час збирання')
    RELEASES.mkdir(parents=True, exist_ok=True)
    bundle = RELEASES / f'ailang-site-{VERSION}.zip'
    current_downloads = {STARTER_NAME, STARTER_NAME + '.sha256'}
    with zipfile.ZipFile(bundle, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(OUT.rglob('*')):
            if path.is_file():
                relative = path.relative_to(OUT)
                if relative.parts[0] == 'downloads' and relative.name not in current_downloads:
                    continue
                archive.write(path, relative.as_posix())
    print(f'Site: {OUT}\nUpload archive: {bundle}\nStarter: {OUT / "downloads" / STARTER_NAME}\nSource files preserved: {len(SOURCES)}')


if __name__ == '__main__':
    main()

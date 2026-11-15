/* Автор: Ruslan_A7 (RA7).
 * Розробник: Codex (GPT-6.1 Sol) від OpenAI під управлінням RA7.
 * Створено з використанням AILang.
 * Ліцензія: RA7 Open Free License — https://ra7.iuid.cc/LICENSE.
 * Версія файла: 0.9.0. */
(() => {
  'use strict';
  document.documentElement.classList.remove('no-js');
  const menu = document.querySelector('[data-menu]');
  const navigation = document.getElementById('navigation');
  if (menu && navigation) {
    const close = () => { navigation.classList.remove('is-open'); menu.setAttribute('aria-expanded', 'false'); };
    menu.addEventListener('click', () => {
      const open = navigation.classList.toggle('is-open');
      menu.setAttribute('aria-expanded', String(open));
    });
    navigation.addEventListener('click', (event) => { if (event.target.closest('a')) close(); });
    document.addEventListener('keydown', (event) => { if (event.key === 'Escape') close(); });
    window.matchMedia('(min-width: 761px)').addEventListener('change', (event) => { if (event.matches) close(); });
  }

  document.querySelectorAll('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const target = document.getElementById(button.dataset.copy);
      const status = document.getElementById('copy-status');
      if (!target) return;
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(target.textContent);
        } else {
          const area = document.createElement('textarea');
          area.value = target.textContent;
          area.setAttribute('readonly', '');
          area.style.cssText = 'position:fixed;left:-9999px;top:0';
          document.body.append(area);
          let copied = false;
          try { area.select(); copied = document.execCommand('copy'); }
          finally { area.remove(); button.focus(); }
          if (!copied) throw new Error('Clipboard unavailable');
        }
        if (status) status.textContent = button.dataset.success;
      } catch {
        if (status) status.textContent = button.dataset.failure;
      }
    });
  });

  const search = document.getElementById('doc-search');
  const results = document.getElementById('search-results');
  const config = window.AILANG_DOCS;
  if (!search || !results || !config) return;
  const normalize = (value) => value.toLocaleLowerCase().replace(/[’'ʼ]/g, '');
  let timeout;
  const render = () => {
    const query = search.value.trim().slice(0, 160);
    results.replaceChildren();
    results.hidden = !query;
    if (!query) return;
    const words = normalize(query).split(/\s+/);
    const matches = config.documents.filter((doc) => words.every((word) => normalize(`${doc.title} ${doc.text}`).includes(word)));
    const heading = document.createElement('h2');
    heading.textContent = config.resultsLabel;
    const summary = document.createElement('p');
    summary.setAttribute('role', 'status');
    summary.textContent = matches.length ? `${config.resultsLabel} ${matches.length}` : config.empty;
    results.append(heading, summary);
    const list = document.createElement('ul');
    matches.forEach((doc) => {
      const item = document.createElement('li');
      const link = document.createElement('a');
      link.href = `${doc.slug}.html`;
      link.textContent = doc.title;
      const snippet = document.createElement('p');
      const position = Math.max(0, normalize(doc.text).indexOf(words[0]) - 55);
      snippet.textContent = `${position ? '…' : ''}${doc.text.slice(position, position + 190).replace(/\s+/g, ' ')}…`;
      item.append(link, snippet);
      list.append(item);
    });
    results.append(list);
  };
  search.addEventListener('input', () => { clearTimeout(timeout); timeout = setTimeout(render, 150); });
  search.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') { search.value = ''; render(); }
    if (event.key === 'Enter') { clearTimeout(timeout); render(); }
  });
})();

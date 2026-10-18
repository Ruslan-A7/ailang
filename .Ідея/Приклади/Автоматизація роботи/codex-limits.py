"""Читання лише залишків лімітів через локальний протокол Codex, без доступу до секретів."""
import json
import queue
import shutil
import subprocess
import threading
import time


def main():
    executable = shutil.which('codex')
    if not executable:
        raise RuntimeError('Codex CLI недоступний.')
    process = subprocess.Popen([executable, '--no-daemon', 'app-server', '--stdio'], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               text=True, encoding='utf-8', creationflags=subprocess.CREATE_NO_WINDOW)
    messages = queue.Queue()

    def receive():
        for line in process.stdout:
            try:
                messages.put(json.loads(line))
            except ValueError:
                continue

    threading.Thread(target=receive, daemon=True).start()

    def send(value):
        process.stdin.write(json.dumps(value) + '\n')
        process.stdin.flush()

    def response(identifier):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            try:
                message = messages.get(timeout=1)
            except queue.Empty:
                continue
            if message.get('id') == identifier:
                if 'error' in message:
                    details = str(message['error'].get('message', '')).lower()
                    reasons = [value for value in ['api key', 'not supported', 'not logged', '401', '403', 'error sending request', 'failed to fetch', 'not available'] if value in details]
                    raise RuntimeError(f'Codex: request={identifier}, code={message["error"].get("code", "unknown")}, hints={reasons}.')
                return message.get('result', {})
        raise RuntimeError('Час очікування відповіді Codex вичерпано.')

    try:
        send({'id': 1, 'method': 'initialize', 'params': {'clientInfo': {'name': 'shm_limits', 'version': '0.1.48'}, 'capabilities': {'experimentalApi': True}}})
        response(1)
        send({'method': 'initialized', 'params': {}})
        send({'id': 2, 'method': 'account/rateLimits/read', 'params': {'excludeResetCreditDetails': True}})
        result = response(2)
        limits = result.get('rateLimits', {})
        # Друкуються лише відсотки, тривалість вікон і момент поновлення.
        sanitized = {}
        for name in ['primary', 'secondary']:
            window = limits.get(name)
            if isinstance(window, dict):
                sanitized[name] = {key: window.get(key) for key in ['usedPercent', 'windowDurationMins', 'resetsAt']}
        if not sanitized:
            raise RuntimeError('Залишки лімітів невідомі.')
        print(json.dumps(sanitized))
    finally:
        process.stdin.close()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.terminate()


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(str(error))
        raise SystemExit(1)

@{
    # Відносно цієї папки. Для розміщення tools/automation це корінь проєкту.
    ProjectRoot = '../..'
    StateDirectory = '.runtime/automation'
    DisplayName = 'Автоматизація Codex'
    TaskPrefix = 'CodexAutomation'
    FirstDelaySeconds = 11100
    CycleDelaySeconds = 18000
    # Порожнє значення: знайти codex.exe через PATH поточного користувача.
    CodexExecutable = ''
    MessageFile = 'resume-message.txt'
}

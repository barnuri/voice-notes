using System.Runtime.InteropServices;
using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;
using VoiceNotes.Windows.Native;

namespace VoiceNotes.Windows.Services;

internal sealed unsafe class SendInputTextTyper : ITextTyper
{
    private const string BlockedMessage =
        "VoiceNotes can't type into the active window. That window may run as administrator. The text is on the clipboard. Press Ctrl+V to paste it.";
    private const string ClipboardFailedMessage =
        "VoiceNotes can't type into the active window, and it can't copy the text to the clipboard.";
    private const int ClipboardRetryCount = 5;
    private const int ClipboardRetryDelayMilliseconds = 100;

    public void Type(string text)
    {
        if (ForegroundWindowRejectsInput() || !SendUnicode(text))
        {
            CopyToClipboard(text);
            throw new DictationException(BlockedMessage);
        }
    }

    private static bool SendUnicode(string text)
    {
        var inputs = new Input[text.Length * 2];
        for (var index = 0; index < text.Length; index++)
        {
            inputs[index * 2] = UnicodeKey(text[index], User32.KeyEventUnicode);
            inputs[(index * 2) + 1] = UnicodeKey(text[index], User32.KeyEventUnicode | User32.KeyEventKeyUp);
        }
        fixed (Input* first = inputs)
        {
            return User32.SendInput((uint)inputs.Length, first, sizeof(Input)) == inputs.Length;
        }
    }

    private static Input UnicodeKey(char codeUnit, uint flags) => new()
    {
        Type = User32.InputKeyboard,
        Union = new InputUnion { Keyboard = new KeyboardInput { ScanCode = codeUnit, Flags = flags } },
    };

    // Windows silently drops SendInput into a process with higher integrity (UIPI), so detect that case up front.
    // A token that VoiceNotes can't open counts as higher integrity.
    private static bool ForegroundWindowRejectsInput()
    {
        if (Environment.IsPrivilegedProcess)
        {
            return false;
        }
        User32.GetWindowThreadProcessId(User32.GetForegroundWindow(), out var processId);
        if (processId == 0)
        {
            return false;
        }
        var process = Kernel32.OpenProcess(Kernel32.ProcessQueryLimitedInformation, inheritHandle: false, processId);
        if (process == 0)
        {
            return false;
        }
        try
        {
            if (!Advapi32.OpenProcessToken(process, Advapi32.TokenQuery, out var token))
            {
                return true;
            }
            try
            {
                uint elevated = 0;
                return Advapi32.GetTokenInformation(token, Advapi32.TokenElevationClass, &elevated, sizeof(uint), out _)
                    && elevated != 0;
            }
            finally
            {
                Kernel32.CloseHandle(token);
            }
        }
        finally
        {
            Kernel32.CloseHandle(process);
        }
    }

    private static void CopyToClipboard(string text)
    {
        try
        {
            Clipboard.SetDataObject(text, copy: true, ClipboardRetryCount, ClipboardRetryDelayMilliseconds);
        }
        catch (ExternalException error)
        {
            throw new DictationException(ClipboardFailedMessage, error);
        }
    }
}

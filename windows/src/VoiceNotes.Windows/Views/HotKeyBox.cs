using System.ComponentModel;
using System.Media;
using VoiceNotes.Core.Models;
using VoiceNotes.Windows.Native;

namespace VoiceNotes.Windows.Views;

internal sealed class HotKeyBox : TextBox
{
    private const int PressedMask = 0x8000;
    private HotKey hotKey = HotKey.DefaultDictation;

    internal HotKeyBox()
    {
        ReadOnly = true;
        ShortcutsEnabled = false;
        BackColor = SystemColors.Window;
        Cursor = Cursors.Hand;
    }

    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    internal HotKey HotKey
    {
        get => hotKey;
        set
        {
            hotKey = value;
            Text = value.DisplayString;
        }
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        var key = keyData & Keys.KeyCode;
        var modifiers = ModifiersFrom(keyData);
        var isNavigationKey = key is Keys.Tab or Keys.Escape or Keys.Return;
        if (isNavigationKey && (modifiers & ~HotKeyModifiers.Shift) == HotKeyModifiers.None)
        {
            return base.ProcessCmdKey(ref msg, keyData);
        }
        if (IsModifierKey(key))
        {
            return true;
        }
        if (!IsUsableShortcut(key, modifiers))
        {
            SystemSounds.Beep.Play();
            return true;
        }
        HotKey = new HotKey(modifiers, (int)key, LabelFor(key));
        return true;
    }

    private static HotKeyModifiers ModifiersFrom(Keys keyData)
    {
        var modifiers = HotKeyModifiers.None;
        if (keyData.HasFlag(Keys.Control))
        {
            modifiers |= HotKeyModifiers.Control;
        }
        if (keyData.HasFlag(Keys.Alt))
        {
            modifiers |= HotKeyModifiers.Alt;
        }
        if (keyData.HasFlag(Keys.Shift))
        {
            modifiers |= HotKeyModifiers.Shift;
        }
        if (IsPressed(User32.VkLeftWindows) || IsPressed(User32.VkRightWindows))
        {
            modifiers |= HotKeyModifiers.Windows;
        }
        return modifiers;
    }

    private static bool IsPressed(int virtualKey) => (User32.GetKeyState(virtualKey) & PressedMask) != 0;

    private static bool IsModifierKey(Keys key) =>
        key is Keys.ShiftKey or Keys.ControlKey or Keys.Menu or Keys.LWin or Keys.RWin
            or Keys.LShiftKey or Keys.RShiftKey or Keys.LControlKey or Keys.RControlKey or Keys.LMenu or Keys.RMenu;

    private static bool IsFunctionKey(Keys key) => key is >= Keys.F1 and <= Keys.F24;

    private static bool IsUsableShortcut(Keys key, HotKeyModifiers modifiers)
    {
        var withoutShift = modifiers & ~HotKeyModifiers.Shift;
        return withoutShift != HotKeyModifiers.None || IsFunctionKey(key);
    }

    private static string LabelFor(Keys key) => key switch
    {
        >= Keys.D0 and <= Keys.D9 => ((char)('0' + (key - Keys.D0))).ToString(),
        >= Keys.NumPad0 and <= Keys.NumPad9 => $"Num {key - Keys.NumPad0}",
        Keys.Return => "Enter",
        Keys.Back => "Backspace",
        Keys.Prior => "PageUp",
        Keys.Next => "PageDown",
        Keys.Escape => "Esc",
        Keys.OemMinus => "-",
        Keys.Oemplus => "=",
        Keys.Oemcomma => ",",
        Keys.OemPeriod => ".",
        Keys.OemQuestion => "/",
        Keys.OemSemicolon => ";",
        Keys.OemQuotes => "'",
        Keys.OemOpenBrackets => "[",
        Keys.OemCloseBrackets => "]",
        Keys.OemPipe => "\\",
        Keys.Oemtilde => "`",
        _ => key.ToString(),
    };
}

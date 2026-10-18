using VoiceNotes.Core.Models;
using VoiceNotes.Windows.Native;

namespace VoiceNotes.Windows.Services;

internal sealed class GlobalHotKey : NativeWindow, IDisposable
{
    private const int HotKeyId = 0x564E;
    private bool registered;

    internal GlobalHotKey()
    {
        CreateHandle(new CreateParams { Parent = User32.MessageOnlyParent });
    }

    internal event EventHandler? Pressed;

    internal bool Register(HotKey hotKey)
    {
        Unregister();
        registered = User32.RegisterHotKey(Handle, HotKeyId, (uint)hotKey.Modifiers | User32.ModNoRepeat, (uint)hotKey.VirtualKey);
        return registered;
    }

    internal void Unregister()
    {
        if (!registered)
        {
            return;
        }
        User32.UnregisterHotKey(Handle, HotKeyId);
        registered = false;
    }

    public void Dispose()
    {
        Unregister();
        DestroyHandle();
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == User32.WmHotKey && m.WParam == HotKeyId)
        {
            Pressed?.Invoke(this, EventArgs.Empty);
            return;
        }
        base.WndProc(ref m);
    }
}

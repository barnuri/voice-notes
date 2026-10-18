using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

[StructLayout(LayoutKind.Sequential)]
internal struct MouseInput
{
    public int X;
    public int Y;
    public uint MouseData;
    public uint Flags;
    public uint Time;
    public nint ExtraInfo;
}

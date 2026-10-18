using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

[StructLayout(LayoutKind.Sequential)]
internal struct Input
{
    public uint Type;
    public InputUnion Union;
}
